import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class CustomerOrderPage extends StatefulWidget {
  const CustomerOrderPage({super.key});

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  final user = FirebaseAuth.instance.currentUser;

  // Format tanggal simpel
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  // Menampilkan Pop-Up Rincian Pesanan
  void _showOrderDetail(Map<String, dynamic> data) {
    List items = data['items'] ?? [];
    double subtotal = (data['subtotal'] ?? 0).toDouble();
    double ongkir = (data['ongkir'] ?? 0).toDouble();
    double total = (data['total_bayar'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header BottomSheet
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rincian Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ],
              ),
            ),
            // Isi Rincian
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['nama_toko'] ?? 'Toko', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      Text(data['status_pesanan'], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text('Tgl: ${_formatDate(data['waktu_pesan'])}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Divider(height: 30),
                  
                  // Daftar Item
                  const Text('Daftar Item', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${item['qty']}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nama_produk']),
                              Text('Rp ${item['harga_final'].toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('Rp ${(item['harga_final'] * item['qty']).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                  const Divider(height: 30),

                  // Ringkasan Pembayaran
                  const Text('Ringkasan Pembayaran', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(color: Colors.grey)), Text('Rp ${subtotal.toInt()}')]),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Ongkos Kirim', style: TextStyle(color: Colors.grey)), Text('Rp ${ongkir.toInt()}')]),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Rp ${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryOrange)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wallet, color: Colors.grey, size: 16),
                        const SizedBox(width: 8),
                        Text('Metode Pembayaran: ${data['metode_bayar']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.primaryOrange, title: const Text('Pesanan Saya', style: TextStyle(color: Colors.white))),
        body: const Center(child: Text('Silakan login terlebih dahulu.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: AppColors.primaryOrange,
          title: const Text('Pesanan Saya', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Sedang Proses'),
              Tab(text: 'Riwayat Selesai'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(isCompleted: false),
            _buildOrderList(isCompleted: true),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList({required bool isCompleted}) {
    List<String> activeStatus = ['Menunggu Pembayaran', 'Sedang Disiapkan', 'Sedang Diantar'];
    List<String> historyStatus = ['Selesai', 'Dibatalkan'];

    return StreamBuilder<QuerySnapshot>(
      // Ambil semua pesanan milik user ini
      stream: FirebaseFirestore.instance.collection('pesanan').where('id_customer', isEqualTo: user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

        // Dart-side filtering untuk menghindari Composite Index Error
        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String status = data['status_pesanan'] ?? '';
          if (isCompleted) {
            return historyStatus.contains(status);
          } else {
            return activeStatus.contains(status);
          }
        }).toList();

        // Urutkan dari yang terbaru
        docs.sort((a, b) {
          Timestamp tA = (a.data() as Map<String, dynamic>)['waktu_pesan'] ?? Timestamp.now();
          Timestamp tB = (b.data() as Map<String, dynamic>)['waktu_pesan'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            String status = data['status_pesanan'] ?? 'Unknown';
            String orderId = data['order_id'] ?? docs[index].id.substring(0, 8).toUpperCase();
            
            Color statusColor = Colors.grey;
            if (status == 'Menunggu Pembayaran') statusColor = Colors.red;
            if (status == 'Sedang Disiapkan') statusColor = AppColors.primaryOrange;
            if (status == 'Sedang Diantar') statusColor = Colors.blue;
            if (status == 'Selesai') statusColor = Colors.green;

            return GestureDetector(
              onTap: () => _showOrderDetail(data),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront, color: Colors.grey, size: 18),
                            const SizedBox(width: 8),
                            Text(data['nama_toko'] ?? 'Toko', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order ID: $orderId', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(_formatDate(data['waktu_pesan']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Total Belanja', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            Text('Rp ${(data['total_bayar'] ?? 0).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange, fontSize: 14)),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text('Belum ada pesanan.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}