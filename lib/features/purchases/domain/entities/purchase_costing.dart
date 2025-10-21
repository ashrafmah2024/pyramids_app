import 'package:equatable/equatable.dart';

class PurchaseCosting extends Equatable {
  final String id;
  final String purchaseId;
  
  // Direct costs
  final double directCostPerUnit;
  final double totalDirectCost;
  
  // Indirect costs
  final double indirectCostPerUnit;
  final double totalIndirectCost;
  
  // Total costs (calculated)
  final double totalCostPerUnit;
  final double totalCost;
  
  // Pricing
  final double markupPercentage;
  final double sellingPricePerUnit;
  
  // Timestamps
  final DateTime? lastCalculationDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PurchaseCosting({
    required this.id,
    required this.purchaseId,
    this.directCostPerUnit = 0.0,
    this.totalDirectCost = 0.0,
    this.indirectCostPerUnit = 0.0,
    this.totalIndirectCost = 0.0,
    required this.totalCostPerUnit,
    required this.totalCost,
    this.markupPercentage = 0.0,
    required this.sellingPricePerUnit,
    this.lastCalculationDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseCosting.fromJson(Map<String, dynamic> json) {
    return PurchaseCosting(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String,
      directCostPerUnit: (json['direct_cost_per_unit'] as num).toDouble(),
      totalDirectCost: (json['total_direct_cost'] as num).toDouble(),
      indirectCostPerUnit: (json['indirect_cost_per_unit'] as num).toDouble(),
      totalIndirectCost: (json['total_indirect_cost'] as num).toDouble(),
      totalCostPerUnit: (json['total_cost_per_unit'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      markupPercentage: (json['markup_percentage'] as num?)?.toDouble() ?? 0.0,
      sellingPricePerUnit: (json['selling_price_per_unit'] as num).toDouble(),
      lastCalculationDate: json['last_calculation_date'] != null 
          ? DateTime.parse(json['last_calculation_date'] as String).toLocal()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'direct_cost_per_unit': directCostPerUnit,
      'total_direct_cost': totalDirectCost,
      'indirect_cost_per_unit': indirectCostPerUnit,
      'total_indirect_cost': totalIndirectCost,
      'total_cost_per_unit': totalCostPerUnit,
      'total_cost': totalCost,
      'markup_percentage': markupPercentage,
      'selling_price_per_unit': sellingPricePerUnit,
      if (lastCalculationDate != null)
        'last_calculation_date': lastCalculationDate!.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        purchaseId,
        directCostPerUnit,
        totalDirectCost,
        indirectCostPerUnit,
        totalIndirectCost,
        totalCostPerUnit,
        totalCost,
        markupPercentage,
        sellingPricePerUnit,
        lastCalculationDate,
        createdAt,
        updatedAt,
      ];

  PurchaseCosting copyWith({
    double? directCostPerUnit,
    double? totalDirectCost,
    double? indirectCostPerUnit,
    double? totalIndirectCost,
    double? totalCostPerUnit,
    double? totalCost,
    double? markupPercentage,
    double? sellingPricePerUnit,
  }) {
    return PurchaseCosting(
      id: id,
      purchaseId: purchaseId,
      directCostPerUnit: directCostPerUnit ?? this.directCostPerUnit,
      totalDirectCost: totalDirectCost ?? this.totalDirectCost,
      indirectCostPerUnit: indirectCostPerUnit ?? this.indirectCostPerUnit,
      totalIndirectCost: totalIndirectCost ?? this.totalIndirectCost,
      totalCostPerUnit: totalCostPerUnit ?? this.totalCostPerUnit,
      totalCost: totalCost ?? this.totalCost,
      markupPercentage: markupPercentage ?? this.markupPercentage,
      sellingPricePerUnit: sellingPricePerUnit ?? this.sellingPricePerUnit,
      lastCalculationDate: DateTime.now(),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helper methods
  double get profitPerUnit => sellingPricePerUnit - totalCostPerUnit;
  double get totalProfit => profitPerUnit * (totalCost / totalCostPerUnit);
  double get profitMargin => totalCost > 0 ? (totalProfit / totalCost) * 100 : 0.0;
}
