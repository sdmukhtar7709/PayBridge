import 'package:flutter/material.dart';

import '../../widgets/custom_textfield.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                hint: 'Old Password',
                icon: Icons.lock_outline,
                controller: _oldPasswordController,
                isPassword: true,
              ),
              CustomTextField(
                hint: 'New Password',
                icon: Icons.lock,
                controller: _newPasswordController,
                isPassword: true,
              ),
              CustomTextField(
                hint: 'Confirm Password',
                icon: Icons.lock_reset,
                controller: _confirmPasswordController,
                isPassword: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _handleUpdate,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleUpdate() {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    String? error;
    if (oldPassword.isEmpty) {
      error = 'Please enter your old password';
    } else if (newPassword.isEmpty) {
      error = 'Please enter a new password';
    } else if (confirmPassword.isEmpty) {
      error = 'Please confirm your new password';
    } else if (newPassword != confirmPassword) {
      error = 'New password and confirm password do not match';
    }

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    // TODO: Call backend API to change password securely (pass old & new passwords).
    debugPrint('Old: $oldPassword');
    debugPrint('New: $newPassword');
    debugPrint('Confirm: $confirmPassword');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully')),
    );
  }
}
