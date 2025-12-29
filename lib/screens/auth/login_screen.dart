import 'package:flutter/material.dart';

import '../../widgets/custom_textfield.dart';
import '../user/user_home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _loginUser() {
    // 🔐 BACKEND LOGIN INTEGRATION POINT
    // 1. Read email & password from controllers
    // 2. Send POST request to backend: /api/auth/login
    // 3. Backend verifies credentials
    // 4. On success → receive token (JWT)
    // 5. Navigate to Home/Dashboard screen
    // 6. On failure → show error message

    final email = _emailController.text.trim();
    // ignore: unused_local_variable
    final password = _passwordController.text.trim();

    // Temporary: surface collected values to keep analyzer happy until backend is wired.
    debugPrint('Login attempt for $email');

    // Example (future):
    // AuthService.login(email, password);

    // Temporary demo navigation until backend is wired
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UserHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center( // ✅ PERFECT CENTERING
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 💰 APP ICON
                const Icon(
                  Icons.account_balance_wallet,
                  size: 80,
                  color: Colors.green,
                ),

                const SizedBox(height: 20),

                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // 📧 EMAIL FIELD
                CustomTextField(
                  hint: 'Email',
                  icon: Icons.email,
                  controller: _emailController,
                ),

                // 🔐 PASSWORD FIELD
                CustomTextField(
                  hint: 'Password',
                  icon: Icons.lock,
                  controller: _passwordController,
                  isPassword: true,
                ),

                const SizedBox(height: 20),

                // 🔗 LOGIN BUTTON
                ElevatedButton(
                  onPressed: _loginUser,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Login'),
                ),

                // 🚧 Test-only shortcut to jump to user home
                OutlinedButton(
                  
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Skip to User Home'),
                ),

                // 🔁 GO TO REGISTER
                TextButton(
                  onPressed: _goToRegister,
                  child: const Text("Don't have an account? Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
