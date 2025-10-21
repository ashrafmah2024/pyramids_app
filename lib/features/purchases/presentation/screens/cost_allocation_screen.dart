import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/theme/app_colors.dart';
import 'package:pyramids/core/utils/responsive.dart';
import '../../domain/entities/expense_allocation_rule.dart';
import '../../domain/entities/purchase_costing.dart';
import '../../domain/entities/purchase_expense.dart';
import '../providers/expense_provider.dart';
import 'dart:ui' as ui;

class CostAllocationScreen extends StatefulWidget {
  final String purchaseId;
  final String purchaseName;

  const CostAllocationScreen({
    Key? key,
    required this.purchaseId,
    required this.purchaseName,
  }) : super(key: key);

  @override
  _CostAllocationScreenState createState() => _CostAllocationScreenState();
}

class _CostAllocationScreenState extends State<CostAllocationScreen> {
  bool _isLoading = false;
  final Map<String, double> _allocatedAmounts = {};
  String? _selectedRuleId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      await provider.fetchExpenses(widget.purchaseId);
      await provider.loadAllocationRules();
      await provider.calculateCosting(widget.purchaseId);
      
      // تحميل التخصيصات الحالية إذا وجدت
      final expenses = provider.indirectExpenses;
      for (var expense in expenses) {
        if (expense.allocationRuleId != null) {
          _allocatedAmounts[expense.id] = expense.amount;
        }
      }
      
