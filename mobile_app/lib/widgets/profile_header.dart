import 'dart:io';

import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onManageProfile;
  final File? photoFile;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onManageProfile,
    this.photoFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: const Color(0xffe0f2fe),
          backgroundImage: photoFile != null ? FileImage(photoFile!) : null,
          child: photoFile == null
              ? const Icon(Icons.person, size: 48, color: Colors.blue)
              : null,
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
                  color: Color.fromARGB(255, 0, 103, 187),
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
