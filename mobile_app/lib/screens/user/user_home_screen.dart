import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'upi_to_cash_screen.dart';
import 'cash_to_upi_screen.dart';
import 'available_agents_screen.dart';
import 'user_profile_screen.dart';
import 'my_requests_screen.dart';
import '../../services/profile_photo_service.dart';
import '../../services/user_service.dart';
import '../../services/location_service.dart';
import '../shared/nearby_map_screen.dart';        

/// =======================================================
/// USER HOME SCREEN
/// Main dashboard for users
/// =======================================================
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _currentIndex = 0; // Track selected tab locally.
  bool _useCurrentLocation = false;
  String _cityLabel = 'Wagholi, Pune';
  String _profileName = 'User';
  File? _photoFile;
  Uint8List? _profilePhotoBytes;
  bool _isFetchingLocation = false;
  LatLng _mapCenter = const LatLng(18.5912, 73.7389);
  GoogleMapController? _mapController;
  final Set<Marker> _mapMarkers = {
    const Marker(
      markerId: MarkerId('default_location'),
      position: LatLng(18.5912, 73.7389),
      infoWindow: InfoWindow(title: 'Current Area'),
    ),
  };
  final ProfilePhotoService _photoService = ProfilePhotoService();
  final UserService _userService = UserService();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadProfileName();
    _loadInitialMapLocation();
  }

  void _openFullMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyMapScreen(
          initialCenter: _mapCenter,
          markers: _mapMarkers,
        ),
      ),
    );
  }

  Future<void> _openAvailableAgentsFromHome() async {
    final city = _cityLabel.split(',').first.trim();
    await Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => AvailableAgentsScreen(
              city: city.isEmpty ? 'your area' : city,
              latitude: _mapCenter.latitude,
              longitude: _mapCenter.longitude,
              radiusKm: 5.0,
              transactionType: 'UPI → Cash',
              amount: '1000',
            ),
          ),
        )
        .then((_) {
      if (mounted) setState(() => _currentIndex = 0);
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMapLocation() async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      _updateMapLocation(location);
    } catch (_) {
      // Keep default map center if initial GPS fetch fails.
    }
  }

  void _updateMapLocation(AppLocation location) {
    final nextCenter = LatLng(location.latitude, location.longitude);
    setState(() {
      _mapCenter = nextCenter;
      _mapMarkers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: nextCenter,
            infoWindow: InfoWindow(title: _cityLabel),
          ),
        );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(nextCenter, 14),
    );
  }

  Future<void> _applyCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      try {
        await _userService.updateProfile({'address': location.address});
      } catch (_) {
        // Ignore profile persistence errors here; location UX should still work.
      }
      if (!mounted) return;
      setState(() {
        _useCurrentLocation = true;
        _cityLabel = location.city;
      });
      _updateMapLocation(location);
    } catch (error) {
      if (!mounted) return;
      setState(() => _useCurrentLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<void> _loadPhoto() async {
    final file = await _photoService.loadPhotoFile();
    if (mounted) {
      setState(() => _photoFile = file);
    }
  }

  Uint8List? _decodeProfileImage(String? imageValue) {
    if (imageValue == null || imageValue.trim().isEmpty) return null;
    final trimmed = imageValue.trim();
    final base64Part = trimmed.startsWith('data:image') && trimmed.contains(',')
        ? trimmed.substring(trimmed.indexOf(',') + 1)
        : trimmed;
    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadProfileName() async {
    try {
      final profile = await _userService.getProfile();
      if (!mounted) return;
      setState(() {
        _profileName = profile.displayName.isEmpty ? 'User' : profile.displayName;
        _profilePhotoBytes = _decodeProfileImage(profile.profileImage);
      });
    } catch (_) {
      final cached = await _userService.getCachedProfile();
      if (!mounted || cached == null) return;
      setState(() {
        _profileName = cached.displayName.isEmpty ? 'User' : cached.displayName;
        _profilePhotoBytes = _decodeProfileImage(cached.profileImage);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F9FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildHeroCard(),
              const SizedBox(height: 20),
              _buildActionRow(),
              const SizedBox(height: 18),
              _buildTrustRow(context),
              const SizedBox(height: 18),
              _buildAgents(context),
              const SizedBox(height: 18),
              _buildMapPreview(),
              const SizedBox(height: 14),
              _buildSos(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            _openFullMap();
            return;
          }

          if (index == 2) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const MyRequestsScreen(),
                  ),
                )
                .then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
            return;
          }

          if (index == 3) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const UserProfileScreen(),
                  ),
                )
                .then((_) {
              if (mounted) {
                _loadPhoto();
                _loadProfileName();
                setState(() => _currentIndex = 0);
              }
            });
            return;
          }

          if (index == 4) {
            _openAvailableAgentsFromHome();
            return;
          }

          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.groups_2_outlined), label: 'Agents'),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Header
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                    )
                    .then((_) {
                  _loadPhoto();
                  _loadProfileName();
                });
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.blue,
                backgroundImage: _profilePhotoBytes != null
                    ? MemoryImage(_profilePhotoBytes!)
                    : (_photoFile != null ? FileImage(_photoFile!) : null),
                child: _profilePhotoBytes == null && _photoFile == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _showLocationSheet,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cityLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profileName,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined, size: 28),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Hero card
  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 201, 228, 248),
            Color.fromARGB(255, 248, 217, 217),
          ],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Convert Digital Money to Cash',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 14),
          Text(
            'Nearby & Secure',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 17),
          Text(
            'Find trusted agents around you in seconds',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Cash actions
  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            title: 'Cash Out',
            subtitle: 'UPI ? Cash',
            color: const Color(0xFF4CAF50), // Professional green
            onPressed: () {
              // Navigate to UPI ? Cash filters; backend matching comes later.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UpiToCashScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionButton(
            title: 'Cash In',
            subtitle: 'Cash ? Bank / UPI',
            color: Colors.blue,
             onPressed: () {
              // Navigate to UPI ? Cash filters; backend matching comes later.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CashToUpiScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // Trust indicators
  Widget _buildTrustRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _infoCard(Icons.speed, 'Fast')),
        const SizedBox(width: 10),
        Expanded(child: _infoCard(Icons.lock, 'OTP / QR Secure')),
      ],
    );
  }

  // -------------------------------------------------------
  // Agents
  Widget _buildAgents(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Nearby Trusted Agents',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text('View Map', style: TextStyle(color: Colors.blue)),
          ],
        ),
        const SizedBox(height: 10),
        _agentCard('Bankar General Store', '0.5 km'),
        const SizedBox(height: 12),
        _agentCard("Patil's Cyber Cafe", '0.7 km'),
      ],
    );
  }

  // -------------------------------------------------------
  // Map preview
  Widget _buildMapPreview() {
    return InkWell(
      onTap: _openFullMap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xffe8f1ff), Color(0xfff7fbff)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Nearby Banks & ATMs',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.map_outlined, color: Colors.blue),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 140,
                child: IgnorePointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _mapCenter,
                      zoom: 13,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _mapMarkers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap to open full map and view nearby banks & ATMs',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------
  // SOS
  Widget _buildSos() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffFFF3E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 10),
          Text(
            'Emergency / SOS',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Reusable widgets
  Widget _actionButton({
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed ?? () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _agentCard(String name, String distance) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(distance, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Text('Available', style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Use Current Location',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: _useCurrentLocation,
                    onChanged: (val) async {
                      if (val) {
                        await _applyCurrentLocation();
                        return;
                      }
                      setState(() => _useCurrentLocation = false);
                    },
                  ),
                ],
              ),
              if (_isFetchingLocation) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        );
      },
    );
  }
}

