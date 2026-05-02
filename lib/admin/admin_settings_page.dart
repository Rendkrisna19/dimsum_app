import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../auth/login_page.dart'; 

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _tokoData;
  String? _idToko;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Mengambil data user sekaligus data toko cabang
  Future<void> _fetchData() async {
    if (_user == null) return;

    try {
      // 1. Ambil Data Profil Admin
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
      Map<String, dynamic>? userData = userDoc.data();
      String? idToko = userData?['id_toko'];
      Map<String, dynamic>? tokoData;

      // 2. Jika Admin punya cabang, ambil data Cabangnya
      if (idToko != null) {
        final tokoDoc = await FirebaseFirestore.instance.collection('toko').doc(idToko).get();
        tokoData = tokoDoc.data();
      }

      if (mounted) {
        setState(() {
          _userData = userData;
          _idToko = idToko;
          _tokoData = tokoData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    }
  }

  // Fungsi Update Foto Profil 
  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        List<int> imageBytes = await pickedFile.readAsBytes();
        
        if ((imageBytes.length / (1024 * 1024)) > 2.0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gambar terlalu besar! Maksimal 2MB'), backgroundColor: Colors.red));
          setState(() => _isLoading = false);
          return;
        }

        String base64Image = base64Encode(imageBytes);

        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'photo_base64': base64Image,
        });

        await _fetchData(); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profil berhasil diperbarui!'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  // Fungsi Universal untuk memunculkan Dialog Edit Text (Diperbarui untuk mendukung Multi-line & Angka)
  Future<void> _showEditDialog({
    required String title, 
    required String label, 
    required String currentValue, 
    required Function(String) onSave, 
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? hintText,
  }) async {
    final controller = TextEditingController(text: isPassword ? '' : currentValue);
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark)),
            content: TextFormField(
              controller: controller,
              obscureText: isPassword,
              keyboardType: keyboardType,
              maxLines: isPassword ? 1 : maxLines,
              decoration: InputDecoration(
                labelText: label,
                hintText: hintText,
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.fireOrange)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.fireOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (controller.text.trim().isEmpty) return;
                        setDialogState(() => isSaving = true);
                        await onSave(controller.text.trim());
                        if (mounted) Navigator.pop(context);
                      },
                child: isSaving 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- LOGIKA UPDATE PROFIL ---
  Future<void> _updateName(String newName) async {
    await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({'name': newName});
    await _user?.updateDisplayName(newName);
    await _fetchData();
  }

  Future<void> _updateEmail(String newEmail) async {
    try {
      await _user?.verifyBeforeUpdateEmail(newEmail); 
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({'email': newEmail});
      await _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cek inbox email baru Anda untuk verifikasi!'), backgroundColor: Colors.blue));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e (Mungkin perlu login ulang)'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updatePassword(String newPassword) async {
    try {
      await _user?.updatePassword(newPassword);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil diubah!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e (Mungkin perlu login ulang)'), backgroundColor: Colors.red));
    }
  }

  // --- LOGIKA UPDATE DATA CABANG ---
  Future<void> _updateTokoField(String field, String newValue) async {
    if (_idToko == null) return;
    try {
      await FirebaseFirestore.instance.collection('toko').doc(_idToko).update({
        field: newValue,
        'diupdate_pada': FieldValue.serverTimestamp(),
      });
      await _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cabang berhasil diperbarui!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan data cabang: $e'), backgroundColor: Colors.red));
    }
  }

  // Fungsi Keluar
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.fireOrange)));
    }

    String nama = _userData?['name'] ?? 'Admin';
    String email = _userData?['email'] ?? 'admin@dimsum.com';
    String? photoBase64 = _userData?['photo_base64'];

    String namaToko = _tokoData?['nama_toko'] ?? 'Cabang Tidak Diketahui';
    String alamatToko = _tokoData?['alamat_toko'] ?? 'Alamat belum diatur';
    String waToko = _tokoData?['whatsapp_toko'] ?? 'Belum ada nomor WA';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. HEADER & FOTO PROFIL
            SizedBox(
              height: 280,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    height: 200,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.fireRed, AppColors.fireOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                    ),
                  ),
                  const Positioned(
                    top: 60,
                    child: Text('Pengaturan', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  Positioned(
                    top: 130,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: AppColors.fireOrange.withOpacity(0.1),
                                backgroundImage: photoBase64 != null && photoBase64.isNotEmpty
                                    ? MemoryImage(base64Decode(photoBase64))
                                    : null,
                                child: photoBase64 == null || photoBase64.isEmpty
                                    ? Text(nama[0].toUpperCase(), style: const TextStyle(fontSize: 30, color: AppColors.fireOrange, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              GestureDetector(
                                onTap: _updateProfilePicture,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppColors.fireRed, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(nama, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(namaToko, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // 2. PENGATURAN CABANG / TOKO (KHUSUS MULTI-TENANT)
            if (_idToko != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                child: Align(alignment: Alignment.centerLeft, child: Text('Informasi Cabang', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: Column(
                    children: [
                      _buildSettingsItem(
                        icon: Icons.storefront_outlined,
                        title: 'Alamat Cabang',
                        subtitle: alamatToko,
                        onTap: () => _showEditDialog(
                          title: 'Ubah Alamat Cabang',
                          label: 'Alamat Lengkap',
                          currentValue: alamatToko == 'Alamat belum diatur' ? '' : alamatToko,
                          maxLines: 3, // Multi-line untuk alamat
                          onSave: (val) => _updateTokoField('alamat_toko', val),
                        ),
                      ),
                      const Divider(height: 1, indent: 60, endIndent: 20),
                      _buildSettingsItem(
                        icon: Icons.message,
                        title: 'Nomor WhatsApp',
                        subtitle: waToko,
                        onTap: () => _showEditDialog(
                          title: 'Nomor WhatsApp Cabang',
                          label: 'Contoh: 628123456789',
                          hintText: 'Gunakan awalan 62',
                          keyboardType: TextInputType.phone, // Keyboard angka
                          currentValue: waToko == 'Belum ada nomor WA' ? '' : waToko,
                          onSave: (val) => _updateTokoField('whatsapp_toko', val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 3. PENGATURAN PROFIL ADMIN
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              child: Align(alignment: Alignment.centerLeft, child: Text('Keamanan Akun', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
                child: Column(
                  children: [
                    _buildSettingsItem(
                      icon: Icons.person_outline,
                      title: 'Edit Nama Profil',
                      subtitle: nama,
                      onTap: () => _showEditDialog(title: 'Ubah Nama', label: 'Nama Baru', currentValue: nama, onSave: _updateName),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 20),
                    _buildSettingsItem(
                      icon: Icons.email_outlined,
                      title: 'Edit Email',
                      subtitle: email,
                      onTap: () => _showEditDialog(title: 'Ubah Email', label: 'Email Baru', currentValue: email, onSave: _updateEmail),
                    ),
                    const Divider(height: 1, indent: 60, endIndent: 20),
                    _buildSettingsItem(
                      icon: Icons.lock_outline,
                      title: 'Edit Password',
                      subtitle: '********',
                      onTap: () => _showEditDialog(title: 'Ubah Password', label: 'Password Baru (Min 6 karakter)', currentValue: '', onSave: _updatePassword, isPassword: true),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 4. TOMBOL LOGOUT KELUAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.fireRed, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: const Icon(Icons.logout, color: AppColors.fireRed),
                  label: const Text('Keluar Aplikasi', style: TextStyle(color: AppColors.fireRed, fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Keluar?'),
                        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.fireRed),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) _logout();
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Widget Helper untuk List Menu Pengaturan yang Bersih (Clean Design)
  Widget _buildSettingsItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.fireOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.fireOrange),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}