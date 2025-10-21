class SupplierField {
  final String id;
  final String? supplierId;
  final String? fieldId;
  final DateTime createdAt;

  SupplierField({
    required this.id,
    this.supplierId,
    this.fieldId,
    required this.createdAt,
  });

  factory SupplierField.fromJson(Map<String, dynamic> json) {
    return SupplierField(
      id: json['id'] as String,
      supplierId: json['supplier_id'] as String?,
      fieldId: json['field_id'] as String?,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
