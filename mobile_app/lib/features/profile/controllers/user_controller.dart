import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

/// User Profile Model with full role-based profile support
class UserProfile {
  final String? id;
  final String name;
  final String email;
  final String phone;
  final String role; // 'HARVESTER', 'COLLECTOR_PROCESSOR', 'LAB', 'PACKAGING', 'ADMIN'
  final String? avatarUrl; // Tier 1: Custom user-uploaded picture
  final String? googlePhotoUrl; // Tier 2: Google profile picture
  final String? photoUrl; // Backward-compatible alias
  final String? organizationName;
  final String? facilityLocation;
  final String? licenseNumber;
  final String? designation;

  // Beekeeper identity (permanent collision-resistant ID e.g. BKR-XXXXXX)
  final String? beekeeperId;

  // Harvester identity (issued once, persisted in PostgreSQL, never regenerated casually)
  final String? bsid;
  final String? bspPass;

  final String? authProvider; // 'google', 'local', etc.

  // Authoritative status from backend if available
  final bool? isBackendComplete;
  final bool? isVerifiedStatus;

  const UserProfile({
    this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'HARVESTER',
    this.avatarUrl,
    this.googlePhotoUrl,
    this.photoUrl,
    this.organizationName,
    this.facilityLocation,
    this.licenseNumber,
    this.designation,
    this.beekeeperId,
    this.bsid,
    this.bspPass,
    this.authProvider,
    this.isBackendComplete,
    this.isVerifiedStatus,
  });

  bool get isVerified => isVerifiedStatus == true || isBackendComplete == true || _localProfileComplete;

  /// Effective profile photo URL following 3-tier priority:
  /// Tier 1: User-uploaded custom profile picture (`avatarUrl`)
  /// Tier 2: Google profile picture (`googlePhotoUrl` or legacy `photoUrl`)
  /// Tier 3: null (falls back to initial letters / placeholder)
  String? get effectivePhotoUrl {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!.trim();
    }
    if (googlePhotoUrl != null && googlePhotoUrl!.trim().isNotEmpty) {
      return googlePhotoUrl!.trim();
    }
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return photoUrl!.trim();
    }
    return null;
  }

  /// Role-based profile completion calculation.
  /// Backend's isBackendComplete / isVerifiedStatus are authoritative.
  /// If either backend field confirms completion or verified status, return true.
  bool get isProfileComplete {
    // Backend authoritative: verified users are always considered complete.
    if (isVerifiedStatus == true) return true;
    if (isBackendComplete == true) return true;
    // If backend explicitly says incomplete, respect it.
    if (isBackendComplete == false) return _localProfileComplete;
    // No backend data yet — fall back to local field check.
    return _localProfileComplete;
  }

  /// Local heuristic profile completion, used as fallback when backend is unreachable.
  bool get _localProfileComplete {
    final nameOk = name.trim().isNotEmpty && name.trim().toLowerCase() != 'unknown';
    final emailOk = email.trim().isNotEmpty && !email.contains('anonymous');
    final phoneOk = phone.trim().isNotEmpty;

    final normRole = role.toUpperCase().trim();

    // 1. Harvester Profile — name + email sufficient (phone added if available).
    if (normRole.isEmpty || normRole == 'HARVESTER') {
      // For Google-auth harvesters without a phone, name+email is enough locally.
      return nameOk && emailOk;
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

  /// Initial letter of name or email, capitalized
  String get initial {
    if (name.trim().isNotEmpty) {
      return name.trim()[0].toUpperCase();
    }
    if (email.trim().isNotEmpty) {
      return email.trim()[0].toUpperCase();
    }
    return 'H';
  }

  String get initials {
    return name[0].toUpperCase();
  }
}

/// Summary of a role-specific account for multi-role switching
class RoleAccountSummary {
  final String id;
  final String role;
  final String email;
  final String name;
  final String? phone;
  final String? avatarUrl;
  final String? googlePhotoUrl;
  final String? photoUrl;
  final String? authProvider;
  final String? organizationName;
  final String? facilityLocation;
  final String? licenseNumber;
  final bool isProfileComplete;
  final bool isVerified;
  final String verificationStatus;
  final int completedSteps;
  final int totalSteps;

  const RoleAccountSummary({
    required this.id,
    required this.role,
    required this.email,
    required this.name,
    this.phone,
    this.avatarUrl,
    this.googlePhotoUrl,
    this.photoUrl,
    this.authProvider,
    this.organizationName,
    this.facilityLocation,
    this.licenseNumber,
    required this.isProfileComplete,
    required this.isVerified,
    required this.verificationStatus,
    this.completedSteps = 0,
    this.totalSteps = 3,
  });

  /// Effective profile photo URL following 3-tier priority
  String? get effectivePhotoUrl {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) return avatarUrl!.trim();
    if (googlePhotoUrl != null && googlePhotoUrl!.trim().isNotEmpty) return googlePhotoUrl!.trim();
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) return photoUrl!.trim();
    return null;
  }

  factory RoleAccountSummary.fromJson(Map<String, dynamic> json) {
    return RoleAccountSummary(
      id: json['id'] ?? '',
      role: json['role'] ?? 'HARVESTER',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      googlePhotoUrl: json['googlePhotoUrl'] as String?,
      photoUrl: json['photoUrl'] as String?,
      authProvider: json['authProvider'] as String?,
      organizationName: json['organizationName'] as String?,
      facilityLocation: json['facilityLocation'] as String?,
      licenseNumber: json['licenseNumber'] as String?,
      isProfileComplete: json['isProfileComplete'] == true,
      isVerified: json['isVerified'] == true,
      verificationStatus: json['verificationStatus'] ?? 'Not Started',
      completedSteps: json['completedSteps'] is int ? json['completedSteps'] : 0,
      totalSteps: json['totalSteps'] is int ? json['totalSteps'] : 3,
    );
  }
}

