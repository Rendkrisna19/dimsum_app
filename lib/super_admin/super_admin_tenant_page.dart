import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'super_admin_tenant_form.dart';

class SuperAdminTenantPage extends StatelessWidget {
  const SuperAdminTenantPage({super.key});

  // Fungsi Hapus Tenant
  Future<void> _deleteTenant(BuildContext context, String id, String namaToko) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tenant?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Yakin ingin menghapus cabang "$namaToko"?\n\nPeringatan: Akun admin yang terikat dengan toko ini akan tetap ada namun kehilangan akses ke toko ini.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Cabang', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('toko').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant berhasil dihapus dari sistem')));
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
            gradient: LinearGradient(colors: [Color(0xFF8B0000), AppColors.fireRed]),
          ),
        ),
        title: const Text('Daftar Cabang / Tenant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('toko').orderBy('dibuat_pada', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.fireRed));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  const Text('Belum ada cabang terdaftar.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isAktif = data['status_aktif'] ?? true;
              final String idToko = doc.id; 

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // Ikon Toko (Aktif Biru, Nonaktif Abu-abu)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isAktif ? Colors.blue.withOpacity(0.1) : Colors.grey.shade200, 
                                    borderRadius: BorderRadius.circular(15)
                                  ),
                                  child: Icon(Icons.storefront_rounded, color: isAktif ? Colors.blue : Colors.grey, size: 28),
                                ),
                                const SizedBox(width: 15),
                                // Nama & Status
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['nama_toko'] ?? '-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isAktif ? AppColors.textDark : Colors.grey)),
                                      const SizedBox(height: 5),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: isAktif ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                        child: Text(isAktif ? 'Beroperasi' : 'Nonaktif', style: TextStyle(color: isAktif ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Tombol Aksi (Edit & Delete) Popup Menu agar ringkas
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => SuperAdminTenantForm(docId: idToko, data: data)));
                              } else if (value == 'delete') {
                                _deleteTenant(context, idToko, data['nama_toko']);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 10), Text('Edit Data')])),
                              const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 10), Text('Hapus')])),
                            ],
                          ),
                        ],
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(),
                      ),
                      
                      // Alamat Toko
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(data['alamat_toko'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4))),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.fireRed,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Cabang Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminTenantForm())),
      ),
    );
  }
}