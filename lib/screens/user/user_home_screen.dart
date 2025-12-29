import 'package:flutter/material.dart';

import '../agent/agent_registration_screen.dart';
import '../agent/agent_access_screen.dart';
import 'upi_to_cash_screen.dart';
import 'cash_to_upi_screen.dart';
import 'user_profile_screen.dart';
import 'transactions_screen.dart';

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
  final String _cityLabel = 'Wagholi, Pune';

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
          if (index == 2) {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => const TransactionsScreen(),
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
              if (mounted) setState(() => _currentIndex = 0);
            });
            return;
          }

          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Transactions'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
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
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
              },
              child: const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
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
                        _useCurrentLocation ? 'Wagholi, Pune' : _cityLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text('Current location', style: TextStyle(color: Colors.grey)),
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
            subtitle: 'UPI → Cash',
            color: const Color(0xFF4CAF50), // Professional green
            onPressed: () {
              // Navigate to UPI → Cash filters; backend matching comes later.
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
            subtitle: 'Cash → Bank / UPI',
            color: Colors.blue,
             onPressed: () {
              // Navigate to UPI → Cash filters; backend matching comes later.
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
        Expanded(child: _infoCard(Icons.lock, 'OTP / QR Secure')),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () {
              // TODO: Connect to backend agent onboarding + admin approval flow.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AgentAccessScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: _infoCard(Icons.verified_user, 'Join as Agent'),
          ),
        ),
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
    return Container(
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
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/map_preview.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: const [
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.location_on,
                      size: 42,
                      color: Colors.blue,
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.layers_outlined, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap the map to view nearest partners and ATMs',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
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
                    onChanged: (val) {
                      setState(() => _useCurrentLocation = val);
                      // TODO: Hook permission, GPS fetch, and backend profile update APIs here.
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
