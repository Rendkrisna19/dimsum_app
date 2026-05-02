import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../theme/app_colors.dart';

class SuperAdminTenantForm extends StatefulWidget {
  final String? docId; 
  final Map<String, dynamic>? data;

  const SuperAdminTenantForm({super.key, this.docId, this.data});

  @override
  State<SuperAdminTenantForm> createState() => _SuperAdminTenantFormState();
}

class _SuperAdminTenantFormState extends State<SuperAdminTenantForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Controller Data Toko
  final _namaTokoController = TextEditingController();
  final _alamatTokoController = TextEditingController();
  bool _statusAktif = true;

  // Controller Akun Admin Tenant
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _namaTokoController.text = widget.data!['nama_toko'] ?? '';
      _alamatTokoController.text = widget.data!['alamat_toko'] ?? '';
      _statusAktif = widget.data!['status_aktif'] ?? true;
    }
  }

  Future<void> _simpanTenantDanAkun() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final tenantData = {
        'nama_toko': _namaTokoController.text.trim(),
        'alamat_toko': _alamatTokoController.text.trim(),
        'status_aktif': _statusAktif,
        'diupdate_pada': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        // -------------------------------------------------------------
        // MODE TAMBAH BARU: Buat Toko + Daftarkan Akun Admin Tenant
        // -------------------------------------------------------------
        tenantData['dibuat_pada'] = FieldValue.serverTimestamp();
        
        // 1. Simpan Data Toko ke Firestore dan dapatkan ID-nya
        DocumentReference tokoRef = await FirebaseFirestore.instance.collection('toko').add(tenantData);

        // 2. Buat Akun Firebase Auth Menggunakan "Secondary App" agar Super Admin tidak ter-logout
        FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
        
        try {
          UserCredential cred = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

          // 3. Simpan data akun ke koleksi 'users' dengan Role Admin dan ID Toko
          await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
            'name': 'Admin ${_namaTokoController.text.trim()}',
            'email': _emailController.text.trim(),
            'role': 'admin', // ROLE KHUSUS ADMIN TENANT
            'id_toko': tokoRef.id, // IKATKAN DENGAN ID TOKO
            'dibuat_pada': FieldValue.serverTimestamp(),
          });
        } finally {
          // Hapus app bayangan setelah selesai
          await secondaryApp.delete();
        }

      } else {
        // -------------------------------------------------------------
        // MODE EDIT: Hanya Update Data Toko Saja
        // -------------------------------------------------------------
        await FirebaseFirestore.instance.collection('toko').doc(widget.docId).update(tenantData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tenant & Akun berhasil disimpan!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditMode = widget.docId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8B0000), AppColors.fireRed])),
        ),
        title: Text(isEditMode ? 'Edit Tenant' : 'Buat Tenant Baru', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.fireRed))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BAGIAN 1: INFO TOKO ---
                  _buildSectionTitle('Informasi Toko / Cabang', Icons.storefront),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))]),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _namaTokoController,
                          validator: (value) => value!.isEmpty ? 'Nama toko wajib diisi' : null,
                          decoration: InputDecoration(labelText: 'Nama Cabang', prefixIcon: const Icon(Icons.store, color: AppColors.fireRed), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _alamatTokoController,
                          validator: (value) => value!.isEmpty ? 'Alamat wajib diisi' : null,
                          maxLines: 2,
                          decoration: InputDecoration(labelText: 'Alamat Lengkap', prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 20), child: Icon(Icons.location_on, color: AppColors.fireRed)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Status Operasional', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            Switch(value: _statusAktif, activeColor: AppColors.fireRed, onChanged: (val) => setState(() => _statusAktif = val)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),

                  // --- BAGIAN 2: AKUN ADMIN (Hanya Muncul Saat Tambah Baru) ---
                  if (!isEditMode) ...[
                    _buildSectionTitle('Kredensial Login Admin', Icons.security),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade200, width: 2), boxShadow: [BoxShadow(color: Colors.orange.shade100, blurRadius: 10, offset: const Offset(0, 5))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Akun ini akan digunakan oleh pengelola cabang tersebut untuk masuk ke dashboard Admin.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value!.isEmpty || !value.contains('@') ? 'Email tidak valid' : null,
                            decoration: InputDecoration(labelText: 'Email Admin', prefixIcon: const Icon(Icons.email, color: AppColors.fireOrange), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock, color: AppColors.fireOrange),
                              suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // TOMBOL SIMPAN
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.fireRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 5),
                      onPressed: _simpanTenantDanAkun,
                      child: const Text('SIMPAN & DAFTARKAN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textDark, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }
}