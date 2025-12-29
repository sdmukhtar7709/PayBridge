import 'package:flutter/material.dart';

class AboutPlatformScreen extends StatelessWidget {
  const AboutPlatformScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Platform'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Platform Overview',
                body:
                    'Cash IO connects users with trusted agents to cash-in or cash-out securely using UPI and location-aware workflows. The experience is designed for reliability, clarity, and compliance-friendly audits.',
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.star_rate_outlined,
                title: 'Key Features',
                body:
                    '• Instant cash-in and cash-out with transparent steps.\n• Trusted agents near you with guided navigation.\n• UPI-first flows with QR and OTP support.\n• Simple dashboards for everyday use.',
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.shield_outlined,
                title: 'Security & Trust',
                body:
                    'We prioritize user safety with encrypted communication, OTP-confirmed actions, and clear audit trails. Identity checks for agents and users help keep every transaction accountable.',
              ),
              const SizedBox(height: 16),
              _section(
                icon: Icons.info_outline,
                title: 'Version Information',
                body: 'App version: 1.0.0 (static copy for demo).',
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: This content is static and does not require backend integration.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
