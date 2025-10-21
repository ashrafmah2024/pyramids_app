import 'package:flutter/material.dart';
import 'package:pyramids/features/manufacturing/presentation/screens/operation_stages_screen.dart';

class OperationDetailsScreen extends StatelessWidget {
  final String operationId;
  const OperationDetailsScreen({super.key, required this.operationId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل العملية'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'نظرة عامة', icon: Icon(Icons.info_outline)),
              Tab(text: 'المراحل', icon: Icon(Icons.stacked_bar_chart)),
              Tab(text: 'التكلفة والأرباح', icon: Icon(Icons.attach_money)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OperationSummary(operationId: operationId),
            OperationStagesScreen(operationId: operationId),
            _OperationFinancials(operationId: operationId),
          ],
        ),
      ),
    );
  }
}

class _OperationSummary extends StatelessWidget {
  final String operationId;
  const _OperationSummary({required this.operationId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'نظرة عامة عن العملية',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'المعرف: $operationId',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text('سيتم عرض تفاصيل وصف العملية والعميل والحالة هنا.'),
          ],
        ),
      ),
    );
  }
}

class _OperationFinancials extends StatelessWidget {
  final String operationId;
  const _OperationFinancials({required this.operationId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.ssid_chart, size: 48),
            const SizedBox(height: 12),
            Text(
              'ملخص التكاليف والأرباح',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'المعرف: $operationId',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const Text('سيتم عرض تكاليف المواد، التصنيع، المصروفات، والإيرادات وصافي الربح هنا.'),
          ],
        ),
      ),
    );
  }
}
