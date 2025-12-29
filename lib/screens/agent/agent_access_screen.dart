import 'package:flutter/material.dart';

import 'agent_registration_screen.dart';
import 'agent_login_screen.dart';

class AgentAccessScreen extends StatelessWidget {
  const AgentAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join as Agent'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heroCard(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
                );
                // TODO: Integrate backend agent authentication, onboarding, and admin approval checks here.
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: const Text('Register as Agent'),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
                  );
                },
                child: const Text(
                  'Already have an agent account? Login',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF3D8BFF), Color(0xFF9C6CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Become a Trusted Member of Cash IO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Earn by providing cash services securely',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Serve customers in your area and grow your income with Cash IO.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
