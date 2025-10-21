import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../manufacturers/data/datasources/manufacturers_remote_data_source.dart';
import '../../../manufacturers/data/models/manufacturer.dart';

class ManufacturersProvider extends ChangeNotifier {
  final ManufacturersRemoteDataSource _remote;
  ManufacturersProvider(SupabaseClient client) : _remote = ManufacturersRemoteDataSource(client);

  final _client = Supabase.instance.client;

  List<Manufacturer> _items = [];
  bool _isLoading = false;
  String? _error;
  String _search = '';
  String? _typeFilter;

  List<Manufacturer> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;
  String? get typeFilter => _typeFilter;

  void setSearch(String v) {
    _search = v;
    load();
  }

  void setTypeFilter(String? v) {
    _typeFilter = v;
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _remote.list(search: _search.isEmpty ? null : _search, type: _typeFilter);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(ManufacturerInput input) async {
    try {
      final user = _client.auth.currentUser;
      final userName = user?.email ?? user?.userMetadata?['full_name'];
      final created = await _remote.create(input, userId: user?.id, userName: userName);
      _items.insert(0, created);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOne(String id, ManufacturerInput input) async {
    try {
      final user = _client.auth.currentUser;
      final userName = user?.email ?? user?.userMetadata?['full_name'];
      final updated = await _remote.update(id, input, userId: user?.id, userName: userName);
      final idx = _items.indexWhere((x) => x.id == id);
      if (idx != -1) {
        _items[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOne(String id) async {
    try {
      final user = _client.auth.currentUser;
      final userName = user?.email ?? user?.userMetadata?['full_name'];
      await _remote.delete(id, userId: user?.id, userName: userName);
      _items.removeWhere((x) => x.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // === Manufacturer ↔ Stages (Many-to-Many by stage_id) ===
  Future<List<String>> getStages(String manufacturerId) async {
    try {
      return await _remote.listStageIdsForManufacturer(manufacturerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<bool> setStages(String manufacturerId, List<String> stageIds) async {
    try {
      await _remote.replaceStagesForManufacturer(manufacturerId, stageIds);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> getManufacturerFullSummary(String manufacturerId) async {
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('manufacturer_transactions')
          .select('amount, direction')
          .eq('manufacturer_id', manufacturerId);

      double _parse(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }

      double totalOperations = 0.0; // credit
      double totalPayments = 0.0;   // debit

      for (final r in (rows as List)) {
        final m = r as Map<String, dynamic>;
        final dir = (m['direction'] as String?)?.toLowerCase();
        final amt = _parse(m['amount']);
        if (dir == 'credit') {
          totalOperations += amt;
        } else if (dir == 'debit') {
          totalPayments += amt;
        }
      }

      final balance = totalOperations - totalPayments;
      return {
        'total_operations': totalOperations,
        'total_payments': totalPayments,
        'balance': balance,
      };
    } catch (e) {
      debugPrint('Error getting manufacturer full summary: $e');
      return {
        'total_operations': 0.0,
        'total_payments': 0.0,
        'balance': 0.0,
      };
    }
  }
}
