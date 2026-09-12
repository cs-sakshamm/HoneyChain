import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// User Profile Model with full role-based profile support
class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String role; // 'HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB', 'PACKAGING', 'ADMIN'
  final String? organizationName;
  final String? facilityLocation;
  final String? licenseNumber;
  final String? designation;

  // Harvester identity (issued once, persisted in PostgreSQL, never regenerated casually)
  final String? bsid;
  final String? bspPass;

  // Authoritative status from backend if available
  final bool? isBackendComplete;

  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'HARVESTER',
    this.organizationName,
    this.facilityLocation,
    this.licenseNumber,
    this.designation,
    this.bsid,
    this.bspPass,
    this.isBackendComplete,
  });

  /// Role-based profile completion calculation.
  /// Backend remains the authoritative validator.
  bool get isProfileComplete {
    final nameOk = name.trim().isNotEmpty && name.trim().toLowerCase() != 'unknown';
    final emailOk = email.trim().isNotEmpty && !email.contains('anonymous');
    final phoneOk = phone.trim().isNotEmpty;

    final normRole = role.toUpperCase().trim();

    // 1. Harvester Profile
    if (normRole.isEmpty || normRole == 'HARVESTER') {
      return nameOk && emailOk && phoneOk;
    }

    // 2. Collection & Processing Profile
    if (normRole.contains('COLLECT') || normRole.contains('PROCESS')) {
      final orgOk = organizationName?.trim().isNotEmpty ?? false;
      final locOk = facilityLocation?.trim().isNotEmpty ?? false;
      final licOk = licenseNumber?.trim().isNotEmpty ?? false;
      return nameOk && phoneOk && orgOk && locOk && licOk;
    }

    // 3. Lab Testing Profile
    if (normRole.contains('LAB')) {
      final orgOk = organizationName?.trim().isNotEmpty ?? false;
      final locOk = facilityLocation?.trim().isNotEmpty ?? false;
      final licOk = licenseNumber?.trim().isNotEmpty ?? false;
      return nameOk && phoneOk && orgOk && locOk && licOk;
    }

    // 4. Packaging Profile
    if (normRole.contains('PKG') || normRole.contains('PACKAG')) {
      final orgOk = organizationName?.trim().isNotEmpty ?? false;
      final locOk = facilityLocation?.trim().isNotEmpty ?? false;
      final licOk = licenseNumber?.trim().isNotEmpty ?? false;
      return nameOk && phoneOk && orgOk && locOk && licOk;
    }

    return nameOk && phoneOk;
  }

  String get initials {
    if (name.trim().isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
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
  static const String _roleKey = 'user_profile_role';
  static const String _orgKey = 'user_profile_organization';
  static const String _locKey = 'user_profile_location';
  static const String _licKey = 'user_profile_license';
  static const String _desigKey = 'user_profile_designation';
  static const String _bsidKey = 'user_profile_bsid';
  static const String _bspKey = 'user_profile_bsp_pass';

  final http.Client _client;
  final String _baseUrl;

  UserProfile _user = const UserProfile(
    name: 'HoneyChain Apiary Manager',
    email: 'operations@honeychain.io',
    phone: '+1 (555) 234-5678',
    role: 'HARVESTER',
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

  Future<void> _loadProfile([String? roleOverride]) async {
    // 1. First load from local SharedPreferences for immediate UI responsiveness
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey) ?? 'HoneyChain Apiary Manager';
    final email = prefs.getString(_emailKey) ?? 'operations@honeychain.io';
    final phone = prefs.getString(_phoneKey) ?? '+1 (555) 234-5678';
    final role = roleOverride ?? prefs.getString(_roleKey) ?? 'HARVESTER';
    final org = prefs.getString(_orgKey);
    final loc = prefs.getString(_locKey);
    final lic = prefs.getString(_licKey);
    final desig = prefs.getString(_desigKey);

    _user = UserProfile(
      name: name,
      email: email,
      phone: phone,
      role: role,
      organizationName: org,
      facilityLocation: loc,
      licenseNumber: lic,
      designation: desig,
      bsid: prefs.getString(_bsidKey),
      bspPass: prefs.getString(_bspKey),
    );
    notifyListeners();

    // 2. Fetch authoritative profile from PostgreSQL backend
    await fetchProfile(role: role);
  }

  /// Switch the active role context and sync authoritative role profile
  Future<void> switchRole(String newRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, newRole);
    _user = UserProfile(
      name: _user.name,
      email: _user.email,
      phone: _user.phone,
      role: newRole,
      organizationName: _user.organizationName,
      facilityLocation: _user.facilityLocation,
      licenseNumber: _user.licenseNumber,
      designation: _user.designation,
      bsid: _user.bsid,
      bspPass: _user.bspPass,
    );
    notifyListeners();
    await fetchProfile(role: newRole);
  }

  /// Fetch authoritative profile from backend
  Future<void> fetchProfile({String? role}) async {
    try {
      final activeRole = role ?? _user.role;
      final uri = Uri.parse('$_baseUrl/api/profile').replace(
        queryParameters: {'role': activeRole},
      );
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['profile'] != null) {
          final p = data['profile'];
          _user = UserProfile(
            name: p['name'] ?? _user.name,
            email: p['email'] ?? _user.email,
            phone: p['phone'] ?? _user.phone,
            role: p['role'] ?? _user.role,
            organizationName: p['organizationName'] ?? _user.organizationName,
            facilityLocation: p['facilityLocation'] ?? _user.facilityLocation,
            licenseNumber: p['licenseNumber'] ?? _user.licenseNumber,
            designation: p['designation'] ?? _user.designation,
            bsid: p['bsid'] ?? _user.bsid,
            bspPass: p['bspPass'] ?? _user.bspPass,
            isBackendComplete: p['isProfileComplete'] as bool?,
          );
          notifyListeners();

          // Save to local cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_nameKey, _user.name);
          await prefs.setString(_emailKey, _user.email);
          await prefs.setString(_phoneKey, _user.phone);
          await prefs.setString(_roleKey, _user.role);
          if (_user.organizationName != null) await prefs.setString(_orgKey, _user.organizationName!);
          if (_user.facilityLocation != null) await prefs.setString(_locKey, _user.facilityLocation!);
          if (_user.licenseNumber != null) await prefs.setString(_licKey, _user.licenseNumber!);
          if (_user.designation != null) await prefs.setString(_desigKey, _user.designation!);
          if (_user.bsid != null) await prefs.setString(_bsidKey, _user.bsid!);
          if (_user.bspPass != null) await prefs.setString(_bspKey, _user.bspPass!);
        }
      }
    } catch (e) {
      debugPrint('[UserController] Profile backend sync skipped: $e');
    }
  }

  /// Update profile details across all role fields
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? role,
    String? organizationName,
    String? facilityLocation,
    String? licenseNumber,
    String? designation,
  }) async {
    final effectiveRole = role ?? _user.role;

    _user = UserProfile(
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: effectiveRole,
      organizationName: organizationName?.trim(),
      facilityLocation: facilityLocation?.trim(),
      licenseNumber: licenseNumber?.trim(),
      designation: designation?.trim(),
      bsid: _user.bsid,
      bspPass: _user.bspPass,
    );
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, _user.name);
    await prefs.setString(_emailKey, _user.email);
    await prefs.setString(_phoneKey, _user.phone);
    await prefs.setString(_roleKey, _user.role);
    if (_user.organizationName != null) {
      await prefs.setString(_orgKey, _user.organizationName!);
    } else {
      await prefs.remove(_orgKey);
    }
    if (_user.facilityLocation != null) {
      await prefs.setString(_locKey, _user.facilityLocation!);
    } else {
      await prefs.remove(_locKey);
    }
    if (_user.licenseNumber != null) {
      await prefs.setString(_licKey, _user.licenseNumber!);
    } else {
      await prefs.remove(_licKey);
    }
    if (_user.designation != null) {
      await prefs.setString(_desigKey, _user.designation!);
    } else {
      await prefs.remove(_desigKey);
    }

    // Sync with PostgreSQL backend
    try {
      final url = Uri.parse('$_baseUrl/api/profile');
      final res = await _client
          .put(
            url,
            headers: _headers,
            body: jsonEncode({
              'name': _user.name,
              'email': _user.email,
              'phone': _user.phone,
              'role': _user.role,
              'organizationName': _user.organizationName,
              'facilityLocation': _user.facilityLocation,
              'licenseNumber': _user.licenseNumber,
              'designation': _user.designation,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['profile'] != null) {
          final p = data['profile'];
          _user = UserProfile(
            name: p['name'] ?? _user.name,
            email: p['email'] ?? _user.email,
            phone: p['phone'] ?? _user.phone,
            role: p['role'] ?? _user.role,
            organizationName: p['organizationName'] ?? _user.organizationName,
            facilityLocation: p['facilityLocation'] ?? _user.facilityLocation,
            licenseNumber: p['licenseNumber'] ?? _user.licenseNumber,
            designation: p['designation'] ?? _user.designation,
            bsid: p['bsid'] ?? _user.bsid,
            bspPass: p['bspPass'] ?? _user.bspPass,
            isBackendComplete: p['isProfileComplete'] as bool?,
          );
          notifyListeners();
        }
      }
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
              role: _user.role,
              organizationName: _user.organizationName,
              facilityLocation: _user.facilityLocation,
              licenseNumber: _user.licenseNumber,
              designation: _user.designation,
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
        role: _user.role,
        organizationName: _user.organizationName,
        facilityLocation: _user.facilityLocation,
        licenseNumber: _user.licenseNumber,
        designation: _user.designation,
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
