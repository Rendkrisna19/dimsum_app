import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String role; // <-- TAMBAHAN WAJIB: Menerima role dari database

  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role, // <-- Wajib diisi saat memanggil widget ini
  });

  @override
  Widget build(BuildContext context) {
    // --- PENDEFINISIAN MENU BERDASARKAN ROLE ---
    List<BottomNavigationBarItem> navItems = [];

    if (role == 'admin' || role == 'superadmin') {
      // MENU FULL UNTUK ADMIN CABANG
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.fastfood_rounded), label: 'Produk'),
        BottomNavigationBarItem(icon: Icon(Icons.category_rounded), label: 'Kategori'),
        BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Staf'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Transaksi'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Setting'),
      ];
    } else if (role == 'kasir') {
      // MENU TERBATAS UNTUK KASIR
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'), // Tetap butuh Home untuk lihat nama & tombol Logout
        BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
        BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Riwayat Kasir'),
      ];
    } else {
      // Fallback jika role belum ter-load
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: AppColors.fireRed,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), 
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: navItems, 
      ),
    );
  }
}