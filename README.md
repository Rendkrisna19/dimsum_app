# 📱 Dimsum App - Multi-Tenant POS & Food Delivery System

Dimsum App adalah sistem komprehensif berbasis Flutter dan Firebase yang menggabungkan fitur **Kasir (Point of Sale)** untuk penjualan *offline* dan **Food Delivery** untuk penjualan *online*. Aplikasi ini mendukung sistem **Multi-Tenant** (Banyak Cabang/Toko), di mana setiap cabang memiliki admin, staf, stok, dan pengaturan ongkos kirimnya sendiri.

---

## 🚀 Teknologi yang Digunakan
* **Frontend:** Flutter & Dart
* **Backend & Database:** Firebase (Authentication & Cloud Firestore)
* **Payment Gateway:** Midtrans (Sandbox API dengan WebView Interceptor)
* **Pemetaan & Lokasi:** Geolocator, LatLong2, Flutter Map, OpenStreetMap (Nominatim API)
* **Cetak Struk:** PDF & Printing (Support Printer Thermal 80mm)
* **Lainnya:** URL Launcher (WhatsApp & Google Maps Intent)

---

## 👥 Hak Akses (Roles) & Akun Demo
Aplikasi ini memiliki pembagian Role-Based Access Control (RBAC) yang ketat. 

| Role | Deskripsi Akses | Contoh Akun (Ubah Sesuai Firebase Kamu) |
| :--- | :--- | :--- |
| **Super Admin** | Mengelola seluruh pendaftaran cabang/toko baru (Master Data). | `superadmin@gmail.com` / `123456` |
| **Admin Cabang** | Pemilik cabang. Mengelola staf (Kasir), produk, kategori, memproses pesanan online, melihat dashboard pendapatan, serta mengatur titik GPS toko dan tarif ongkir/KM. | `admin_medan@gmail.com` / `123456` |
| **Kasir** | Staf toko. Hanya bisa mengakses halaman POS (Kasir offline), mencetak struk thermal, dan mengelola pesanan masuk di cabangnya. | `kasir_medan@gmail.com` / `123456` |
| **Customer** | Pelanggan global. Bisa memesan dari cabang mana saja, fitur hitung ongkir otomatis via GPS, metode bayar (COD/Midtrans), dan melacak status pesanan. | `pelanggan1@gmail.com` / `123456` |

---

## 🌟 Fitur Utama

### 🏪 Modul Admin Cabang / Kasir (Tenant)
* **Dashboard Analytics:** Pantau total pendapatan harian/mingguan/bulanan (gabungan *offline* & *online*), antrean pesanan, dan stok menipis secara *real-time*.
* **Sistem Kasir (POS):** Antarmuka responsif (mendukung Tablet & HP), fitur keranjang, pembayaran tunai/non-tunai, dan cetak struk PDF otomatis.
* **Manajemen Produk & Kategori:** Tambah, edit, dan hapus menu makanan khusus untuk cabang tersebut (Isolasi Data).
* **Manajemen Staf:** Admin dapat membuatkan akun akses khusus untuk kasir di cabangnya.
* **Manajemen Transaksi Online:** Terima pesanan pelanggan, ubah status (*Sedang Disiapkan* -> *Sedang Diantar* -> *Selesai*).
* **Kurir & Navigasi:** Tombol langsung menuju WhatsApp pelanggan dan rute *Google Maps* berdasarkan titik koordinat pelanggan.
* **Pengaturan Toko Dinamis:** Set titik koordinat (GPS) toko dan tarif ongkos kirim per KM langsung dari aplikasi.

### 🛵 Modul Customer (Pelanggan)
* **Auto-Location:** Aplikasi otomatis mendeteksi lokasi pelanggan menggunakan GPS dan mengubahnya menjadi teks alamat via OpenStreetMap.
* **Katalog Interaktif:** Tampilan *carousel* promo, kategori yang bisa difilter, dan *badge* nama cabang pada setiap produk.
* **Ongkir Dinamis:** Menghitung jarak (dalam *meter* atau *km*) menggunakan rumus Haversine antara rumah pelanggan dan titik koordinat toko.
* **Pembayaran Midtrans:** Integrasi langsung dengan API Snap Midtrans tanpa Webhook (menggunakan *WebView URL Interceptor*).
* **Live Tracking Widget:** Widget melayang yang menampilkan status pesanan secara *real-time* sebelum pesanan selesai.
* **Favorit & Riwayat:** Simpan menu favorit dan pantau riwayat transaksi sebelumnya.

---

## 🛠️ Persyaratan Sistem (Prerequisites)
Sebelum melakukan *build* atau menjalankan proyek, pastikan sistem kamu memiliki:
* Flutter SDK versi `3.x.x` atau terbaru.
* Android Studio / Xcode untuk kebutuhan *emulator* dan kompilasi *native*.
* Proyek Firebase yang sudah terhubung (memiliki `google-services.json` untuk Android dan `GoogleService-Info.plist` untuk iOS).
* Akun Midtrans Sandbox (untuk *Server Key*).

---

## ⚙️ Cara Menjalankan Aplikasi (Development)

1. **Clone & Install Dependencies**
   Buka terminal di folder proyek, lalu jalankan:
   ```bash
   flutter clean
   flutter pub get