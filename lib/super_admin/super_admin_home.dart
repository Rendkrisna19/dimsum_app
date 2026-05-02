import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class SuperAdminHome extends StatelessWidget {
  const SuperAdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String adminName = user?.displayName ?? 'Super Admin';
    if (adminName.contains(' ')) adminName = adminName.split(' ')[0];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
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
                    Expanded(child: _buildMainStatCard('Total Tenant', '12', Icons.storefront, Colors.blue)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildMainStatCard('Total User', '1.2K', Icons.people_alt, Colors.purple)),
                  ],
                ),
              ),
            ),

            // 3. KARTU PENDAPATAN GLOBAL
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
                  const Text('Rp 84.500.000', style: TextStyle(color: AppColors.textDark, fontSize: 32, fontWeight: FontWeight.bold)),
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
                  Text('Lihat Semua', style: TextStyle(color: AppColors.fireRed, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            // Dummy List Tenant
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 3,
              itemBuilder: (context, index) {
                List<String> tokoNames = ['Dimsum Merdeka Raya', 'Dimsum Cab. Setiabudi', 'Dimsum Helvetia'];
                List<String> omsets = ['Rp 24 Jt', 'Rp 18 Jt', 'Rp 15 Jt'];
                
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
                        decoration: BoxDecoration(color: AppColors.fireOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.store, color: AppColors.fireOrange),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tokoNames[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Omset: ${omsets[index]}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Aktif', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 10)),
                      )
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget Helper untuk Kartu Statistik Atas
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
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textDark)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: AppColors.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}