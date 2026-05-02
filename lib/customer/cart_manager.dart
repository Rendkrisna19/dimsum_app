import 'package:flutter/material.dart';

class CartManager {
  // Singleton pattern agar memori keranjang sama di seluruh halaman
  static final CartManager instance = CartManager._internal();
  CartManager._internal();

  // ValueNotifier agar UI otomatis ter-update saat keranjang berubah
  final ValueNotifier<List<Map<String, dynamic>>> cartItems = ValueNotifier([]);

  void addToCart(Map<String, dynamic> product) {
    final items = List<Map<String, dynamic>>.from(cartItems.value);
    int index = items.indexWhere((item) => item['id'] == product['id']);
    
    if (index != -1) {
      if (items[index]['qty'] < product['stok']) {
        items[index]['qty']++;
      }
    } else {
      items.add({...product, 'qty': 1});
    }
    cartItems.value = items;
  }

  void updateQty(int index, int newQty) {
    final items = List<Map<String, dynamic>>.from(cartItems.value);
    if (newQty <= 0) {
      items.removeAt(index);
    } else {
      items[index]['qty'] = newQty;
    }
    cartItems.value = items;
  }

  void clearCart() {
    cartItems.value = [];
  }

  double getTotalPrice() {
    return cartItems.value.fold(0, (sum, item) => sum + (item['harga_final'] * item['qty']));
  }
}