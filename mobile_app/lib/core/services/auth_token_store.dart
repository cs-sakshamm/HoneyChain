import 'package:shared_preferences/shared_preferences.dart';

/// Process-wide holder for the backend JWT issued by /api/auth/login.
/// Set by AuthController after every successful login/role-switch and read by
/// every API controller so that backend requests carry a real identity
/// (Authorization: Bearer) instead of the removed x-user-id fallback.
class AuthTokenStore {
  AuthTokenStore._();

  static String? _token;
  static String? _userId;

  static String? get token => _token;
  static String? get userId => _userId;

  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static void set({String? token, String? userId}) {
    if (token != null && token.isNotEmpty) _token = token;
    if (userId != null && userId.isNotEmpty) _userId = userId;
  }

  static void clear() {
    _token = null;
    _userId = null;
  }

  /// Load the persisted session (call once at app startup).
  static Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      _userId = prefs.getString('auth_user_id');
    } catch (_) {}
  }

  /// Headers every controller should merge into its request.
  static Map<String, String> authHeader() {
    return {
      if (hasToken) 'Authorization': 'Bearer $_token',
    };
  }
}
