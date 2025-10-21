import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_account_statement.dart';

class ClientAccountStatementProvider with ChangeNotifier {
  Client? _client;
  double _openingBalance = 0.0;
  bool _isLoading = false;
  String? _error;
  List<ClientAccountStatementEntry> _entries = [];
  DateTime? _from;
  DateTime? _to;

  Client? get client => _client;
  double get openingBalance => _openingBalance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ClientAccountStatementEntry> get entries => _entries;
  double get closingBalance => _entries.isNotEmpty ? _entries.last.balance : _openingBalance;
  DateTime? get from => _from;
  DateTime? get to => _to;

  void initializeWithClient(Client client) {
    _client = client;
    // Default range: last 90 days
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _from = _to!.subtract(const Duration(days: 90));
    load();
  }

  void setDateRange(DateTime from, DateTime to) {
    _from = DateTime(from.year, from.month, from.day, 0, 0, 0);
    _to = DateTime(to.year, to.month, to.day, 23, 59, 59);
    load();
  }

  Future<void> load() async {
    if (_client == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final supabase = Supabase.instance.client;
      // Ensure date range
      final fromIso = (_from ?? DateTime.now().subtract(const Duration(days: 90))).toUtc().toIso8601String();
      final toIso = (_to ?? DateTime.now()).toUtc().toIso8601String();

      final t0 = DateTime.now();
      // Fire both queries in parallel
      final priorFuture = supabase
          .from('client_transactions')
          .select('amount, direction, created_at')
          .eq('client_id', _client!.id)
          .lt('created_at', fromIso);

      final rangeFuture = supabase
          .from('client_transactions')
          .select('id, client_id, operation_id, amount, direction, currency, created_at, created_by, notes')
          .eq('client_id', _client!.id)
          .gte('created_at', fromIso)
          .lte('created_at', toIso)
          .order('created_at', ascending: true);

      final results = await Future.wait([priorFuture, rangeFuture]);
      final priorRows = (results[0] as List<dynamic>).cast<Map<String, dynamic>>();
      double _parseAmount(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }
      bool _isOperationDir(String? d) {
        final x = d?.toLowerCase();
        return x == null || x == 'debit' || x == 'out';
      }
      bool _isPaymentDir(String? d) {
        final x = d?.toLowerCase();
        return x == 'credit' || x == 'in';
      }
      final priorOps = priorRows.where((r) => _isOperationDir(r['direction'] as String?)).fold<double>(0.0, (s, r) => s + _parseAmount(r['amount']));
      final priorPays = priorRows.where((r) => _isPaymentDir(r['direction'] as String?)).fold<double>(0.0, (s, r) => s + _parseAmount(r['amount']));
      _openingBalance = priorOps - priorPays;

      final rows = (results[1] as List<dynamic>).cast<Map<String, dynamic>>();

      // Map rows to entries
      final mapped = rows
          .map((r) => ClientAccountStatementEntry.fromTransaction(r, runningBalance: 0))
          .toList();

      // Calculate running balance starting from computed opening
      double running = _openingBalance;
      for (var i = 0; i < mapped.length; i++) {
        final e = mapped[i];
        if (e.type == 'operation') {
          running += e.debit;
        } else if (e.type == 'payment') {
          running -= e.credit;
        }
        mapped[i] = e.copyWith(balance: running);
      }

      _entries = mapped;
      final t1 = DateTime.now();
      debugPrint('[ClientAccountStatementProvider] load() done in: ${t1.difference(t0).inMilliseconds}ms (rows=${rows.length}, prior=${priorRows.length})');
    } catch (e) {
      _error = 'فشل تحميل كشف حساب العميل: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refresh() => load();
}
