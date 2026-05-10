import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../auth/login_page.dart'; 

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final user = FirebaseAuth.instance.currentUser;
  String _selectedFilter = 'Bulan Ini'; 

  // State Data Dashboard
  bool _isLoading = true;
  String _adminName = 'Admin';
  double _totalPendapatan = 0;
  int _pesananBaru = 0;
  int _menuAktif = 0;
  int _stokMenipis = 0;
  int _totalTransaksi = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  // LOGIKA MENGAMBIL DATA DENGAN DART-SIDE FILTERING (ANTI ERROR FIREBASE)
  Future<void> _fetchDashboardData() async {
    if (user == null) return;
    
    setState(() => _isLoading = true);

    try {
      // 1. Ambil Data Admin (ID Toko & Nama Asli)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userData = userDoc.data();
      final String? idToko = userData?['id_toko'];
      
      if (userData != null && userData['name'] != null) {
        _adminName = userData['name'].split(' ')[0]; // Ambil nama depan
      }

      if (idToko == null) {
        if (mounted) setState(() => _isLoading = false);
        return; 
      }

      // 2. Hitung Tanggal Batas Bawah Berdasarkan Filter
      DateTime now = DateTime.now();
      DateTime startDate;
      if (_selectedFilter == 'Hari Ini') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (_selectedFilter == 'Minggu Ini') {
        startDate = now.subtract(const Duration(days: 7));
      } else {
        startDate = DateTime(now.year, now.month, 1); 
      }

      double sumPendapatan = 0;
      int countTransaksi = 0;
      int countPesananBaru = 0;

      // 3. Tarik Data TRANSAKSI KASIR (Offline)
      final kasirSnap = await FirebaseFirestore.instance.collection('transaksi_kasir').where('id_toko', isEqualTo: idToko).get();
      for (var doc in kasirSnap.docs) {
        final data = doc.data();
        Timestamp? t = data['waktu_beli'];
        if (t != null && (t.toDate().isAfter(startDate) || t.toDate().isAtSameMomentAs(startDate))) {
          sumPendapatan += (data['total_belanja'] ?? 0).toDouble();
          countTransaksi++;
        }
      }

      // 4. Tarik Data PESANAN ONLINE (Midtrans / COD)
      final pesananSnap = await FirebaseFirestore.instance.collection('pesanan').where('id_toko', isEqualTo: idToko).get();
      for (var doc in pesananSnap.docs) {
        final data = doc.data();
        Timestamp? t = data['waktu_pesan'];
        String status = data['status_pesanan'] ?? '';

        // Hitung Pendapatan & Jumlah Transaksi Online (Filter waktu)
        if (t != null && (t.toDate().isAfter(startDate) || t.toDate().isAtSameMomentAs(startDate))) {
          // Hanya hitung yang sudah masuk proses / selesai
          if (status == 'Sedang Disiapkan' || status == 'Sedang Diantar' || status == 'Selesai') {
            sumPendapatan += (data['total_bayar'] ?? 0).toDouble();
            countTransaksi++;
          }
        }

        // Hitung Pesanan Baru yang butuh tindakan koki/admin
        if (status == 'Sedang Disiapkan') {
          countPesananBaru++;
        }
      }

      // 5. Tarik Data PRODUK (Menu & Stok)
      final produkSnap = await FirebaseFirestore.instance.collection('produk').where('id_toko', isEqualTo: idToko).get();
      int countMenu = produkSnap.docs.length;
      int countStok = 0;
      for (var doc in produkSnap.docs) {
        num stok = doc.data()['stok'] ?? 0;
        if (stok <= 5) countStok++; // Stok menipis
      }

      // Update State UI
      if (mounted) {
        setState(() {
          _totalPendapatan = sumPendapatan;
          _menuAktif = countMenu;
          _stokMenipis = countStok;
          _pesananBaru = countPesananBaru;
          _totalTransaksi = countTransaksi;
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

  // Fungsi Logout
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData, // Bisa ditarik ke bawah untuk refresh
        color: AppColors.fireOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Agar selalu bisa di-scroll & refresh
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER GRADASI TEMA API
              Container(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.fireRed, AppColors.fireOrange],
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
                        Text(
                          'Halo, $_adminName 👋',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Pantau performa bisnismu hari ini.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_active, color: Colors.white),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                          child: IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: () => _logout(context),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // 2. KARTU PENDAPATAN (REVENUE CARD) DENGAN FILTER
              Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pendapatan', style: TextStyle(color: AppColors.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                          // DROPDOWN FILTER
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.fireOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                icon: const Icon(Icons.arrow_drop_down, color: AppColors.fireOrange),
                                style: const TextStyle(color: AppColors.fireOrange, fontWeight: FontWeight.bold, fontSize: 12),
                                items: ['Hari Ini', 'Minggu Ini', 'Bulan Ini'].map((String value) {
                                  return DropdownMenuItem<String>(value: value, child: Text(value));
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() => _selectedFilter = newValue!);
                                  _fetchDashboardData(); 
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      // ANGKA PENDAPATAN DARI FIRESTORE
                      _isLoading
                        ? const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: LinearProgressIndicator(color: AppColors.fireOrange))
                        : Text(
                            'Rp ${_totalPendapatan.toInt()}', 
                            style: const TextStyle(color: AppColors.textDark, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                      
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.trending_up, color: Colors.green, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Text('$_totalTransaksi transaksi ($_selectedFilter)', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      )
                    ],
                  ),
                ),
              ),

              // 3. STATISTIK CEPAT (GRID)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ringkasan Aktivitas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    if (_isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.fireOrange, strokeWidth: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.5,
                  children: [
                    _buildStatCard('Antrean Online', '$_pesananBaru', Icons.delivery_dining, AppColors.fireOrange),
                    _buildStatCard('Menu Aktif', '$_menuAktif', Icons.fastfood, Colors.blue),
                    _buildStatCard('Total Transaksi', '$_totalTransaksi', Icons.receipt_long, Colors.purple),
                    _buildStatCard('Stok Menipis', '$_stokMenipis', Icons.warning_rounded, _stokMenipis > 0 ? Colors.red : Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Widget Helper untuk Kartu Statistik
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ],
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: AppColors.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}