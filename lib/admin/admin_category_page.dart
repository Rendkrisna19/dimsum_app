import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import 'admin_category_form.dart';

class AdminCategoryPage extends StatefulWidget {
  const AdminCategoryPage({super.key});

  @override
  State<AdminCategoryPage> createState() => _AdminCategoryPageState();
}

class _AdminCategoryPageState extends State<AdminCategoryPage> {
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

  // Fungsi Hapus Kategori
  Future<void> _deleteCategory(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: const Text('Apakah Anda yakin? Pastikan tidak ada produk yang masih menggunakan kategori ini.'),
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
      await FirebaseFirestore.instance.collection('kategori').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori dihapus', style: TextStyle(color: Colors.white))));
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
        title: const Text('Kelola Kategori', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.fireOrange))
          : StreamBuilder<QuerySnapshot>(
              // Filter data HANYA untuk id_toko milik admin ini
              stream: FirebaseFirestore.instance.collection('kategori').where('id_toko', isEqualTo: _idToko).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.fireOrange));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Belum ada data kategori di toko ini.'));

                // Mengurutkan data terbaru di atas secara manual agar tidak perlu buat composite index di Firebase
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
                    final bool isAktif = data['status_aktif'] ?? true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isAktif ? Colors.transparent : Colors.red.shade100, width: 2),
                        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isAktif ? AppColors.fireOrange.withOpacity(0.1) : Colors.grey.shade200,
                          child: Icon(Icons.category, color: isAktif ? AppColors.fireOrange : Colors.grey),
                        ),
                        title: Text(
                          data['nama_kategori'] ?? '-', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: isAktif ? AppColors.textDark : Colors.grey),
                        ),
                        subtitle: Text(
                          isAktif ? 'Status: Aktif' : 'Status: Nonaktif',
                          style: TextStyle(color: isAktif ? Colors.green : Colors.red, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              // Kirim idToko ke Form saat edit (untuk jaga-jaga)
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCategoryForm(docId: doc.id, data: data, idToko: _idToko))),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.fireRed),
                              onPressed: () => _deleteCategory(context, doc.id),
                            ),
                          ],
                        ),
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCategoryForm(idToko: _idToko)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan ID Toko')));
          }
        },
      ),
    );
  }
}