import 'package:equatable/equatable.dart';

class PurchaseExpense extends Equatable {
  final String id;
  final String purchaseId;
  final String expenseType; // 'direct' or 'indirect'
  final String nameAr;
  final String? nameEn;
  final double amount;
  final String currency;
  final String? allocationRuleId;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseExpense({
    required this.id,
    required this.purchaseId,
    required this.expenseType,
    required this.nameAr,
    this.nameEn,
    required this.amount,
    this.currency = 'EGP',
    this.allocationRuleId,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseExpense.fromJson(Map<String, dynamic> json) {
    return PurchaseExpense(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      expenseType: json['expense_type'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EGP',
      allocationRuleId: json['allocation_rule_id'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'expense_type': expenseType,
      'name_ar': nameAr,
      if (nameEn != null) 'name_en': nameEn,
      'amount': amount,
      'currency': currency,
      if (allocationRuleId != null) 'allocation_rule_id': allocationRuleId,
      if (notes != null) 'notes': notes,
      if (createdBy != null) 'created_by': createdBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        purchaseId,
        expenseType,
        nameAr,
        nameEn,
        amount,
        currency,
        allocationRuleId,
        notes,
        createdBy,
        createdAt,
        updatedAt,
      ];

  bool get isDirect => expenseType == 'direct';
  bool get isIndirect => expenseType == 'indirect';

  PurchaseExpense copyWith({
    String? purchaseId,
    String? expenseType,
    String? nameAr,
    String? nameEn,
    double? amount,
    String? currency,
    String? allocationRuleId,
    String? notes,
  }) {
    return PurchaseExpense(
      id: id,
      purchaseId: purchaseId ?? this.purchaseId,
      expenseType: expenseType ?? this.expenseType,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      allocationRuleId: allocationRuleId ?? this.allocationRuleId,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
