class BusinessField {
  final String id;
  final String nameAr;
  final String? nameEn;
  final String? description;
  final bool isActive;
  final DateTime createdAt;

  BusinessField({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.description,
    required this.isActive,
    required this.createdAt,
  });

  factory BusinessField.fromJson(Map<String, dynamic> json) {
    return BusinessField(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String?,
      description: json['description'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at']).toLocal(),
    );
  }
}
