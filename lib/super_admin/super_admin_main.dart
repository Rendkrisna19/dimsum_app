import 'package:flutter/material.dart';
import 'super_admin_home.dart';
import './widget/super_admin_bottom_nav.dart';
import 'super_admin_tenant_page.dart';

class SuperAdminMain extends StatefulWidget {
  const SuperAdminMain({super.key});

  @override
  State<SuperAdminMain> createState() => _SuperAdminMainState();
}

class _SuperAdminMainState extends State<SuperAdminMain> {
  int _currentIndex = 0;

  // Daftar Halaman Super Admin
  final List<Widget> _pages = [
    const SuperAdminHome(),
    const SuperAdminTenantPage(),
    const Center(child: Text('Laporan Global (Coming Soon)')),
    const Center(child: Text('Pengaturan Platform (Coming Soon)')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // Memanggil widget navigasi yang sudah kita pisah
      bottomNavigationBar: SuperAdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}