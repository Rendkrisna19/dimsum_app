import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'cart_manager.dart';

class CustomerFavoritePage extends StatefulWidget {
  const CustomerFavoritePage({super.key});

  @override
  State<CustomerFavoritePage> createState() => _CustomerFavoritePageState();
}

class _CustomerFavoritePageState extends State<CustomerFavoritePage> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _removeFromFavorite(String productId) async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('favorites').doc(productId).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dihapus dari favorit'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        title: const Text('Menu Favorit Saya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null 
        ? const Center(child: Text('Silakan login terlebih dahulu.'))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('favorites').snapshots(),
            builder: (context, favSnapshot) {
              if (favSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
              if (!favSnapshot.hasData || favSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text('Belum ada menu favorit nih.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              List<String> favIds = favSnapshot.data!.docs.map((doc) => doc.id).toList();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('produk').snapshots(),
                builder: (context, productSnapshot) {
                  if (!productSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));

                  // Filter produk yang ID-nya ada di daftar favorit
                  var favoriteProducts = productSnapshot.data!.docs.where((doc) => favIds.contains(doc.id)).toList();

                  if (favoriteProducts.isEmpty) return const Center(child: Text('Menu favorit tidak ditemukan.'));

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 15, mainAxisSpacing: 15,
                    ),
                    itemCount: favoriteProducts.length,
                    itemBuilder: (context, index) {
                      final doc = favoriteProducts[index];
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;

                      double hargaAsli = (data['harga_asli'] ?? 0).toDouble();
                      double hargaDiskon = (data['harga_diskon'] ?? 0).toDouble();
                      bool adaDiskon = hargaDiskon > 0 && hargaDiskon < hargaAsli;
                      double hargaFinal = adaDiskon ? hargaDiskon : hargaAsli;
                      String gambarBase64 = data['gambar_base64'] ?? '';
                      String idToko = data['id_toko'] ?? '';

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
                                Positioned(
                                  top: 8, right: 8,
                                  child: GestureDetector(
                                    onTap: () => _removeFromFavorite(doc.id),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.favorite, color: Colors.red, size: 18),
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
    );
  }
}