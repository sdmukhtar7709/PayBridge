import 'package:flutter/material.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  String _selectedTheme = 'Light'; // Local-only state; add persistence/API later.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme'),
      ),
      body: ListView(
        children: [
          RadioListTile<String>(
            title: const Text('Light Mode'),
            value: 'Light',
            groupValue: _selectedTheme,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedTheme = value);
              // TODO: Save preference to local storage (e.g., SharedPreferences) or backend.
            },
          ),
          RadioListTile<String>(
            title: const Text('Dark Mode'),
            value: 'Dark',
            groupValue: _selectedTheme,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedTheme = value);
              // TODO: Save preference to local storage (e.g., SharedPreferences) or backend.
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Theme selection is local-only for now. Hook global theming and persistence here later.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
