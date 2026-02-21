import 'dart:io';

import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import 'about_platform_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_screen.dart';
import 'theme_screen.dart';
import '../../services/profile_photo_service.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_tile.dart';
import '../../widgets/upi_card.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final String _profileName = 'Muktar Sayyad';
  final String _upiId = '770968@ybl';
  File? _photoFile;
  final ProfilePhotoService _photoService = ProfilePhotoService();

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final file = await _photoService.loadPhotoFile();
    if (file != null && mounted) {
      setState(() => _photoFile = file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f9ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    ProfileHeader(
                      name: _profileName,
                      subtitle: 'Personal account',
                      photoFile: _photoFile,
                      onManageProfile: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            )
                            .then((_) => _loadPhoto());
                      },
                    ),
                    const SizedBox(height: 20),
                    UpiCard(
                      upiId: _upiId,
                      onCopy: () {
                        // TODO: Hook into clipboard and backend for sharing if needed.
                        debugPrint('Copy UPI ID: $_upiId');
                      },
                    ),
                    const SizedBox(height: 20),
                    SettingsSection(
                      children: [
                        SettingsTile(
                          icon: Icons.brightness_6_outlined,
                          title: 'Theme',
                          onTap: () {
                            // Simple UI navigation; theme application/persistence handled in ThemeScreen later.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ThemeScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SettingsTile(
                          icon: Icons.info_outline,
                          title: 'About Cash IO',
                          onTap: () {
                            // Simple UI navigation to static About screen; content is static and offline.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutPlatformScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () {
                            // TODO: Open Privacy Policy screen or webview.
                          },
                        ),
                        const Divider(height: 1),
                        SettingsTile(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () {
                            // UI navigation only; password update API handled inside ChangePasswordScreen.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SettingsTile(
                          icon: Icons.language,
                          title: 'Language',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LanguageScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Call backend logout API here to invalidate the session/token.
                      // For now, we clear any local session placeholders and return to login.
                      debugPrint(
                        'Logging out user (demo) and clearing session',
                      );

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return SettingsTile(icon: icon, title: title, onTap: onTap);
  }
}
