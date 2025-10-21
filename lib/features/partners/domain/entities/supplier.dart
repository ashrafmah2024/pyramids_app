class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? notes;
  final bool isActive;
  final num balance;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
    required this.isActive,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      taxNumber: json['tax_number'] as String?,
      notes: json['notes'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      balance: (json['balance'] ?? 0) as num,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'notes': notes,
      'is_active': isActive,
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    }..removeWhere((k, v) => v == null);
  }
}
