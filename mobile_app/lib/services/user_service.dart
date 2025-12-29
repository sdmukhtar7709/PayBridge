import 'package:flutter/material.dart';

class UserService {
  // TODO: Wire this to backend logout API.
  void logoutUser() {
    debugPrint('UserService.logoutUser: simulate logout');
  }

  // TODO: Wire this to backend profile update API.
  void updateProfile(Map<String, dynamic> profileData) {
    debugPrint('UserService.updateProfile: $profileData');
  }

  // TODO: Wire this to backend change-password API.
  void changePassword({required String oldPassword, required String newPassword}) {
    debugPrint('UserService.changePassword: old=$oldPassword new=$newPassword');
  }

  // TODO: Persist language to backend or local storage.
  void saveLanguagePreference(String language) {
    debugPrint('UserService.saveLanguagePreference: $language');
  }
}
