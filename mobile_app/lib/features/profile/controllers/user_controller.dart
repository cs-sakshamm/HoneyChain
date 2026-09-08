import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User Profile Model
class UserProfile {
  final String name;
  final String email;
  final String phone;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
  });

  String get initials {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

/// Controller managing user profile details and password updating
class UserController extends ChangeNotifier {
  static const String _nameKey = 'user_profile_name';
  static const String _emailKey = 'user_profile_email';
  static const String _phoneKey = 'user_profile_phone';

  UserProfile _user = const UserProfile(
    name: 'HoneyChain Apiary Manager',
    email: 'operations@honeychain.io',
    phone: '+1 (555) 234-5678',
  );

  UserProfile get user => _user;

  UserController() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey) ?? 'HoneyChain Apiary Manager';
    final email = prefs.getString(_emailKey) ?? 'operations@honeychain.io';
    final phone = prefs.getString(_phoneKey) ?? '+1 (555) 234-5678';

    _user = UserProfile(name: name, email: email, phone: phone);
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    _user = UserProfile(name: name.trim(), email: email.trim(), phone: phone.trim());
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _user.name);
    await prefs.setString(_emailKey, _user.email);
    await prefs.setString(_phoneKey, _user.phone);
    return true;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Simulate network validation delay
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }
}
