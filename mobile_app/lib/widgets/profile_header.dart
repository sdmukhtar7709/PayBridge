import 'dart:io';

import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onManageProfile;
  final File? photoFile;
  final ImageProvider<Object>? photoImage;
  final bool? isVerified;
  final VoidCallback? onVerifiedTap;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.subtitle,
    required this.onManageProfile,
    this.photoFile,
    this.photoImage,
    this.isVerified,
    this.onVerifiedTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageProvider = photoImage ?? (photoFile != null ? FileImage(photoFile!) : null);
    return Column(
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: const Color(0xffe0f2fe),
          backgroundImage: imageProvider,
          child: imageProvider == null
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: isVerified == true ? onVerifiedTap : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isVerified == true
                                  ? const Color(0xffECFDF3)
                                  : const Color(0xffFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isVerified == true
                                    ? const Color(0xffA7F3D0)
                                    : const Color(0xffFCD34D),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVerified == true ? Icons.verified : Icons.info_outline,
                                  size: 12,
                                  color: isVerified == true
                                      ? const Color(0xff059669)
                                      : const Color(0xffB45309),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isVerified == true ? 'Verified' : 'Not Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isVerified == true
                                        ? const Color(0xff059669)
                                        : const Color(0xffB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
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
