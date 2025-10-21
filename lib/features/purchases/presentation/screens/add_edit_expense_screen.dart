import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/theme/app_colors.dart';
import 'package:pyramids/core/utils/responsive.dart';
import '../../domain/entities/purchase_expense.dart';
import '../providers/expense_provider.dart';
import 'dart:ui' as ui;

class AddEditExpenseScreen extends StatefulWidget {
  final PurchaseExpense? expense;
  final String purchaseId;

  const AddEditExpenseScreen({
    Key? key,
    this.expense,
    required this.purchaseId,
  }) : super(key: key);

  @override
  _AddEditExpenseScreenState createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameArController;
  late TextEditingController _nameEnController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  
  String _expenseType = 'direct';
  String? _allocationRuleId;
  String _currency = 'EGP';

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _nameArController = TextEditingController(text: expense?.nameAr ?? '');
    _nameEnController = TextEditingController(text: expense?.nameEn ?? '');
    _amountController = TextEditingController(
      text: expense?.amount.toStringAsFixed(2) ?? '',
    );
    _notesController = TextEditingController(text: expense?.notes ?? '');
    _expenseType = expense?.expenseType ?? 'direct';
    _allocationRuleId = expense?.allocationRuleId;
    _currency = expense?.currency ?? 'EGP';
  }

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;

    final expense = PurchaseExpense(
      id: widget.expense?.id ?? '',
      purchaseId: widget.purchaseId,
      expenseType: _expenseType,
      nameAr: _nameArController.text.trim(),
      nameEn: _nameEnController.text.trim().isNotEmpty 
          ? _nameEnController.text.trim() 
          : null,
      amount: double.parse(_amountController.text),
      currency: _currency,
      allocationRuleId: _expenseType == 'indirect' ? _allocationRuleId : null,
      notes: _notesController.text.trim().isNotEmpty 
          ? _notesController.text.trim() 
          : null,
      createdBy: widget.expense?.createdBy,
      createdAt: widget.expense?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      if (widget.expense == null) {
        await provider.addExpense(expense);
      } else {
        await provider.updateExpense(expense);
      }
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = Responsive.isSmallScreen(context);
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.expense == null ? 'إضافة مصروف جديد' : 'تعديل المصروف'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveExpense,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: isSmallScreen 
              ? const EdgeInsets.all(16.0) 
              : const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // نوع المصروف (مباشر/غير مباشر)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نوع المصروف',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('مصروف مباشر'),
                                value: 'direct',
                                groupValue: _expenseType,
                                onChanged: (value) {
                                  setState(() {
                                    _expenseType = value!;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('مصروف غير مباشر'),
                                value: 'indirect',
                                groupValue: _expenseType,
                                onChanged: (value) {
                                  setState(() {
                                    _expenseType = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // تفاصيل المصروف
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تفاصيل المصروف',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // الاسم بالعربية
                        TextFormField(
                          controller: _nameArController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم بالعربية *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يجب إدخال الاسم بالعربية';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // الاسم بالإنجليزية (اختياري)
                        TextFormField(
                          controller: _nameEnController,
                          decoration: const InputDecoration(
                            labelText: 'الاسم بالإنجليزية (اختياري)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // المبلغ والعملة
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'المبلغ *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.attach_money),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يجب إدخال المبلغ';
                                  }
                                  if (double.tryParse(value) == null) {
                                    return 'يجب إدخال رقم صحيح';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                value: _currency,
                                decoration: const InputDecoration(
                                  labelText: 'العملة',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'EGP',
                                    child: Text('جنيه'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'USD',
                                    child: Text('دولار'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'EUR',
                                    child: Text('يورو'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _currency = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // قاعدة التوزيع (للمصروفات غير المباشرة)
                        if (_expenseType == 'indirect') ...[  
                          const SizedBox(height: 16),
                          Consumer<ExpenseProvider>(
                            builder: (context, provider, _) {
                              final rules = provider.allocationRules
                                  .where((r) => r.isActive)
                                  .toList();
                                  
                              return DropdownButtonFormField<String>(
                                value: _allocationRuleId,
                                decoration: const InputDecoration(
                                  labelText: 'قاعدة توزيع التكلفة *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.rule),
                                ),
                                hint: const Text('اختر قاعدة التوزيع'),
                                items: rules.map((rule) {
                                  return DropdownMenuItem(
                                    value: rule.id,
                                    child: Text(rule.nameAr),
                                  );
                                }).toList(),
                                validator: (value) {
                                  if (_expenseType == 'indirect' && 
                                      (value == null || value.isEmpty)) {
                                    return 'يجب اختيار قاعدة توزيع';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {
                                    _allocationRuleId = value;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // ملاحظات
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // زر الحفظ
                ElevatedButton(
                  onPressed: _saveExpense,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: Text(
                    widget.expense == null ? 'إضافة المصروف' : 'حفظ التعديلات',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                
                if (widget.expense != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
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
                      
                      if (confirm == true && mounted) {
                        try {
                          await Provider.of<ExpenseProvider>(
                            context, 
                            listen: false,
                          ).deleteExpense(widget.expense!.id);
                          
                          if (mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
                            );
                          }
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text(
                      'حذف المصروف',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
