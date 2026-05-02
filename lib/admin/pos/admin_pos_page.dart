import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_colors.dart';
import 'pos_product_grid.dart';
import 'pos_cart_panel.dart';

class AdminPosPage extends StatefulWidget {
  const AdminPosPage({super.key});

  @override
  State<AdminPosPage> createState() => _AdminPosPageState();
}

class _AdminPosPageState extends State<AdminPosPage> {
  String? _idToko;
  bool _isLoadingToko = true;
  List<Map<String, dynamic>> _cart = [];

  @override
  void initState() {
    super.initState();
    _fetchIdToko();
  }

  // Mengambil id_toko dari admin yang sedang login
  Future<void> _fetchIdToko() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _idToko = doc.data()?['id_toko'];
          _isLoadingToko = false;
        });
      }
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      int index = _cart.indexWhere((item) => item['id'] == product['id']);
      if (index != -1) {
        if (_cart[index]['qty'] < product['stok']) _cart[index]['qty']++;
      } else {
        _cart.add({...product, 'qty': 1});
      }
    });
  }

  void _updateQty(int index, int newQty) {
    setState(() {
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index]['qty'] = newQty;
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingToko) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.fireRed)));
    }
    if (_idToko == null) {
      return const Scaffold(body: Center(child: Text('Akses Ditolak: Anda tidak terikat dengan cabang manapun.')));
    }

    double totalCart = _cart.fold(0, (sum, item) => sum + (item['harga_final'] * item['qty']));
    int totalItems = _cart.fold(0, (sum, item) => sum + (item['qty'] as int));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.fireRed, AppColors.fireOrange])),
        ),
        title: const Text('Kasir POS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(flex: 6, child: PosProductGrid(idToko: _idToko!, onAddToCart: _addToCart)),
                Expanded(flex: 4, child: PosCartPanel(idToko: _idToko!, cartItems: _cart, onClearCart: _clearCart, onUpdateQty: _updateQty)),
              ],
            );
          } 
          return PosProductGrid(idToko: _idToko!, onAddToCart: _addToCart);
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: MediaQuery.of(context).size.width <= 800 && _cart.isNotEmpty
          ? Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              width: double.infinity,
              height: 60,
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.fireRed,
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: PosCartPanel(idToko: _idToko!, cartItems: _cart, onClearCart: _clearCart, onUpdateQty: _updateQty),
                      ),
                    ),
                  );
                },
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      child: Text('$totalItems item', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 15),
                    const Text('Lihat Keranjang  • ', style: TextStyle(color: Colors.white)),
                    Text('Rp ${totalCart.toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}