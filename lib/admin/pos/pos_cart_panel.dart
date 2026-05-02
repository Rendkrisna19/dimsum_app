import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../theme/app_colors.dart';

class PosCartPanel extends StatefulWidget {
  final String idToko;
  final List<Map<String, dynamic>> cartItems;
  final Function() onClearCart;
  final Function(int, int) onUpdateQty; 

  const PosCartPanel({
    super.key,
    required this.idToko,
    required this.cartItems,
    required this.onClearCart,
    required this.onUpdateQty,
  });

  @override
  State<PosCartPanel> createState() => _PosCartPanelState();
}

class _PosCartPanelState extends State<PosCartPanel> {
  final _uangPelangganController = TextEditingController();
  bool _isLoading = false;
  String _metodeBayar = 'Tunai'; // Pilihan: Tunai, Non-Tunai (QRIS/Transfer)

  double get _totalBelanja {
    return widget.cartItems.fold(0, (sum, item) => sum + (item['harga_final'] * item['qty']));
  }

  Future<void> _prosesPembayaran(BuildContext context) async {
    double uangPelanggan = 0;
    double kembalian = 0;

    // Logika Tunai vs Non-Tunai
    if (_metodeBayar == 'Tunai') {
      uangPelanggan = double.tryParse(_uangPelangganController.text) ?? 0;
      if (uangPelanggan < _totalBelanja) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uang pelanggan kurang!'), backgroundColor: Colors.red));
        return;
      }
      kembalian = uangPelanggan - _totalBelanja;
    } else {
      // Jika Non-Tunai (QRIS), uang pelanggan otomatis pas (sama dengan total belanja)
      uangPelanggan = _totalBelanja;
      kembalian = 0;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Ambil Data Nama Toko & Alamat dari Firebase untuk keperluan struk
      DocumentSnapshot tokoDoc = await FirebaseFirestore.instance.collection('toko').doc(widget.idToko).get();
      String namaToko = tokoDoc.data() != null ? (tokoDoc.data() as Map<String, dynamic>)['nama_toko'] ?? 'Dimsum App' : 'Dimsum App';
      String alamatToko = tokoDoc.data() != null ? (tokoDoc.data() as Map<String, dynamic>)['alamat_toko'] ?? '' : '';

      // 2. Simpan Transaksi ke Database
      final transaksiData = {
        'id_toko': widget.idToko, // <-- Wajib untuk Multi-Tenant
        'total_belanja': _totalBelanja,
        'uang_pelanggan': uangPelanggan,
        'kembalian': kembalian,
        'metode_bayar': _metodeBayar, // 'Tunai' atau 'Non-Tunai (QRIS/Transfer)'
        'waktu_beli': FieldValue.serverTimestamp(),
        'kasir': 'Admin Kasir', 
        'daftar_belanjaan': widget.cartItems.map((item) => {
          'id_produk': item['id'],
          'nama_produk': item['nama_produk'],
          'harga_satuan': item['harga_final'],
          'jumlah_beli': item['qty'],
          'subtotal': item['harga_final'] * item['qty'],
          'harga_modal_satuan': item['harga_modal'] 
        }).toList(),
      };

      await FirebaseFirestore.instance.collection('transaksi_kasir').add(transaksiData);

      // 3. Kurangi Stok Produk
      for (var item in widget.cartItems) {
        final docRef = FirebaseFirestore.instance.collection('produk').doc(item['id']);
        await docRef.update({'stok': FieldValue.increment(-item['qty'])});
      }

      // 4. Cetak Struk (PDF)
      await _cetakStrukThermal(namaToko, alamatToko, uangPelanggan, kembalian);

      if (mounted) {
        _uangPelangganController.clear();
        widget.onClearCart();
        Navigator.maybePop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran berhasil & Struk dicetak!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // LOGIKA PEMBUATAN PDF STRUK (UKURAN KERTAS ROLL 80mm THERMAL)
  Future<void> _cetakStrukThermal(String namaToko, String alamatToko, double uangPelanggan, double kembalian) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Format kertas thermal 80mm
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(namaToko, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              if (alamatToko.isNotEmpty)
                pw.Center(child: pw.Text(alamatToko, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
              pw.SizedBox(height: 10),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Text('Metode Bayar: $_metodeBayar', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Tgl: ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 5),
              
              // Daftar Belanja
              ...widget.cartItems.map((item) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item['nama_produk'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${item['qty']} x Rp ${item['harga_final'].toInt()}', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Rp ${(item['harga_final'] * item['qty']).toInt()}', style: const pw.TextStyle(fontSize: 12)),
                      ]
                    ),
                    pw.SizedBox(height: 5),
                  ]
                );
              }),
              
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)), pw.Text('Rp ${_totalBelanja.toInt()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Bayar', style: const pw.TextStyle(fontSize: 12)), pw.Text('Rp ${uangPelanggan.toInt()}', style: const pw.TextStyle(fontSize: 12))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Kembali', style: const pw.TextStyle(fontSize: 12)), pw.Text('Rp ${kembalian.toInt()}', style: const pw.TextStyle(fontSize: 12))]),
              pw.SizedBox(height: 15),
              pw.Center(child: pw.Text('Terima Kasih atas Kunjungan Anda!', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))),
              pw.SizedBox(height: 20), // Margin bawah untuk potongan thermal
            ]
          );
        },
      ),
    );

    // Membuka UI Print Preview (Bisa langsung dihubungkan ke printer Bluetooth/WiFi di HP)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Struk_POS_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // HEADER KERANJANG
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            color: AppColors.background,
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close, color: AppColors.textDark), onPressed: () => Navigator.maybePop(context)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Keranjang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark))),
                if (widget.cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: widget.onClearCart,
                    icon: const Icon(Icons.delete_sweep, color: AppColors.fireRed, size: 20),
                    label: const Text('Kosongkan', style: TextStyle(color: AppColors.fireRed)),
                  )
              ],
            ),
          ),
          
          // DAFTAR BARANG
          Expanded(
            child: widget.cartItems.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('Keranjang masih kosong', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = widget.cartItems[index];
                      return Container(
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Text(item['nama_produk'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text('Rp ${item['harga_final'].toInt()}  x  ${item['qty']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => widget.onUpdateQty(index, 0),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.fireOrange),
                                onPressed: () => widget.onUpdateQty(index, item['qty'] - 1),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.fireOrange),
                                onPressed: () {
                                  if (item['qty'] < item['stok']) {
                                    widget.onUpdateQty(index, item['qty'] + 1);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak cukup!'), duration: Duration(seconds: 1)));
                                  }
                                },
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // BAGIAN PEMBAYARAN BAWAH
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -5))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Belanja', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text('Rp ${_totalBelanja.toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  ],
                ),
                const SizedBox(height: 15),
                if (widget.cartItems.isNotEmpty) ...[
                  // PILIHAN METODE BAYAR
                  DropdownButtonFormField<String>(
                    value: _metodeBayar,
                    decoration: InputDecoration(
                      labelText: 'Metode Pembayaran',
                      prefixIcon: const Icon(Icons.account_balance_wallet, color: AppColors.fireOrange),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                    items: ['Tunai', 'Non-Tunai (QRIS/Transfer)'].map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _metodeBayar = val!;
                        // Kosongkan form uang pelanggan jika pindah metode
                        _uangPelangganController.clear(); 
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  
                  // INPUT UANG HANYA JIKA TUNAI
                  if (_metodeBayar == 'Tunai') ...[
                    TextField(
                      controller: _uangPelangganController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Uang Tunai Pelanggan (Rp)',
                        prefixIcon: const Icon(Icons.money, color: Colors.green),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.fireOrange, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  // TOMBOL PROSES
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.fireRed, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      onPressed: _isLoading ? null : () => _prosesPembayaran(context),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('PROSES & CETAK STRUK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}