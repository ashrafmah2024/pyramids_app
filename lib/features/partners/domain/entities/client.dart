 import 'business_field.dart';

 class Client {
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
  final List<BusinessField> businessFields;

  Client({
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
    this.businessFields = const [],
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    final fields = (json['business_fields'] as List?)
            ?.map((e) => BusinessField.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];

    return Client(
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
      businessFields: fields,
    );
  }

  Client copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<BusinessField>? businessFields,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      businessFields: businessFields ?? this.businessFields,
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
      'business_fields': businessFields.map((f) => {
            'id': f.id,
            'name_ar': f.nameAr,
            'name_en': f.nameEn,
            'description': f.description,
            'is_active': f.isActive,
            'created_at': f.createdAt.toIso8601String(),
          }).toList(),
    }..removeWhere((k, v) => v == null);
  }
}
