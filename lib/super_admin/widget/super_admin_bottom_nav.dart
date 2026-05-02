import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class SuperAdminBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SuperAdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed, // Agar icon tidak membesar/mengecil saat diklik
        selectedItemColor: AppColors.fireRed, // Pakai warna merah khusus Super Admin
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.store_mall_directory_rounded), label: 'Tenant'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Platform'),
        ],
      ),
    );
  }
}