import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flag-free Language model representing one of the 22 supported languages
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

/// Centralized localization service supporting 22 languages (Flag-free & Text-based)
class LanguageController extends ChangeNotifier {
  static const String _prefKey = 'honeychain_language_code';

  static const List<AppLanguage> supportedLanguages = [
    AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
    AppLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    AppLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    AppLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    AppLanguage(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
    AppLanguage(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
    AppLanguage(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
    AppLanguage(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    AppLanguage(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    AppLanguage(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
    AppLanguage(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
    AppLanguage(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
    AppLanguage(code: 'zh', name: 'Chinese', nativeName: '中文'),
    AppLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    AppLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    AppLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    AppLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
    AppLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    AppLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    AppLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    AppLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
  ];

  String _currentLanguageCode = 'en';

  String get currentLanguageCode => _currentLanguageCode;

  AppLanguage get currentLanguage => supportedLanguages.firstWhere(
        (l) => l.code == _currentLanguageCode,
        orElse: () => supportedLanguages.first,
      );

  LanguageController() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguageCode = prefs.getString(_prefKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (_currentLanguageCode == code) return;
    _currentLanguageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  /// Translate a key into the currently selected language
  String tr(String key) {
    final map = _translations[_currentLanguageCode] ?? _translations['en']!;
    return map[key] ?? _translations['en']![key] ?? key;
  }

  // Core dictionary for UI strings
  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_name': 'HoneyChain',
      'home': 'Home',
      'hives': 'Hives',
      'profile': 'Profile',
      'add_hive': 'Add Hive',
      'create_manage_hive': 'Create and manage your hive',
      'recent_hives': 'Recent Hives',
      'show_more': 'Show more',
      'all_hives': 'All Hives',
      'search_hives_hint': 'Search hives...',
      'search_language_hint': 'Search language...',
      'no_hives_yet': 'No hives added yet',
      'no_hives_subtitle': 'Create your first hive to start tracking production and health.',
      'add_first_hive': 'Add Your First Hive',
      'quick_insights': 'Quick Insights',
      'overview': 'Overview',
      'production': 'Production',
      'inspection': 'Inspection',
      'queen': 'Queen Information',
      'notes': 'Notes & Observations',
      'edit_hive': 'Edit Hive',
      'delete_hive': 'Delete Hive',
      'save_hive': 'Save Hive',
      'cancel': 'Cancel',
      'delete_confirm_title': 'Delete this hive?',
      'delete_confirm_msg': 'This action cannot be undone.',
      'delete': 'Delete',
      'account': 'Account',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'appearance': 'Appearance',
      'theme': 'Theme',
      'language': 'Language',
      'preferences': 'Preferences',
      'notifications': 'Notifications',
      'about': 'About HoneyChain',
      'security': 'Security',
      'logout': 'Logout',
      'light': 'Light',
      'dark': 'Dark',
      'system_default': 'System Default',
      'select_language': 'Choose Language',
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_password': 'Confirm Password',
      'update_password': 'Update Password',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone Number',
      'save_changes': 'Save Changes',
    },
    'es': {
      'app_name': 'HoneyChain',
      'home': 'Inicio',
      'hives': 'Colmenas',
      'profile': 'Perfil',
      'add_hive': 'Añadir Colmena',
      'create_manage_hive': 'Crea y gestiona tu colmena',
      'recent_hives': 'Colmenas Recientes',
      'show_more': 'Ver más',
      'all_hives': 'Todas las Colmenas',
      'search_hives_hint': 'Buscar colmenas...',
      'search_language_hint': 'Buscar idioma...',
      'no_hives_yet': 'Aún no hay colmenas añadidas',
      'no_hives_subtitle': 'Crea tu primera colmena para comenzar el seguimiento.',
      'add_first_hive': 'Añadir tu primera colmena',
      'quick_insights': 'Resumen Rápido',
      'overview': 'Visión General',
      'production': 'Producción',
      'inspection': 'Inspección',
      'queen': 'Reina',
      'notes': 'Notas u Observaciones',
      'edit_hive': 'Editar Colmena',
      'delete_hive': 'Eliminar Colmena',
      'save_hive': 'Guardar Colmena',
      'cancel': 'Cancelar',
      'delete_confirm_title': '¿Eliminar esta colmena?',
      'delete_confirm_msg': 'Esta acción no se puede deshacer.',
      'delete': 'Eliminar',
      'account': 'Cuenta',
      'edit_profile': 'Editar Perfil',
      'change_password': 'Cambiar Contraseña',
      'appearance': 'Apariencia',
      'theme': 'Tema',
      'language': 'Idioma',
      'preferences': 'Preferencias',
      'notifications': 'Notificaciones',
      'about': 'Acerca de HoneyChain',
      'security': 'Seguridad',
      'logout': 'Cerrar Sesión',
      'light': 'Claro',
      'dark': 'Oscuro',
      'system_default': 'Predeterminado del Sistema',
      'select_language': 'Seleccionar Idioma',
      'current_password': 'Contraseña Actual',
      'new_password': 'Nueva Contraseña',
      'confirm_password': 'Confirmar Contraseña',
      'update_password': 'Actualizar Contraseña',
      'name': 'Nombre',
      'email': 'Correo',
      'phone': 'Teléfono',
      'save_changes': 'Guardar Cambios',
    },
    'hi': {
      'app_name': 'HoneyChain',
      'home': 'होम',
      'hives': 'छत्ते',
      'profile': 'प्रोफ़ाइल',
      'add_hive': 'छत्ता जोड़ें',
      'create_manage_hive': 'अपने छत्ते का प्रबंधन करें',
      'recent_hives': 'हाल के छत्ते',
      'show_more': 'और देखें',
      'all_hives': 'सभी छत्ते',
      'search_hives_hint': 'छत्ता खोजें...',
      'search_language_hint': 'भाषा खोजें...',
      'no_hives_yet': 'कोई छत्ता नहीं जोड़ा गया',
      'no_hives_subtitle': 'ट्रैकिंग शुरू करने के लिए अपना पहला छत्ता जोड़ें।',
      'add_first_hive': 'पहला छत्ता जोड़ें',
      'quick_insights': 'त्वरित अंतर्दृष्टि',
      'overview': 'अवलोकन',
      'production': 'उत्पादन',
      'inspection': 'निरीक्षण',
      'queen': 'रानी मक्खी',
      'notes': 'नोट्स',
      'edit_hive': 'छत्ता संपादित करें',
      'delete_hive': 'छत्ता हटाएं',
      'save_hive': 'छत्ता सहेजें',
      'cancel': 'रद्द करें',
      'delete_confirm_title': 'क्या आप इस छत्ते को हटाना चाहते हैं?',
      'delete_confirm_msg': 'यह कार्रवाई वापस नहीं ली जा सकती।',
      'delete': 'हटाएं',
      'account': 'खाता',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'change_password': 'पासवर्ड बदलें',
      'appearance': 'दिखावट',
      'theme': 'थीम',
      'language': 'भाषा',
      'preferences': 'वरीयताएं',
      'notifications': 'सूचनाएं',
      'about': 'HoneyChain के बारे में',
      'security': 'सुरक्षा',
      'logout': 'लॉग आउट',
      'light': 'लाइट',
      'dark': 'डार्क',
      'system_default': 'सिस्टम डिफ़ॉल्ट',
      'select_language': 'भाषा चुनें',
      'current_password': 'वर्तमान पासवर्ड',
      'new_password': 'नया पासवर्ड',
      'confirm_password': 'पासवर्ड की पुष्टि करें',
      'update_password': 'पासवर्ड अपडेट करें',
      'name': 'नाम',
      'email': 'ईमेल',
      'phone': 'फ़ोन नंबर',
      'save_changes': 'बदलाव सहेजें',
    },
  };
}
