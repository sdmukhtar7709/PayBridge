import 'package:flutter/material.dart';

import '../../widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _registerUser() {
    // 📝 BACKEND REGISTRATION INTEGRATION POINT
    // 1. Collect user details (name, email, phone, password)
    // 2. Send POST request to backend: /api/auth/register
    // 3. Backend validates & stores user securely
    // 4. Backend sends success response
    // 5. Redirect user to Login or OTP verification screen

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    // ignore: unused_local_variable
    final password = _passwordController.text.trim();

    // Temporary: log collected values until backend wiring is added.
    debugPrint('Register user: $name, $email, $phone');

    // Example (future):
    // AuthService.register(name, email, phone, password);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center( // ✅ PERFECT CENTERING
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 👤 FULL NAME
                CustomTextField(
                  hint: 'Full Name',
                  icon: Icons.person,
                  controller: _nameController,
                ),

                // 📧 EMAIL
                CustomTextField(
                  hint: 'Email',
                  icon: Icons.email,
                  controller: _emailController,
                ),

                // 📱 PHONE NUMBER
                CustomTextField(
                  hint: 'Phone Number',
                  icon: Icons.phone,
                  controller: _phoneController,
                ),

                // 🔐 PASSWORD
                CustomTextField(
                  hint: 'Password',
                  icon: Icons.lock,
                  controller: _passwordController,
                  isPassword: true,
                ),

                const SizedBox(height: 20),

                // 🔗 REGISTER BUTTON
                ElevatedButton(
                  onPressed: _registerUser,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
