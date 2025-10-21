class Manufacturer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double balance;
  final String? type;
  final String? taxNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;

  Manufacturer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.balance,
    this.type,
    this.taxNumber,
    this.createdAt,
    this.updatedAt,
    this.updatedBy,
  });

  factory Manufacturer.fromMap(Map<String, dynamic> json) {
    return Manufacturer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      balance: (json['balance'] is int)
          ? (json['balance'] as int).toDouble()
          : (json['balance'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String?,
      taxNumber: json['tax_number'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        'balance': balance,
        if (type != null) 'type': type,
        if (taxNumber != null) 'tax_number': taxNumber,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}

class ManufacturerInput {
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double balance;
  final String? type;
  final String? taxNumber;

  ManufacturerInput({
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.balance = 0.0,
    this.type,
    this.taxNumber,
  });

  Map<String, dynamic> toMap({String? updatedBy}) => {
        'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        'balance': balance,
        if (type != null) 'type': type,
        if (taxNumber != null) 'tax_number': taxNumber,
        if (updatedBy != null) 'updated_by': updatedBy,
      };
}
