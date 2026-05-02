import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'admin_product_form.dart';

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  final user = FirebaseAuth.instance.currentUser;
  String? _idToko;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchIdToko();
  }

  // Mengambil id_toko milik admin yang sedang login
  Future<void> _fetchIdToko() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (mounted) {
        setState(() {
          _idToko = doc.data()?['id_toko'];
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi hapus produk
  Future<void> _deleteProduct(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Produk?'),
        content: const Text('Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.fireRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('produk').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil dihapus')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.fireRed, AppColors.fireOrange]),
          ),
        ),
        title: const Text('Kelola Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.fireOrange))
          : StreamBuilder<QuerySnapshot>(
              // Filter data HANYA untuk id_toko milik admin ini
              stream: FirebaseFirestore.instance.collection('produk').where('id_toko', isEqualTo: _idToko).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.fireOrange));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Belum ada produk. Tambahkan sekarang!'));

                // Mengurutkan data terbaru di atas secara manual
                final docs = snapshot.data!.docs.toList();
                docs.sort((a, b) {
                  Timestamp tA = (a.data() as Map<String, dynamic>)['dibuat_pada'] ?? Timestamp.now();
                  Timestamp tB = (b.data() as Map<String, dynamic>)['dibuat_pada'] ?? Timestamp.now();
                  return tB.compareTo(tA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    // Logika Harga Coret
                    double hargaAsli = (data['harga_asli'] ?? 0).toDouble();
                    double hargaDiskon = (data['harga_diskon'] ?? 0).toDouble();
                    bool adaDiskon = hargaDiskon > 0 && hargaDiskon < hargaAsli;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Row(
                        children: [
                          // Gambar Base64
                          ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                            child: Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade100,
                              child: data['gambar_base64'] != null && data['gambar_base64'].toString().isNotEmpty
                                  ? Image.memory(base64Decode(data['gambar_base64']), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                  : const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Detail Produk
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['nama_produk'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  // Harga Asli (Coret jika ada diskon)
                                  if (adaDiskon)
                                    Text('Rp ${hargaAsli.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.lineThrough)),
                                  // Harga Tampil (Diskon atau Asli)
                                  Text('Rp ${adaDiskon ? hargaDiskon.toInt() : hargaAsli.toInt()}', style: const TextStyle(color: AppColors.fireOrange, fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 8),
                                  // Info Tambahan (Stok & Modal)
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.fireRed.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                        child: Text('Stok: ${data['stok']}', style: const TextStyle(fontSize: 10, color: AppColors.fireRed, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('Modal: Rp ${data['harga_modal']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Aksi (Edit & Hapus)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                // Kirim idToko ke Form saat edit
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProductForm(docId: doc.id, data: data, idToko: _idToko))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.fireRed),
                                onPressed: () => _deleteProduct(context, doc.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.fireRed,
        child: const Icon(Icons.add, color: Colors.white),
        // Kirim idToko ke Form saat tambah baru
        onPressed: () {
          if (_idToko != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminProductForm(idToko: _idToko)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan ID Toko')));
          }
        },
      ),
    );
  }
}