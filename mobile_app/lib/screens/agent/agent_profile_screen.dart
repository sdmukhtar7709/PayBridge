import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/agent_service.dart';
import '../../widgets/settings_section.dart';
import '../../widgets/settings_tile.dart';
import '../auth/login_screen.dart';
import '../user/profile/about_platform_screen.dart';
import '../user/profile/change_password_screen.dart';
import '../user/profile/language_screen.dart';
import '../user/profile/theme_screen.dart';
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
  bool _isUpdatingAvailability = false;

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

    if (shouldLogout == true) {
      final navigator = Navigator.of(context);
      await AgentService.clearToken();
      if (!mounted) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = (profile?.name.trim().isNotEmpty ?? false) ? profile!.name.trim() : 'Agent';
    final isVerified = profile?.isVerified ?? false;
    final isAvailable = profile?.available ?? false;
    final isBanned = profile?.isBanned ?? false;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('My Profile', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (isBanned) ...[
                      _buildBannedBanner(),
                      const SizedBox(height: 12),
                    ],
                    _buildHeader(
                      name: name,
                      accountType: 'Agent',
                      isVerified: isVerified,
                      onVerifiedTap: isVerified ? _showVerifiedDialog : null,
                      photoImage:
                          _profilePhotoBytes != null ? MemoryImage(_profilePhotoBytes!) : null,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openManageProfile(),
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
                          onTap: () => _openManageProfile(),
                        ),
                        _QuickAction(
                          icon: isAvailable ? Icons.toggle_on : Icons.toggle_off,
                          label: isAvailable ? 'Go Offline' : 'Go Online',
                          onTap: _isUpdatingAvailability ? null : _toggleAvailability,
                        ),
                        _QuickAction(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Cash Limit',
                          onTap: () => _openManageProfile(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Profile Details'),
                    const SizedBox(height: 8),
                    _infoSection(
                      title: 'Personal Info',
                      rows: [
                        _InfoRow('Email', _field(profile?.email)),
                        _InfoRow('Phone', _field(profile?.phone)),
                        _InfoRow('Gender', _field(profile?.gender)),
                        _InfoRow('Age', profile?.age?.toString() ?? '-'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoSection(
                      title: 'Location',
                      rows: [
                        _InfoRow('City', _field(profile?.city)),
                        _InfoRow('Address', _field(profile?.address)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoSection(
                      title: 'Agent Info',
                      rows: [
                        _InfoRow('Shop Name', _field(profile?.locationName)),
                        _InfoRow('Cash Limit', _numField(profile?.cashLimit)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _statusSection(
                      title: 'Status',
                      items: [
                        _StatusItem(label: 'Verified', value: isVerified),
                        _StatusItem(label: 'Available', value: isAvailable),
                        _StatusItem(label: 'Banned', value: isBanned, positiveWhenTrue: false),
                      ],
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
                              MaterialPageRoute(builder: (_) => const ThemeScreen()),
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
                              MaterialPageRoute(builder: (_) => const AboutPlatformScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        SettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () {},
                        ),
                        const SizedBox(height: 6),
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
                        const SizedBox(height: 6),
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
                    const SizedBox(height: 20),
                    Center(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: ElevatedButton.icon(
                          onPressed: _confirmLogout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
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
    );
  }

  void _openManageProfile() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => const AgentManageProfileScreen(),
          ),
        )
        .then((updated) {
      if (updated == true) _loadProfile();
    });
  }

  Future<void> _toggleAvailability() async {
    final profile = _profile;
    if (profile == null || _isUpdatingAvailability) return;
    final next = !(profile.available ?? false);
    setState(() => _isUpdatingAvailability = true);
    try {
      await AgentService.patchAgentProfile({'available': next});
      if (!mounted) return;
      await _loadProfile();
    } catch (_) {
      // keep previous state
    } finally {
      if (mounted) setState(() => _isUpdatingAvailability = false);
    }
  }

  Widget _buildHeader({
    required String name,
    required String accountType,
    required bool isVerified,
    ImageProvider<Object>? photoImage,
    VoidCallback? onVerifiedTap,
  }) {
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
            backgroundImage: photoImage,
            child: photoImage == null
                ? const Icon(Icons.person, size: 34, color: Color(0xff2563EB))
                : null,
          ),
          const SizedBox(width: 14),
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
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isVerified)
                      GestureDetector(
                        onTap: onVerifiedTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xffECFDF3),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xffA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: Color(0xff059669)),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
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
                      color: action.onTap == null
                          ? const Color(0xffF3F5F9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xffE6EBF5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          action.icon,
                          color: action.onTap == null
                              ? const Color(0xff9CA3AF)
                              : const Color(0xff2563EB),
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          action.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: action.onTap == null
                                ? const Color(0xff9CA3AF)
                                : Colors.black87,
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
    final text = value ? 'Yes' : 'No';
    final isPositive = value == item.positiveWhenTrue;
    final Color chipColor = isPositive ? const Color(0xffECFDF3) : const Color(0xffFEF2F2);
    final Color borderColor = isPositive ? const Color(0xffA7F3D0) : const Color(0xffFECACA);
    final Color textColor = isPositive ? const Color(0xff059669) : const Color(0xffDC2626);

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

  Future<void> _showVerifiedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xffECFDF3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified, color: Color(0xff059669)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '🎉 You’re Verified!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your agent account has been approved by the admin.',
                  style: TextStyle(color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You can now:',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Accept nearby requests\nPerform cash-in and cash-out services',
                  style: TextStyle(color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Text(
                  '🚀 Start earning now!',
                  style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('OK'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xffFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffF7B6B6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'You are banned',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
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
  final VoidCallback? onTap;

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
  final bool value;
  final bool positiveWhenTrue;

  const _StatusItem({
    required this.label,
    required this.value,
    this.positiveWhenTrue = true,
  });
}
