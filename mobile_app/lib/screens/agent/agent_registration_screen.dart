import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../services/agent_service.dart';
import '../../services/location_service.dart';
import 'agent_login_screen.dart';

class AgentRegistrationScreen extends StatefulWidget {
  const AgentRegistrationScreen({super.key});

  @override
  State<AgentRegistrationScreen> createState() => _AgentRegistrationScreenState();
}

class _AgentRegistrationScreenState extends State<AgentRegistrationScreen> {
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _cashLimitController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();

  String _gender = 'Male';
  String _maritalStatus = 'Single';
  DateTime? _dob;
  XFile? _pickedImage;
  String? _profileImageData;
  String _locationStatus = 'Pending';
  bool _isFetchingLocation = false;
  bool _isSubmitting = false;
  static const Color _primary = Color(0xFF5E4AE3);
  static const Color _bg = Color(0xFFF7F2FF);

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  Future<void> _prefillFromProfile() async {
    AgentProfileData? profile;
    try {
      profile = await AgentService.getProfile();
    } catch (_) {
      profile = await AgentService.getCachedProfile();
    }

    if (!mounted || profile == null) return;

    final trimmedFirst = (profile.firstName ?? '').trim();
    final trimmedLast = (profile.lastName ?? '').trim();
    var firstName = trimmedFirst;
    var lastName = trimmedLast;

    if (firstName.isEmpty && lastName.isEmpty) {
      final parts = profile.name
          .trim()
          .split(RegExp(r'\s+'))
          .where((value) => value.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }
    }

    if (_firstNameController.text.trim().isEmpty && firstName.isNotEmpty) {
      _firstNameController.text = firstName;
    }
    if (_lastNameController.text.trim().isEmpty && lastName.isNotEmpty) {
      _lastNameController.text = lastName;
    }
    if (_mobileController.text.trim().isEmpty && (profile.phone ?? '').trim().isNotEmpty) {
      _mobileController.text = profile.phone!.trim();
    }
    if (_addressController.text.trim().isEmpty && (profile.address ?? '').trim().isNotEmpty) {
      _addressController.text = profile.address!.trim();
    }
    if (_cityController.text.trim().isEmpty && (profile.city ?? '').trim().isNotEmpty) {
      _cityController.text = profile.city!.trim();
    }
    if (_shopNameController.text.trim().isEmpty && (profile.locationName ?? '').trim().isNotEmpty) {
      _shopNameController.text = profile.locationName!.trim();
    }
    if (_cashLimitController.text.trim().isEmpty && profile.cashLimit != null) {
      _cashLimitController.text = profile.cashLimit!.toString();
    }
    if ((_profileImageData ?? '').trim().isEmpty && (profile.profileImage ?? '').trim().isNotEmpty) {
      _profileImageData = profile.profileImage!.trim();
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _aadhaarController.dispose();
    _shopNameController.dispose();
    _cashLimitController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submitAgentRegistration() async {
    final hasAgentSession = (await AgentService.getToken())?.isNotEmpty == true;
    if (!mounted) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final mobile = _mobileController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final shopName = _shopNameController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final cashLimitRaw = _cashLimitController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name and last name are required')),
      );
      return;
    }
    if (!hasAgentSession && (email.isEmpty || password.length < 8)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid email and password (min 8 chars)')),
      );
      return;
    }
    if (mobile.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mobile and address are required')),
      );
      return;
    }
    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('City is required for agent availability')),
      );
      return;
    }

    final cashLimit = double.tryParse(cashLimitRaw);
    if (cashLimit == null || cashLimit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid cash limit amount')),
      );
      return;
    }

    final age = _dob == null
        ? 21
        : DateTime.now().difference(_dob!).inDays ~/ 365;

    setState(() => _isSubmitting = true);
    try {
      if (hasAgentSession) {
        await AgentService.updatePersonalProfile({
          'firstName': firstName,
          'lastName': lastName,
          'phone': mobile,
          'gender': _gender,
          'maritalStatus': _maritalStatus,
          'age': age,
          'address': address,
          'profileImage': _profileImageData ?? '',
        });
        await AgentService.patchAgentProfile({'city': city}).catchError((_) {});
      } else {
        await AgentService.registerAgent(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phone: mobile,
          gender: _gender,
          maritalStatus: _maritalStatus,
          age: age,
          address: address,
          shopName: shopName,
          cashLimit: cashLimit,
          city: city,
          profileImage: _profileImageData,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hasAgentSession ? 'Profile updated successfully' : 'Agent registered successfully')),
      );
      if (hasAgentSession) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.verified_user_outlined, size: 54, color: Colors.green),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Agent Registration',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 22),
                  _pillField(controller: _firstNameController, hint: 'First name', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _pillField(controller: _middleNameController, hint: 'Middle name (optional)', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _pillField(controller: _lastNameController, hint: 'Last name', icon: Icons.person_outline),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _mobileController,
                    hint: 'Mobile number',
                    icon: Icons.phone_android,
                    keyboardType: TextInputType.phone,
                    helper: 'WhatsApp OTP verification placeholder',
                  ),
                  const SizedBox(height: 12),
                  _dropdownField(
                    label: 'Gender',
                    value: _gender,
                    items: const ['Male', 'Female', 'Other'],
                    onChanged: (v) => setState(() => _gender = v ?? _gender),
                  ),
                  const SizedBox(height: 12),
                  _dropdownField(
                    label: 'Marital Status',
                    value: _maritalStatus,
                    items: const ['Single', 'Married', 'Other'],
                    onChanged: (v) => setState(() => _maritalStatus = v ?? _maritalStatus),
                  ),
                  const SizedBox(height: 12),
                  _datePickerField(context),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _aadhaarController,
                    hint: 'Aadhaar number',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _pillField(controller: _shopNameController, hint: 'Shop name (optional)', icon: Icons.store_mall_directory_outlined),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _cashLimitController,
                    hint: 'Cash limit (e.g. 50000)',
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _addressController,
                    hint: 'Address',
                    icon: Icons.location_on_outlined,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _cityController,
                    hint: 'City (e.g. Pune)',
                    icon: Icons.location_city_outlined,
                  ),
                  const SizedBox(height: 12),
                  _profilePhotoPicker(),
                  const SizedBox(height: 12),
                  _currentLocationSection(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitAgentRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit / Apply as Agent'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await AgentService.clearToken();
                        if (!mounted) return;
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '* All information will be verified by the Cash IO admin. You will be contacted for further background verification before approval.',
                      style: TextStyle(color: Colors.black54, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: _primary, width: 1.4),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(helper, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ],
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: _primary, width: 1.4),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _datePickerField(BuildContext context) {
    final text = _dob == null
        ? 'Select Date of Birth'
        : '${_dob!.day.toString().padLeft(2, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.year}';
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000, 1, 1),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => _dob = picked);
          // TODO: Send DOB to backend with the rest of the form data.
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Date of Birth',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(color: _primary, width: 1.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.blue),
            const SizedBox(width: 10),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _profilePhotoPicker() {
    final photoBytes = _currentPhotoBytes;
    final ImageProvider<Object>? photoProvider = _pickedImage != null
        ? FileImage(File(_pickedImage!.path))
        : (photoBytes != null ? MemoryImage(photoBytes) : null);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xffe0f2fe),
            backgroundImage: photoProvider,
            child: photoProvider == null ? const Icon(Icons.person, color: Colors.blue) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profile Picture'),
                const SizedBox(height: 4),
                Text(
                  photoBytes == null ? 'Tap upload to pick an image.' : 'Profile picture ready',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _showImagePicker,
            child: const Text('Upload'),
          ),
        ],
      ),
    );
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

  Future<void> _showImagePicker() async {
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
      if (picked == null) return;
      final dataUri = await _toDataUri(picked);
      if (!mounted) return;
      setState(() {
        _pickedImage = picked;
        _profileImageData = dataUri;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick image. Please try again.')),
      );
    }
  }

  Widget _currentLocationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Use current location for address',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          OutlinedButton(
            onPressed: _isFetchingLocation ? null : _applyCurrentLocation,
            child: Text(_isFetchingLocation ? 'Getting...' : 'Use Now'),
          ),
          const SizedBox(width: 8),
          Text(
            _locationStatus,
            style: TextStyle(
              color: _locationStatus == 'Updated' ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      final location = await _locationService.getCurrentLocation();
      final hasAgentSession = (await AgentService.getToken())?.isNotEmpty == true;
      if (hasAgentSession) {
        try {
          await AgentService.updatePersonalProfile({'address': location.address});
        } catch (_) {
          // Ignore profile persistence errors for smoother UX.
        }
        try {
          await AgentService.updateAgentLocation(
            locationName: location.city,
            latitude: location.latitude,
            longitude: location.longitude,
          );
        } catch (_) {
          // Ignore business location persistence errors for smoother UX.
        }
      }
      if (!mounted) return;
      setState(() {
        _addressController.text = location.address;
        if (_shopNameController.text.trim().isEmpty) {
          _shopNameController.text = location.city;
        }
        _locationStatus = 'Updated';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationStatus = 'Failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }
}
