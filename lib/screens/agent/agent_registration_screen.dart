import 'package:flutter/material.dart';

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
      appBar: AppBar(
        title: const Text('Agent Registration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(_firstNameController, 'First Name'),
              _buildTextField(_middleNameController, 'Middle Name (optional)'),
              _buildTextField(_lastNameController, 'Last Name'),
              _buildTextField(
                _mobileController,
                'Mobile Number',
                keyboardType: TextInputType.phone,
                helper: 'WhatsApp OTP verification placeholder',
                // TODO: Integrate WhatsApp OTP API here.
              ),
              _buildDropdown(
                label: 'Gender',
                value: _gender,
                items: const ['Male', 'Female', 'Other'],
                onChanged: (v) => setState(() => _gender = v ?? _gender),
              ),
              _buildDropdown(
                label: 'Marital Status',
                value: _maritalStatus,
                items: const ['Single', 'Married', 'Other'],
                onChanged: (v) => setState(() => _maritalStatus = v ?? _maritalStatus),
              ),
              _datePickerField(context),
              _buildTextField(
                _emailController,
                'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField(
                _aadhaarController,
                'Aadhaar Number',
                keyboardType: TextInputType.number,
              ),
              _buildTextField(_shopNameController, 'Shop Name (optional)'),
              _buildTextField(
                _addressController,
                'Address',
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _profilePhotoPicker(),
              const SizedBox(height: 12),
              _currentLocationSection(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // TODO: Submit to backend/admin dashboard for review.
                  debugPrint('Submitting agent application');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Application submitted (demo)')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Submit / Apply as Agent'),
              ),
              const SizedBox(height: 12),
              const Text(
                '* All information will be verified by the Cash IO admin. You will be contacted for further background verification before approval.',
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _datePickerField(BuildContext context) {
    final text = _dob == null
        ? 'Select Date of Birth'
        : '${_dob!.day.toString().padLeft(2, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
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
            labelText: 'Date of Birth',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.blue),
              const SizedBox(width: 10),
              Text(text),
            ],
          ),
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
