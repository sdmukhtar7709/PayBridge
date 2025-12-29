import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onManageProfile;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onManageProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const CircleAvatar(
          radius: 46,
          backgroundColor: Color(0xffe0f2fe),
          child: Icon(Icons.person, size: 48, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onManageProfile,
              child: const Text(
                'Manage Profile',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
