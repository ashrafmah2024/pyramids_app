import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// Removed AppRouter import as we'll use direct navigation
import 'package:pyramids/features/purchases/domain/entities/purchase_entity.dart';
import 'package:pyramids/core/services/supabase_service.dart';

import 'add_purchase_screen.dart';

class PurchaseDetailsScreen extends StatefulWidget {
  final PurchaseEntity purchase;
  
  const PurchaseDetailsScreen({
    Key? key,
    required this.purchase,
  }) : super(key: key);

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {

  Future<String> _getPaymentMethodName() async {
    if (widget.purchase.paymentMethodId == null || widget.purchase.paymentMethodId!.isEmpty) {
      return 'غير محدد';
    }

    try {
      // Import SupabaseService
      final client = SupabaseService().client;
      final response = await client
          .from('payment_methods')
          .select('name_ar')
          .eq('id', widget.purchase.paymentMethodId!)
          .eq('is_active', true)
          .single();

      if (response != null && response['name_ar'] != null) {
        return response['name_ar'].toString();
      }
    } catch (e) {
      debugPrint('Error fetching payment method name: $e');
    }

    return 'غير محدد';
  }

  Widget _buildPaymentMethodRow() {
    return FutureBuilder<String>(
      future: _getPaymentMethodName(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('جاري التحميل...');
        } else if (snapshot.hasError) {
          return const Text('خطأ في التحميل');
        } else {
          return Text(snapshot.data ?? 'غير محدد');
        }
      },
    );
  }

  Future<void> _refreshData() async {
    // يمكنك إضافة تحديث للبيانات هنا إذا لزم الأمر
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الفاتورة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _refreshData();
                setState(() {});
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // Navigate to edit screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPurchaseScreen(
                      purchase: widget.purchase.toJson(),
                    ),
                  ),
                ).then((_) {
                  _refreshData();
                });
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoRow('الرقم المرجعي', widget.purchase.referenceNumber),
                  if (widget.purchase.item?.isNotEmpty == true) ...[
                    _buildInfoRow('البيان', widget.purchase.item!),
                  ],
                  _buildInfoRow('المورد', widget.purchase.supplierName ?? 'غير محدد'),
                  _buildInfoRow('رقم فاتورة المورد', widget.purchase.invoiceNumber ?? 'غير محدد'),
                  _buildInfoRow('تاريخ الفاتورة', _formatDate(widget.purchase.purchaseDate)),
                  _buildInfoRow('تاريخ الاستحقاق', _formatDate(widget.purchase.dueDate)),
                  _buildInfoRow('طريقة الدفع', _buildPaymentMethodRow()),
                  const Divider(thickness: 1.5),
                  _buildInfoRow('الكمية', '${widget.purchase.quantity.toStringAsFixed(2)} ${widget.purchase.unitName}'),
                  _buildInfoRow('سعر الوحدة', '${widget.purchase.unitPrice.toStringAsFixed(2)} ج.م'),
                  _buildInfoRow('الاجمالي', '${widget.purchase.totalAmount.toStringAsFixed(2)} ج.م'),
                  _buildInfoRow('ضريبة قيمة مضافة', '${widget.purchase.taxAmount.toStringAsFixed(2)} ج.م'),
                  _buildInfoRow('نسبة الخصم', '${widget.purchase.discountPercent.toStringAsFixed(2)}%'),
                  _buildInfoRow('قيمة الخصم', '${widget.purchase.discountAmount.toStringAsFixed(2)} ج.م'),
                  const Divider(thickness: 1.5),
                  _buildInfoRow('المبلغ المدفوع', '${widget.purchase.amountPaid.toStringAsFixed(2)} ج.م', isBold: true),
                  _buildInfoRow('المبلغ المتبقي', '${widget.purchase.amountDue.toStringAsFixed(2)} ج.م', isBold: true),
                  const SizedBox(height: 8),
                  _buildStatusChip(),
                  if (widget.purchase.notesAr?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    _buildInfoRow('ملاحظات', widget.purchase.notesAr!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label (right-aligned for RTL)
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          // Value with proper text wrapping
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: value is Widget
                ? value
                : Text(
                    value?.toString() ?? 'غير محدد',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final code = (widget.purchase.statusCode).toLowerCase();
    final statusText = code; // عرض statusCode مباشرة
    final statusColor = _getStatusColor(widget.purchase.statusColor, code);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Color _getStatusColor(String? colorHex, String code) {
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    switch (code) {
      case 'completed':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'draft':
      default:
        return Colors.grey;
    }
  }


  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    try {
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return 'غير محدد';
    }
  }
}
