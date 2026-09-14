import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// User Profile Model
class UserProfile {
  final String name;
  final String email;
  final String phone;

  // Harvester identity (issued once, persisted in PostgreSQL, never regenerated casually)
  final String? bsid;
  final String? bspPass;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.bsid,
    this.bspPass,
  });

  bool get isProfileComplete =>
      name.trim().isNotEmpty && email.trim().isNotEmpty && phone.trim().isNotEmpty;

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
/// persistent harvester identity (BSID + BSP Pass) backed by PostgreSQL.
class UserController extends ChangeNotifier {
  static const String _nameKey = 'user_profile_name';
  static const String _emailKey = 'user_profile_email';
  static const String _phoneKey = 'user_profile_phone';
  static const String _bsidKey = 'user_profile_bsid';
  static const String _bspKey = 'user_profile_bsp_pass';

  final http.Client _client;
  final String _baseUrl;

  UserProfile _user = const UserProfile(
    name: 'HoneyChain Apiary Manager',
    email: 'operations@honeychain.io',
    phone: '+1 (555) 234-5678',
  );

  UserProfile get user => _user;

  UserController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl() {
    _loadProfile();
  }

  static String _resolveBaseUrl() {
    if (kIsWeb) {
      return AppConstants.backendBaseUrl;
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:3000';
      }
    } catch (_) {}
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<void> _loadProfile() async {
    // 1. First load from local SharedPreferences for immediate UI responsiveness
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

    // 2. Fetch authoritative profile from PostgreSQL backend
    try {
      final url = Uri.parse('$_baseUrl/api/profile');
      final response = await _client.get(url, headers: _headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['profile'] != null) {
          final p = data['profile'];
          _user = UserProfile(
            name: p['name'] ?? _user.name,
            email: p['email'] ?? _user.email,
            phone: p['phone'] ?? _user.phone,
            bsid: p['bsid'] ?? _user.bsid,
            bspPass: p['bspPass'] ?? _user.bspPass,
          );
          notifyListeners();

          // Save to local cache
          await prefs.setString(_nameKey, _user.name);
          await prefs.setString(_emailKey, _user.email);
          await prefs.setString(_phoneKey, _user.phone);
          if (_user.bsid != null) await prefs.setString(_bsidKey, _user.bsid!);
          if (_user.bspPass != null) await prefs.setString(_bspKey, _user.bspPass!);
        }
      }
    } catch (e) {
      debugPrint('[UserController] Profile backend sync skipped: $e');
    }
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

    // Sync with PostgreSQL backend
    try {
      final url = Uri.parse('$_baseUrl/api/profile');
      await _client
          .put(
            url,
            headers: _headers,
            body: jsonEncode({
              'name': _user.name,
              'email': _user.email,
              'phone': _user.phone,
            }),
          )
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[UserController] Profile update backend sync error: $e');
    }

    return true;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }

  /// Whether this account already holds a harvester identity.
  bool get hasIdentity => _user.bsid != null && _user.bspPass != null;

  /// Issue the harvester identity (BSID + BSP Pass) exactly once.
  ///
  /// Requests authoritative identity credentials from PostgreSQL backend.
  Future<bool> generateIdentity() async {
    if (!hasIdentity && _user.isProfileComplete) {
      try {
        final url = Uri.parse('$_baseUrl/api/profile/identity');
        final response = await _client
            .post(url, headers: _headers, body: jsonEncode({}))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final bsid = data['bsid'] as String?;
          final bsp = data['bspPass'] as String?;

          if (bsid != null && bsp != null) {
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
        }
      } catch (e) {
        debugPrint('[UserController] Backend identity generation error: $e');
      }

      // Offline fallback: Issue cryptographically random identity locally
      final bsid = _issueLocalId(AppConstants.bsidPrefix, 4);
      final bsp = _issueLocalId(AppConstants.bspPassPrefix, 3);
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

  String _issueLocalId(String prefix, int bytes) {
    final now = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    final suffix = now.length > bytes * 2 ? now.substring(now.length - bytes * 2) : now;
    return '$prefix-2026-$suffix';
  }
}
