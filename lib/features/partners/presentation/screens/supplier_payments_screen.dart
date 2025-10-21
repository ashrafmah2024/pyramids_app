// ملف: lib/features/partners/presentation/screens/supplier_payments_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/supplier.dart';
import 'add_supplier_payment_screen.dart';
import 'supplier_account_statement_screen.dart';
import '../providers/supplier_account_statement_provider.dart';

// نموذج بسيط للدفعة (مبني على جدول supplier_payments في Supabase)
class SupplierPayment {
  final String id;
  final String supplierId;
  final double amount;
  final String currency;
  final DateTime paidAt;
  final String method;
  final String reference;
  final String notes;
  final Map<String, dynamic>? metadata;
  final String createdBy;
  final DateTime createdAt;

  SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.amount,
    required this.currency,
    required this.paidAt,
    required this.method,
    required this.reference,
    required this.notes,
    this.metadata,
    required this.createdBy,
    required this.createdAt,
  });

  // دالة لتحويل بيانات Supabase إلى كائن SupplierPayment
  factory SupplierPayment.fromSupabase(Map<String, dynamic> data) {
    return SupplierPayment(
      id: data['id'] as String,
      supplierId: data['supplier_id'] as String,
      amount: (data['amount'] as num).toDouble(),
      currency: data['currency'] as String,
      paidAt: DateTime.parse(data['paid_at'] as String),
      method: data['method'] as String,
      reference: data['reference'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdBy: data['created_by'] as String,
      createdAt: DateTime.parse(data['created_at'] as String),
    );
  }
}

class SupplierPaymentsScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierPaymentsScreen({super.key, required this.supplier});

  @override
  State<SupplierPaymentsScreen> createState() => _SupplierPaymentsScreenState();
}

class _SupplierPaymentsScreenState extends State<SupplierPaymentsScreen> {
  // دالة لجلب دفعات المورد من Supabase
  Future<List<SupplierPayment>> _fetchSupplierPayments() async {
    try {
      final response = await Supabase.instance.client
          .from('supplier_payments')
          .select()
          .eq('supplier_id', widget.supplier.id)
          .order('paid_at', ascending: false);

      final data = response as List<dynamic>;
      return data.map((item) => SupplierPayment.fromSupabase(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('فشل في جلب الدفعات: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('دفعات المورد: ${widget.supplier.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance),
            onPressed: () {
              // Initialize the provider with the supplier before navigating
              final provider = context.read<SupplierAccountStatementProvider>();
              provider.initializeWithSupplier(widget.supplier);

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SupplierAccountStatementScreen(supplier: widget.supplier),
                ),
              );
            },
            tooltip: 'كشف الحساب',
          ),
        ],
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
        child: FutureBuilder<List<SupplierPayment>>(
          future: _fetchSupplierPayments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('خطأ في تحميل البيانات: ${snapshot.error}'),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('لا توجد دفعات مسجلة لهذا المورد'),
                  ],
                ),
              );
            } else {
              final payments = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showPaymentDetails(context, payment),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with icon, amount and reference
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Icon(Icons.payment, color: Theme.of(context).colorScheme.onPrimary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${payment.amount} ${payment.currency}',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        payment.reference,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Divider
                            Divider(height: 1, thickness: 1),
                            const SizedBox(height: 12),
                            // Payment details section
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'طريقة الدفع',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        payment.method,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'التاريخ',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        payment.paidAt.toLocal().toString().split(' ')[0],
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (payment.notes.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Divider(height: 1, thickness: 1),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ملاحظات',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    payment.notes,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNewPayment(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة دفعة جديدة'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showPaymentDetails(BuildContext context, SupplierPayment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل الدفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المبلغ: ${payment.amount} ${payment.currency}'),
            Text('طريقة الدفع: ${payment.method}'),
            Text('التاريخ: ${payment.paidAt.toLocal()}'),
            Text('المرجع: ${payment.reference}'),
            Text('ملاحظات: ${payment.notes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _addNewPayment(BuildContext context) async {
    // الانتقال إلى شاشة إضافة دفعة جديدة
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSupplierPaymentScreen(supplier: widget.supplier),
      ),
    );
    if (result == true) {
      // إعادة تحميل البيانات إذا تم إضافة دفعة جديدة بنجاح
      setState(() {}); // هذا سيؤدي إلى إعادة بناء FutureBuilder
    }
  }

  void _editPayment(BuildContext context, SupplierPayment payment) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddSupplierPaymentScreen(
          supplier: widget.supplier,
          payment: payment,
        ),
      ),
    );
    if (result == true) {
      // إعادة تحميل البيانات إذا تم تعديل الدفعة بنجاح
      setState(() {}); // هذا سيؤدي إلى إعادة بناء FutureBuilder
    }
  }
}
