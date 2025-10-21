import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/supplier.dart';
import '../providers/supplier_account_statement_provider.dart';
import '../../domain/entities/supplier_account_statement.dart';

class SupplierAccountStatementScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierAccountStatementScreen({
    super.key,
    required this.supplier,
  });

  @override
  State<SupplierAccountStatementScreen> createState() => _SupplierAccountStatementScreenState();
}

class _SupplierAccountStatementScreenState extends State<SupplierAccountStatementScreen> {
  @override
  void initState() {
    super.initState();
    // Load the account statement when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierAccountStatementProvider>().loadAccountStatement();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب المورد: ${widget.supplier.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SupplierAccountStatementProvider>().refresh();
            },
          ),
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
        child: Consumer<SupplierAccountStatementProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'خطأ في تحميل البيانات',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(provider.error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.refresh(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Summary Card
                _buildSummaryCard(provider),

                // Transactions Table
                Expanded(
                  child: provider.statementEntries.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionsTable(provider.statementEntries),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(SupplierAccountStatementProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الرصيد الافتتاحي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${provider.openingBalance.toStringAsFixed(2)} ج.م',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: Colors.grey[300],
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الرصيد الختامي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${provider.closingBalance.toStringAsFixed(2)} ج.م',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'لا توجد معاملات لهذا المورد',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'لم يتم تسجيل أي مشتريات أو دفعات لهذا المورد حتى الآن',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(List<SupplierAccountStatement> entries) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildTransactionCard(entry);
      },
    );
  }

  Widget _buildTransactionCard(SupplierAccountStatement entry) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'ar');
    final isPurchase = entry.type == 'purchase';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isPurchase ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.description,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المرجع: ${entry.reference}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dateFormat.format(entry.date),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPurchase
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPurchase ? 'مشتريات' : 'دفعة',
                        style: TextStyle(
                          color: isPurchase ? Colors.orange : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Amounts Row
            Row(
              children: [
                if (isPurchase) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مدين',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${entry.debit.toStringAsFixed(2)} ج.م',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دائن',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${entry.credit.toStringAsFixed(2)} ج.م',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey[300],
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الرصيد',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${entry.balance.toStringAsFixed(2)} ج.م',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: entry.balance >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Notes (if available)
            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ملاحظات: ${entry.notes}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
