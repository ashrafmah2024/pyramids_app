class ClientField {
  final String id;
  final String? clientId;
  final String? fieldId;
  final DateTime createdAt;

  ClientField({
    required this.id,
    this.clientId,
    this.fieldId,
    required this.createdAt,
  });

  factory ClientField.fromJson(Map<String, dynamic> json) {
    return ClientField(
      id: json['id'] as String,
      clientId: json['client_id'] as String?,
      fieldId: json['field_id'] as String?,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
