import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileService {
  static const String _profileKey = 'user_profile';

  // Save profile
  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = json.encode(profile.toJson());
    await prefs.setString(_profileKey, profileJson);
  }

  // Load profile
  Future<UserProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_profileKey);
    
    if (profileJson == null || profileJson.isEmpty) {
      return UserProfile();
    }
    
    try {
      final Map<String, dynamic> decoded = json.decode(profileJson);
      return UserProfile.fromJson(decoded);
    } catch (e) {
      return UserProfile();
    }
  }

  // Clear profile
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
  }
}
