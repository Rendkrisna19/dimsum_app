import 'package:flutter/material.dart';
import 'admin_home.dart';
import './widget/admin_bottom_nav.dart';
import 'admin_product_page.dart';
import 'admin_category_page.dart';
import 'pos/admin_pos_page.dart';
import 'admin_user_page.dart';
import 'admin_settings_page.dart';
import 'admin_transaction_page.dart';

class AdminMain extends StatefulWidget {
  const AdminMain({super.key});

  @override
  State<AdminMain> createState() => _AdminMainState();
}

class _AdminMainState extends State<AdminMain> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const AdminHome(),
    const AdminProductPage(),
    const AdminCategoryPage(),
    const AdminPosPage(),
    const AdminUserPage(),
    const AdminTransactionPage(),
    const AdminSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: AdminBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
