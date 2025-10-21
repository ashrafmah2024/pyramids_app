class SupplierPaymentEntity {
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

  SupplierPaymentEntity({
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

  factory SupplierPaymentEntity.fromSupabase(Map<String, dynamic> data) {
    return SupplierPaymentEntity(
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier_id': supplierId,
      'amount': amount,
      'currency': currency,
      'paid_at': paidAt.toIso8601String(),
      'method': method,
      'reference': reference,
      'notes': notes,
      'metadata': metadata,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
