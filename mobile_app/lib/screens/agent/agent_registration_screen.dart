import 'package:flutter/material.dart';

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
  final _aadhaarController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();

  String _gender = 'Male';
  String _maritalStatus = 'Single';
  DateTime? _dob;
  static const Color _primary = Color(0xFF5E4AE3);
  static const Color _bg = Color(0xFFF7F2FF);

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _aadhaarController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
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
                          color: Colors.black.withOpacity(0.05),
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
                    controller: _aadhaarController,
                    hint: 'Aadhaar number',
                    icon: Icons.badge_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _pillField(controller: _shopNameController, hint: 'Shop name (optional)', icon: Icons.store_mall_directory_outlined),
                  const SizedBox(height: 12),
                  _pillField(
                    controller: _addressController,
                    hint: 'Address',
                    icon: Icons.location_on_outlined,
                    keyboardType: TextInputType.multiline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _profilePhotoPicker(),
                  const SizedBox(height: 12),
                  _currentLocationSection(),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Submit to backend/admin dashboard for review.
                        debugPrint('Submitting agent application');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Application submitted (demo)')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: const Text('Submit / Apply as Agent'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text('Back to Agent Login'),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xffe0f2fe),
            child: Icon(Icons.person, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Profile Picture'),
                SizedBox(height: 4),
                Text(
                  'Tap upload to pick an image (placeholder).',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              // TODO: Integrate image picker & upload to backend.
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Widget _currentLocationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: const [
          Icon(Icons.location_on, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Using current location (will auto-detect later)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'Pending',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
