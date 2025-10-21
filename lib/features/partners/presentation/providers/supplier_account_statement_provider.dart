import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_account_statement.dart';
import '../../../../features/purchases/domain/entities/purchase_entity.dart';
import '../../domain/entities/supplier_payment_entity.dart';

class SupplierAccountStatementProvider with ChangeNotifier {
  Supplier? _supplier;

  SupplierAccountStatementProvider();

  // Method to initialize with a supplier
  void initializeWithSupplier(Supplier supplier) {
    _supplier = supplier;
    loadAccountStatement();
  }

  Supplier? get supplier => _supplier;

  bool _isLoading = false;
  String? _error;
  List<SupplierAccountStatement> _statementEntries = [];
  double _openingBalance = 0.0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SupplierAccountStatement> get statementEntries => _statementEntries;
  double get openingBalance => _openingBalance;

  // Calculate closing balance (balance after last transaction)
  double get closingBalance => _statementEntries.isNotEmpty
      ? _statementEntries.last.balance
      : _openingBalance;

  Future<void> loadAccountStatement() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch purchases and payments
      final purchasesFuture = _fetchSupplierPurchases();
      final paymentsFuture = _fetchSupplierPayments();

      final purchasesResult = await purchasesFuture;
      final paymentsResult = await paymentsFuture;

      if (purchasesResult.isLeft()) {
        _error = purchasesResult.fold((l) => l.toString(), (r) => null);
        return;
      }

      if (paymentsResult.isLeft()) {
        _error = paymentsResult.fold((l) => l.toString(), (r) => null);
        return;
      }

      final purchases = purchasesResult.getOrElse(() => []);
      final payments = paymentsResult.getOrElse(() => []);

      // Combine and sort by date
      final allTransactions = <SupplierAccountStatement>[];

      // Convert purchases to statement entries (debit transactions)
      for (final purchase in purchases) {
        allTransactions.add(SupplierAccountStatement.fromPurchase(purchase, 0.0));
      }

      // Convert payments to statement entries (credit transactions)
      for (final payment in payments) {
        allTransactions.add(SupplierAccountStatement.fromPayment(payment, 0.0));
      }

      // Sort by date (oldest first)
      allTransactions.sort((a, b) => a.date.compareTo(b.date));

      // Calculate running balance
      double runningBalance = _openingBalance;
      for (int i = 0; i < allTransactions.length; i++) {
        final transaction = allTransactions[i];

        if (transaction.type == 'purchase') {
          // Purchases increase supplier balance (we owe them more)
          runningBalance += transaction.debit;
        } else if (transaction.type == 'payment') {
          // Payments decrease supplier balance (we pay them)
          runningBalance -= transaction.credit;
        }

        // Create new entry with calculated balance
        allTransactions[i] = SupplierAccountStatement(
          id: transaction.id,
          supplierId: transaction.supplierId,
          date: transaction.date,
          type: transaction.type,
          reference: transaction.reference,
          description: transaction.description,
          debit: transaction.debit,
          credit: transaction.credit,
          balance: runningBalance,
          notes: transaction.notes,
          invoiceNumber: transaction.invoiceNumber,
        );
      }

      _statementEntries = allTransactions;

    } catch (e) {
      _error = 'فشل في تحميل كشف الحساب: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Either<Exception, List<PurchaseEntity>>> _fetchSupplierPurchases() async {
    if (_supplier == null) {
      return Left(Exception('Supplier not initialized'));
    }

    try {
      final response = await Supabase.instance.client
          .from('purchases')
          .select()
          .eq('supplier_id', _supplier!.id)
          .order('purchase_date', ascending: true);

      final data = response as List<dynamic>;
      final purchases = data
          .map((item) => PurchaseEntity.fromJson(item as Map<String, dynamic>))
          .toList();

      return Right(purchases);
    } catch (e) {
      return Left(Exception('فشل في جلب المشتريات: $e'));
    }
  }

  Future<Either<Exception, List<SupplierPaymentEntity>>> _fetchSupplierPayments() async {
    if (_supplier == null) {
      return Left(Exception('Supplier not initialized'));
    }

    try {
      final response = await Supabase.instance.client
          .from('supplier_payments')
          .select()
          .eq('supplier_id', _supplier!.id)
          .order('paid_at', ascending: true);

      final data = response as List<dynamic>;
      final payments = data
          .map((item) => SupplierPaymentEntity.fromSupabase(item as Map<String, dynamic>))
          .toList();

      return Right(payments);
    } catch (e) {
      return Left(Exception('فشل في جلب الدفعات: $e'));
    }
  }

  void refresh() {
    loadAccountStatement();
  }
}
