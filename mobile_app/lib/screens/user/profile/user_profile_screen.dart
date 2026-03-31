import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/login_screen.dart';
import 'about_platform_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'language_screen.dart';
import 'theme_screen.dart';
import '../../../services/profile_photo_service.dart';
import '../../../services/user_service.dart';
import '../../../widgets/settings_section.dart';
import '../../../widgets/settings_tile.dart';
import '../../../widgets/upi_card.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _profileName = 'User';
  final String _email = '-';
  String _phone = '-';
  String _gender = '-';
  String _age = '-';
  String _city = '-';
  String _address = '-';
  final String _upiId = '770968@ybl';
  File? _photoFile;
  Uint8List? _profilePhotoBytes;
  final ProfilePhotoService _photoService = ProfilePhotoService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadProfile();
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

  Future<void> _loadProfile() async {
    try {
      final profile = await _userService.getProfile();
      if (!mounted) return;
      setState(() {
        _profileName = profile.displayName.isEmpty ? 'User' : profile.displayName;
        _profilePhotoBytes = _decodeProfileImage(profile.profileImage);
        _phone = _field(profile.phone);
        _gender = _field(profile.gender);
        _age = profile.age?.toString() ?? '-';
        _address = _field(profile.address);
        _city = _resolveCity(profile.city, profile.address);
      });
    } catch (_) {
      final cached = await _userService.getCachedProfile();
      if (!mounted || cached == null) return;
      setState(() {
        _profileName = cached.displayName.isEmpty ? 'User' : cached.displayName;
        _profilePhotoBytes = _decodeProfileImage(cached.profileImage);
        _phone = _field(cached.phone);
        _gender = _field(cached.gender);
        _age = cached.age?.toString() ?? '-';
        _address = _field(cached.address);
        _city = _resolveCity(cached.city, cached.address);
      });
    }
  }

  String _field(String? value, {String fallback = '-'}) {
    if (value == null || value.trim().isEmpty) return fallback;
    return value.trim();
  }

  String _deriveCity(String? address) {
    final raw = (address ?? '').trim();
    if (raw.isEmpty) return '-';
    final parts = raw.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    for (final part in parts.reversed) {
      if (!RegExp(r'\d').hasMatch(part)) return part;
    }
    return '-';
  }

  String _resolveCity(String? city, String? address) {
    final trimmed = (city ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    return _deriveCity(address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('My Profile', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(
                      name: _profileName,
                      accountType: 'User',
                      photoFile: _photoFile,
                      photoImage:
                          _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              )
                              .then((updated) {
                            _loadPhoto();
                            if (updated == true) {
                              _loadProfile();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Manage Profile'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Quick Actions'),
                    const SizedBox(height: 8),
                    _buildQuickActions(
                      actions: [
                        _QuickAction(
                          icon: Icons.edit,
                          label: 'Edit Profile',
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => const EditProfileScreen(),
                                  ),
                                )
                                .then((updated) {
                              _loadPhoto();
                              if (updated == true) {
                                _loadProfile();
                              }
                            });
                          },
                        ),
                        _QuickAction(
                          icon: Icons.copy,
                          label: 'Copy UPI',
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: _upiId));
                            if (!context.mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('UPI ID copied')),
                            );
                          },
                        ),
                        _QuickAction(
                          icon: Icons.share,
                          label: 'Share UPI',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share UPI coming soon')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Profile Details'),
                    const SizedBox(height: 8),
                    _infoSection(
                      title: 'Personal Info',
                      rows: [
                        _InfoRow('Email', _email),
                        _InfoRow('Phone', _phone),
                        _InfoRow('Gender', _gender),
                        _InfoRow('Age', _age),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoSection(
                      title: 'Location',
                      rows: [
                        _InfoRow('City', _city),
                        _InfoRow('Address', _address),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _statusSection(
                      title: 'Status',
                      items: const [
                        _StatusItem(label: 'Verified', value: false),
                        _StatusItem(label: 'Available', value: null, nullText: 'N/A'),
                        _StatusItem(label: 'Banned', value: false, positiveWhenTrue: false),
                      ],
                    ),
                    const SizedBox(height: 16),
                    UpiCard(
                      upiId: _upiId,
                      onCopy: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(ClipboardData(text: _upiId));
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('UPI ID copied')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Settings'),
                    const SizedBox(height: 8),
                    SettingsSection(
                      children: [
                        SettingsTile(
                          icon: Icons.brightness_6_outlined,
                          title: 'Theme',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ThemeScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        SettingsTile(
                          icon: Icons.info_outline,
                          title: 'About',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutPlatformScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        SettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () {
                            // TODO: Open Privacy Policy screen or webview.
                          },
                        ),
                        const SizedBox(height: 6),
                        SettingsTile(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: OutlinedButton.icon(
                onPressed: () {
                  debugPrint('Logging out user (demo) and clearing session');
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, size: 18, color: Color(0xffDC2626)),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  foregroundColor: const Color(0xffDC2626),
                  side: const BorderSide(color: Color(0xffFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String name,
    required String accountType,
    File? photoFile,
    ImageProvider<Object>? photoImage,
  }) {
    final imageProvider = photoImage ?? (photoFile != null ? FileImage(photoFile) : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFF7FBFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xffE0ECFF),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(Icons.person, size: 34, color: Color(0xff2563EB))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  accountType,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions({required List<_QuickAction> actions}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 360;
        return GridView.count(
          crossAxisCount: wide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: actions
              .map(
                (action) => InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffE6EBF5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(action.icon, color: const Color(0xff2563EB), size: 20),
                        const SizedBox(height: 6),
                        Text(
                          action.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _infoSection({required String title, required List<_InfoRow> rows}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE6EBF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) => _infoRow(row.label, row.value)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection({required String title, required List<_StatusItem> items}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffE6EBF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => _statusRow(item)),
        ],
      ),
    );
  }

  Widget _statusRow(_StatusItem item) {
    final value = item.value;
    final text = value == null ? item.nullText : (value ? 'Yes' : 'No');
    final isPositive = value == null ? null : (value == item.positiveWhenTrue);
    final Color chipColor;
    final Color borderColor;
    final Color textColor;

    if (isPositive == null) {
      chipColor = const Color(0xffF3F4F6);
      borderColor = const Color(0xffE5E7EB);
      textColor = const Color(0xff6B7280);
    } else if (isPositive) {
      chipColor = const Color(0xffECFDF3);
      borderColor = const Color(0xffA7F3D0);
      textColor = const Color(0xff059669);
    } else {
      chipColor = const Color(0xffFEF2F2);
      borderColor = const Color(0xffFECACA);
      textColor = const Color(0xffDC2626);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              text,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

class _StatusItem {
  final String label;
  final bool? value;
  final bool positiveWhenTrue;
  final String nullText;

  const _StatusItem({
    required this.label,
    required this.value,
    this.positiveWhenTrue = true,
    this.nullText = 'N/A',
  });
}
