import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/custom_textfield.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firstNameController = TextEditingController(text: 'Muktar');
  final _lastNameController = TextEditingController(text: 'Sayyad');
  final _mobileController = TextEditingController(text: '+91 7709685469');
  final _emailController = TextEditingController(text: 'muktar.sayyad@example.com');
  final _ageController = TextEditingController(text: '22');
  final _addressController = TextEditingController(text: 'Wagholi, Pune');

  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  String _selectedGender = 'Male';
  String _selectedMaritalStatus = 'Single';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f9ff),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black87)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: const Color(0xffe0f2fe),
                          backgroundImage: _pickedImage != null ? FileImage(File(_pickedImage!.path)) : null,
                          child: _pickedImage == null
                              ? const Icon(Icons.person, size: 34, color: Colors.blue)
                              : null,
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
                    const SizedBox(height: 18),
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
                    CustomTextField(
                      hint: 'Email',
                      icon: Icons.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
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
                    CustomTextField(
                      hint: 'Address',
                      icon: Icons.location_on,
                      controller: _addressController,
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Save changes to sync with your account. API wiring can be added in this button handler.',
                      style: TextStyle(color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
        setState(() => _pickedImage = picked);
        // TODO: Upload picked image file to backend storage here.
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image. Please try again.')),
      );
    }
  }

  void _handleSave() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final ageText = _ageController.text.trim();
    final address = _addressController.text.trim();

    String? error;

    if (first.isEmpty) {
      error = 'First name is required';
    } else if (last.isEmpty) {
      error = 'Last name is required';
    } else if (!_isValidPhone(mobile)) {
      error = 'Enter a valid mobile number';
    } else if (!_isValidEmail(email)) {
      error = 'Enter a valid email address';
    } else if (!_isValidAge(ageText)) {
      error = 'Enter a valid age (number)';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    // Log values for demo; replace with API call when backend is ready.
    debugPrint('Saving profile:');
    debugPrint('Name: $first $last');
    debugPrint('Mobile: $mobile');
    debugPrint('Email: $email');
    debugPrint('Gender: $_selectedGender');
    debugPrint('Marital Status: $_selectedMaritalStatus');
    debugPrint('Age: $ageText');
    debugPrint('Address: $address');
    debugPrint('Photo: ${_pickedImage?.path ?? 'not changed'}');
    // TODO: Call backend API to persist profile changes.

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  bool _isValidPhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 8;
  }

  bool _isValidEmail(String input) {
    final emailReg = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailReg.hasMatch(input);
  }

  bool _isValidAge(String input) {
    final age = int.tryParse(input);
    return age != null && age > 0 && age < 120;
  }
}
