import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/agent_service.dart';
import '../../widgets/profile_header.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_tile.dart';
import '../auth/login_screen.dart';
import '../user/about_platform_screen.dart';
import '../user/change_password_screen.dart';
import '../user/language_screen.dart';
import '../user/theme_screen.dart';
import 'agent_manage_profile_screen.dart';

class AgentProfileScreen extends StatefulWidget {
  const AgentProfileScreen({super.key});

  @override
  State<AgentProfileScreen> createState() => _AgentProfileScreenState();
}

class _AgentProfileScreenState extends State<AgentProfileScreen> {
  AgentProfileData? _profile;
  Uint8List? _profilePhotoBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await AgentService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _profilePhotoBytes = _decodeProfileImage(profile.profileImage);
        _loading = false;
      });
    } catch (_) {
      final cached = await AgentService.getCachedProfile();
      if (!mounted) return;
      setState(() {
        _profile = cached;
        _profilePhotoBytes = _decodeProfileImage(cached?.profileImage);
        _loading = false;
      });
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

  String _field(String? value, {String fallback = '-'}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  String _numField(num? value, {String fallback = '-'}) {
    return value == null ? fallback : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = (profile?.name.trim().isNotEmpty ?? false) ? profile!.name.trim() : 'Agent';

    return Scaffold(
      backgroundColor: const Color(0xfff6f9ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('My Profile', style: TextStyle(color: Colors.black87)),
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
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    ProfileHeader(
                      name: name,
                      subtitle: 'Agent account',
                      photoImage: _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null,
                      onManageProfile: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const AgentManageProfileScreen(),
                              ),
                            )
                            .then((updated) {
                          if (updated == true) _loadProfile();
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _detailRow('Email', _field(profile?.email)),
                          _divider(),
                          _detailRow('Phone', _field(profile?.phone)),
                          _divider(),
                          _detailRow('Gender', _field(profile?.gender)),
                          _divider(),
                          _detailRow('Marital Status', _field(profile?.maritalStatus)),
                          _divider(),
                          _detailRow('Age', profile?.age?.toString() ?? '-'),
                          _divider(),
                          _detailRow('Address', _field(profile?.address)),
                          _divider(),
                          _detailRow('Shop Name', _field(profile?.locationName)),
                          _divider(),
                          _detailRow('City', _field(profile?.city)),
                          _divider(),
                          _detailRow('Cash Limit', _numField(profile?.cashLimit)),
                          _divider(),
                          _detailRow('Verified', (profile?.isVerified ?? false) ? 'Yes' : 'No'),
                          _divider(),
                          _detailRow('Available', (profile?.available ?? false) ? 'Yes' : 'No'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SettingsSection(
                      children: [
                        SettingsTile(
                          icon: Icons.brightness_6_outlined,
                          title: 'Theme',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ThemeScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SettingsTile(
                          icon: Icons.info_outline,
                          title: 'About Cash IO',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AboutPlatformScreen()),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        SettingsTile(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
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
                              MaterialPageRoute(builder: (_) => const LanguageScreen()),
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
              child: ElevatedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await AgentService.clearToken();
                  if (!mounted) return;
                  navigator.pushAndRemoveUntil(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1),
      );
}
