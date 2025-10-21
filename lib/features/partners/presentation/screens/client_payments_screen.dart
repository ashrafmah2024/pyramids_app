import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/client.dart';
import 'add_client_payment_screen.dart';

class ClientPaymentItem {
  final String id;
  final String clientId;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final String? reference;
  final String? notes;

  ClientPaymentItem({
    required this.id,
    required this.clientId,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.reference,
    this.notes,
  });

  static double _parseAmount(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory ClientPaymentItem.fromRow(Map<String, dynamic> row) {
    return ClientPaymentItem(
      id: row['id'] as String,
      clientId: row['client_id'] as String,
      amount: _parseAmount(row['amount']),
      currency: (row['currency'] as String?) ?? 'EGP',
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      reference: row['operation_id'] as String?,
      notes: row['notes'] as String?,
    );
  }
}

class ClientPaymentsScreen extends StatefulWidget {
  final Client client;
  const ClientPaymentsScreen({super.key, required this.client});

  @override
  State<ClientPaymentsScreen> createState() => _ClientPaymentsScreenState();
}

class _ClientPaymentsScreenState extends State<ClientPaymentsScreen> {
  Future<List<ClientPaymentItem>> _fetchClientPayments() async {
    final client = Supabase.instance.client;
    final resp = await client
        .from('client_transactions')
        .select('id, client_id, operation_id, amount, currency, created_at, notes, direction')
        .eq('client_id', widget.client.id)
        .inFilter('direction', ['credit', 'in'])
        .order('created_at', ascending: false);

    final list = (resp as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(ClientPaymentItem.fromRow).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('دفعات العميل: ${widget.client.name}')
      ),
      body: FutureBuilder<List<ClientPaymentItem>>(
        future: _fetchClientPayments(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('فشل تحميل الدفعات: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد دفعات مسجلة لهذا العميل'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _PaymentTile(item: items[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => AddClientPaymentScreen(client: widget.client),
            ),
          );
          if (added == true && mounted) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إضافة دفعة'),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final ClientPaymentItem item;
  const _PaymentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(Icons.payment, color: Theme.of(context).colorScheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.amount.toStringAsFixed(2)} ${item.currency}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      if ((item.reference ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.reference!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التاريخ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(item.createdAt.toString().split(' ').first, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            if ((item.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('ملاحظات', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(item.notes!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