/// Controller managing user profile details, password updating, and the
/// persistent harvester identity (BSID + BSP Pass) backed by PostgreSQL.
class UserController extends ChangeNotifier {
  static const String _idKey = 'user_profile_id';
  static const String _nameKey = 'user_profile_name';
  static const String _emailKey = 'user_profile_email';
  static const String _phoneKey = 'user_profile_phone';
  static const String _roleKey = 'user_profile_role';
  static const String _avatarUrlKey = 'user_profile_avatar_url';
  static const String _googlePhotoUrlKey = 'user_profile_google_photo_url';
  static const String _photoUrlKey = 'user_profile_photo_url';
  static const String _orgKey = 'user_profile_organization';
  static const String _locKey = 'user_profile_location';
  static const String _licKey = 'user_profile_license';
  static const String _desigKey = 'user_profile_designation';
  static const String _beekeeperIdKey = 'user_profile_beekeeper_id';
  static const String _bsidKey = 'user_profile_bsid';
  static const String _bspKey = 'user_profile_bsp_pass';
  static const String _authProviderKey = 'user_profile_auth_provider';

  final http.Client _client;
  final String _baseUrl;

  UserProfile _user = const UserProfile(
    id: null,
    name: '',
    email: '',
    phone: '',
    role: 'HARVESTER',
  );

  List<RoleAccountSummary> _roleAccounts = [];

  UserProfile get user => _user;
  List<RoleAccountSummary> get roleAccounts => _roleAccounts;

