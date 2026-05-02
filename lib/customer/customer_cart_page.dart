import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'cart_manager.dart';

class CustomerCartPage extends StatelessWidget {
  const CustomerCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        title: const Text('Keranjang Saya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Kosongkan Keranjang',
            onPressed: () {
              CartManager.instance.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang dibersihkan!')));
            },
          )
        ],
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: CartManager.instance.cartItems,
        builder: (context, cart, child) {
          if (cart.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 15),
                  Text('Keranjangmu masih kosong nih!', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    String gambarBase64 = item['gambar_base64'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: 70, height: 70, color: Colors.grey.shade100,
                              child: gambarBase64.isNotEmpty
                                  ? Image.memory(base64Decode(gambarBase64), fit: BoxFit.cover)
                                  : const Icon(Icons.fastfood, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['nama_produk'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('Rp ${item['harga_final'].toInt()}', style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Kontrol Qty
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryOrange),
                                onPressed: () => CartManager.instance.updateQty(index, item['qty'] - 1),
                                constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('${item['qty']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryOrange),
                                onPressed: () {
                                  if (item['qty'] < item['stok']) {
                                    CartManager.instance.updateQty(index, item['qty'] + 1);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok tidak cukup!'), duration: Duration(seconds: 1)));
                                  }
                                },
                                constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Bagian Total & Checkout
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, -5))]),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembayaran', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          Text('Rp ${CartManager.instance.getTotalPrice().toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Checkout & Pilih Alamat segera hadir!')));
                          },
                          child: const Text('LANJUTKAN PESANAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}