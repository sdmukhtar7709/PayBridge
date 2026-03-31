import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/user_service.dart';
import '../../../widgets/custom_textfield.dart';
import '../../../services/profile_photo_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final ProfilePhotoService _photoService = ProfilePhotoService();
  final UserService _userService = UserService();
  XFile? _pickedImage;
  File? _savedPhotoFile;
  String? _profileImageData;
  bool _isLoadingProfile = false;
  bool _isSaving = false;

  String _selectedGender = 'Male';
  String _selectedMaritalStatus = 'Single';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await _userService.getProfile();
      if (!mounted) return;

      setState(() {
        _firstNameController.text = profile.firstName ?? '';
        _lastNameController.text = profile.lastName ?? '';
        _mobileController.text = profile.phone ?? '';
        _ageController.text = profile.age?.toString() ?? '';
        _cityController.text = profile.city ?? '';
        _addressController.text = profile.address ?? '';

        const genders = ['Male', 'Female', 'Other'];
        const maritalStatuses = ['Single', 'Married', 'Other'];

        _selectedGender = genders.contains(profile.gender) ? profile.gender! : 'Male';
        _selectedMaritalStatus = maritalStatuses.contains(profile.maritalStatus)
            ? profile.maritalStatus!
            : 'Single';
      });

      final profileImagePath = profile.profileImage;
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        final file = File(profileImagePath);
        if (await file.exists()) {
          await _persistPhotoPath(profileImagePath);
          if (!mounted) return;
          setState(() => _savedPhotoFile = file);
        } else {
          setState(() => _profileImageData = profileImagePath);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.4,
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            children: [
              Container(
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
                                    : (_currentPhotoBytes != null ? MemoryImage(_currentPhotoBytes!) : null),
                                child: _currentPhotoFile == null && _currentPhotoBytes == null
                                    ? const Icon(Icons.person, size: 40, color: Colors.blue)
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
                                child: const Icon(Icons.edit, size: 16, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
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
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Personal Info',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
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
                      hint: 'City',
                      icon: Icons.location_city,
                      controller: _cityController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                    ),
                    CustomTextField(
                      hint: 'Address',
                      icon: Icons.location_on,
                      controller: _addressController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xff2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _persistPhotoPath(String path) async {
    await _photoService.savePath(path);
    _savedPhotoFile = File(path);
  }

  Future<void> _loadSavedPhoto() async {
    final file = await _photoService.loadPhotoFile();
    if (file != null && mounted) {
      setState(() => _savedPhotoFile = file);
    }
  }

  File? get _currentPhotoFile {
    if (_pickedImage != null) return File(_pickedImage!.path);
    if (_savedPhotoFile != null) return _savedPhotoFile;
    return null;
  }

  Uint8List? get _currentPhotoBytes {
    if (_profileImageData == null || _profileImageData!.trim().isEmpty) return null;
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Future<void> _showImagePicker() async {
    // For real apps, remember to add image_picker to pubspec.yaml and request permissions.
    showModalBottomSheet(
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 75);
      if (picked != null) {
        final imageData = await _toDataUri(picked);
        setState(() {
          _pickedImage = picked;
          _profileImageData = imageData;
        });
        await _persistPhotoPath(picked.path);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Image pick error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image. Please try again.')),
      );
    }
  }

  Future<void> _handleSave() async {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final ageText = _ageController.text.trim();
    final city = _cityController.text.trim();
    final address = _addressController.text.trim();

    String? error;

    if (first.isEmpty) {
      error = 'First name is required';
    } else if (last.isEmpty) {
      error = 'Last name is required';
    } else if (!_isValidPhone(mobile)) {
      error = 'Enter a valid mobile number';
    } else if (!_isValidAge(ageText)) {
      error = 'Enter a valid age (number)';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid age (number)')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _userService.updateProfile({
        'firstName': first,
        'lastName': last,
        'phone': mobile,
        'gender': _selectedGender,
        'maritalStatus': _selectedMaritalStatus,
        'age': age,
        'address': address,
        'city': city,
        'profileImage': _profileImageData ?? '',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool _isValidPhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8;
  }

  bool _isValidAge(String input) {
    final age = int.tryParse(input);
    return age != null && age > 0 && age < 120;
  }
}
