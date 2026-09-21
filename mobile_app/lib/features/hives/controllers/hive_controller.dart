import 'package:flutter/foundation.dart';
import '../models/hive_model.dart';
import '../services/hive_storage_service.dart';

/// A hive submission that the backend rejected (or that never reached it).
/// Kept in memory so the UI can render an honest per-hive error card with a
/// Retry action instead of silently dropping the failure.
class FailedHiveSubmission {
  final String localKey;
  final Hive hive;
  final String message;
  FailedHiveSubmission({
    required this.localKey,
    required this.hive,
    required this.message,
  });
}

/// State management controller for HoneyChain Hives backed by PostgreSQL
/// with genuine database persistence and local cache fallback.
class HiveController extends ChangeNotifier {
  final HiveStorageService _storageService = HiveStorageService();

  List<Hive> _hives = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _searchQuery = '';
  final Map<String, FailedHiveSubmission> _failedSubmissions = {};
  String _selectedFilter = 'All'; // All, Healthy, Needs Attention, High Production, Recently Added
  String _selectedSort = 'Name A-Z'; // Name A-Z, Production High-Low, Last Inspected, Date Added
  String? _activeUserId;
  String? _lastError;

  List<Hive> get hives => _hives;
  bool get isLoading => _isLoading;
  /// True while a hive create/update call is in flight — guards double-taps.
  bool get isSubmitting => _isSubmitting;
  /// Failed create submissions keyed by the client-side hive code used.
  Map<String, FailedHiveSubmission> get failedSubmissions => Map.unmodifiable(_failedSubmissions);
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  String get selectedSort => _selectedSort;
  String? get lastError => _lastError;

  HiveController() {
    loadHives();
  }

  /// Initialize and load hives from PostgreSQL backend for the active beekeeper.
  /// [clearFailures] resets per-session failed submission cards (default true).
  Future<void> loadHives({String? userId, bool clearFailures = true}) async {
    if (userId != null && userId.trim().isNotEmpty) {
      _activeUserId = userId.trim();
    }
    _isLoading = true;
    _lastError = null;
    if (clearFailures) _failedSubmissions.clear();
    notifyListeners();

    _hives = await _storageService.loadHives(userId: _activeUserId);
    _lastError = _storageService.lastError;
    _isLoading = false;
    notifyListeners();
  }

  /// Set the active beekeeper context and refresh hives
  Future<void> setActiveBeekeeper(String? userId) async {
    _activeUserId = userId;
    await loadHives(userId: userId);
  }

  /// Fetch an authoritative unique hive code from the backend
  Future<String?> fetchAuthoritativeHiveCode() async {
    return await _storageService.fetchUniqueHiveCode();
  }

  /// Add a new hive to PostgreSQL and local state.
  /// Uses server-assigned unique ID and server-validated hive code.
  ///
  /// On failure the attempted submission is recorded so the matching hive
  /// card can show the real backend error with a Retry action.
  Future<bool> addHive(Hive hive, {String? userId}) async {
    if (_isSubmitting) return false;
    final effectiveUserId = userId ?? _activeUserId;
    _lastError = null;
    _isSubmitting = true;
    notifyListeners();

    try {
      final createdHive = await _storageService.createHive(hive, userId: effectiveUserId);

      if (createdHive != null) {
        _failedSubmissions.remove(hive.hiveCode);
        // Re-sync from the backend so the list reflects exactly what is
        // persisted (no optimistic fake rows, no stale cache order).
        _hives = await _storageService.loadHives(userId: effectiveUserId);
        await _storageService.saveHives(_hives);
        return true;
      }
      _lastError = _storageService.lastError;
      _failedSubmissions[hive.hiveCode] = FailedHiveSubmission(
        localKey: hive.hiveCode,
        hive: hive,
        message: _lastError ?? 'Unable to create hive. Please try again.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Retry a previously failed hive submission (same payload, fresh attempt).
  Future<bool> retryFailedSubmission(String localKey) async {
    final failed = _failedSubmissions[localKey];
    if (failed == null) return false;
    return addHive(failed.hive, userId: failed.hive.userId ?? _activeUserId);
  }

  /// Dismiss a failed submission card once the user is done with it.
  void dismissFailedSubmission(String localKey) {
    _failedSubmissions.remove(localKey);
    notifyListeners();
  }

  /// Update an existing hive in PostgreSQL and local state
  Future<bool> updateHive(Hive updatedHive, {String? userId}) async {
    final effectiveUserId = userId ?? _activeUserId;
    _lastError = null;
    final success = await _storageService.updateHiveInBackend(updatedHive, userId: effectiveUserId);

    if (success) {
      final index = _hives.indexWhere((h) => h.id == updatedHive.id);
      if (index != -1) {
        _hives[index] = updatedHive;
      }
      await _storageService.saveHives(_hives);
      notifyListeners();
      return true;
    }
    _lastError = _storageService.lastError;
    notifyListeners();
    return false;
  }

  /// Delete a hive by ID from PostgreSQL and local state
  Future<bool> deleteHive(String id, {String? userId}) async {
    final effectiveUserId = userId ?? _activeUserId;
    _lastError = null;
    final success = await _storageService.deleteHiveFromBackend(id, userId: effectiveUserId);

    if (success) {
      _hives.removeWhere((h) => h.id == id);
      await _storageService.saveHives(_hives);
      notifyListeners();
      return true;
    }
    _lastError = _storageService.lastError;
    notifyListeners();
    return false;
  }

  /// Get hive by ID
  Hive? getHiveById(String id) {
    try {
      return _hives.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Whether a hive code is already taken in the loaded list
  bool isHiveCodeTaken(String code, {String? excludingHiveId}) {
    final normalized = code.trim().toLowerCase();
    return _hives.any(
      (h) => h.id != excludingHiveId && h.hiveCode.trim().toLowerCase() == normalized,
    );
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set filter criteria
  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  /// Set sort criteria
  void setSort(String sort) {
    _selectedSort = sort;
    notifyListeners();
  }

  /// Get 3 most recently updated hives for dashboard
  List<Hive> get recentHives {
    final list = List<Hive>.from(_hives);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.take(3).toList();
  }

  /// Get filtered and sorted list of hives
  List<Hive> get filteredAndSortedHives {
    var result = List<Hive>.from(_hives);

    // Apply Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((h) {
        return h.name.toLowerCase().contains(q) ||
            h.hiveCode.toLowerCase().contains(q) ||
            h.apiaryLocation.toLowerCase().contains(q) ||
            h.beeBreed.toLowerCase().contains(q) ||
            h.honeyType.toLowerCase().contains(q);
      }).toList();
    }

    // Apply Filter
    switch (_selectedFilter) {
      case 'Healthy':
        result = result.where((h) => h.isHealthy).toList();
        break;
      case 'Needs Attention':
        result = result.where((h) => !h.isHealthy).toList();
        break;
      case 'High Production':
        result = result.where((h) => h.currentYearProductionKg >= 25.0).toList();
        break;
      case 'Recently Inspected':
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        result = result.where((h) => h.lastInspectionDate.isAfter(cutoff)).toList();
        break;
      case 'All':
      default:
        break;
    }

    // Apply Sort
    switch (_selectedSort) {
      case 'Production High-Low':
        result.sort((a, b) => b.currentYearProductionKg.compareTo(a.currentYearProductionKg));
        break;
      case 'Last Inspected':
        result.sort((a, b) => b.lastInspectionDate.compareTo(a.lastInspectionDate));
        break;
      case 'Date Added':
        result.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case 'Name A-Z':
      default:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }

    return result;
  }
}