  UserController({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _resolveBaseUrl() {
    _loadProfile();
  }

  static String _resolveBaseUrl() {
    // Works on web, Android emulator (10.0.2.2), and physical devices
    // (override with --dart-define=BACKEND_URL=...).
    return AppConstants.backendBaseUrl;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Reload user profile from local cache & backend
  Future<void> reloadProfile() async {
    await _loadProfile();
  }

  Future<void> _loadProfile([String? roleOverride]) async {
    // 1. First load from local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    final name = prefs.getString(_nameKey) ?? '';
    final email = prefs.getString(_emailKey) ?? '';
    final phone = prefs.getString(_phoneKey) ?? '';
    final role = roleOverride ?? prefs.getString(_roleKey) ?? 'HARVESTER';
    final avatarUrl = prefs.getString(_avatarUrlKey);
    final googlePhotoUrl = prefs.getString(_googlePhotoUrlKey);
    final photoUrl = prefs.getString(_photoUrlKey);
    final org = prefs.getString(_orgKey);
    final loc = prefs.getString(_locKey);
    final lic = prefs.getString(_licKey);
    final desig = prefs.getString(_desigKey);
    final beekeeperId = prefs.getString(_beekeeperIdKey);
    final authProvider = prefs.getString(_authProviderKey);

    _user = UserProfile(
      id: id,
      name: name,
      email: email,
      phone: phone,
      role: role,
      avatarUrl: avatarUrl,
      googlePhotoUrl: googlePhotoUrl,
      photoUrl: photoUrl,
      organizationName: org,
      facilityLocation: loc,
      licenseNumber: lic,
      designation: desig,
      beekeeperId: beekeeperId,
      bsid: prefs.getString(_bsidKey),
      bspPass: prefs.getString(_bspKey),
      authProvider: authProvider,
    );
    notifyListeners();

    // 2. Fetch authoritative profile from PostgreSQL backend if identifier exists
    if (id != null || email.isNotEmpty) {
      await fetchProfile(userId: id ?? email, role: role);
    }
  }

  /// Sets the active user directly upon login/registration
  Future<void> setUser({
    required String id,
    required String name,
    required String email,
    String? phone,
    String? role,
    String? avatarUrl,
    String? googlePhotoUrl,
    String? photoUrl,
    String? beekeeperId,
    String? bsid,
    String? bspPass,
    String? authProvider,
  }) async {
    _user = UserProfile(
      id: id,
      name: name,
      email: email,
      phone: phone ?? '',
      role: role ?? 'HARVESTER',
      avatarUrl: avatarUrl ?? _user.avatarUrl,
      googlePhotoUrl: googlePhotoUrl ?? _user.googlePhotoUrl,
      photoUrl: photoUrl ?? _user.photoUrl,
      beekeeperId: beekeeperId,
      bsid: bsid,
      bspPass: bspPass,
      authProvider: authProvider ?? _user.authProvider,
    );
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, id);
    await prefs.setString(_nameKey, name);
    await prefs.setString(_emailKey, email);
    if (phone != null) await prefs.setString(_phoneKey, phone);
    if (role != null) await prefs.setString(_roleKey, role);
    if (avatarUrl != null) await prefs.setString(_avatarUrlKey, avatarUrl);
    if (googlePhotoUrl != null) await prefs.setString(_googlePhotoUrlKey, googlePhotoUrl);
    if (photoUrl != null) await prefs.setString(_photoUrlKey, photoUrl);
    if (beekeeperId != null) await prefs.setString(_beekeeperIdKey, beekeeperId);
    if (bsid != null) await prefs.setString(_bsidKey, bsid);
    if (bspPass != null) await prefs.setString(_bspKey, bspPass);
    if (authProvider != null) await prefs.setString(_authProviderKey, authProvider);

    await fetchProfile(userId: id);
  }

  /// Switch the active role context and sync authoritative role profile
  Future<void> switchRole(String newRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, newRole);
    _user = UserProfile(
      id: _user.id,
      name: _user.name,
      email: _user.email,
      phone: _user.phone,
      role: newRole,
      avatarUrl: _user.avatarUrl,
      googlePhotoUrl: _user.googlePhotoUrl,
      photoUrl: _user.photoUrl,
      organizationName: _user.organizationName,
      facilityLocation: _user.facilityLocation,
      licenseNumber: _user.licenseNumber,
      designation: _user.designation,
      beekeeperId: _user.beekeeperId,
      bsid: _user.bsid,
      bspPass: _user.bspPass,
      authProvider: _user.authProvider,
    );
    notifyListeners();
    await fetchProfile(userId: _user.id, role: newRole);
  }

  /// Fetch authoritative profile from backend
  Future<void> fetchProfile({String? userId, String? role}) async {
    try {
      final activeUserId = userId ?? _user.id ?? _user.email;
      final activeRole = role ?? _user.role;
      final uri = Uri.parse('$_baseUrl/api/profile').replace(
        queryParameters: {
          if (activeUserId.isNotEmpty) 'userId': activeUserId,
          'role': activeRole,
        },
      );
      final response = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final p = data['profile'] ?? data['user'];
        if (data['success'] == true && p != null) {
          _user = UserProfile(
            id: p['id'] ?? _user.id,
            name: p['name'] ?? _user.name,
            email: p['email'] ?? _user.email,
            phone: p['phone'] ?? _user.phone,
            role: p['role'] ?? _user.role,
            avatarUrl: p['avatarUrl'] as String?,
            googlePhotoUrl: p['googlePhotoUrl'] as String?,
            photoUrl: p['photoUrl'] as String? ?? _user.photoUrl,
            authProvider: p['authProvider'] as String? ?? _user.authProvider,
            organizationName: p['organizationName'] ?? _user.organizationName,
            facilityLocation: p['facilityLocation'] ?? _user.facilityLocation,
            licenseNumber: p['licenseNumber'] ?? _user.licenseNumber,
            designation: p['designation'] ?? _user.designation,
            beekeeperId: p['beekeeperId'] ?? _user.beekeeperId,
            bsid: p['bsid'] ?? _user.bsid,
            bspPass: p['bspPass'] ?? _user.bspPass,
            isBackendComplete: p['isProfileComplete'] as bool?,
            isVerifiedStatus: p['isVerified'] as bool?,
          );
          notifyListeners();

          // Save to local cache
          final prefs = await SharedPreferences.getInstance();
          if (_user.id != null) await prefs.setString(_idKey, _user.id!);
          await prefs.setString(_nameKey, _user.name);
          await prefs.setString(_emailKey, _user.email);
          await prefs.setString(_phoneKey, _user.phone);
          await prefs.setString(_roleKey, _user.role);
          if (_user.avatarUrl != null) {
            await prefs.setString(_avatarUrlKey, _user.avatarUrl!);
          } else {
            await prefs.remove(_avatarUrlKey);
          }
          if (_user.googlePhotoUrl != null) {
            await prefs.setString(_googlePhotoUrlKey, _user.googlePhotoUrl!);
          } else {
            await prefs.remove(_googlePhotoUrlKey);
          }
          if (_user.photoUrl != null) {
            await prefs.setString(_photoUrlKey, _user.photoUrl!);
          }
          if (_user.authProvider != null) {
            await prefs.setString(_authProviderKey, _user.authProvider!);
          }
          if (_user.organizationName != null) await prefs.setString(_orgKey, _user.organizationName!);
          if (_user.facilityLocation != null) await prefs.setString(_locKey, _user.facilityLocation!);
          if (_user.licenseNumber != null) await prefs.setString(_licKey, _user.licenseNumber!);
          if (_user.designation != null) await prefs.setString(_desigKey, _user.designation!);
          if (_user.beekeeperId != null) await prefs.setString(_beekeeperIdKey, _user.beekeeperId!);
          if (_user.bsid != null) await prefs.setString(_bsidKey, _user.bsid!);
          if (_user.bspPass != null) await prefs.setString(_bspKey, _user.bspPass!);
        }
      }
    } catch (e) {
      debugPrint('[UserController] Profile backend sync skipped: $e');
    }
  }

