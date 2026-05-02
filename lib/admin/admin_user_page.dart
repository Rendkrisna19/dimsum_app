import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_colors.dart';

class AdminUserPage extends StatefulWidget {
  const AdminUserPage({super.key});

  @override
  State<AdminUserPage> createState() => _AdminUserPageState();
}

class _AdminUserPageState extends State<AdminUserPage> {
  final user = FirebaseAuth.instance.currentUser;
  String? _idToko;
  bool _isLoadingToko = true;

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
          _isLoadingToko = false;
        });
      }
    }
  }

  // Fungsi Hapus Staf
  Future<void> _deleteUser(BuildContext context, String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Staf?'),
        content: Text('Yakin ingin mencabut akses $nama dari cabang ini?\n\n(Ini hanya menghapus data profil, kredensial Firebase Auth tetap ada namun tidak bisa login ke toko ini lagi).'),
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
      await FirebaseFirestore.instance.collection('users').doc(id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akses staf berhasil dihapus')));
      }
    }
  }

  // Fungsi Tambah Staf Baru (Kasir / Admin Cabang)
  Future<void> _addStaffDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final namaController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'kasir';
    bool isLoading = false;
    bool isPasswordVisible = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Tambah Staf Baru', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: namaController,
                      validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person, color: Colors.grey)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val!.isEmpty || !val.contains('@') ? 'Email tidak valid' : null,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email, color: Colors.grey)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      validator: (val) => val!.length < 6 ? 'Min 6 karakter' : null,
                      decoration: InputDecoration(
                        labelText: 'Password', 
                        prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                        )
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Peran / Jabatan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                      items: const [
                        DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin Cabang')),
                      ],
                      onChanged: (val) => setState(() => selectedRole = val!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.fireRed),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          // Gunakan Secondary App agar Admin yg login tidak ter-logout
                          FirebaseApp secondaryApp = await Firebase.initializeApp(name: 'SecondaryApp', options: Firebase.app().options);
                          UserCredential cred = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
                            email: emailController.text.trim(),
                            password: passwordController.text.trim(),
                          );

                          // Simpan dengan id_toko milik admin ini
                          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
                            'name': namaController.text.trim(),
                            'email': emailController.text.trim(),
                            'role': selectedRole,
                            'id_toko': _idToko,
                            'dibuat_pada': FieldValue.serverTimestamp(),
                          });

                          await secondaryApp.delete();

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staf berhasil ditambahkan'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                        }
                      },
                child: isLoading
                    ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Fungsi Edit Staf
  Future<void> _editUserDialog(BuildContext context, String id, Map<String, dynamic> data) async {
    final namaController = TextEditingController(text: data['name']);
    String selectedRole = data['role'] ?? 'kasir';
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Staf', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: namaController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person, color: Colors.grey)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Peran / Jabatan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
                    items: const [
                      DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                      DropdownMenuItem(value: 'admin', child: Text('Admin Cabang')),
                    ],
                    onChanged: (val) => setState(() => selectedRole = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.fireOrange),
                onPressed: isLoading
                    ? null
                    : () async {
                        if (namaController.text.trim().isEmpty) return;
                        setState(() => isLoading = true);
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(id).update({
                            'name': namaController.text.trim(),
                            'role': selectedRole,
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data berhasil diperbarui'), backgroundColor: Colors.green));
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: isLoading
                    ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
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
        title: const Text('Manajemen Staf Cabang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoadingToko 
        ? const Center(child: CircularProgressIndicator(color: AppColors.fireOrange))
        : StreamBuilder<QuerySnapshot>(
            // MENGAMBIL HANYA USER YANG MEMILIKI ID TOKO SAMA (Hanya staf toko ini)
            stream: FirebaseFirestore.instance.collection('users').where('id_toko', isEqualTo: _idToko).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.fireOrange));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('Belum ada staf di cabang ini.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  String nama = data['name'] ?? 'Tanpa Nama';
                  String email = data['email'] ?? '-';
                  String role = data['role'] ?? 'kasir';
                  
                  Color roleColor = role == 'admin' ? AppColors.fireRed : AppColors.fireOrange;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: CircleAvatar(
                        backgroundColor: roleColor.withOpacity(0.2),
                        child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : '?', style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                            child: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editUserDialog(context, doc.id, data),
                          ),
                          // Cegah Admin menghapus dirinya sendiri
                          if (doc.id != FirebaseAuth.instance.currentUser?.uid)
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppColors.fireRed),
                              onPressed: () => _deleteUser(context, doc.id, nama),
                            ),
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
        label: const Text('Tambah Staf', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _addStaffDialog(context),
      ),
    );
  }
}