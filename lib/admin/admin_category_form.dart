import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class AdminCategoryForm extends StatefulWidget {
  final String? docId; 
  final Map<String, dynamic>? data;
  final String? idToko; // <--- WAJIB UNTUK MULTI-TENANT

  const AdminCategoryForm({super.key, this.docId, this.data, this.idToko});

  @override
  State<AdminCategoryForm> createState() => _AdminCategoryFormState();
}

class _AdminCategoryFormState extends State<AdminCategoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  bool _statusAktif = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.data != null) {
      _namaController.text = widget.data!['nama_kategori'] ?? '';
      _statusAktif = widget.data!['status_aktif'] ?? true;
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final categoryData = <String, dynamic>{
        'nama_kategori': _namaController.text.trim(),
        'status_aktif': _statusAktif,
        'diupdate_pada': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        // MODE TAMBAH BARU: Wajib sertakan id_toko
        categoryData['dibuat_pada'] = FieldValue.serverTimestamp();
        categoryData['id_toko'] = widget.idToko; 
        
        await FirebaseFirestore.instance.collection('kategori').add(categoryData);
      } else {
        // MODE EDIT
        await FirebaseFirestore.instance.collection('kategori').doc(widget.docId).update(categoryData);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori berhasil disimpan!', style: TextStyle(color: Colors.white))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    super.dispose();
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
        title: Text(widget.docId == null ? 'Tambah Kategori' : 'Edit Kategori', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _namaController,
                validator: (value) => value!.isEmpty ? 'Nama kategori tidak boleh kosong' : null,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori (Misal: Kukus, Goreng)',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.category, color: AppColors.fireOrange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppColors.fireOrange)),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Aktif', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Switch(
                      value: _statusAktif,
                      activeColor: AppColors.fireOrange,
                      onChanged: (val) => setState(() => _statusAktif = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.fireOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _isLoading ? null : _saveData,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}