import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/features/purchases/domain/entities/purchase_expense.dart';
import 'package:pyramids/features/purchases/domain/entities/expense_allocation_rule.dart';
import 'package:pyramids/features/purchases/domain/entities/purchase_costing.dart';
import 'package:pyramids/core/error/failures.dart';

class ExpenseProvider with ChangeNotifier {
  final SupabaseClient _supabase;
  List<PurchaseExpense> _expenses = [];
  List<ExpenseAllocationRule> _allocationRules = [];
  PurchaseCosting? _costing;

  ExpenseProvider({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  List<PurchaseExpense> get expenses => _expenses;
  List<ExpenseAllocationRule> get allocationRules => _allocationRules;
  PurchaseCosting? get costing => _costing;
  
  // Get only direct expenses (where expenseType is 'direct' or null)
  List<PurchaseExpense> get directExpenses => 
      _expenses.where((expense) => expense.expenseType == 'direct' || expense.expenseType == null).toList();
      
  // Get only indirect expenses (where expenseType is 'indirect')
  List<PurchaseExpense> get indirectExpenses => 
      _expenses.where((expense) => expense.expenseType == 'indirect').toList();

  // تحميل قواعد التخصيص
  Future<void> loadAllocationRules() async {
    try {
      final response = await _supabase
          .from('expense_allocation_rules')
          .select('*')
          .order('name', ascending: true);

      _allocationRules = (response as List<dynamic>)
          .map((e) => ExpenseAllocationRule.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل تحميل قواعد التخصيص: $e');
    }
  }

  // حساب تكلفة المشتريات
  Future<void> calculatePurchaseCosting(String purchaseId) async {
    try {
      final response = await _supabase
          .rpc('calculate_purchase_costing', params: {'purchase_id': purchaseId});
      
      // Update the costing if the response contains the expected data
      if (response != null) {
        _costing = PurchaseCosting.fromJson(response);
      }
      
      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل حساب تكلفة المشتريات: $e');
    }
  }

  // جلب كل المصروفات
  Future<void> fetchExpenses(String purchaseId) async {
    try {
      final response = await _supabase
          .from('purchase_expenses')
          .select('*')
          .eq('purchase_id', purchaseId)
          .order('date', ascending: false);

      _expenses = (response as List<dynamic>)
          .map((e) => PurchaseExpense.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل تحميل المصروفات: $e');
    }
  }

  // إضافة مصروف جديد
  Future<void> addExpense(PurchaseExpense expense) async {
    try {
      final response = await _supabase
          .from('purchase_expenses')
          .insert(expense.toJson())
          .select()
          .single();

      final newExpense = PurchaseExpense.fromJson(response);
      _expenses.insert(0, newExpense);
      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل إضافة المصروف: $e');
    }
  }

  // تحديث مصروف
  Future<void> updateExpense(PurchaseExpense expense) async {
    try {
      await _supabase
          .from('purchase_expenses')
          .update(expense.toJson())
          .eq('id', expense.id);

      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      throw ServerFailure('فشل تحديث المصروف: $e');
    }
  }

  // حذف مصروف
  Future<void> deleteExpense(String expenseId) async {
    try {
      await _supabase.from('purchase_expenses').delete().eq('id', expenseId);

      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل حذف المصروف: $e');
    }
  }

  // جلب قواعد التوزيع
  Future<void> fetchAllocationRules() async {
    try {
      final response = await _supabase
          .from('expense_allocation_rules')
          .select('*')
          .order('name_ar');

      _allocationRules = (response as List<dynamic>)
          .map((e) => ExpenseAllocationRule.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل تحميل قواعد التوزيع: $e');
    }
  }

  // حساب التكاليف
  Future<void> calculateCosting(String purchaseId) async {
    try {
      // جلب بيانات الفاتورة
      final purchaseResponse = await _supabase
          .from('purchases')
          .select('*')
          .eq('id', purchaseId)
          .single();

      // جلب العناصر المشتراة
      final itemsResponse = await _supabase
          .from('purchase_items')
          .select('*')
          .eq('purchase_id', purchaseId);

      // جلب المصروفات
      await fetchExpenses(purchaseId);

      // حساب التكاليف
      double totalDirectCost = 0;
      double totalIndirectCost = 0;

      // حساب التكلفة المباشرة
      for (var item in itemsResponse) {
        totalDirectCost += (item['unit_price'] * item['quantity']);
      }

      // حساب التكلفة غير المباشرة
      for (var expense in _expenses) {
        if (expense.isDirect) {
          totalDirectCost += expense.amount;
        } else {
          totalIndirectCost += expense.amount;
        }
      }

      // حساب التكاليف للوحدة
      final totalQuantity = itemsResponse.fold<double>(
        0,
        (sum, item) => sum + (item['quantity'] as num).toDouble(),
      );

      final directCostPerUnit = totalQuantity > 0
          ? totalDirectCost / totalQuantity
          : 0;

      final indirectCostPerUnit = totalQuantity > 0
          ? totalIndirectCost / totalQuantity
          : 0;

      // تحديث كائن التكلفة
      _costing = PurchaseCosting(
        purchaseId: purchaseId,
        totalDirectCost: totalDirectCost.toDouble(),
        totalIndirectCost: totalIndirectCost.toDouble(),
        directCostPerUnit: directCostPerUnit.toDouble(),
        indirectCostPerUnit: indirectCostPerUnit.toDouble(),
        totalCost: (totalDirectCost + totalIndirectCost).toDouble(),
        totalCostPerUnit: (directCostPerUnit + indirectCostPerUnit).toDouble(),
        sellingPricePerUnit: 0.0, // Provide default value
        markupPercentage: 0.0,    // Add missing required field
        id: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastCalculationDate: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      throw ServerFailure('فشل حساب التكاليف: $e');
    }
  }
}
