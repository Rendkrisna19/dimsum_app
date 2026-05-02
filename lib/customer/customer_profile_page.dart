import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../auth/login_page.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;

  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _alamatController = TextEditingController(); // Detail patokan, cat rumah, dll

  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Mengambil data user dari Firestore
  Future<void> _fetchUserData() async {
    if (_user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _namaController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _whatsappController.text = data['whatsapp'] ?? '';
          _alamatController.text = data['alamat_detail'] ?? '';
          _photoBase64 = data['photo_base64'];
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi Upload Foto Profil
  Future<void> _updateProfilePicture() async {
    // VALIDASI: Tolak ubah foto jika WA dan Alamat masih kosong
    if (_whatsappController.text.trim().isEmpty || _alamatController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi dan SIMPAN data No. WhatsApp & Alamat Detail terlebih dahulu sebelum mengubah foto profil!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 30);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        List<int> imageBytes = await pickedFile.readAsBytes();
        
        // Validasi ukuran maks 2MB
        if ((imageBytes.length / (1024 * 1024)) > 2.0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gambar terlalu besar! Maksimal 2MB'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
          return;
        }

        String base64Image = base64Encode(imageBytes);

        // Simpan langsung ke Firestore
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'photo_base64': base64Image,
        });

        setState(() {
          _photoBase64 = base64Image;
          _isLoading = false;
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil berhasil diperbarui!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  // Fungsi Simpan Data Profil (Teks)
  Future<void> _saveProfileData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'name': _namaController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'alamat_detail': _alamatController.text.trim(),
        'diupdate_pada': FieldValue.serverTimestamp(),
      });
      
      // Update display name di Firebase Auth jika nama berubah
      if (_user?.displayName != _namaController.text.trim()) {
        await _user?.updateDisplayName(_namaController.text.trim());
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Fungsi Keluar
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white, 
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
      );
    }

    String initialName = _namaController.text.isNotEmpty ? _namaController.text[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HEADER & FOTO PROFIL (Desain Overlap)
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Latar Belakang Melengkung
                  Container(
                    height: 180,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                    ),
                  ),
                  const Positioned(
                    top: 50,
                    child: Text('Profil Saya', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  // Kartu Foto Profil Mengambang
                  Positioned(
                    top: 110,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 10))],
                      ),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
                            backgroundImage: _photoBase64 != null && _photoBase64!.isNotEmpty
                                ? MemoryImage(base64Decode(_photoBase64!))
                                : null,
                            child: _photoBase64 == null || _photoBase64!.isEmpty
                                ? Text(initialName, style: const TextStyle(fontSize: 35, color: AppColors.primaryOrange, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          GestureDetector(
                            onTap: _updateProfilePicture,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: AppColors.textDark, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. FORM PROFIL
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi Pribadi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 15),

                    // Nama
                    _buildTextField(
                      controller: _namaController,
                      label: 'Nama Lengkap',
                      icon: Icons.person_outline,
                    ),

                    // Email (Readonly - hanya tampil)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: TextFormField(
                        controller: _emailController,
                        readOnly: true,
                        style: const TextStyle(color: Colors.grey),
                        decoration: InputDecoration(
                          labelText: 'Email (Terdaftar)',
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),

                    // WhatsApp
                    _buildTextField(
                      controller: _whatsappController,
                      label: 'Nomor WhatsApp Aktif',
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      hint: 'Contoh: 08123456789',
                    ),

                    const SizedBox(height: 10),
                    const Text('Alamat Pengiriman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    const SizedBox(height: 15),

                    // Detail Alamat
                    _buildTextField(
                      controller: _alamatController,
                      label: 'Detail Alamat Rumah',
                      icon: Icons.home_outlined,
                      maxLines: 3,
                      hint: 'Contoh: Jl. Merdeka No. 10, RT 01/RW 02. Cat rumah warna biru, pagar hitam.',
                    ),

                    const SizedBox(height: 25),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 3,
                        ),
                        onPressed: _isSaving ? null : _saveProfileData,
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('SIMPAN PROFIL', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Tombol Keluar
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text('Keluar Akun', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Helper Form Input
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) => value == null || value.isEmpty ? 'Data ini wajib diisi' : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 45 : 0), // Angkat icon jika multiline
            child: Icon(icon, color: AppColors.primaryOrange),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
        ),
      ),
    );
  }
}