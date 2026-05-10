import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';

class ActiveOrderWidget extends StatelessWidget {
  const ActiveOrderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pesanan')
          .where('id_customer', isEqualTo: user.uid)
          .where('status_pesanan', whereIn: ['Menunggu Pembayaran', 'Sedang Disiapkan', 'Sedang Diantar'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();

        final order = snapshot.data!.docs.first;
        final data = order.data() as Map<String, dynamic>;
        String status = data['status_pesanan'];
        
        return Positioned(
          bottom: 20, left: 20, right: 20,
          child: GestureDetector(
            onTap: () {
              // Munculkan detail pesanan (Pop up ringkas)
              showModalBottomSheet(context: context, builder: (c) => _buildOrderDetail(data));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textDark,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
              ),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, color: Colors.white),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pesanan Aktif', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetail(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detail Status Pesanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Text('Toko: ${data['nama_toko']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Jarak: ${data['jarak_teks']}'),
          const SizedBox(height: 15),
          _buildStatusStep('Pesanan Diterima', data['status_pesanan'] != 'Menunggu Pembayaran'),
          _buildStatusStep('Sedang Disiapkan', data['status_pesanan'] == 'Sedang Disiapkan' || data['status_pesanan'] == 'Sedang Diantar'),
          _buildStatusStep('Sedang Diantar', data['status_pesanan'] == 'Sedang Diantar'),
          const SizedBox(height: 20),
          Text('Total Bayar: Rp ${data['total_bayar'].toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
        ],
      ),
    );
  }

  Widget _buildStatusStep(String title, bool isDone) {
    return Row(
      children: [
        Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked, color: isDone ? Colors.green : Colors.grey),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: isDone ? Colors.black : Colors.grey)),
      ],
    );
  }
}