  /// Fetch all registered role accounts associated with this email
  Future<void> fetchRoleAccounts([String? email]) async {
    final targetEmail = email ?? _user.email;
    if (targetEmail.isEmpty) return;
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/accounts').replace(
        queryParameters: {'email': targetEmail},
      );
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['accounts'] is List) {
          _roleAccounts = (data['accounts'] as List)
              .map((acc) => RoleAccountSummary.fromJson(acc as Map<String, dynamic>))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[UserController] fetchRoleAccounts warning: $e');
    }
  }

  /// Switch the active account to another role
  Future<bool> switchAccountRole(String targetRole) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/switch-role');
      final res = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'email': _user.email,
              'targetRole': targetRole,
              'createIfNotExists': true,
              'name': _user.name,
              'phone': _user.phone,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['user'] != null) {
          final u = data['user'];
          final prefs = await SharedPreferences.getInstance();
          if (u['id'] != null) await prefs.setString(_idKey, u['id']);
          if (u['name'] != null) await prefs.setString(_nameKey, u['name']);
          if (u['email'] != null) await prefs.setString(_emailKey, u['email']);
          if (u['phone'] != null) await prefs.setString(_phoneKey, u['phone']);
          if (u['role'] != null) await prefs.setString(_roleKey, u['role']);
          if (u['avatarUrl'] != null) {
            await prefs.setString(_avatarUrlKey, u['avatarUrl']);
          } else {
            await prefs.remove(_avatarUrlKey);
          }
          if (u['googlePhotoUrl'] != null) {
            await prefs.setString(_googlePhotoUrlKey, u['googlePhotoUrl']);
          } else {
            await prefs.remove(_googlePhotoUrlKey);
          }
          if (u['photoUrl'] != null) await prefs.setString(_photoUrlKey, u['photoUrl']);
          if (u['bsid'] != null) await prefs.setString(_bsidKey, u['bsid']);
          if (u['bspPass'] != null) await prefs.setString(_bspKey, u['bspPass']);

          await _loadProfile(u['role'] as String?);
          await fetchRoleAccounts(_user.email);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[UserController] switchAccountRole error: $e');
    }
    return false;
  }

  /// Update profile details across all role fields
  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
    String? role,
    String? avatarUrl,
    String? organizationName,
    String? facilityLocation,
    String? licenseNumber,
    String? designation,
  }) async {
    final effectiveRole = role ?? _user.role;
    final effectiveAvatarUrl = avatarUrl != null ? (avatarUrl.trim().isEmpty ? null : avatarUrl.trim()) : _user.avatarUrl;

    _user = UserProfile(
      id: _user.id,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: effectiveRole,
      avatarUrl: effectiveAvatarUrl,
      googlePhotoUrl: _user.googlePhotoUrl,
      photoUrl: effectiveAvatarUrl ?? _user.googlePhotoUrl ?? _user.photoUrl,
      organizationName: organizationName?.trim(),
      facilityLocation: facilityLocation?.trim(),
      licenseNumber: licenseNumber?.trim(),
      designation: designation?.trim(),
      beekeeperId: _user.beekeeperId,
      bsid: _user.bsid,
      bspPass: _user.bspPass,
      authProvider: _user.authProvider,
    );
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (_user.id != null) await prefs.setString(_idKey, _user.id!);
    await prefs.setString(_nameKey, _user.name);
    await prefs.setString(_emailKey, _user.email);
    await prefs.setString(_phoneKey, _user.phone);
    await prefs.setString(_roleKey, _user.role);
    if (effectiveAvatarUrl != null) {
      await prefs.setString(_avatarUrlKey, effectiveAvatarUrl);
    } else {
      await prefs.remove(_avatarUrlKey);
    }
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
              'userId': _user.id,
              'name': _user.name,
              'email': _user.email,
              'phone': _user.phone,
              'role': _user.role,
              'avatarUrl': effectiveAvatarUrl ?? '',
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
            id: p['id'] ?? _user.id,
            name: p['name'] ?? _user.name,
            email: p['email'] ?? _user.email,
            phone: p['phone'] ?? _user.phone,
            role: p['role'] ?? _user.role,
            avatarUrl: p['avatarUrl'] as String?,
            googlePhotoUrl: p['googlePhotoUrl'] as String?,
            photoUrl: p['photoUrl'] as String? ?? _user.photoUrl,
            authProvider: p['authProvider'] as String? ?? _user.authProvider,
            organizationName: p['organizationName'] ?? _user.organizationName,
            facilityLocation: p['facilityLocation'] ?? _user.facilityLocation,
            licenseNumber: p['licenseNumber'] ?? _user.licenseNumber,
            designation: p['designation'] ?? _user.designation,
            beekeeperId: p['beekeeperId'] ?? _user.beekeeperId,
            bsid: p['bsid'] ?? _user.bsid,
            bspPass: p['bspPass'] ?? _user.bspPass,
            isBackendComplete: p['isProfileComplete'] as bool?,
            isVerifiedStatus: p['isVerified'] as bool?,
          );
          notifyListeners();
          if (_user.beekeeperId != null) await prefs.setString(_beekeeperIdKey, _user.beekeeperId!);
        }
      }
    } catch (e) {
      debugPrint('[UserController] Profile update backend sync error: $e');
    }

    return true;
  }

  /// Sets or updates custom avatar URL
  Future<bool> setAvatarUrl(String? url) async {
    return updateProfile(
      name: _user.name,
      email: _user.email,
      phone: _user.phone,
      role: _user.role,
      avatarUrl: url ?? '',
      organizationName: _user.organizationName,
      facilityLocation: _user.facilityLocation,
      licenseNumber: _user.licenseNumber,
      designation: _user.designation,
    );
  }

  /// Removes custom avatar to revert back to Google Photo if available
  Future<bool> clearCustomAvatar() async {
    return setAvatarUrl('');
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Backend API logic goes here
    return true;
  }

  /// Whether this account already holds a harvester identity.
  bool get hasIdentity => _user.bsid != null && _user.bspPass != null;

  /// Issue the harvester identity (BSID + BSP Pass) exactly once from backend.
  Future<bool> generateIdentity() async {
    if (!hasIdentity && _user.isProfileComplete) {
      try {
        final url = Uri.parse('$_baseUrl/api/profile/identity');
        final response = await _client
            .post(
              url,
              headers: _headers,
              body: jsonEncode({
                'userId': _user.id,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final bsid = data['bsid'] as String?;
          final bsp = data['bspPass'] as String?;

          if (bsid != null && bsp != null) {
            _user = UserProfile(
              id: _user.id,
              name: _user.name,
              email: _user.email,
              phone: _user.phone,
              role: _user.role,
              organizationName: _user.organizationName,
              facilityLocation: _user.facilityLocation,
              licenseNumber: _user.licenseNumber,
              designation: _user.designation,
              beekeeperId: _user.beekeeperId,
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
    }
    return false;
  }
}

