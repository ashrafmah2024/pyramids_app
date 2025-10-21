import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/client.dart';
import '../providers/client_account_statement_provider.dart';
import '../../domain/entities/client_account_statement.dart';

class ClientAccountStatementScreen extends StatefulWidget {
  final Client client;
  const ClientAccountStatementScreen({super.key, required this.client});

  @override
  State<ClientAccountStatementScreen> createState() => _ClientAccountStatementScreenState();
}

class _ClientAccountStatementScreenState extends State<ClientAccountStatementScreen> {
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'ar');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب العميل: ${widget.client.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ClientAccountStatementProvider>().refresh(),
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue[900]!.withOpacity(0.2)
                  : Colors.blue[50]!,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Consumer<ClientAccountStatementProvider>(
          builder: (context, prov, _) {
            if (prov.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (prov.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(prov.error!),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: prov.refresh, child: const Text('إعادة المحاولة')),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildSummaryCard(prov),
                Expanded(
                  child: prov.entries.isEmpty ? _buildEmptyState() : _buildList(prov.entries),
                )
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ClientAccountStatementProvider prov) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الرصيد الافتتاحي', style: Theme.of(context).textTheme.titleMedium),
              Text(
                prov.openingBalance.toStringAsFixed(2),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
          ),
          Container(width: 1, height: 40, color: Colors.grey[300]),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('الرصيد الختامي', style: Theme.of(context).textTheme.titleMedium),
              Text(
                prov.closingBalance.toStringAsFixed(2),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text('لا توجد معاملات لهذا العميل', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('لم يتم تسجيل أي عمليات أو دفعات لهذا العميل حتى الآن', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildList(List<ClientAccountStatementEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildEntry(entries[index]),
    );
  }

  Widget _buildEntry(ClientAccountStatementEntry e) {
    final isOperation = e.type == 'operation';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isOperation ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    e.description,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('المرجع: ${e.reference}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_dateFormat.format(e.date), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOperation ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isOperation ? 'عملية' : 'دفعة', style: TextStyle(color: isOperation ? Colors.orange : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ])
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (isOperation) ...[
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('مدين', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                    Text(e.debit.toStringAsFixed(2), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ] else ...[
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('دائن', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                    Text(e.credit.toStringAsFixed(2), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
              Container(width: 1, height: 30, color: Colors.grey[300]),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('الرصيد', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                  Text(
                    e.balance.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: e.balance >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
            ]),
            if (e.notes != null && e.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                child: Text('ملاحظات: ${e.notes}', style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
