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
import '../../../widgets/responsive_utils.dart';
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

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AlertDialog(
              title: const Text('Logout'),
              content: const SingleChildScrollView(
                child: Text('Are you sure you want to logout?'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldLogout == true && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaleFactor = Responsive.scaleFactor(context);
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('My Profile', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pagePadding = Responsive.pagePadding(context);
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      pagePadding.left,
                      16,
                      pagePadding.right,
                      20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth >= 900 ? 760 : double.infinity,
                        ),
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
                                child: Text(
                                  'Manage Profile',
                                  style: TextStyle(fontSize: 14 * scaleFactor),
                                ),
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
                            Center(
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                constraints: const BoxConstraints(maxWidth: 520),
                                child: ElevatedButton.icon(
                                  onPressed: _confirmLogout,
                                  icon: const Icon(Icons.logout),
                                  label: Text(
                                    'Logout',
                                    style: TextStyle(fontSize: 15 * scaleFactor),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
            radius: 34 * Responsive.scaleFactor(context),
            backgroundColor: const Color(0xffE0ECFF),
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Icon(
                    Icons.person,
                    size: 34 * Responsive.scaleFactor(context),
                    color: const Color(0xff2563EB),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: Responsive.fs(context, 20),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  accountType,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: Responsive.fs(context, 13),
                  ),
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
      style: TextStyle(
        fontSize: Responsive.fs(context, 15),
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: Responsive.fs(context, 12),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.black54,
                fontSize: Responsive.fs(context, 12),
              ),
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                fontSize: Responsive.fs(context, 12),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
