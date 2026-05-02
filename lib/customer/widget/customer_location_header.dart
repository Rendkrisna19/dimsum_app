import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http; // Package baru
import '../../theme/app_colors.dart';

class CustomerLocationHeader extends StatefulWidget {
  const CustomerLocationHeader({super.key});

  @override
  State<CustomerLocationHeader> createState() => _CustomerLocationHeaderState();
}

class _CustomerLocationHeaderState extends State<CustomerLocationHeader> {
  String _currentAddress = "Mencari lokasi...";
  LatLng? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // Fungsi Cek Izin dan Dapatkan Lokasi GPS
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() { _currentAddress = "GPS tidak aktif"; _isLoading = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() { _currentAddress = "Izin lokasi ditolak"; _isLoading = false; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() { _currentAddress = "Izin lokasi diblokir"; _isLoading = false; });
      return;
    }

    try {
      // 1. Ambil Titik Koordinat (Latitude & Longitude)
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }

      // 2. Ubah Koordinat Jadi Teks Alamat via OpenStreetMap API (Support Web & Android)
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}');
      final response = await http.get(url, headers: {
        'User-Agent': 'dimsum_app/1.0', // Wajib diisi agar tidak diblokir server OSM
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};

        // Ambil data kelurahan/kecamatan dan kota
        String daerah = address['suburb'] ?? address['village'] ?? address['neighbourhood'] ?? '';
        String kota = address['city'] ?? address['town'] ?? address['county'] ?? '';

        if (mounted) {
          setState(() {
            if (daerah.isNotEmpty && kota.isNotEmpty) {
              _currentAddress = "$daerah, $kota";
            } else if (data['display_name'] != null) {
              // Jika data spesifik kosong, potong nama lengkap alamatnya (ambil 2 kata pertama)
              List<String> addressParts = data['display_name'].toString().split(',');
              _currentAddress = addressParts.take(2).join(',').trim();
            } else {
              _currentAddress = "Lokasi Ditemukan";
            }
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Gagal menghubungi server peta');
      }
    } catch (e) {
      // Fallback: Jika internet jelek/error API, tampilkan saja angka koordinatnya daripada bilang gagal
      if (mounted && _currentPosition != null) {
        setState(() {
          _currentAddress = "Titik: ${_currentPosition!.latitude.toStringAsFixed(3)}, ${_currentPosition!.longitude.toStringAsFixed(3)}";
          _isLoading = false;
        });
      }
    }
  }

  // Memunculkan Dialog Peta
  void _showMapDialog() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lokasi belum ditemukan, pastikan GPS aktif.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 500, // Membatasi lebar maksimum di Web
          height: 400,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _currentPosition!,
                  initialZoom: 16.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.codifyhub.dimsum',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 50,
                        height: 50,
                        child: const Icon(Icons.location_on, color: AppColors.primaryOrange, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
                  child: Text(_currentAddress, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showMapDialog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lokasi Pengiriman', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              _isLoading
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Expanded(
                      child: Text(
                        _currentAddress, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}