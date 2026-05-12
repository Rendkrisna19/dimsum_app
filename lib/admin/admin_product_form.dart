import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';

class AdminProductForm extends StatefulWidget {
  final String? docId; 
  final Map<String, dynamic>? data;
  final String? idToko; 

  const AdminProductForm({super.key, this.docId, this.data, this.idToko});

  @override
  State<AdminProductForm> createState() => _AdminProductFormState();
}

class _AdminProductFormState extends State<AdminProductForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingCategories = true;

  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _hargaModalController = TextEditingController();
  final _hargaAsliController = TextEditingController();
  final _hargaDiskonController = TextEditingController(); 
  final _stokController = TextEditingController();

  String? _base64Image;
  String? _selectedKategoriId;
  List<Map<String, dynamic>> _kategoriList = [];

  @override
  void initState() {
    super.initState();
    _fetchKategori(); 

    if (widget.data != null) {
      _namaController.text = widget.data!['nama_produk'] ?? '';
      _deskripsiController.text = widget.data!['deskripsi'] ?? '';
      _hargaModalController.text = widget.data!['harga_modal'].toString();
      _hargaAsliController.text = widget.data!['harga_asli'].toString();
      _hargaDiskonController.text = widget.data!['harga_diskon'].toString();
      _stokController.text = widget.data!['stok'].toString();
      _base64Image = widget.data!['gambar_base64'];
    } else {
      _hargaDiskonController.text = '0'; 
    }
  }

  // Fungsi Ambil Data Kategori HANYA untuk Toko Ini
  Future<void> _fetchKategori() async {
    if (widget.idToko == null) {
      setState(() => _isLoadingCategories = false);
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('kategori')
          .where('id_toko', isEqualTo: widget.idToko)
          .where('status_aktif', isEqualTo: true) // Filter tambahan hanya ambil yg aktif
          .get();
          
      final list = snap.docs.map((doc) => {
        'id': doc.id,
        'nama': doc['nama_kategori']
      }).toList();

      setState(() {
        _kategoriList = list;
        _isLoadingCategories = false;

        if (widget.data != null && widget.data!['id_kategori'] != null) {
          bool exists = list.any((k) => k['id'] == widget.data!['id_kategori']);
          if (exists) _selectedKategoriId = widget.data!['id_kategori'];
        } else if (list.isNotEmpty) {
          _selectedKategoriId = list.first['id'];
        }
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat kategori: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    
    if (pickedFile != null) {
      List<int> imageBytes = await pickedFile.readAsBytes();
      
      int sizeInBytes = imageBytes.length;
      double sizeInMb = sizeInBytes / (1024 * 1024);
      
      if (sizeInMb > 2.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran gambar terlalu besar! Maksimal 2MB.'),
              backgroundColor: Colors.red,
            )
          );
        }
        return; 
      }

      setState(() {
        _base64Image = base64Encode(imageBytes);
      });
    }
  }

  Future<void> _simpanProduk() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih gambar produk dulu!'), backgroundColor: Colors.red));
      return;
    }

    if (_selectedKategoriId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan pilih kategori produk!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final produkData = {
        'nama_produk': _namaController.text.trim(),
        'id_kategori': _selectedKategoriId, 
        'deskripsi': _deskripsiController.text.trim(),
        'harga_modal': double.parse(_hargaModalController.text.trim()),
        'harga_asli': double.parse(_hargaAsliController.text.trim()),
        'harga_diskon': double.parse(_hargaDiskonController.text.trim()),
        'stok': int.parse(_stokController.text.trim()),
        'gambar_base64': _base64Image,
        'diupdate_pada': FieldValue.serverTimestamp(),
      };

      if (widget.docId == null) {
        // Mode Tambah: Wajib sertakan id_toko
        produkData['dibuat_pada'] = FieldValue.serverTimestamp();
        produkData['id_toko'] = widget.idToko; // <--- Menyisipkan kepemilikan cabang

        await FirebaseFirestore.instance.collection('produk').add(produkData);
      } else {
        // Mode Edit
        await FirebaseFirestore.instance.collection('produk').doc(widget.docId).update(produkData);
      }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk berhasil disimpan!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
        title: Text(widget.docId == null ? 'Tambah Produk' : 'Edit Produk', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading || _isLoadingCategories
        ? const Center(child: CircularProgressIndicator(color: AppColors.fireOrange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.fireOrange, width: 2, style: BorderStyle.solid),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))
                          ]
                        ),
                        child: _base64Image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.memory(
                                  base64Decode(_base64Image!), 
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 50),
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.fireOrange, size: 40),
                                  SizedBox(height: 5),
                                  Text('Upload Foto', style: TextStyle(color: AppColors.fireOrange, fontWeight: FontWeight.bold)),
                                  Text('(Maks 2MB)', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  _kategoriList.isEmpty 
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            SizedBox(width: 10),
                            Expanded(child: Text('Kategori aktif di toko ini kosong! Silakan buat kategori aktif terlebih dahulu.', style: TextStyle(color: Colors.orange))),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: DropdownButtonFormField<String>(
                          value: _selectedKategoriId,
                          decoration: InputDecoration(
                            labelText: 'Pilih Kategori',
                            prefixIcon: const Icon(Icons.category, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fireOrange, width: 2)),
                          ),
                          items: _kategoriList.map((kategori) {
                            return DropdownMenuItem<String>(
                              value: kategori['id'],
                              child: Text(kategori['nama']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedKategoriId = value;
                            });
                          },
                          validator: (value) => value == null ? 'Kategori wajib dipilih' : null,
                        ),
                      ),

                  _buildInput('Nama Produk', _namaController, TextInputType.text, Icons.fastfood),
                  _buildInput('Deskripsi (Opsional)', _deskripsiController, TextInputType.text, Icons.description, maxLines: 3, isRequired: false),
                  
                  Row(
                    children: [
                      Expanded(child: _buildInput('Harga Modal', _hargaModalController, TextInputType.number, Icons.money_off)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildInput('Stok', _stokController, TextInputType.number, Icons.inventory)),
                    ],
                  ),
                  
                  Row(
                    children: [
                      Expanded(child: _buildInput('Harga Asli', _hargaAsliController, TextInputType.number, Icons.attach_money)),
                      const SizedBox(width: 15),
                      Expanded(child: _buildInput('Harga Diskon', _hargaDiskonController, TextInputType.number, Icons.local_offer, hint: 'Isi 0 jika tdk ada')),
                    ],
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.fireRed,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      onPressed: _simpanProduk,
                      child: const Text('SIMPAN PRODUK', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
        ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, TextInputType type, IconData icon, {int maxLines = 1, bool isRequired = true, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Wajib diisi';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fireOrange, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
        ),
      ),
    );
  }
}