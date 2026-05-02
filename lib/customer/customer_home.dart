import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import 'customer_all_menu_page.dart'; 
import './widget/customer_location_header.dart'; // Pastikan path widget ini benar

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final user = FirebaseAuth.instance.currentUser;
  
  // State untuk Filter Kategori
  String? _selectedCategoryId; // null berarti menampilkan "Semua"
  String _selectedCategoryName = 'Populer Saat Ini';

  @override
  Widget build(BuildContext context) {
    // 1. DYNAMIC QUERY: Query produk berubah berdasarkan kategori yang diklik
    Query productQuery = FirebaseFirestore.instance.collection('produk');
    if (_selectedCategoryId != null) {
      productQuery = productQuery.where('id_kategori', isEqualTo: _selectedCategoryId);
    } else {
      productQuery = productQuery.limit(5); // Jika "Semua", batasi 5 saja di Beranda
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER BERWARNA ORANGE
            Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: CustomerLocationHeader()),
                      // Ikon Notifikasi dan Keranjang Sementara
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryOrange), 
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Halaman Keranjang segera hadir!')));
                              }
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Search Bar Modern
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari dimsum favoritmu...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.tune, color: AppColors.primaryOrange, size: 20),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. HERO SLIDER PROMO (Dipisah agar tidak bikin layar kedip)
            const PromoCarouselWidget(),

            const SizedBox(height: 25),

            // 3. KATEGORI INTERAKTIF (BISA DIKLIK UNTUK FILTER)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Kategori', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ),
            const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kategori').where('status_aktif', isEqualTo: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Belum ada kategori.', style: TextStyle(color: Colors.grey)));

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tombol "Semua" Default
                      _buildCategoryItem(
                        id: null,
                        name: 'Semua',
                        isSelected: _selectedCategoryId == null,
                        onTap: () => setState(() {
                          _selectedCategoryId = null;
                          _selectedCategoryName = 'Populer Saat Ini';
                        }),
                      ),
                      
                      // List Kategori dari Database
                      ...snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildCategoryItem(
                          id: doc.id,
                          name: data['nama_kategori'] ?? 'Kategori',
                          isSelected: _selectedCategoryId == doc.id,
                          onTap: () => setState(() {
                            _selectedCategoryId = doc.id;
                            _selectedCategoryName = data['nama_kategori'];
                          }),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            // 4. DAFTAR MENU (Menampilkan Nama Cabang & Filtered by Category)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_selectedCategoryName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerAllMenuPage()));
                    },
                    child: const Text('Lihat Semua', style: TextStyle(color: AppColors.primaryOrange, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            StreamBuilder<QuerySnapshot>(
              stream: productQuery.snapshots(), // Menggunakan query dinamis berdasarkan kategori
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20), 
                    child: Center(child: Text('Tidak ada produk di kategori ini.', style: TextStyle(color: Colors.grey)))
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    double hargaAsli = (data['harga_asli'] ?? 0).toDouble();
                    double hargaDiskon = (data['harga_diskon'] ?? 0).toDouble();
                    bool adaDiskon = hargaDiskon > 0 && hargaDiskon < hargaAsli;
                    String gambarBase64 = data['gambar_base64'] ?? '';
                    String idToko = data['id_toko'] ?? ''; // ID Cabang pembuat produk

                    // MENGAMBIL NAMA CABANG BERDASARKAN id_toko
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('toko').doc(idToko).get(),
                      builder: (context, tokoSnapshot) {
                        String namaCabang = 'Mencari Cabang...';
                        if (tokoSnapshot.hasData && tokoSnapshot.data!.exists) {
                          namaCabang = (tokoSnapshot.data!.data() as Map<String, dynamic>)['nama_toko'] ?? 'Cabang Tidak Diketahui';
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey.shade100,
                                  child: gambarBase64.isNotEmpty
                                      ? Image.memory(base64Decode(gambarBase64), fit: BoxFit.cover)
                                      : const Center(child: Icon(Icons.fastfood, color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(data['nama_produk'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    
                                    // --- BADGE NAMA CABANG / TENANT ---
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.storefront_rounded, color: Colors.blue, size: 12),
                                          const SizedBox(width: 4),
                                          Flexible(child: Text(namaCabang, style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // ----------------------------------

                                    if (adaDiskon) Text('Rp ${hargaAsli.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.lineThrough)),
                                    Text('Rp ${adaDiskon ? hargaDiskon.toInt() : hargaAsli.toInt()}', style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(12)),
                                child: IconButton(
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang (UI coming soon)'), duration: Duration(seconds: 1)));
                                  },
                                ),
                              )
                            ],
                          ),
                        );
                      }
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Widget Helper untuk mempermudah render item Kategori
  Widget _buildCategoryItem({required String? id, required String name, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange : Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: isSelected 
                  ? [BoxShadow(color: AppColors.primaryOrange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]
                  : [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Icon(
                id == null ? Icons.dashboard_customize : Icons.category, 
                color: isSelected ? Colors.white : AppColors.primaryOrange, 
                size: 30
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name, 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primaryOrange : Colors.black87
              )
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGET CAROUSEL TERPISAH (Agar setState tidak me-render ulang seluruh halaman)
// =========================================================================
class PromoCarouselWidget extends StatefulWidget {
  const PromoCarouselWidget({super.key});

  @override
  State<PromoCarouselWidget> createState() => _PromoCarouselWidgetState();
}

class _PromoCarouselWidgetState extends State<PromoCarouselWidget> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _timer;

  // Daftar Banner (Pastikan nama file di assets sama persis)
  final List<String> _banners = [
    'assets/banner1.jpg',
    'assets/banner2.jpg',
    'assets/banner3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (int page) {
              setState(() => _currentPage = page);
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.grey.shade300,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    _banners[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? AppColors.primaryOrange : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }
}