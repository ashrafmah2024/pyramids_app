class PurchaseEntity {
  final String id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final String unitId;
  final String unitName;
  final String? paymentMethodId;
  final String? paymentMethodName;
  final String invoiceNumber;
  final DateTime purchaseDate;
  final DateTime? dueDate;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final double taxPercent;
  final double taxAmount;
  final double discountPercent;
  final double discountAmount;
  final double amountPaid;
  final double amountDue;
  final String status; // 'paid', 'partially_paid', 'unpaid'
  final String statusCode;
  final String? statusNameAr;
  final String? statusNameEn;
  final String? statusColor;
  final String? notesAr;
  final String? notesEn;
  final String? item;
  final DateTime? paymentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PurchaseEntity({
    required this.id,
    required this.referenceNumber,
    this.supplierId,
    this.supplierName,
    required this.unitId,
    required this.unitName,
    this.paymentMethodId,
    this.paymentMethodName,
    required this.invoiceNumber,
    required this.purchaseDate,
    this.dueDate,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.taxPercent,
    required this.taxAmount,
    required this.discountPercent,
    required this.discountAmount,
    required this.amountPaid,
    required this.amountDue,
    required this.status,
    required this.statusCode,
    this.statusNameAr,
    this.statusNameEn,
    this.statusColor,
    this.notesAr,
    this.notesEn,
    this.item,
    this.paymentDate,
    this.createdAt,
    this.updatedAt,
  });

  factory PurchaseEntity.fromJson(Map<String, dynamic> json) {
    // Handle nested payment method data
    final paymentMethod = json['payment_methods'] is Map ? json['payment_methods'] : null;
    
    return PurchaseEntity(
      id: json['id']?.toString() ?? '',
      referenceNumber: json['reference_number']?.toString() ?? '',
      supplierId: json['supplier_id']?.toString(),
      supplierName: json['supplier_name']?.toString() ?? 
                   (json['suppliers'] is Map ? json['suppliers']['name_ar']?.toString() : null),
      unitId: json['unit_id']?.toString() ?? '',
      unitName: json['unit_name']?.toString() ?? 
               (json['units'] is Map ? json['units']['name_ar']?.toString() : '') ?? '',
      paymentMethodId: json['payment_method_id']?.toString() ?? 
                     (paymentMethod != null ? paymentMethod['id']?.toString() : null),
      paymentMethodName: (paymentMethod != null ? paymentMethod['name_ar']?.toString() : null) ?? 
                       json['payment_method_name']?.toString(),
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      purchaseDate: _parseDate(json['purchase_date']) ?? DateTime.now(),
      dueDate: _parseDate(json['due_date']),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      taxPercent: (json['tax_percent'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'unpaid',
      statusCode: (json['status_code'] ?? json['status'] ?? 'draft').toString(),
      statusNameAr: json['status_name_ar']?.toString(),
      statusNameEn: json['status_name_en']?.toString(),
      statusColor: json['status_color']?.toString(),
      notesAr: json['notes_ar']?.toString(),
      notesEn: json['notes_en']?.toString(),
      item: json['item']?.toString(),
      paymentDate: _parseDate(json['payment_date']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_number': referenceNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'unit_id': unitId,
      'unit_name': unitName,
      'payment_method_id': paymentMethodId,
      'payment_method_name': paymentMethodName,
      'invoice_number': invoiceNumber,
      'purchase_date': purchaseDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'tax_percent': taxPercent,
      'tax_amount': taxAmount,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'amount_paid': amountPaid,
      'amount_due': amountDue,
      'status': status,
      'status_code': statusCode,
      'status_name_ar': statusNameAr,
      'status_name_en': statusNameEn,
      'status_color': statusColor,
      'notes_ar': notesAr,
      'notes_en': notesEn,
      'item': item,
      'payment_date': paymentDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

