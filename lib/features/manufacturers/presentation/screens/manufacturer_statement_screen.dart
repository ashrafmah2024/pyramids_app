import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ManufacturerStatementScreen extends StatefulWidget {
  final String manufacturerId;
  const ManufacturerStatementScreen({super.key, required this.manufacturerId});

  @override
  State<ManufacturerStatementScreen> createState() => _ManufacturerStatementScreenState();
}

class _ManufacturerStatementScreenState extends State<ManufacturerStatementScreen> {
  bool _loading = false;
  Map<String, dynamic>? _manufacturer;
  List<Map<String, dynamic>> _rows = [];
  Map<String, String> _opCodes = {}; // operation_id -> operation_code
  Map<String, String> _opNames = {}; // operation_id -> description/name

  String _onlyDate(String s) {
    try {
      final dt = DateTime.tryParse(s);
      if (dt == null) return s;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return s;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final m = await client
          .from('manufacturers')
          .select('id,name,balance')
          .eq('id', widget.manufacturerId)
          .maybeSingle();
      if (m != null) _manufacturer = Map<String, dynamic>.from(m as Map<String, dynamic>);

      final tx = await client
          .from('manufacturer_transactions')
          .select('id,created_at,amount,direction,notes,operation_id,stage_id,currency')
          .eq('manufacturer_id', widget.manufacturerId)
          .order('created_at');
      _rows = (tx as List).cast<Map<String, dynamic>>();

      // Load operation codes for distinct operation_ids
      final ids = _rows
          .map((e) => (e['operation_id'] as String?))
          .whereType<String>()
          .toSet()
          .toList();
      _opCodes.clear();
      if (ids.isNotEmpty) {
        try {
          final ops = await client
              .from('operations')
              .select('id, operation_code, description')
              .inFilter('id', ids);
          for (final r in (ops as List)) {
            final m = r as Map<String, dynamic>;
            final id = m['id']?.toString();
            final code = m['operation_code']?.toString();
            final name = m['description']?.toString();
            if (id != null) {
              if (code != null && code.isNotEmpty) {
                _opCodes[id] = code;
              }
              if (name != null && name.isNotEmpty) {
                _opNames[id] = name;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_manufacturer?['name']?.toString() ?? 'المصنع');
    final balance = ((_manufacturer?['balance'] as num?) ?? 0).toString();

    num running = 0;
    // We'll compute running balance locally. Convention: credit increases balance, debit decreases
    List<Map<String, dynamic>> computed = _rows.map((e) {
      final dir = (e['direction']?.toString() ?? '');
      final amtDyn = e['amount'];
      num amt = 0;
      if (amtDyn is num) amt = amtDyn; else if (amtDyn is String) { final p = num.tryParse(amtDyn); if (p != null) amt = p; }
      if (dir == 'credit') running += amt; else if (dir == 'debit') running -= amt;
      return {...e, 'running': running};
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('كشف حساب: $name'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/manufacturers/${widget.manufacturerId}/payments');
        },
        icon: const Icon(Icons.payment),
        label: const Text('دفع'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الرصيد الحالي: $balance'),
                      Text('عدد الحركات: ${_rows.length}'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: computed.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = computed[i];
                      final dir = (r['direction']?.toString() ?? '');
                      final amt = (r['amount']?.toString() ?? '0');
                      final notes = (r['notes']?.toString() ?? '');
                      final createdAt = (r['created_at']?.toString() ?? '');
                      final run = (r['running'] as num?)?.toStringAsFixed(2) ?? '';
                      final opId = r['operation_id'] as String?;
                      final opCode = opId != null ? _opCodes[opId] : null;
                      final opName = opId != null ? _opNames[opId] : null;
                      return ListTile(
                        leading: Icon(dir == 'credit' ? Icons.add : Icons.remove, color: dir == 'credit' ? Colors.green : Colors.red),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${dir == 'credit' ? 'دائن' : 'مدين'}: $amt'),
                            Text('بعد الحركة: $run'),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (opCode != null && opCode.isNotEmpty) Text('كود العملية: $opCode'),
                            if (opName != null && opName.isNotEmpty) Text('اسم العملية: $opName'),
                            if (notes.isNotEmpty) Text(notes),
                            Text(_onlyDate(createdAt)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
