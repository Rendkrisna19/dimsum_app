import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class SuperAdminReportPage extends StatefulWidget {
  const SuperAdminReportPage({super.key});

  @override
  State<SuperAdminReportPage> createState() => _SuperAdminReportPageState();
}

class _SuperAdminReportPageState extends State<SuperAdminReportPage> {
  bool _isLoading = true;

  // State Filter
  String _selectedDateFilter = 'Bulan Ini';
  String _selectedTokoId = 'semua'; // 'semua' berarti Semua Cabang
  List<Map<String, dynamic>> _listToko = [];

  // State Data Laporan
  double _totalPendapatan = 0;
  int _totalTransaksi = 0;
  int _pesananOnline = 0;
  int _transaksiOffline = 0;
  List<Map<String, dynamic>> _topProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchDaftarToko();
  }

  // 1. Ambil daftar cabang untuk Dropdown Filter
  Future<void> _fetchDaftarToko() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('toko').get();
      List<Map<String, dynamic>> tempToko = [];
      for (var doc in snap.docs) {
        tempToko.add({'id': doc.id, 'nama_toko': doc.data()['nama_toko']});
      }
      
      if (mounted) {
        setState(() {
          _listToko = tempToko;
        });
        _fetchLaporan(); // Lanjut tarik data laporan setelah toko didapat
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat cabang: $e')));
      }
    }
  }

  // 2. Tarik Data Laporan (Anti Error Composite Index dengan Dart-Side Filtering)
  Future<void> _fetchLaporan() async {
    setState(() => _isLoading = true);

    try {
      DateTime now = DateTime.now();
      DateTime startDate;
      if (_selectedDateFilter == 'Hari Ini') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (_selectedDateFilter == 'Minggu Ini') {
        startDate = now.subtract(const Duration(days: 7));
      } else if (_selectedDateFilter == 'Bulan Ini') {
        startDate = DateTime(now.year, now.month, 1);
      } else {
        startDate = DateTime(2000); // Semua Waktu
      }

      double sumPendapatan = 0;
      int countOnline = 0;
      int countOffline = 0;
      Map<String, int> productSales = {}; // Untuk menghitung produk terlaris

      // A. Tarik Data Pesanan Online (Delivery/Midtrans)
      Query queryOnline = FirebaseFirestore.instance.collection('pesanan');
      if (_selectedTokoId != 'semua') {
        queryOnline = queryOnline.where('id_toko', isEqualTo: _selectedTokoId);
      }
      final snapOnline = await queryOnline.get();

      for (var doc in snapOnline.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Timestamp? t = data['waktu_pesan'];
        String status = data['status_pesanan'] ?? '';

        if (t != null && (t.toDate().isAfter(startDate) || t.toDate().isAtSameMomentAs(startDate))) {
          // Hanya hitung yang sukses/valid
          if (status == 'Sedang Disiapkan' || status == 'Sedang Diantar' || status == 'Selesai') {
            sumPendapatan += (data['total_bayar'] ?? 0).toDouble();
            countOnline++;

            // Hitung item terjual
            List items = data['items'] ?? [];
            for (var item in items) {
              String namaProduk = item['nama_produk'] ?? 'Unknown';
              int qty = item['qty'] ?? 1;
              productSales[namaProduk] = (productSales[namaProduk] ?? 0) + qty;
            }
          }
        }
      }

      // B. Tarik Data Kasir Offline (POS)
      Query queryOffline = FirebaseFirestore.instance.collection('transaksi_kasir');
      if (_selectedTokoId != 'semua') {
        queryOffline = queryOffline.where('id_toko', isEqualTo: _selectedTokoId);
      }
      final snapOffline = await queryOffline.get();

      for (var doc in snapOffline.docs) {
        final data = doc.data() as Map<String, dynamic>;
        Timestamp? t = data['waktu_beli'];

        if (t != null && (t.toDate().isAfter(startDate) || t.toDate().isAtSameMomentAs(startDate))) {
          sumPendapatan += (data['total_belanja'] ?? 0).toDouble();
          countOffline++;

          // Hitung item terjual
          List items = data['daftar_belanjaan'] ?? [];
          for (var item in items) {
            String namaProduk = item['nama_produk'] ?? 'Unknown';
            int qty = item['jumlah_beli'] ?? 1; // di kasir menggunakan jumlah_beli
            productSales[namaProduk] = (productSales[namaProduk] ?? 0) + qty;
          }
        }
      }

      // C. Sorting Produk Terlaris
      var sortedKeys = productSales.keys.toList(growable: false)
        ..sort((k1, k2) => productSales[k2]!.compareTo(productSales[k1]!));
      
      List<Map<String, dynamic>> top = [];
      int limit = sortedKeys.length > 5 ? 5 : sortedKeys.length; // Ambil Top 5
      for (int i = 0; i < limit; i++) {
        top.add({
          'nama': sortedKeys[i],
          'terjual': productSales[sortedKeys[i]],
        });
      }

      if (mounted) {
        setState(() {
          _totalPendapatan = sumPendapatan;
          _pesananOnline = countOnline;
          _transaksiOffline = countOffline;
          _totalTransaksi = countOnline + countOffline;
          _topProducts = top;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat laporan: $e')));
      }
    }
  }

  // Format angka ke Rupiah simpel
  String _formatRp(double val) {
    return 'Rp ${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)]), // Warna Biru Gelap Mewah
          ),
        ),
        title: const Text('Laporan & Analitik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLaporan,
        color: AppColors.fireOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION 1: FILTER (DESAIN MEWAH) ---
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Filter Laporan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Dropdown Cabang
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedTokoId,
                                icon: const Icon(Icons.storefront, color: Colors.grey),
                                style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13),
                                items: [
                                  const DropdownMenuItem(value: 'semua', child: Text('Semua Cabang')),
                                  ..._listToko.map((toko) => DropdownMenuItem<String>(value: toko['id'], child: Text(toko['nama_toko']))),
                                ],
                                onChanged: (val) {
                                  setState(() => _selectedTokoId = val!);
                                  _fetchLaporan();
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Dropdown Waktu
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedDateFilter,
                                icon: const Icon(Icons.calendar_today, color: Colors.blue, size: 18),
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                items: ['Hari Ini', 'Minggu Ini', 'Bulan Ini', 'Semua Waktu'].map((String val) {
                                  return DropdownMenuItem<String>(value: val, child: Text(val));
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedDateFilter = val!);
                                  _fetchLaporan();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // --- SECTION 2: KARTU PENDAPATAN UTAMA ---
              _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.fireOrange))
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.fireRed, AppColors.fireOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [BoxShadow(color: AppColors.fireOrange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      children: [
                        const Text('Total Pendapatan', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 10),
                        Text(_formatRp(_totalPendapatan), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Total Transaksi', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  Text('$_totalTransaksi', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Container(height: 30, width: 1, color: Colors.white.withOpacity(0.5)),
                              Column(
                                children: [
                                  const Text('Cabang Dipantau', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  Text(_selectedTokoId == 'semua' ? '${_listToko.length}' : '1', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

              const SizedBox(height: 25),

              // --- SECTION 3: PERBANDINGAN ONLINE VS OFFLINE ---
              const Text('Sumber Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.delivery_dining, color: Colors.purple, size: 20)),
                          const SizedBox(height: 10),
                          Text('$_pesananOnline', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Text('Online (App)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.point_of_sale, color: Colors.teal, size: 20)),
                          const SizedBox(height: 10),
                          Text('$_transaksiOffline', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Text('Offline (Kasir)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- SECTION 4: TOP PRODUK TERLARIS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Menu Paling Laris', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  Icon(Icons.emoji_events, color: Colors.amber.shade600),
                ],
              ),
              const SizedBox(height: 15),
              _topProducts.isEmpty && !_isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data penjualan.', style: TextStyle(color: Colors.grey))))
                  : Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _topProducts.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                        itemBuilder: (context, index) {
                          final item = _topProducts[index];
                          // Visual Bar (Bar persentase terjual, asumsi maks 100 porsi di grafik agar terlihat proporsional)
                          double percentage = item['terjual'] / 100.0;
                          if (percentage > 1.0) percentage = 1.0; 

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: index == 0 ? Colors.amber.withOpacity(0.2) : Colors.grey.shade100,
                              child: Text('${index + 1}', style: TextStyle(color: index == 0 ? Colors.amber.shade800 : Colors.grey, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text('${item['terjual']} Porsi Terjual', style: const TextStyle(color: AppColors.fireOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                LinearProgressIndicator(
                                  value: percentage,
                                  backgroundColor: Colors.grey.shade200,
                                  color: index == 0 ? Colors.amber : AppColors.fireOrange,
                                  borderRadius: BorderRadius.circular(5),
                                  minHeight: 6,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}