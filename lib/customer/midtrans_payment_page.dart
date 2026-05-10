import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'cart_manager.dart';

class MidtransPaymentPage extends StatefulWidget {
  final String url;
  final String docId; // ID dokumen pesanan di Firestore

  const MidtransPaymentPage({super.key, required this.url, required this.docId});

  @override
  State<MidtransPaymentPage> createState() => _MidtransPaymentPageState();
}

class _MidtransPaymentPageState extends State<MidtransPaymentPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSuccessHandled = false; // Mencegah update berkali-kali

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onUrlChange: (UrlChange change) {
            final url = change.url ?? '';
            // --- LOGIKA PENYADAPAN (INTERCEPTOR) TANPA WEBHOOK ---
            // Midtrans akan mengubah URL saat pembayaran berhasil (settlement/capture)
            if (!_isSuccessHandled && (url.contains('status_code=200') || url.contains('transaction_status=settlement') || url.contains('transaction_status=capture'))) {
              _isSuccessHandled = true;
              _handlePaymentSuccess();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handlePaymentSuccess() async {
    // 1. Update status pesanan di Firestore jadi "Sedang Disiapkan"
    await FirebaseFirestore.instance.collection('pesanan').doc(widget.docId).update({
      'status_pesanan': 'Sedang Disiapkan',
      'waktu_dibayar': FieldValue.serverTimestamp(),
    });

    // 2. Bersihkan Keranjang
    CartManager.instance.clearCart();

    // 3. Tampilkan Alert & Kembali ke Home
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 15),
              const Text('Pembayaran Berhasil!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Pesananmu sudah masuk ke toko dan sedang disiapkan.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: () {
                    // Kembali ke Halaman Utama (Tutup Dialog + Tutup WebView + Tutup Cart)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Pembayaran Aman', style: TextStyle(color: AppColors.textDark, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
        ],
      ),
    );
  }
}