      // تحديد قاعدة التوزيع الافتراضية إذا لم يتم تحديدها
      if (expenses.isNotEmpty && expenses.first.allocationRuleId != null) {
        _selectedRuleId = expenses.first.allocationRuleId;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          title: Text('توزيع التكاليف - ${widget.purchaseName}'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildAllocationContent(),
      ),
    );
  }

  Widget _buildAllocationContent() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final directExpenses = provider.directExpenses;
        final indirectExpenses = provider.indirectExpenses;
        final rules = provider.allocationRules;
        final costing = provider.costing;
        
        if (directExpenses.isEmpty && indirectExpenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.money_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد مصروفات مسجلة',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('تحديث'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ملخص التكاليف
              _buildCostingSummary(costing),
              
              const SizedBox(height: 24),
              
              // قسم المصروفات المباشرة
              _buildSectionHeader('المصروفات المباشرة'),
              const SizedBox(height: 8),
              ...directExpenses.map((expense) => _buildExpenseCard(expense)),
              
              const SizedBox(height: 24),
              
              // قسم المصروفات غير المباشرة
              _buildSectionHeader('المصروفات غير المباشرة'),
              const SizedBox(height: 8),
              
              if (indirectExpenses.isNotEmpty) ...[
                // اختيار قاعدة التوزيع
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'قاعدة توزيع التكاليف',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedRuleId,
                          decoration: const InputDecoration(
                            labelText: 'اختر قاعدة التوزيع',
                            border: OutlineInputBorder(),
                          ),
                          items: rules.map((rule) {
                            return DropdownMenuItem(
                              value: rule.id,
                              child: Text(rule.nameAr),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRuleId = value;
                            });
                          },
                          validator: (value) {
                            if (indirectExpenses.isNotEmpty && value == null) {
                              return 'يجب اختيار قاعدة توزيع';
                            }
                            return null;
                          },
                        ),
                        if (_selectedRuleId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _getRuleDescription(_selectedRuleId, rules),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...indirectExpenses.map((expense) => _buildIndirectExpenseCard(expense)),
              ],
              
              const SizedBox(height: 24),
              
              // زر حفظ التوزيع
              ElevatedButton(
                onPressed: _saveAllocation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text(
                  'حفظ توزيع التكاليف',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCostingSummary(PurchaseCosting? costing) {
    if (costing == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('لا توجد بيانات متاحة')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'ملخص التكاليف',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const Divider(height: 24),
            _buildSummaryRow('التكلفة المباشرة للوحدة', '${costing.directCostPerUnit.toStringAsFixed(2)} EGP'),
            _buildSummaryRow('إجمالي التكلفة المباشرة', '${costing.totalDirectCost.toStringAsFixed(2)} EGP'),
            const Divider(height: 24),
            _buildSummaryRow('التكلفة غير المباشرة للوحدة', '${costing.indirectCostPerUnit.toStringAsFixed(2)} EGP'),
            _buildSummaryRow('إجمالي التكلفة غير المباشرة', '${costing.totalIndirectCost.toStringAsFixed(2)} EGP'),
            const Divider(height: 24),
            _buildSummaryRow(
              'التكلفة الإجمالية للوحدة',
              '${costing.totalCostPerUnit.toStringAsFixed(2)} EGP',
              isBold: true,
              textColor: Colors.green,
            ),
            _buildSummaryRow(
              'إجمالي التكلفة',
              '${costing.totalCost.toStringAsFixed(2)} EGP',
              isBold: true,
              textColor: Colors.green,
            ),
            const Divider(height: 24),
            _buildSummaryRow('هامش الربح', '${costing.markupPercentage}%'),
            _buildSummaryRow(
              'سعر البيع المقترح',
              '${costing.sellingPricePerUnit.toStringAsFixed(2)} EGP',
              isBold: true,
              textColor: Theme.of(context).primaryColor,
            ),
            if (costing.lastCalculationDate != null) ...[
              const Divider(height: 24),
              Text(
                'آخر تحديث: ${_formatDate(costing.lastCalculationDate!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildExpenseCard(PurchaseExpense expense) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(expense.nameAr),
        subtitle: Text('${expense.amount.toStringAsFixed(2)} ${expense.currency}'),
        leading: const Icon(Icons.attach_money, color: Colors.blue),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildIndirectExpenseCard(PurchaseExpense expense) {
    final amount = _allocatedAmounts[expense.id] ?? expense.amount;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: [
          ListTile(
            title: Text(expense.nameAr),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${expense.amount.toStringAsFixed(2)} ${expense.currency}'),
                if (expense.allocationRuleId != null)
                  Text(
                    'قاعدة التوزيع: ${_getRuleName(expense.allocationRuleId, context)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            leading: const Icon(Icons.money_off, color: Colors.orange),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المبلغ المخصص:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Slider(
                  value: amount,
                  min: 0,
                  max: expense.amount * 2, // السماح بزيادة حتى ضعف المبلغ
                  divisions: 100,
                  label: amount.toStringAsFixed(2),
                  onChanged: (value) {
                    setState(() {
                      _allocatedAmounts[expense.id] = value;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '0.00 ${expense.currency}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${(expense.amount * 2).toStringAsFixed(2)} ${expense.currency}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRuleName(String? ruleId, BuildContext context) {
    if (ruleId == null) return 'غير محدد';
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final rule = provider.allocationRules.firstWhere(
      (r) => r.id == ruleId,
      orElse: () => ExpenseAllocationRule(
        id: '',
        nameAr: 'غير معروف',
        allocationType: 'custom',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    return rule.nameAr;
  }

  String _getRuleDescription(String? ruleId, List<ExpenseAllocationRule> rules) {
    if (ruleId == null) return '';
    final rule = rules.firstWhere(
      (r) => r.id == ruleId,
      orElse: () => ExpenseAllocationRule(
        id: '',
        nameAr: 'غير معروف',
        allocationType: 'custom',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    switch (rule.allocationType) {
      case 'quantity':
        return 'يتم التوزيع بناءً على الكمية';
      case 'value':
        return 'يتم التوزيع بناءً على القيمة';
      case 'weight':
        return 'يتم التوزيع بناءً على الوزن';
      case 'custom':
        return 'توزيع مخصص: ${rule.customRatio?.toStringAsFixed(2) ?? '0'}%';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveAllocation() async {
    if (_selectedRuleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار قاعدة توزيع')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      
      // تحديث قواعد التوزيع للمصروفات غير المباشرة
      for (var expense in provider.indirectExpenses) {
        final amount = _allocatedAmounts[expense.id] ?? expense.amount;
        await provider.updateExpense(
          expense.copyWith(
            allocationRuleId: _selectedRuleId,
            amount: amount,
          ),
        );
      }
      
      // حساب التكاليف
      await provider.calculatePurchaseCosting(widget.purchaseId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ توزيع التكاليف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ التوزيع: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
