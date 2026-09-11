import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// User Profile Model
class UserProfile {
  final String name;
  final String email;
  final String phone;

  // Harvester identity (issued once, persisted, never regenerated casually)
  final String? bsid;
  final String? bspPass;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.bsid,
    this.bspPass,
  });

  bool get isProfileComplete => name.trim().isNotEmpty && email.trim().isNotEmpty && phone.trim().isNotEmpty;

  String get initials {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

/// Controller managing user profile details, password updating, and the
/// persistent harvester identity (BSID + BSP Pass).
class UserController extends ChangeNotifier {
  static const String _nameKey = 'user_profile_name';
  static const String _emailKey = 'user_profile_email';
  static const String _phoneKey = 'user_profile_phone';
  static const String _bsidKey = 'user_profile_bsid';
  static const String _bspKey = 'user_profile_bsp_pass';

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

    _user = UserProfile(
      name: name,
      email: email,
      phone: phone,
      bsid: prefs.getString(_bsidKey),
      bspPass: prefs.getString(_bspKey),
    );
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    _user = UserProfile(
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      bsid: _user.bsid,
      bspPass: _user.bspPass,
    );
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

  /// Whether this account already holds a harvester identity.
  bool get hasIdentity => _user.bsid != null && _user.bspPass != null;

  /// Issue the harvester identity (BSID + BSP Pass) exactly once.
  ///
  /// Requires a complete profile — identity is only granted to verified
  /// accounts. If the backend identity endpoint exists it should be used
  /// instead; locally we generate a unique ID with a secure RNG and persist
  /// it so it is never regenerated.
  Future<bool> generateIdentity() async {
    if (!hasIdentity && _user.isProfileComplete) {
      final bsid = _issueId(AppConstants.bsidPrefix, 8);
      final bsp = _issueId(AppConstants.bspPassPrefix, 6);
      _user = UserProfile(
        name: _user.name,
        email: _user.email,
        phone: _user.phone,
        bsid: bsid,
        bspPass: bsp,
      );
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bsidKey, bsid);
      await prefs.setString(_bspKey, bsp);
      return true;
    }
    return false;
  }

  /// Cryptographically random, collision-resistant identifier.
  String _issueId(String prefix, int bytes) {
    final rng = Random.secure();
    final hex = List.generate(
      bytes,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join().toUpperCase();
    return '$prefix-2026-$hex';
  }
}
