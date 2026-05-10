import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import untuk .env
import '../theme/app_colors.dart';
import 'cart_manager.dart';
import 'midtrans_payment_page.dart';

class CustomerCartPage extends StatefulWidget {
  const CustomerCartPage({super.key});

  @override
  State<CustomerCartPage> createState() => _CustomerCartPageState();
}

class _CustomerCartPageState extends State<CustomerCartPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isProcessing = false;

  // Data perhitungan pengiriman
  double _jarakMeter = 0;
  double _ongkir = 0;
  Map<String, dynamic>? _tokoInfo;
  Position? _customerPos; // Untuk menyimpan kordinat asli customer

  @override
  void initState() {
    super.initState();
    _hitungOngkirOtomatis();
  }

  // --- FUNGSI FORMAT RUPIAH ---
  String _formatRupiah(dynamic amount) {
    String result = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  // --- LOGIKA HITUNG JARAK & ONGKIR ---
  Future<void> _hitungOngkirOtomatis() async {
    if (CartManager.instance.cartItems.value.isEmpty) return;

    try {
      String idToko = CartManager.instance.cartItems.value.first['id_toko'];

      DocumentSnapshot tokoDoc = await FirebaseFirestore.instance.collection('toko').doc(idToko).get();
      _tokoInfo = tokoDoc.data() as Map<String, dynamic>;
      
      double tokoLat = _tokoInfo!['latitude'];
      double tokoLng = _tokoInfo!['longitude'];
      double tarifPerKm = (_tokoInfo!['tarif_ongkir_per_km'] ?? 0).toDouble();

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      double distanceInMeters = Geolocator.distanceBetween(tokoLat, tokoLng, pos.latitude, pos.longitude);
      
      setState(() {
        _customerPos = pos;
        _jarakMeter = distanceInMeters;
        _ongkir = (distanceInMeters / 1000) * tarifPerKm;
        if (_ongkir < 5000) _ongkir = 5000; // Minimal ongkir
      });
    } catch (e) {
      print("Gagal hitung ongkir: $e");
    }
  }

  // Format Jarak Sesuai Permintaan (m -> km)
  String _formatJarak(double meter) {
    if (meter < 1000) {
      return "${meter.toInt()} m";
    } else {
      double km = meter / 1000;
      return "${km.toStringAsFixed(1)} km";
    }
  }

  // --- PROSES CHECKOUT (COD / MIDTRANS) ---
  Future<void> _checkout(String metode) async {
    if (_customerPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sedang memuat lokasi, mohon tunggu sebentar...')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      String idToko = CartManager.instance.cartItems.value.first['id_toko'];
      double subtotal = CartManager.instance.getTotalPrice();
      double totalBayar = subtotal + _ongkir;
      String orderId = 'DIMSUM-${DateTime.now().millisecondsSinceEpoch}'; // ID Unik

      final pesananData = {
        'order_id': orderId,
        'id_customer': user!.uid,
        'nama_customer': user!.displayName ?? 'Pelanggan',
        'id_toko': idToko,
        'nama_toko': _tokoInfo?['nama_toko'],
        'items': CartManager.instance.cartItems.value,
        'subtotal': subtotal,
        'ongkir': _ongkir,
        'total_bayar': totalBayar,
        'jarak_teks': _formatJarak(_jarakMeter),
        'latitude_customer': _customerPos!.latitude,   // Fix lokasi customer
        'longitude_customer': _customerPos!.longitude, // Fix lokasi customer
        'metode_bayar': metode,
        'status_pesanan': metode == 'COD' ? 'Sedang Disiapkan' : 'Menunggu Pembayaran',
        'waktu_pesan': FieldValue.serverTimestamp(),
      };

      // 1. Simpan ke Firestore
      DocumentReference docRef = await FirebaseFirestore.instance.collection('pesanan').add(pesananData);

      // 2. Logika Berdasarkan Metode
      if (metode == 'COD') {
        CartManager.instance.clearCart();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan COD Berhasil! Restoran sedang menyiapkan.'), backgroundColor: Colors.green));
        }
      } else if (metode == 'Midtrans') {
        // --- API MIDTRANS SANDBOX DENGAN .ENV ---
        String serverKey = dotenv.env['MIDTRANS_SERVER_KEY'] ?? ''; 
        String basicAuth = 'Basic ${base64Encode(utf8.encode('$serverKey:'))}';

        final response = await http.post(
          Uri.parse('https://app.sandbox.midtrans.com/snap/v1/transactions'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': basicAuth,
          },
          body: jsonEncode({
            "transaction_details": {
              "order_id": orderId,
              "gross_amount": totalBayar.toInt(),
            },
            "customer_details": {
              "first_name": user!.displayName ?? 'Pelanggan',
              "email": user!.email ?? 'customer@dimsum.com',
            }
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          final redirectUrl = jsonDecode(response.body)['redirect_url'];
          if (mounted) {
            // Pindah ke WebView Midtrans
            Navigator.push(context, MaterialPageRoute(builder: (_) => MidtransPaymentPage(url: redirectUrl, docId: docRef.id)));
          }
        } else {
          throw 'Gagal menghubungi Midtrans: ${response.body}';
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Warna background ala Android
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.primaryOrange,
        title: const Text('Checkout Pesanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: CartManager.instance.cartItems,
        builder: (context, cart, child) {
          if (cart.isEmpty) return const Center(child: Text('Keranjang Kosong', style: TextStyle(fontSize: 16, color: Colors.grey)));

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    const Text('Ringkasan Belanja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 12),
                    
                    // Desain List Item ala Android (Pakai Card)
                    ...cart.map((item) => Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.fastfood, color: AppColors.primaryOrange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['nama_produk'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(_formatRupiah(item['harga_final']), style: const TextStyle(color: Colors.grey, fontSize: 13)), // Format Rupiah
                                ],
                              ),
                            ),
                            Text('${item['qty']}x', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                          ],
                        ),
                      ),
                    )),
                    
                    const SizedBox(height: 20),
                    
                    // Info Pengiriman & Jarak
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.delivery_dining, color: AppColors.primaryOrange, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text('Info Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const Spacer(),
                              Flexible(child: Text(_tokoInfo?['nama_toko'] ?? 'Memuat...', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Jarak ke Toko', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            Text(_formatJarak(_jarakMeter), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ]),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Ongkos Kirim', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            Text(_formatRupiah(_ongkir), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)), // Format Rupiah
                          ]),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              // Bagian Total & Tombol Bayar bergaya Bottom Sheet melayang
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                decoration: const BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total Pembayaran', style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.w500)),
                        Text(_formatRupiah(CartManager.instance.getTotalPrice() + _ongkir), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryOrange)), // Format Rupiah
                      ]),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16), 
                                side: const BorderSide(color: AppColors.primaryOrange, width: 1.5), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              onPressed: _isProcessing ? null : () => _checkout('COD'),
                              child: const Text('BAYAR COD', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: AppColors.primaryOrange, 
                                padding: const EdgeInsets.symmetric(vertical: 16), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              ),
                              onPressed: _isProcessing ? null : () => _checkout('Midtrans'),
                              child: _isProcessing 
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('MIDTRANS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}