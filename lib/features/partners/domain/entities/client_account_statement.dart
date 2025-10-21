import 'package:flutter/foundation.dart';

class ClientAccountStatementEntry {
  final String id;
  final String clientId;
  final DateTime date;
  final String type; // 'operation' or 'payment'
  final String reference;
  final String description;
  final double debit; // Amount increases client balance (we bill the client)
  final double credit; // Amount decreases client balance (client pays us)
  final double balance; // Running balance after this transaction
  final String? notes;

  const ClientAccountStatementEntry({
    required this.id,
    required this.clientId,
    required this.date,
    required this.type,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
    this.notes,
  });

  ClientAccountStatementEntry copyWith({
    double? balance,
  }) {
    return ClientAccountStatementEntry(
      id: id,
      clientId: clientId,
      date: date,
      type: type,
      reference: reference,
      description: description,
      debit: debit,
      credit: credit,
      balance: balance ?? this.balance,
      notes: notes,
    );
  }

  static double _parseAmount(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory ClientAccountStatementEntry.fromTransaction(Map<String, dynamic> row, {double runningBalance = 0.0}) {
    final id = row['id'] as String;
    final clientId = row['client_id'] as String;
    final direction = (row['direction'] as String?)?.toLowerCase();
    final amount = _parseAmount(row['amount']);
    final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
    final opId = row['operation_id'] as String?;
    final notes = row['notes'] as String?;

    // Map direction to type
    // operation types: debit / out / null
    // payment types: credit / in
    final isOperation = direction == null || direction == 'debit' || direction == 'out';
    final type = isOperation ? 'operation' : 'payment';

    return ClientAccountStatementEntry(
      id: id,
      clientId: clientId,
      date: createdAt,
      type: type,
      reference: opId ?? '-',
      description: isOperation ? 'عملية على العميل' : 'دفعة من العميل',
      debit: isOperation ? amount : 0.0,
      credit: isOperation ? 0.0 : amount,
      balance: runningBalance,
      notes: notes,
    );
  }
}
