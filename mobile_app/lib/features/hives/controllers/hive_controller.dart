import 'package:flutter/foundation.dart';
import '../models/hive_model.dart';
import '../services/hive_storage_service.dart';

/// State management controller for HoneyChain Hives
class HiveController extends ChangeNotifier {
  final HiveStorageService _storageService = HiveStorageService();

  List<Hive> _hives = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Healthy, Needs Attention, High Production, Recently Added
  String _selectedSort = 'Name A-Z'; // Name A-Z, Production High-Low, Last Inspected, Date Added

  List<Hive> get hives => _hives;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  String get selectedSort => _selectedSort;

  HiveController() {
    loadHives();
  }

  /// Initialize and load stored hives
  Future<void> loadHives() async {
    _isLoading = true;
    notifyListeners();

    _hives = await _storageService.loadHives();
    _isLoading = false;
    notifyListeners();
  }

  /// Add a new hive
  Future<bool> addHive(Hive hive) async {
    _hives.insert(0, hive);
    notifyListeners();
    final success = await _storageService.saveHives(_hives);
    return success;
  }

  /// Update an existing hive
  Future<bool> updateHive(Hive updatedHive) async {
    final index = _hives.indexWhere((h) => h.id == updatedHive.id);
    if (index != -1) {
      _hives[index] = updatedHive;
      notifyListeners();
      return await _storageService.saveHives(_hives);
    }
    return false;
  }

  /// Delete a hive by ID
  Future<bool> deleteHive(String id) async {
    _hives.removeWhere((h) => h.id == id);
    notifyListeners();
    return await _storageService.saveHives(_hives);
  }

  /// Get hive by ID
  Hive? getHiveById(String id) {
    try {
      return _hives.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
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
