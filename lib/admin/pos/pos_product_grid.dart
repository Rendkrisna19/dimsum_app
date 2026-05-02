import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_colors.dart';

class PosProductGrid extends StatelessWidget {
  final String idToko; // <--- Parameter Multi-Tenant
  final Function(Map<String, dynamic>) onAddToCart;

  const PosProductGrid({super.key, required this.idToko, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // FILTER BERDASARKAN ID TOKO SAJA
      stream: FirebaseFirestore.instance.collection('produk').where('id_toko', isEqualTo: idToko).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.fireOrange));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Belum ada produk di cabang ini.'));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 800 ? 4 : constraints.maxWidth > 500 ? 3 : 2;

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 0.8,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id; 

                double hargaAsli = (data['harga_asli'] ?? 0).toDouble();
                double hargaDiskon = (data['harga_diskon'] ?? 0).toDouble();
                double hargaFinal = (hargaDiskon > 0 && hargaDiskon < hargaAsli) ? hargaDiskon : hargaAsli;

                return InkWell(
                  onTap: () {
                    if (data['stok'] > 0) {
                      onAddToCart({...data, 'harga_final': hargaFinal});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok Habis!')));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))],
                      border: Border.all(color: data['stok'] > 0 ? Colors.transparent : Colors.red, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                            child: data['gambar_base64'] != null && data['gambar_base64'].toString().isNotEmpty
                                ? Image.memory(base64Decode(data['gambar_base64']), fit: BoxFit.cover)
                                : const Icon(Icons.image, color: Colors.grey, size: 50),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['nama_produk'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('Rp ${hargaFinal.toInt()}', style: const TextStyle(color: AppColors.fireOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Stok: ${data['stok']}', style: TextStyle(color: data['stok'] > 0 ? Colors.grey : Colors.red, fontSize: 10)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }
        );
      },
    );
  }
}