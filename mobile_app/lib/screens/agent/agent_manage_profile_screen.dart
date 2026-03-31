import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/agent_service.dart';
import '../../widgets/custom_textfield.dart';

class AgentManageProfileScreen extends StatefulWidget {
  const AgentManageProfileScreen({super.key});

  @override
  State<AgentManageProfileScreen> createState() =>
      _AgentManageProfileScreenState();
}

class _AgentManageProfileScreenState extends State<AgentManageProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _cashLimitController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  bool _isLoadingProfile = false;
  bool _isSaving = false;
  bool _available = false;
  bool _isVerified = false;

  String _selectedGender = 'Male';
  String _selectedMaritalStatus = 'Single';
  XFile? _pickedImage;
  String? _profileImageData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _shopNameController.dispose();
    _cityController.dispose();
    _cashLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await AgentService.getProfile();
      if (!mounted) return;
      _applyProfile(profile);
    } catch (_) {
      final cached = await AgentService.getCachedProfile();
      if (!mounted || cached == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }
      _applyProfile(cached);
    }
  }

  void _applyProfile(AgentProfileData profile) {
    final firstName = (profile.firstName ?? '').trim();
    final lastName = (profile.lastName ?? '').trim();

    _firstNameController.text = firstName;
    _lastNameController.text = lastName;
    _emailController.text = (profile.email ?? '').trim();
    _mobileController.text = (profile.phone ?? '').trim();
    _ageController.text = profile.age?.toString() ?? '';
    _addressController.text = (profile.address ?? '').trim();
    _shopNameController.text = (profile.locationName ?? '').trim();
    _cityController.text = (profile.city ?? '').trim();
    _cashLimitController.text = profile.cashLimit?.toString() ?? '';

    const genders = ['Male', 'Female', 'Other'];
    const maritalStatuses = ['Single', 'Married', 'Other'];

    _selectedGender = genders.contains(profile.gender)
        ? profile.gender!
        : 'Male';
    _selectedMaritalStatus = maritalStatuses.contains(profile.maritalStatus)
        ? profile.maritalStatus!
        : 'Single';

    _available = profile.available ?? false;
    _isVerified = profile.isVerified ?? false;
    _profileImageData = profile.profileImage;

    setState(() => _isLoadingProfile = false);
  }

  Uint8List? get _currentPhotoBytes {
    if (_pickedImage != null) return null;
    if (_profileImageData == null || _profileImageData!.trim().isEmpty) {
      return null;
    }
    final raw = _profileImageData!.trim();
    final base64Part = raw.startsWith('data:image') && raw.contains(',')
        ? raw.substring(raw.indexOf(',') + 1)
        : raw;
    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  File? get _currentPhotoFile {
    if (_pickedImage == null) return null;
    return File(_pickedImage!.path);
  }

  Future<String> _toDataUri(XFile picked) async {
    final bytes = await picked.readAsBytes();
    final encoded = base64Encode(bytes);
    final extension = picked.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return 'data:$mimeType;base64,$encoded';
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;
    final imageData = await _toDataUri(picked);
    if (!mounted) return;
    setState(() {
      _pickedImage = picked;
      _profileImageData = imageData;
    });
  }

  Future<void> _showImagePicker() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSave() async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final ageText = _ageController.text.trim();
    final address = _addressController.text.trim();
    final shopName = _shopNameController.text.trim();
    final city = _cityController.text.trim();
    final cashLimitText = _cashLimitController.text.trim();

    if (first.isEmpty || last.isEmpty) {
      _showError('First name and last name are required');
      return;
    }
    if (mobile.isEmpty) {
      _showError('Mobile number is required');
      return;
    }
    if (city.isEmpty) {
      _showError('City is required for agent availability');
      return;
    }

    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null || age < 1 || age > 120) {
        _showError('Enter valid age between 1 and 120');
        return;
      }
    }

    final cashLimit = num.tryParse(cashLimitText);
    if (cashLimit == null || cashLimit < 0) {
      _showError('Enter valid cash limit');
      return;
    }

    final locationNameToSave = shopName;

    setState(() => _isSaving = true);
    try {
      await AgentService.manageProfile(
        user: {
          'firstName': first,
          'lastName': last,
          'name': '$first $last'.trim(),
          'phone': mobile,
          'gender': _selectedGender,
          'maritalStatus': _selectedMaritalStatus,
          'age': age,
          'address': address,
          'profileImage': _profileImageData,
        },
        agentProfile: {
          'locationName': locationNameToSave,
          'city': city,
          'cashLimit': cashLimit,
          'available': _available,
        },
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent profile updated successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text(
          'Manage Agent Profile',
          style: TextStyle(color: Colors.black87),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingProfile)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                Row(
                  children: [
                    InkWell(
                      onTap: _showImagePicker,
                      borderRadius: BorderRadius.circular(44),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: const Color(0xffe0f2fe),
                            backgroundImage: _currentPhotoFile != null
                                ? FileImage(_currentPhotoFile!)
                                : (_currentPhotoBytes != null
                                      ? MemoryImage(_currentPhotoBytes!)
                                      : null),
                            child:
                                _currentPhotoFile == null &&
                                    _currentPhotoBytes == null
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.blue,
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profile photo',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _showImagePicker,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload new photo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Personal Info',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                IgnorePointer(
                  child: Opacity(
                    opacity: 0.75,
                    child: CustomTextField(
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ),
                CustomTextField(
                  hint: 'First Name',
                  icon: Icons.badge,
                  controller: _firstNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
                CustomTextField(
                  hint: 'Last Name',
                  icon: Icons.badge_outlined,
                  controller: _lastNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
                CustomTextField(
                  hint: 'Mobile Number',
                  icon: Icons.phone,
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        label: 'Gender',
                        value: _selectedGender,
                        items: const ['Male', 'Female', 'Other'],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedGender = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdown(
                        label: 'Marital Status',
                        value: _selectedMaritalStatus,
                        items: const ['Single', 'Married', 'Other'],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedMaritalStatus = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                CustomTextField(
                  hint: 'Age',
                  icon: Icons.calendar_today,
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Location',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  hint: 'Address',
                  icon: Icons.location_on,
                  controller: _addressController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Agent Info',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  hint: 'Shop Name',
                  icon: Icons.store_mall_directory_outlined,
                  controller: _shopNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                ),
                CustomTextField(
                  hint: 'City',
                  icon: Icons.location_city_outlined,
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                ),
                CustomTextField(
                  hint: 'Cash Limit',
                  icon: Icons.currency_rupee,
                  controller: _cashLimitController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Availability',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _available,
                  onChanged: (value) => setState(() => _available = value),
                  title: const Text('Available for customers'),
                  subtitle: Text(
                    _isVerified
                        ? 'Verified agent account'
                        : 'Verification pending',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: const Color(0xff2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isSaving ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xffF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffE2E8F0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff2563EB), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}
