import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/business_field.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_field.dart';
import '../../domain/repositories/partners_repository.dart';

class PartnersProvider with ChangeNotifier {
  final PartnersRepository _repo;
  PartnersProvider(this._repo);

  bool _isLoading = false;
  String? _error;
  List<BusinessField> _fields = [];
  List<Client> _clients = [];
  List<Supplier> _suppliers = [];

  String _searchClients = '';
  String _searchSuppliers = '';
  String? _fieldFilterClient;
  String? _fieldFilterSupplier;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BusinessField> get fields => _fields;
  List<Client> get clients => _filteredClients();
  List<Supplier> get suppliers => _filteredSuppliers();

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fieldsEither = await _repo.getBusinessFields();
      final clientsEither = await _repo.getClients();
      final suppliersEither = await _repo.getSuppliers();

      fieldsEither.fold((l) => _error = l.toString(), (r) => _fields = r);
      clientsEither.fold((l) => _error = l.toString(), (r) => _clients = r);
      suppliersEither.fold((l) => _error = l.toString(), (r) => _suppliers = r);

      // تحميل client_fields وربطها بالعملاء
      if (_error == null) {
        final updated = <Client>[];
        for (final c in _clients) {
          final cfEither = await _repo.getClientFields(c.id);
          cfEither.fold(
            (l) => _error = l.toString(),
            (clientFields) {
              final ids = clientFields.map((e) => e.fieldId).whereType<String>().toSet();
              final fields = _fields.where((f) => ids.contains(f.id)).toList();
              updated.add(c.copyWith(businessFields: fields));
            },
          );
          if (_error != null) break;
        }
        if (_error == null) {
          _clients = updated;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setClientSearch(String q) {
    _searchClients = q.trim();
    notifyListeners();
  }

  void setSupplierSearch(String q) {
    _searchSuppliers = q.trim();
    notifyListeners();
  }

  void setClientFieldFilter(String? fieldId) {
    _fieldFilterClient = fieldId;
    notifyListeners();
  }

  void setSupplierFieldFilter(String? fieldId) {
    _fieldFilterSupplier = fieldId;
    notifyListeners();
  }

  List<Client> _filteredClients() {
    Iterable<Client> list = _clients;
    if (_searchClients.isNotEmpty) {
      final q = _searchClients.toLowerCase();
      list = list.where((c) => c.name.toLowerCase().contains(q) || (c.phone ?? '').contains(q));
    }
    if (_fieldFilterClient != null && _fieldFilterClient!.isNotEmpty) {
      final fid = _fieldFilterClient!;
      list = list.where((c) => c.businessFields.any((bf) => bf.id == fid));
    }
    return list.toList();
  }

  List<Supplier> _filteredSuppliers() {
    Iterable<Supplier> list = _suppliers;
    if (_searchSuppliers.isNotEmpty) {
      final q = _searchSuppliers.toLowerCase();
      list = list.where((s) => s.name.toLowerCase().contains(q) || (s.phone ?? '').contains(q));
    }
    if (_fieldFilterSupplier != null && _fieldFilterSupplier!.isNotEmpty) {
      list = list.where((_) => true);
    }
    return list.toList();
  }

  Future<bool> addClient({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.createClient(
      name: name,
      phone: phone,
      email: email,
      address: address,
      taxNumber: taxNumber,
      notes: notes,
      isActive: isActive,
      balance: balance,
    );
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (created) {
      _clients.insert(0, created);
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }

  Future<bool> addSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.createSupplier(
      name: name,
      phone: phone,
      email: email,
      address: address,
      taxNumber: taxNumber,
      notes: notes,
      isActive: isActive,
      balance: balance,
    );
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (created) {
      _suppliers.insert(0, created);
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }

  Future<bool> updateClientBusinessFields({
    required String clientId,
    required List<String> fieldIds,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.updateClientFields(clientId: clientId, fieldIds: fieldIds);
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (ok) {
      final idx = _clients.indexWhere((c) => c.id == clientId);
      if (idx != -1) {
        final fields = _fields.where((f) => fieldIds.contains(f.id)).toList();
        _clients[idx] = _clients[idx].copyWith(businessFields: fields);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }

  Future<bool> updateClient({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.updateClient(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      taxNumber: taxNumber,
      notes: notes,
      isActive: isActive,
      balance: balance,
    );
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (updated) {
      final idx = _clients.indexWhere((c) => c.id == id);
      if (idx != -1) {
        _clients[idx] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }

  Future<bool> updateSupplierBusinessFields({
    required String supplierId,
    required List<String> fieldIds,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.updateSupplierFields(supplierId: supplierId, fieldIds: fieldIds);
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (ok) {
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }

  Future<bool> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.updateSupplier(
      id: id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      taxNumber: taxNumber,
      notes: notes,
      isActive: isActive,
      balance: balance,
    );
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (updated) {
      final idx = _suppliers.indexWhere((s) => s.id == id);
      if (idx != -1) {
        _suppliers[idx] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }

  Future<Map<String, dynamic>> getSupplierPurchaseSummary(String supplierId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('supplier_purchases')
          .select('total_purchase_amount, purchase_count, last_purchase_amount, last_purchase_date, average_purchase_amount')
          .eq('supplier_id', supplierId)
          .single();
      
      return response;
    } catch (e) {
      debugPrint('Error getting supplier purchase summary: $e');
      return {};
    }
  }

  Future<double> getSupplierTotalPurchases(String supplierId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('supplier_purchases')
          .select('total_purchase_amount')
          .eq('supplier_id', supplierId)
          .single();

      return (response['total_purchase_amount'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Error getting supplier total purchases: $e');
      return 0.0;
    }
  }

  Future<double> getSupplierTotalPayments(String supplierId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('supplier_payments')
          .select('amount')
          .eq('supplier_id', supplierId);

      final payments = response as List<dynamic>;
      final total = payments.fold<double>(
        0.0,
        (sum, payment) => sum + ((payment['amount'] as num?)?.toDouble() ?? 0.0),
      );

      return total;
    } catch (e) {
      debugPrint('Error getting supplier total payments: $e');
      return 0.0;
    }
  }

  double calculateSupplierBalance(String supplierId, double totalPurchases, double totalPayments) {
    return totalPurchases - totalPayments;
  }

  Future<Map<String, dynamic>> getSupplierPaymentSummary(String supplierId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('supplier_payments')
          .select('amount, paid_at')
          .eq('supplier_id', supplierId)
          .order('paid_at', ascending: false);

      final payments = response as List<dynamic>;

      if (payments.isEmpty) {
        return {
          'total_paid_amount': 0.0,
          'payment_count': 0,
          'last_payment_amount': null,
          'last_payment_date': null,
          'average_payment_amount': 0.0,
        };
      }

      final totalAmount = payments.fold<double>(
        0.0,
        (sum, payment) => sum + ((payment['amount'] as num?)?.toDouble() ?? 0.0),
      );

      final paymentCount = payments.length;
      final lastPayment = payments.first;
      final lastPaymentAmount = (lastPayment['amount'] as num?)?.toDouble();
      final lastPaymentDate = lastPayment['paid_at'] as String?;
      final averagePaymentAmount = totalAmount / paymentCount;

      return {
        'total_paid_amount': totalAmount,
        'payment_count': paymentCount,
        'last_payment_amount': lastPaymentAmount,
        'last_payment_date': lastPaymentDate,
        'average_payment_amount': averagePaymentAmount,
      };
    } catch (e) {
      debugPrint('Error getting supplier payment summary: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getSupplierFullSummary(String supplierId) async {
    try {
      final purchaseSummary = await getSupplierPurchaseSummary(supplierId);
      final paymentSummary = await getSupplierPaymentSummary(supplierId);

      final totalPurchases = (purchaseSummary['total_purchase_amount'] as num?)?.toDouble() ?? 0.0;
      final totalPayments = (paymentSummary['total_paid_amount'] as num?)?.toDouble() ?? 0.0;
      final balance = calculateSupplierBalance(supplierId, totalPurchases, totalPayments);

      return {
        'total_purchases': totalPurchases,
        'total_payments': totalPayments,
        'balance': balance,
        'purchase_count': purchaseSummary['purchase_count'] ?? 0,
        'payment_count': paymentSummary['payment_count'] ?? 0,
        'last_purchase_date': purchaseSummary['last_purchase_date'],
        'last_payment_date': paymentSummary['last_payment_date'],
      };
    } catch (e) {
      debugPrint('Error getting supplier full summary: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getClientSalesSummary(String clientId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('client_transactions')
          .select('amount, created_at, direction')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);

      final rows = response as List<dynamic>;
      // عمليات العميل: نعتبر الاتجاهات التالية عمليات (مخرجات): out, debit, أو null
      final opRows = rows.where((r) {
        final d = (r['direction'] as String?)?.toLowerCase();
        return d == null || d == 'out' || d == 'debit';
      }).toList();

      if (opRows.isEmpty) {
        return {
          'total_out_amount': 0.0,
          'out_count': 0,
          'last_out_amount': null,
          'last_out_date': null,
          'average_out_amount': 0.0,
        };
      }

      double _parseAmount(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }
      final total = opRows.fold<double>(
        0.0,
        (sum, r) => sum + _parseAmount(r['amount']),
      );
      final count = opRows.length;
      final last = opRows.first;
      return {
        'total_out_amount': total,
        'out_count': count,
        'last_out_amount': _parseAmount(last['amount']),
        'last_out_date': last['created_at'] as String?,
        'average_out_amount': total / count,
      };
    } catch (e) {
      debugPrint('Error getting client sales summary: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getClientPaymentSummary(String clientId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('client_transactions')
          .select('amount, created_at')
          .eq('client_id', clientId)
          .inFilter('direction', ['in', 'credit'])
          .order('created_at', ascending: false);

      final rows = response as List<dynamic>;

      if (rows.isEmpty) {
        return {
          'total_in_amount': 0.0,
          'in_count': 0,
          'last_in_amount': null,
          'last_in_date': null,
          'average_in_amount': 0.0,
        };
      }

      double _parseAmount(dynamic v) {
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v) ?? 0.0;
        return 0.0;
      }
      final total = rows.fold<double>(
        0.0,
        (sum, r) => sum + _parseAmount(r['amount']),
      );
      final count = rows.length;
      final last = rows.first;
      return {
        'total_in_amount': total,
        'in_count': count,
        'last_in_amount': _parseAmount(last['amount']),
        'last_in_date': last['created_at'] as String?,
        'average_in_amount': total / count,
      };
    } catch (e) {
      debugPrint('Error getting client payment summary: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getClientFullSummary(String clientId) async {
    try {
      final sales = await getClientSalesSummary(clientId);
      final payments = await getClientPaymentSummary(clientId);

      final totalOut = (sales['total_out_amount'] as num?)?.toDouble() ?? 0.0;
      final totalIn = (payments['total_in_amount'] as num?)?.toDouble() ?? 0.0;
      final balance = totalOut - totalIn;

      return {
        'total_sales': totalOut,
        'total_payments': totalIn,
        'balance': balance,
        'sales_count': sales['out_count'] ?? 0,
        'payment_count': payments['in_count'] ?? 0,
        'last_sale_date': sales['last_out_date'],
        'last_payment_date': payments['last_in_date'],
      };
    } catch (e) {
      debugPrint('Error getting client full summary: $e');
      return {};
    }
  }

  Future<Either<Exception, List<SupplierField>>> getSupplierFields(String supplierId) {
    return _repo.getSupplierFields(supplierId);
  }

  Future<Either<Exception, List<BusinessField>>> getBusinessFields() {
    return _repo.getBusinessFields();
  }

  Future<Either<Exception, List<BusinessField>>> getSupplierFieldDefinitions() {
    return _repo.getSupplierFieldDefinitions();
  }

  Future<Either<Exception, BusinessField>> createSupplierBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  }) {
    return _repo.createSupplierBusinessField(
      nameAr: nameAr,
      nameEn: nameEn,
      description: description,
    );
  }

  Future<Either<Exception, BusinessField>> createClientBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  }) {
    return _repo.createClientBusinessField(
      nameAr: nameAr,
      nameEn: nameEn,
      description: description,
    );
  }

  Future<bool> deleteSupplier(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final res = await _repo.deleteSupplier(id);
    return res.fold((l) {
      _error = l.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }, (ok) {
      _suppliers.removeWhere((s) => s.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    });
  }
}
