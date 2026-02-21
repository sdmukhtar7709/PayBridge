import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight helper to persist and load the profile photo path.
class ProfilePhotoService {
  static const _key = 'profile_photo_path';

  Future<void> savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  Future<File?> loadPhotoFile() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (await file.exists()) return file;

    await prefs.remove(_key);
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
