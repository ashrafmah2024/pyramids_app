import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/theme/app_colors.dart';
import 'package:pyramids/core/utils/responsive.dart';
import '../../domain/entities/purchase_expense.dart';
import '../providers/expense_provider.dart';
import 'dart:ui' as ui;
import 'add_edit_expense_screen.dart';

class ExpensesListScreen extends StatefulWidget {
  final String purchaseId;
  final String purchaseName;

  const ExpensesListScreen({
    Key? key,
    required this.purchaseId,
    required this.purchaseName,
  }) : super(key: key);

  @override
  _ExpensesListScreenState createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'direct', 'indirect'

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<ExpenseProvider>(context, listen: false)
          .fetchExpenses(widget.purchaseId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل المصروفات: $e')),
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
    // Using Responsive utility for layout adjustments
    final isSmallScreen = Responsive.isSmallScreen(context);
    // The isSmallScreen variable is used in the build method for responsive layout
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('مصروفات ${widget.purchaseName}'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadExpenses,
            ),
          ],
        ),
        body: Column(
          children: [
            // شريط البحث والتصفية
            _buildSearchAndFilterBar(),
            
            // قائمة المصروفات
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildExpensesList(),
            ),
            
            // إجمالي المصروفات
            _buildTotalExpenses(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (context) => AddEditExpenseScreen(
                  purchaseId: widget.purchaseId,
                ),
              ),
            );
            
            if (result == true) {
              _loadExpenses();
            }
          },
          child: const Icon(Icons.add),
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // حقل البحث
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن مصروف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            
            const SizedBox(height: 8),
            
            // أزرار التصفية
            Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('مباشرة', 'direct'),
                const SizedBox(width: 8),
                _buildFilterChip('غير مباشرة', 'indirect'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _filterType == value,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: _filterType == value ? AppColors.primary : Colors.black87,
        fontWeight: _filterType == value ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildExpensesList() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        // تطبيق الفلاتر والبحث
        List<PurchaseExpense> filteredExpenses = provider.expenses.where((expense) {
          final matchesSearch = _searchQuery.isEmpty ||
              expense.nameAr.toLowerCase().contains(_searchQuery) ||
              (expense.nameEn?.toLowerCase().contains(_searchQuery) ?? false) ||
              expense.amount.toString().contains(_searchQuery);
              
          final matchesType = _filterType == 'all' || 
              expense.expenseType == _filterType;
              
          return matchesSearch && matchesType;
        }).toList();

        if (filteredExpenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'لا توجد مصروفات مسجلة',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                if (_searchQuery.isNotEmpty || _filterType != 'all') ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _filterType = 'all';
                      });
                    },
                    child: const Text('إعادة تعيين البحث'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80), // مساحة للزر العائم
          itemCount: filteredExpenses.length,
          itemBuilder: (context, index) {
            final expense = filteredExpenses[index];
            return _buildExpenseItem(expense);
          },
        );
      },
    );
  }

  Widget _buildExpenseItem(PurchaseExpense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          expense.nameAr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
              style: const TextStyle(fontSize: 16, color: Colors.green),
            ),
            if (expense.notes?.isNotEmpty ?? false)
              Text(
                expense.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
            Text(
              expense.isDirect ? 'مصروف مباشر' : 'مصروف غير مباشر',
              style: TextStyle(
                color: expense.isDirect ? Colors.blue : Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _editExpense(expense),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteExpense(expense),
            ),
          ],
        ),
        onTap: () => _editExpense(expense),
      ),
    );
  }

  Future<void> _editExpense(PurchaseExpense expense) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditExpenseScreen(
          expense: expense,
          purchaseId: widget.purchaseId,
        ),
      ),
    );
    
    if (result == true) {
      _loadExpenses();
    }
  }

  Future<void> _confirmDeleteExpense(PurchaseExpense expense) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المصروف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await Provider.of<ExpenseProvider>(context, listen: false)
            .deleteExpense(expense.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المصروف بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
          );
        }
      }
    }
  }

  Widget _buildTotalExpenses() {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        double total = 0;
        double directTotal = 0;
        double indirectTotal = 0;
        
        for (var expense in provider.expenses) {
          total += expense.amount;
          if (expense.isDirect) {
            directTotal += expense.amount;
          } else {
            indirectTotal += expense.amount;
          }
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي المصروفات المباشرة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${directTotal.toStringAsFixed(2)} EGP',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي المصروفات غير المباشرة:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${indirectTotal.toStringAsFixed(2)} EGP',
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الإجمالي الكلي:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '${total.toStringAsFixed(2)} EGP',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
