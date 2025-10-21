import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../../domain/entities/supplier.dart';
import '../screens/supplier_payments_screen.dart';

class AddSupplierPaymentScreen extends StatefulWidget {
  final Supplier supplier;
  final SupplierPayment? payment; // معامل اختياري للدفعة المراد تعديلها

  const AddSupplierPaymentScreen({
    super.key,
    required this.supplier,
    this.payment,
  });

  @override
  State<AddSupplierPaymentScreen> createState() =>
      _AddSupplierPaymentScreenState();
}

class _AddSupplierPaymentScreenState extends State<AddSupplierPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCurrency = 'EGP'; // العملة الافتراضية
  String _selectedMethod = 'نقدي'; // طريقة الدفع الافتراضية
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _currencies = ['EGP', 'USD', 'EUR'];
  final List<String> _paymentMethods = [
    'نقدي',
    'تحويل بنكي',
    'شيك',
    'بطاقة ائتمان',
  ];

  @override
  void initState() {
    super.initState();
    // ملء الحقول بالبيانات الموجودة إذا كانت هناك دفعة للتعديل
    if (widget.payment != null) {
      final payment = widget.payment!;
      _amountController.text = payment.amount.toString();
      _referenceController.text = payment.reference;
      _notesController.text = payment.notes;
      _selectedCurrency = payment.currency;
      _selectedMethod = payment.method;
      _selectedDate = payment.paidAt;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // دالة عامة لحفظ الدفعة (إضافة أو تعديل)
  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final paymentData = {
        'supplier_id': widget.supplier.id,
        'amount': double.parse(_amountController.text),
        'currency': _selectedCurrency,
        'paid_at': _selectedDate.toIso8601String(),
        'method': _selectedMethod,
        'reference': _referenceController.text.trim(),
        'notes': _notesController.text.trim(),
        'metadata': {}, // يمكن إضافة بيانات إضافية هنا
        'created_by': currentUser.id,
      };

      if (widget.payment != null) {
        // تعديل دفعة موجودة (ذرّي عبر RPC لإعادة التوزيع حسب المبلغ الجديد)
        final double newAmount = double.parse(_amountController.text);

        // 1) تعديل المبلغ وإعادة التوزيع عبر RPC
        final rpcRes = await Supabase.instance.client.rpc(
          'adjust_supplier_payment',
          params: {
            'p_payment_id': widget.payment!.id,
            'p_new_amount': newAmount,
          },
        );
        debugPrint('[RPC] adjust_supplier_payment => $rpcRes');

        // 2) تحديث الحقول غير المرتبطة بالمبلغ فقط
        final Map<String, dynamic> nonAmountUpdates = Map<String, dynamic>.from(paymentData)
          ..remove('amount')
          ..remove('created_by');
        if (nonAmountUpdates.isNotEmpty) {
          await Supabase.instance.client
              .from('supplier_payments')
              .update(nonAmountUpdates)
              .eq('id', widget.payment!.id);
        }

        try {
          final authUser = Supabase.instance.client.auth.currentUser;
          if (authUser != null) {
            final displayName =
                authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
            // حساب الفروق قبل/بعد
            final old = widget.payment!;
            final List<String> diffs = [];
            // amount (تم ضبطه عبر RPC)
            final oldAmount = old.amount;
            if (oldAmount != newAmount) {
              diffs.add('amount: $oldAmount -> $newAmount');
            }
            // currency
            if (old.currency != _selectedCurrency) {
              diffs.add('currency: ${old.currency} -> $_selectedCurrency');
            }
            // paid_at
            if (old.paidAt != _selectedDate) {
              diffs.add('paid_at: ${old.paidAt.toIso8601String()} -> ${_selectedDate.toIso8601String()}');
            }
            // method
            if (old.method != _selectedMethod) {
              diffs.add('method: ${old.method} -> $_selectedMethod');
            }
            // reference
            if (old.reference != _referenceController.text.trim()) {
              diffs.add('reference: ${old.reference} -> ${_referenceController.text.trim()}');
            }
            // notes
            if (old.notes != _notesController.text.trim()) {
              diffs.add('notes: ${old.notes} -> ${_notesController.text.trim()}');
            }
            final String diffText = diffs.isNotEmpty ? ' | ' + diffs.join(', ') : '';
            await Supabase.instance.client.from('activity_logs').insert({
              'user_id': authUser.id,
              'user_name': displayName,
              'action': 'UPDATE',
              'description':
                  'تعديل دفعة (مع إعادة توزيع) لمورد: ${widget.supplier.name} بقيمة ${_amountController.text} ${_selectedCurrency} (${_selectedMethod}) مرجع: ${_referenceController.text.trim()}'+diffText,
            });
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الدفعة وإعادة توزيعها بنجاح')),
          );
        }
      } else {
        // إضافة دفعة جديدة مع استرجاع المعرف
        final insertedPayment = await Supabase.instance.client
            .from('supplier_payments')
            .insert(paymentData)
            .select()
            .single();

        // توزيع المبلغ تلقائياً على فواتير المورد المفتوحة/الجزئية حسب الأقدمية (FIFO)
        try {
          double remainingPayment = (paymentData['amount'] as num).toDouble();
          if (remainingPayment > 0) {
            final purchases = await Supabase.instance.client
                .from('purchases')
                .select(
                  'id, invoice_number, total_amount, amount_paid, amount_due, purchase_date, status, due_date',
                )
                .eq('supplier_id', widget.supplier.id)
                .or('status.eq.pending,status.eq.partially_paid')
                .gt('amount_due', 0)
                .order('purchase_date', ascending: true);
            final list = (purchases as List);
            debugPrint('[Alloc] Found ${list.length} eligible invoices for supplier ${widget.supplier.id}');
            int affected = 0;
            final List<Map<String, dynamic>> allocationRows = [];
            // ترتيب محلي: المتأخرة (due_date < اليوم) أولاً ثم بقية الفواتير
            final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            DateTime? toDate(dynamic v) {
              if (v == null) return null;
              try {
                final d = DateTime.parse(v.toString());
                return DateTime(d.year, d.month, d.day);
              } catch (_) {
                return null;
              }
            }
            bool isOverdue(Map p) {
              final dd = toDate(p['due_date']);
              return dd != null && dd.isBefore(today);
            }
            final List sorted = List.from(list);
            sorted.sort((a, b) {
              final ao = isOverdue(a);
              final bo = isOverdue(b);
              if (ao != bo) return ao ? -1 : 1; // المتأخرة أولاً
              final ad = toDate(a['due_date']);
              final bd = toDate(b['due_date']);
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return ad.compareTo(bd);
            });
            for (final p in sorted) {
              if (remainingPayment <= 0) break;

              final String purchaseId = p['id'] as String;
              final String inv = (p['invoice_number'] ?? '').toString();
              final double total = (p['total_amount'] as num?)?.toDouble() ?? 0.0;
              final double paid = (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
              final double remainingOnInvoice = (total - paid).clamp(0.0, double.infinity);
              if (remainingOnInvoice <= 0) {
                debugPrint('[Alloc] Skip $inv ($purchaseId): already fully paid or zero total');
                continue;
              }

              final double allocate = math.min(remainingPayment, remainingOnInvoice);
              debugPrint('[Alloc] Allocating $allocate to $inv ($purchaseId) | total=$total paid=$paid remaining=$remainingOnInvoice');

              // إنشاء سجل تخصيص (تجميع للإدراج الدفعي)
              allocationRows.add({
                'payment_id': insertedPayment['id'],
                'purchase_id': purchaseId,
                'allocated_amount': allocate,
              });

              // تحديث الفاتورة
              final double newPaid = paid + allocate;
              final double newDueRaw = (total - newPaid);
              final double newDue = newDueRaw < 0 ? 0.0 : newDueRaw;
              final bool isFullyPaid = newPaid >= total - 0.0001;
              final bool isPartial = newPaid > 0 && !isFullyPaid;
              final Map<String, dynamic> updateMap = {
                'amount_paid': newPaid,
                'amount_due': newDue,
              };
              if (isFullyPaid) {
                updateMap['status'] = 'completed';
                updateMap['status_code'] = 'مدفوع';
              } else if (isPartial) {
                updateMap['status'] = 'partially_paid';
                updateMap['status_code'] = 'مدفوعة جزئياً';
              } else {
                // If no payment applied (shouldn't happen here), ensure pending code
                updateMap['status'] = 'pending';
                updateMap['status_code'] = 'غير مدفوع';
              }
              final updateRes = await Supabase.instance.client
                  .from('purchases')
                  .update(updateMap)
                  .eq('id', purchaseId)
                  .select('id, amount_paid, amount_due, status')
                  .maybeSingle();

              debugPrint(
                '[Alloc] Updated invoice ${p['invoice_number']} ($purchaseId): ${updateRes ?? {'amount_paid': newPaid, 'amount_due': newDue, if (isFullyPaid) 'status': 'completed', if (isPartial) 'status': 'partially_paid'}}',
              );

              remainingPayment -= allocate;
              affected++;
            }
            if (allocationRows.isNotEmpty) {
              await Supabase.instance.client
                  .from('supplier_payment_allocations')
                  .insert(allocationRows);
            }
            if (affected == 0) {
              debugPrint('[Alloc] No invoices were updated. Check RLS policies and column names (amount_paid, amount_due, status)');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لم يتم العثور على فواتير صالحة للتوزيع أو تم منع التحديث بواسطة الصلاحيات')), 
                );
              }
            }
          }
        } catch (e) {
          // يمكن لاحقاً ترحيل المنطق إلى RPC لضمان الذرّية
          debugPrint('Allocation error: $e');
        }

        try {
          final authUser = Supabase.instance.client.auth.currentUser;
          if (authUser != null) {
            final displayName =
                authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
            await Supabase.instance.client.from('activity_logs').insert({
              'user_id': authUser.id,
              'user_name': displayName,
              'action': 'INSERT',
              'description':
                  'إضافة دفعة + توزيع تلقائي لمورد: ${widget.supplier.name} بقيمة ${_amountController.text} ${_selectedCurrency} (${_selectedMethod}) مرجع: ${_referenceController.text.trim()}',
            });
          }
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة الدفعة وتوزيعها تلقائياً بنجاح'),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // العودة إلى الشاشة السابقة مع إشارة نجاح
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في حفظ الدفعة: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.payment != null
              ? 'تعديل الدفعة'
              : 'إضافة دفعة جديدة لـ ${widget.supplier.name}',
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.green[900]!.withOpacity(0.2)
                  : Colors.green[50]!,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // حقل المبلغ
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'المبلغ',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'المبلغ مطلوب';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // اختيار العملة
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'العملة',
                      border: OutlineInputBorder(),
                    ),
                    items: _currencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCurrency = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // اختيار طريقة الدفع
                  DropdownButtonFormField<String>(
                    value: _selectedMethod,
                    decoration: const InputDecoration(
                      labelText: 'طريقة الدفع',
                      border: OutlineInputBorder(),
                    ),
                    items: _paymentMethods.map((method) {
                      return DropdownMenuItem(
                        value: method,
                        child: Text(method),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedMethod = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // اختيار التاريخ
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() => _selectedDate = pickedDate);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Text(
                            'التاريخ: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // حقل المرجع
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'المرجع (اختياري)',
                      prefixIcon: Icon(Icons.tag),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // حقل الملاحظات
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختيارية)',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // زر الحفظ
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('حفظ الدفعة'),
                    ),
                  ),

                  // زر الإلغاء
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
