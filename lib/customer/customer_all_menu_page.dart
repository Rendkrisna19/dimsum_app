import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'cart_manager.dart';
import 'customer_cart_page.dart';

class CustomerAllMenuPage extends StatefulWidget {
  const CustomerAllMenuPage({super.key});

  @override
  State<CustomerAllMenuPage> createState() => _CustomerAllMenuPageState();
}

class _CustomerAllMenuPageState extends State<CustomerAllMenuPage> {
  final user = FirebaseAuth.instance.currentUser;
  
  // State Filter Kategori
  String? _selectedCategoryId;

  // Fungsi Toggle Favorit
  Future<void> _toggleFavorite(String productId, bool isCurrentlyFavorite) async {
    if (user == null) return;
    
    final favRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('favorites').doc(productId);

    if (isCurrentlyFavorite) {
      await favRef.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dihapus dari favorit'), duration: Duration(seconds: 1)));
    } else {
      await favRef.set({'added_at': FieldValue.serverTimestamp()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disimpan ke favorit! ❤️'), duration: Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Query dinamis berdasarkan filter kategori
    Query productQuery = FirebaseFirestore.instance.collection('produk');
    if (_selectedCategoryId != null) {
      productQuery = productQuery.where('id_kategori', isEqualTo: _selectedCategoryId);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        title: const Text('Semua Menu Dimsum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Ikon Keranjang di Pojok Kanan Atas dengan Badge Angka
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: CartManager.instance.cartItems,
            builder: (context, cart, child) {
              int totalItems = cart.fold(0, (sum, item) => sum + (item['qty'] as int));
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerCartPage())),
                  ),
                  if (totalItems > 0)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$totalItems', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    )
                ],
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // FILTER KATEGORI (Scroll Horizontal)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            color: Colors.white,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kategori').where('status_aktif', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      _buildCategoryChip(id: null, name: 'Semua Menu', isSelected: _selectedCategoryId == null),
                      ...snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildCategoryChip(id: doc.id, name: data['nama_kategori'], isSelected: _selectedCategoryId == doc.id);
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // GRID PRODUK
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: productQuery.snapshots(),
              builder: (context, productSnapshot) {
                if (productSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
                if (!productSnapshot.hasData || productSnapshot.data!.docs.isEmpty) return const Center(child: Text('Tidak ada produk di kategori ini.'));

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('favorites').snapshots(),
                  builder: (context, favSnapshot) {
                    List<String> favList = [];
                    if (favSnapshot.hasData) {
                      favList = favSnapshot.data!.docs.map((doc) => doc.id).toList();
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 15, mainAxisSpacing: 15, // Ditinggikan rasio untuk nama cabang
                      ),
                      itemCount: productSnapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = productSnapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        data['id'] = doc.id; // Penting untuk cart
                        
                        bool isFavorite = favList.contains(doc.id);
                        double hargaAsli = (data['harga_asli'] ?? 0).toDouble();
                        double hargaDiskon = (data['harga_diskon'] ?? 0).toDouble();
                        bool adaDiskon = hargaDiskon > 0 && hargaDiskon < hargaAsli;
                        double hargaFinal = adaDiskon ? hargaDiskon : hargaAsli;
                        String gambarBase64 = data['gambar_base64'] ?? '';
                        String idToko = data['id_toko'] ?? '';

                        // Mengambil nama cabang
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('toko').doc(idToko).get(),
                          builder: (context, tokoSnapshot) {
                            String namaCabang = 'Mencari...';
                            if (tokoSnapshot.hasData && tokoSnapshot.data!.exists) {
                              namaCabang = (tokoSnapshot.data!.data() as Map<String, dynamic>)['nama_toko'] ?? 'Cabang Unknown';
                            }

                            return Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))]),
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                          child: gambarBase64.isNotEmpty
                                              ? Image.memory(base64Decode(gambarBase64), fit: BoxFit.cover)
                                              : const Icon(Icons.fastfood, color: Colors.grey, size: 50),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(data['nama_produk'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            
                                            // BADGE CABANG
                                            Row(
                                              children: [
                                                const Icon(Icons.storefront, color: Colors.blue, size: 12),
                                                const SizedBox(width: 4),
                                                Expanded(child: Text(namaCabang, style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),

                                            if (adaDiskon) Text('Rp ${hargaAsli.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 10, decoration: TextDecoration.lineThrough)),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Rp ${hargaFinal.toInt()}', style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                                                
                                                // TOMBOL ADD TO CART ASLI
                                                GestureDetector(
                                                  onTap: () {
                                                    if ((data['stok'] ?? 0) > 0) {
                                                      CartManager.instance.addToCart({...data, 'harga_final': hargaFinal});
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masuk Keranjang! 🛒'), duration: Duration(milliseconds: 800)));
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok Habis!'), backgroundColor: Colors.red));
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                    child: const Icon(Icons.add_shopping_cart, color: AppColors.primaryOrange, size: 18),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // TOMBOL FAVORIT
                                  Positioned(
                                    top: 8, right: 8,
                                    child: GestureDetector(
                                      onTap: () => _toggleFavorite(doc.id, isFavorite),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                        child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey, size: 18),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                        );
                      },
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Desain Kapsul Filter Kategori
  Widget _buildCategoryChip({required String? id, required String name, required bool isSelected}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primaryOrange : Colors.grey.shade300),
        ),
        child: Text(
          name, 
          style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)
        ),
      ),
    );
  }
}