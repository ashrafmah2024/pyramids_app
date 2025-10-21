// Model for supplier account statement entries
import '../../../../features/purchases/domain/entities/purchase_entity.dart';
import 'supplier_payment_entity.dart';
class SupplierAccountStatement {
  final String id;
  final String supplierId;
  final DateTime date;
  final String type; // 'purchase' or 'payment'
  final String reference;
  final String description;
  final double debit; // Amount for purchases (money going out to supplier)
  final double credit; // Amount for payments (money coming in from supplier)
  final double balance; // Running balance after this transaction
  final String? notes;
  final String? invoiceNumber;

  SupplierAccountStatement({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.type,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.notes,
    this.invoiceNumber,
  });

  factory SupplierAccountStatement.fromPurchase(PurchaseEntity purchase, double runningBalance) {
    return SupplierAccountStatement(
      id: purchase.id,
      supplierId: purchase.supplierId ?? '',
      date: purchase.purchaseDate,
      type: 'purchase',
      reference: purchase.referenceNumber,
      description: 'مشتريات - ${purchase.item ?? 'غير محدد'}',
      debit: purchase.totalAmount,
      credit: 0.0,
      balance: runningBalance,
      notes: purchase.notesAr,
      invoiceNumber: purchase.invoiceNumber,
    );
  }

  factory SupplierAccountStatement.fromPayment(SupplierPaymentEntity payment, double runningBalance) {
    return SupplierAccountStatement(
      id: payment.id,
      supplierId: payment.supplierId,
      date: payment.paidAt,
      type: 'payment',
      reference: payment.reference,
      description: 'دفعة مورد - ${payment.method}',
      debit: 0.0,
      credit: payment.amount,
      balance: runningBalance,
      notes: payment.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'date': date.toIso8601String(),
      'type': type,
      'reference': reference,
      'description': description,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'notes': notes,
      'invoice_number': invoiceNumber,
    };
  }
}
