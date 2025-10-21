import 'package:equatable/equatable.dart';

class ExpenseAllocationRule extends Equatable {
  final String id;
  final String nameAr;
  final String? nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String allocationType; // 'quantity', 'value', 'weight', 'custom'
  final bool isActive;
  final String? createdBy;
  final double? customRatio; // 0-100
  final double totalAllocatedAmount;
  final int allocationCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpenseAllocationRule({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.allocationType,
    this.isActive = true,
    this.createdBy,
    this.customRatio,
    this.totalAllocatedAmount = 0.0,
    this.allocationCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseAllocationRule.fromJson(Map<String, dynamic> json) {
    return ExpenseAllocationRule(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String?,
      descriptionAr: json['description_ar'] as String?,
      descriptionEn: json['description_en'] as String?,
      allocationType: json['allocation_type'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      customRatio: (json['custom_ratio'] as num?)?.toDouble(),
      totalAllocatedAmount: (json['total_allocated_amount'] as num?)?.toDouble() ?? 0.0,
      allocationCount: (json['allocation_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      if (nameEn != null) 'name_en': nameEn,
      if (descriptionAr != null) 'description_ar': descriptionAr,
      if (descriptionEn != null) 'description_en': descriptionEn,
      'allocation_type': allocationType,
      'is_active': isActive,
      if (createdBy != null) 'created_by': createdBy,
      if (customRatio != null) 'custom_ratio': customRatio,
      'total_allocated_amount': totalAllocatedAmount,
      'allocation_count': allocationCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        nameAr,
        nameEn,
        descriptionAr,
        descriptionEn,
        allocationType,
        isActive,
        createdBy,
        customRatio,
        totalAllocatedAmount,
        allocationCount,
        createdAt,
        updatedAt,
      ];

  ExpenseAllocationRule copyWith({
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? descriptionEn,
    String? allocationType,
    bool? isActive,
    double? customRatio,
    double? totalAllocatedAmount,
    int? allocationCount,
  }) {
    return ExpenseAllocationRule(
      id: id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      allocationType: allocationType ?? this.allocationType,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy,
      customRatio: customRatio ?? this.customRatio,
      totalAllocatedAmount: totalAllocatedAmount ?? this.totalAllocatedAmount,
      allocationCount: allocationCount ?? this.allocationCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
