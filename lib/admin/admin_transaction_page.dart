import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../theme/app_colors.dart';

class AdminTransactionPage extends StatefulWidget {
  const AdminTransactionPage({super.key});

  @override
  State<AdminTransactionPage> createState() => _AdminTransactionPageState();
}

class _AdminTransactionPageState extends State<AdminTransactionPage> {
  final user = FirebaseAuth.instance.currentUser;
  String? _idToko;
  bool _isLoading = true;

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
          _isLoading = false;
        });
      }
    }
  }

  // --- FUNGSI BUKA WHATSAPP ---
  Future<void> _bukaWhatsApp(String phone, String orderId) async {
    if (phone.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WA Customer tidak ditemukan')));
      return;
    }
    
    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }

    String pesan = "Halo kak, pesanan Dimsum dengan Order ID *$orderId* sedang kami proses ya!";
    final Uri waUrl = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(pesan)}");

    try {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
    }
  }

  // --- FUNGSI BUKA GOOGLE MAPS MENGGUNAKAN KOORDINAT (LAT/LNG) ---
  Future<void> _bukaMaps(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Titik koordinat pelanggan tidak ditemukan')));
      return;
    }
    
    // Melempar titik akurat ke Google Maps
    final Uri mapsUrl = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    try {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka Maps')));
    }
  }

  // Fungsi untuk mengubah status pesanan
  Future<void> _updateStatus(String docId, String newStatus, {double? latMaps, double? lngMaps}) async {
    try {
      await FirebaseFirestore.instance.collection('pesanan').doc(docId).update({
        'status_pesanan': newStatus,
        'diupdate_pada': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status pesanan diubah menjadi: $newStatus'), backgroundColor: Colors.green));
      }

      // Jika statusnya Sedang Diantar, otomatis buka Maps MENGGUNAKAN KOORDINAT
      if (newStatus == 'Sedang Diantar' && latMaps != null && lngMaps != null) {
        _bukaMaps(latMaps, lngMaps);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah status: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator(color: AppColors.fireOrange)));
    }

    if (_idToko == null) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: Text('Akses Ditolak: Anda tidak terikat dengan cabang manapun.')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.fireRed, AppColors.fireOrange]),
            ),
          ),
          title: const Text('Pesanan Pelanggan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Pesanan Aktif'),
              Tab(text: 'Selesai / Riwayat'),
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
    List<String> statusList = isCompleted 
        ? ['Selesai'] 
        : ['Sedang Disiapkan', 'Sedang Diantar']; 

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pesanan').where('id_toko', isEqualTo: _idToko).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.fireOrange));
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState(isCompleted);

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String status = data['status_pesanan'] ?? '';
          return statusList.contains(status); 
        }).toList();

        docs.sort((a, b) {
          Timestamp tA = (a.data() as Map<String, dynamic>)['waktu_pesan'] ?? Timestamp.now();
          Timestamp tB = (b.data() as Map<String, dynamic>)['waktu_pesan'] ?? Timestamp.now();
          return tB.compareTo(tA); 
        });

        if (docs.isEmpty) return _buildEmptyState(isCompleted);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            String status = data['status_pesanan'] ?? 'Unknown';
            String orderId = data['order_id'] ?? doc.id.substring(0, 8).toUpperCase();
            String idCustomer = data['id_customer'] ?? '';
            String pelanggan = data['nama_customer'] ?? 'Pelanggan';
            String metode = data['metode_bayar'] ?? '-';
            double total = (data['total_bayar'] ?? 0).toDouble();
            List items = data['items'] ?? [];

            Color statusColor = Colors.grey;
            if (status == 'Sedang Disiapkan') statusColor = AppColors.fireOrange;
            if (status == 'Sedang Diantar') statusColor = Colors.blue;
            if (status == 'Selesai') statusColor = Colors.green;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER KARTU
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order: $orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                            const SizedBox(height: 4),
                            Text('Pembayaran: $metode', style: TextStyle(color: metode == 'COD' ? Colors.red : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                  
                  // DETAIL PELANGGAN & ITEM
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(idCustomer).get(),
                      builder: (context, userSnap) {
                        String waCustomer = '';
                        String alamatDetail = 'Alamat belum diatur';
                        double? latCustomer;
                        double? lngCustomer;

                        // KITA AMBIL KOORDINAT (LAT/LNG) DARI DATABASE USER
                        if (userSnap.hasData && userSnap.data!.exists) {
                          var userData = userSnap.data!.data() as Map<String, dynamic>;
                          waCustomer = userData['whatsapp'] ?? '';
                          alamatDetail = userData['alamat_detail'] ?? 'Alamat belum diatur';
                          latCustomer = userData['latitude'];
                          lngCustomer = userData['longitude'];
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(pelanggan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                Text('Jarak: ${data['jarak_teks']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            
                            // ALAMAT CUSTOMER
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, size: 16, color: AppColors.fireRed),
                                const SizedBox(width: 8),
                                Expanded(child: Text(alamatDetail, style: const TextStyle(color: Colors.grey, fontSize: 13))),
                              ],
                            ),

                            // TOMBOL MAPS & WHATSAPP
                            if (!isCompleted) ...[
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 8)),
                                      icon: const Icon(Icons.chat, color: Colors.green, size: 18),
                                      label: const Text('Chat WA', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () => _bukaWhatsApp(waCustomer, orderId),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue), padding: const EdgeInsets.symmetric(vertical: 8)),
                                      icon: const Icon(Icons.map, color: Colors.blue, size: 18),
                                      label: const Text('Buka Maps', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                      // TOMBOL INI SEKARANG MELEMPAR KOORDINAT ASLI
                                      onPressed: () => _bukaMaps(latCustomer, lngCustomer),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                            
                            ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${item['qty']}x ${item['nama_produk']}', style: const TextStyle(fontSize: 13)),
                                  Text('Rp ${(item['harga_final'] * item['qty']).toInt()}', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            )),
                            
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ongkos Kirim', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('Rp ${(data['ongkir'] ?? 0).toInt()}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL BAYAR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Rp ${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryOrange)),
                              ],
                            ),

                            // TOMBOL AKSI UPDATE STATUS 
                            if (!isCompleted) ...[
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: status == 'Sedang Disiapkan'
                                  ? ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      icon: const Icon(Icons.two_wheeler, color: Colors.white, size: 20),
                                      label: const Text('ANTAR PESANAN & BUKA MAPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      // TOMBOL INI JUGA MELEMPAR KOORDINAT ASLI
                                      onPressed: () => _updateStatus(doc.id, 'Sedang Diantar', latMaps: latCustomer, lngMaps: lngCustomer),
                                    )
                                  : ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                      icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      label: const Text('PESANAN SELESAI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      onPressed: () => _updateStatus(doc.id, 'Selesai'),
                                    ),
                              )
                            ]
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isCompleted) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(isCompleted ? 'Belum ada riwayat pesanan.' : 'Tidak ada pesanan aktif.', style: const TextStyle(color: Colors.grey)),
        ],
      )
    );
  }
}