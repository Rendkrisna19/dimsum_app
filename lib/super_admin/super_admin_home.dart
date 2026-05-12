import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class SuperAdminHome extends StatefulWidget {
  const SuperAdminHome({super.key});

  @override
  State<SuperAdminHome> createState() => _SuperAdminHomeState();
}

class _SuperAdminHomeState extends State<SuperAdminHome> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  // State Data Platform
  int _totalTenant = 0;
  int _totalUser = 0;
  double _gmvPlatform = 0;
  List<Map<String, dynamic>> _topTenants = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // Menarik Semua Data Secara Real-Time / Aktual
  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Hitung Total User
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      int userCount = usersSnap.docs.length;

      // 2. Hitung Total Tenant (Cabang) & Simpan Nama Toko
      final tokoSnap = await FirebaseFirestore.instance.collection('toko').get();
      int tokoCount = tokoSnap.docs.length;
      
      Map<String, String> mapToko = {};
      for (var doc in tokoSnap.docs) {
        mapToko[doc.id] = doc.data()['nama_toko'] ?? 'Toko Unknown';
      }

      // 3. Hitung GMV (Pendapatan Global) Bulan Ini
      DateTime now = DateTime.now();
      DateTime startOfMonth = DateTime(now.year, now.month, 1);
      Timestamp startTimestamp = Timestamp.fromDate(startOfMonth);

      double totalGmv = 0;
      Map<String, double> omsetPerToko = {};

      // -- Tarik Data Pesanan Online --
      final pesananSnap = await FirebaseFirestore.instance.collection('pesanan')
          .where('waktu_pesan', isGreaterThanOrEqualTo: startTimestamp)
          .get();
          
      for (var doc in pesananSnap.docs) {
        final data = doc.data();
        String status = data['status_pesanan'] ?? '';
        
        if (status == 'Sedang Disiapkan' || status == 'Sedang Diantar' || status == 'Selesai') {
          double bayar = (data['total_bayar'] ?? 0).toDouble();
          String idToko = data['id_toko'] ?? '';
          
          totalGmv += bayar;
          omsetPerToko[idToko] = (omsetPerToko[idToko] ?? 0) + bayar;
        }
      }

      // -- Tarik Data Kasir Offline --
      final kasirSnap = await FirebaseFirestore.instance.collection('transaksi_kasir')
          .where('waktu_beli', isGreaterThanOrEqualTo: startTimestamp)
          .get();
          
      for (var doc in kasirSnap.docs) {
        final data = doc.data();
        double bayar = (data['total_belanja'] ?? 0).toDouble();
        String idToko = data['id_toko'] ?? '';
        
        totalGmv += bayar;
        omsetPerToko[idToko] = (omsetPerToko[idToko] ?? 0) + bayar;
      }

      // 4. Urutkan Tenant Berdasarkan Omzet (Top Performing)
      var sortedKeys = omsetPerToko.keys.toList(growable: false)
        ..sort((k1, k2) => omsetPerToko[k2]!.compareTo(omsetPerToko[k1]!));

      List<Map<String, dynamic>> top = [];
      int limit = sortedKeys.length > 5 ? 5 : sortedKeys.length; // Ambil Top 5
      for (int i = 0; i < limit; i++) {
        String idT = sortedKeys[i];
        top.add({
          'nama': mapToko[idT] ?? 'Cabang Terhapus',
          'omset': omsetPerToko[idT] ?? 0,
        });
      }

      if (mounted) {
        setState(() {
          _totalUser = userCount;
          _totalTenant = tokoCount;
          _gmvPlatform = totalGmv;
          _topTenants = top;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    }
  }

  // Format angka menjadi format Rupiah dengan pemisah titik
  String _formatRp(double val) {
    return 'Rp ${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  // Fungsi Singkatan untuk mengubah 1500 menjadi 1.5K
  String _formatK(int val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    String adminName = user?.displayName ?? 'Super Admin';
    if (adminName.contains(' ')) adminName = adminName.split(' ')[0];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData, // Fitur Tarik ke Bawah untuk Refresh
        color: AppColors.fireRed,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER KHUSUS SUPER ADMIN (Gradient Gelap / Merah)
              Container(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B0000), AppColors.fireRed], // Merah gelap ke merah terang (Kesan Otoritas)
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text('Halo, $adminName', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text('Pantau seluruh jaringan tenant Anda.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.notifications_active, color: Colors.white),
                        onPressed: () {},
                      ),
                    )
                  ],
                ),
              ),

              // 2. KARTU STATISTIK PLATFORM
              Transform.translate(
                offset: const Offset(0, -25),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildMainStatCard('Total Tenant', '$_totalTenant', Icons.storefront, Colors.blue)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildMainStatCard('Total User', _formatK(_totalUser), Icons.people_alt, Colors.purple)),
                    ],
                  ),
                ),
              ),

              // 3. KARTU PENDAPATAN GLOBAL (GMV)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 15, offset: const Offset(0, 10))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('GMV / Pendapatan Platform', style: TextStyle(color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                        Icon(Icons.trending_up, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoading 
                      ? const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator(color: AppColors.fireRed))
                      : Text(_formatRp(_gmvPlatform), style: const TextStyle(color: AppColors.textDark, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text('Bulan Ini (Semua Tenant)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 4. DAFTAR TENANT TERATAS (Top Performing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tenant Performa Terbaik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    if (_isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.fireRed, strokeWidth: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              
              _topTenants.isEmpty && !_isLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada transaksi bulan ini.', style: TextStyle(color: Colors.grey))))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _topTenants.length,
                    itemBuilder: (context, index) {
                      final toko = _topTenants[index];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: index == 0 ? Colors.amber.withOpacity(0.2) : AppColors.fireOrange.withOpacity(0.1), 
                                borderRadius: BorderRadius.circular(10)
                              ),
                              child: Icon(
                                index == 0 ? Icons.emoji_events : Icons.store, 
                                color: index == 0 ? Colors.amber.shade700 : AppColors.fireOrange
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(toko['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('Omset: ${_formatRp(toko['omset'])}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                              child: Text('#${index + 1}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                      );
                    },
                  ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 15),
          _isLoading 
            ? const SizedBox(height: 26, width: 26, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}