import 'package:flutter/material.dart';
import 'customer_home.dart';
import './widget/custom_bottom_nav.dart';
import 'customer_profile_page.dart';

class CustomerMain extends StatefulWidget {
  const CustomerMain({super.key});

  @override
  State<CustomerMain> createState() => _CustomerMainState();
}

class _CustomerMainState extends State<CustomerMain> {
  int _currentIndex = 0;

  // Daftar halaman berdasarkan tab yang diklik
  final List<Widget> _pages = [
    const CustomerHome(),
    const Center(child: Text('Halaman Favorit (Coming Soon)')),
    const Center(child: Text('Halaman Chat (Coming Soon)')),
    const CustomerProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNav(
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