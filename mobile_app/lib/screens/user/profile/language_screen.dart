import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'English'; // Local-only state; no backend yet.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
      ),
      body: ListView(
        children: [
          _languageTile('English'),
          _languageTile('Hindi'),
          _languageTile('Marathi'),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Selection is local-only for now. Add persistence/localization wiring here later.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageTile(String language) {
    return RadioListTile<String>(
      title: Text(language),
      value: language,
      groupValue: _selectedLanguage,
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedLanguage = value);
        // TODO: Persist chosen language or trigger localization updates here.
      },
    );
  }
}
