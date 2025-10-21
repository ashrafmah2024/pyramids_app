import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/core/navigation/app_router.dart';

class OperationStagesScreen extends StatefulWidget {
  final String operationId;
  final bool readOnly;
  const OperationStagesScreen({super.key, required this.operationId, this.readOnly = false});

  @override
  State<OperationStagesScreen> createState() => _OperationStagesScreenState();
}

class _OperationStagesScreenState extends State<OperationStagesScreen> {
  // Helper method to build compact info chips
  Widget _buildInfoChip(BuildContext context, String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      margin: const EdgeInsets.only(left: 2, right: 2),
      constraints: const BoxConstraints(minWidth: 40),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, height: 1.1),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  num _totalExpense = 0;
  num _totalWaste = 0;
  bool _isClosed = false;
  String? _opType; // commercial or manufacturing
  // Finance fields from operations
  num _indirectExpense = 0;
  num _agreementUnitPrice = 0; // سعر الوحدة المتفق عليه
  num _wasteUnitCostPurchase = 0; // سعر شراء الفرخ
  // Removed operation-level purchases summary: purchases will be recorded per stage
  final _indirectCtrl = TextEditingController();
  final _wasteUnitCostCtrl = TextEditingController();
  // Manufacturers cache
  bool _loadingManufacturers = false;
  List<Map<String, dynamic>> _manufacturers = [];

  @override
  void dispose() {
    _indirectCtrl.dispose();
    _wasteUnitCostCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManufacturers() async {
    setState(() => _loadingManufacturers = true);
    try {
      final data = await Supabase.instance.client
          .from('manufacturers')
          .select('id,name')
          .order('name')
          .limit(200);
      final list = (data as List).cast<Map<String, dynamic>>()
          .where((e) => e['id'] != null && e['name'] != null)
          .toList();
      if (mounted) setState(() => _manufacturers = list);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingManufacturers = false);
    }
  }

  Future<void> _assignManufacturerToStage({
    required String stageId,
    required String? manufacturerId,
  }) async {
    try {
      await Supabase.instance.client
          .from('operation_stages')
          .update({'manufacturer_id': manufacturerId})
          .eq('operation_id', widget.operationId)
          .eq('stage_id', stageId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ المصنع للمرحلة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ المصنع: $e')),
        );
      }
    }
  }

  Future<void> _recomputeWasteForStage({
    required String stageId,
    required int orderNo,
    required String stageName,
  }) async {
    // Skip auto waste for commercial operations
    final t = (_opType ?? '').toLowerCase();
    final isCommercial = t == 'commercial' || t.contains('commerc') || t.contains('تجار');
    if (isCommercial) return;
    final n = (stageName).toString();
    if (n.contains('تسليم')) return;
    num totalReceive = 0;
    num totalDeliver = 0;
    try {
      final recRows = await Supabase.instance.client
          .from('operation_stage_logs')
          .select('qty')
          .eq('operation_id', widget.operationId)
          .eq('stage_id', stageId)
          .eq('log_type', 'receive');
      for (final r in (recRows as List)) {
        final v = (r as Map)['qty'];
        if (v is num) totalReceive += v;
        if (v is String) {
          final p = num.tryParse(v);
          if (p != null) totalReceive += p;
        }
      }
    } catch (_) {}
    try {
      final delRows = await Supabase.instance.client
          .from('operation_stage_logs')
          .select('qty')
          .eq('operation_id', widget.operationId)
          .eq('stage_id', stageId)
          .eq('log_type', 'deliver');
      for (final r in (delRows as List)) {
        final v = (r as Map)['qty'];
        if (v is num) totalDeliver += v;
        if (v is String) {
          final p = num.tryParse(v);
          if (p != null) totalDeliver += p;
        }
      }
    } catch (_) {}
    final waste = totalReceive - totalDeliver;
    final w = waste > 0 ? waste : 0;
    try {
      await Supabase.instance.client
          .from('operation_stage_logs')
          .delete()
          .eq('operation_id', widget.operationId)
          .eq('stage_id', stageId)
          .eq('log_type', 'waste');
      if (w > 0) {
        await Supabase.instance.client.from('operation_stage_logs').insert({
          'operation_id': widget.operationId,
          'stage_id': stageId,
          'order_no': orderNo,
          'log_type': 'waste',
          'qty': w,
          'note': 'حساب تلقائي للهالك',
        });
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _fetchOperation() async {
    try {
      final op = await Supabase.instance.client
          .from('operations')
          .select(
            'id, client_id, type, agreement_unit_price, is_closed, indirect_expense',
          )
          .eq('id', widget.operationId)
          .maybeSingle();
      return (op as Map<String, dynamic>?);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveFinance() async {
    if (_isClosed) return;
    setState(() => _loading = true);
    try {
      _indirectExpense =
          num.tryParse(_indirectCtrl.text.replaceAll(',', '.')) ??
          _indirectExpense;

      await Supabase.instance.client
          .from('operations')
          .update({
            'indirect_expense': _indirectExpense,
          })
          .eq('id', widget.operationId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ الملخص')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ الملخص: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _finishOperation(Map<String, dynamic> lastStageRow) async {
    final op = await _fetchOperation();
    if (op == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة بيانات العملية')),
        );
      }
      return;
    }
    if ((op['is_closed'] as bool?) == true || _isClosed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذه العملية مغلقة بالفعل')),
        );
      }
      return;
    }
    final unitPrice = (op['agreement_unit_price'] as num?) ?? 0;
    final deliverQty = (lastStageRow['total_deliver'] as num?) ?? 0;
    final baseTotal = unitPrice * deliverQty;

    // Collect invoice, currency, tax%, discount
    final invoiceCtrl = TextEditingController();
    final currencyCtrl = TextEditingController(text: 'EGP');
    final taxCtrl = TextEditingController(text: '0');
    final discountCtrl = TextEditingController(text: '0');
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('بيانات الفاتورة والضرائب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الأساس: $baseTotal = $deliverQty × $unitPrice'),
            const SizedBox(height: 8),
            TextField(
              controller: invoiceCtrl,
              decoration: const InputDecoration(
                labelText: 'رقم اذن التسليم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: currencyCtrl,
              decoration: const InputDecoration(
                labelText: 'العملة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'خصم (قيمة)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: taxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ضريبة %',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء العملية'),
        content: const Text('هل أنت متأكد من إنهاء العملية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.rpc('finish_operation', params: {
        'p_operation_id': widget.operationId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنهاء العملية بنجاح')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadManufacturers();
  }

  Future<void> _startStage(Map<String, dynamic> r) async {
    final stageId = r['stage_id'] as String;
    final alreadyStarted = r['started_at'] != null;
    try {
      // إزالة الحالية عن أي مرحلة أخرى
      await Supabase.instance.client
          .from('operation_stages')
          .update({'is_current': false})
          .eq('operation_id', widget.operationId);
      // تعيين الحالية وتحديد started_at إذا كانت null
      final updateMap = <String, dynamic>{'is_current': true};
      if (!alreadyStarted) {
        updateMap['started_at'] = DateTime.now().toIso8601String();
      }
      await Supabase.instance.client
          .from('operation_stages')
          .update(updateMap)
          .eq('operation_id', widget.operationId)
          .eq('stage_id', stageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم بدء المرحلة: ${r['stage_name']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر البدء: $e')));
      }
    }
    await _load();
  }

  Future<void> _finishStage(Map<String, dynamic> r) async {
    final stageId = r['stage_id'] as String;
    final orderNo = r['order_no'] as int;
    try {
      // Finish current stage
      await Supabase.instance.client
          .from('operation_stages')
          .update({
            'finished_at': DateTime.now().toIso8601String(),
            'is_current': false,
          })
          .eq('operation_id', widget.operationId)
          .eq('stage_id', stageId);
      // Pick next unfinished stage
      final nextRows = await Supabase.instance.client
          .from('operation_stages')
          .select('stage_id')
          .eq('operation_id', widget.operationId)
          .isFilter('finished_at', null)
          .gt('order_no', orderNo)
          .order('order_no')
          .limit(1);
      final nextList = (nextRows as List).cast<Map<String, dynamic>>();
      if (nextList.isNotEmpty) {
        final nextId = nextList.first['stage_id'] as String;
        await Supabase.instance.client
            .from('operation_stages')
            .update({
              'is_current': true,
              'started_at': DateTime.now().toIso8601String(),
            })
            .eq('operation_id', widget.operationId)
            .eq('stage_id', nextId);
      }
      // After finishing the stage, create manufacturer payable if a manufacturer is assigned.
      try {
        // 1) Find assigned manufacturer for this stage
        final manRow = await Supabase.instance.client
            .from('operation_stages')
            .select('manufacturer_id')
            .eq('operation_id', widget.operationId)
            .eq('stage_id', stageId)
            .maybeSingle();
        final manufacturerId = (manRow is Map<String, dynamic>)
            ? (manRow['manufacturer_id'] as String?)
            : null;

        if (manufacturerId != null && manufacturerId.isNotEmpty) {
          // 2) Sum expenses for this stage
          num totalExpense = 0;
          try {
            final expRows = await Supabase.instance.client
                .from('operation_stage_logs')
                .select('amount')
                .eq('operation_id', widget.operationId)
                .eq('stage_id', stageId)
                .eq('log_type', 'expense');
            for (final row in (expRows as List)) {
              final m = row as Map<String, dynamic>;
              final v = m['amount'];
              if (v is num) totalExpense += v;
              if (v is String) {
                final p = num.tryParse(v);
                if (p != null) totalExpense += p;
              }
            }
          } catch (_) {}

          if (totalExpense > 0) {
            // 3) Insert manufacturer transaction as credit (payable)
            await Supabase.instance.client.from('manufacturer_transactions').insert({
              'manufacturer_id': manufacturerId,
              'operation_id': widget.operationId,
              'stage_id': stageId,
              'amount': totalExpense,
              'direction': 'credit',
              'currency': 'EGP',
              'notes': 'مصروف مرحلة: ' + ((r['stage_name']?.toString() ?? '')),
            });
            // 4) Update manufacturer balance (+ amount)
            try {
              final cb = await Supabase.instance.client
                  .from('manufacturers')
                  .select('balance')
                  .eq('id', manufacturerId)
                  .maybeSingle();
              final currentBal =
                  ((cb as Map<String, dynamic>?)?['balance'] as num?) ?? 0;
              final newBal = currentBal + totalExpense;
              await Supabase.instance.client
                  .from('manufacturers')
                  .update({'balance': newBal})
                  .eq('id', manufacturerId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم إنشاء مستحق للمصنع بقيمة: $totalExpense')),
                );
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {}
    await _load();
  }

  @override
  void didUpdateWidget(covariant OperationStagesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationId != widget.operationId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch closed state
      try {
        final op = await Supabase.instance.client
            .from('operations')
            .select(
              'type, is_closed, indirect_expense, agreement_unit_price',
            )
            .eq('id', widget.operationId)
            .maybeSingle();
        if (mounted && op != null) {
          final m = (op as Map<String, dynamic>);
          _opType = (m['type']?.toString() ?? '').toLowerCase();
          _isClosed = (m['is_closed'] as bool?) ?? false;
          _indirectExpense = (m['indirect_expense'] as num?) ?? 0;
          _agreementUnitPrice = (m['agreement_unit_price'] as num?) ?? 0;
          _indirectCtrl.text = _indirectExpense.toString();
          setState(() {});
        }
      } catch (_) {}

      var stages = await Supabase.instance.client
          .from('operation_stages')
          .select('stage_id, order_no, started_at, finished_at, is_current, manufacturer_id')
          .eq('operation_id', widget.operationId)
          .order('order_no', ascending: true);
      var list = (stages as List).cast<Map<String, dynamic>>();

      // If commercial operation (or inferred commercial by purchases): ensure a stage named "شراء من مورد" is present for this operation
      var isCommercial = () {
        final t = (_opType ?? '').toLowerCase();
        return t == 'commercial' || t.contains('commerc') || t.contains('تجار');
      }();
      if (!isCommercial) {
        try {
          final pc = await Supabase.instance.client
              .from('purchases')
              .select('id')
              .eq('operation_id', widget.operationId)
              .limit(1);
          // If any row returned, infer commercial.
          final listAny = (pc as List?) ?? const [];
          if (listAny.isNotEmpty) {
            isCommercial = true;
          }
        } catch (_) {}
      }
      if (isCommercial) {
        try {
          // 1) Ensure stage exists in manufacturing_stages
          final name = 'شراء من مورد';
          String stageId;
          final existing = await Supabase.instance.client
              .from('manufacturing_stages')
              .select('id')
              .eq('stage_name', name)
              .limit(1);
          if (existing is List && existing.isNotEmpty) {
            stageId = (existing.first as Map<String, dynamic>)['id'] as String;
          } else {
            final inserted = await Supabase.instance.client
                .from('manufacturing_stages')
                .insert({'stage_name': name})
                .select('id');
            stageId = (inserted.first as Map<String, dynamic>)['id'] as String;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إنشاء مرحلة "شراء من مورد"')),
              );
            }
          }

          // 2) Ensure an operation_stages row exists for this operation & stage_id
          final hasStage = await Supabase.instance.client
              .from('operation_stages')
              .select('stage_id')
              .eq('operation_id', widget.operationId)
              .eq('stage_id', stageId)
              .limit(1);
          final hasStageList = (hasStage as List?) ?? const [];
          if (hasStageList.isEmpty) {
            // Pick next order_no
            int nextOrder = 1;
            if (list.isNotEmpty) {
              final maxOrder = list.map((e) => (e['order_no'] as int?) ?? 0).fold<int>(0, (a, b) => b > a ? b : a);
              nextOrder = (maxOrder <= 0) ? 1 : (maxOrder + 1);
            }
            await Supabase.instance.client.from('operation_stages').insert({
              'operation_id': widget.operationId,
              'stage_id': stageId,
              'name': name,
              'order_no': nextOrder,
              'is_current': false,
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم ربط مرحلة "شراء من مورد" بالعملية')),
              );
            }
          } else {
            if (mounted) {
              // Already present
              // Avoid spamming: only show when user expects creation
              // Keeping a subtle hint
              // Note: No extra action
            }
          }

          // Reload list
          stages = await Supabase.instance.client
              .from('operation_stages')
              .select('stage_id, order_no, started_at, finished_at, is_current')
              .eq('operation_id', widget.operationId)
              .order('order_no', ascending: true);
          list = (stages as List).cast<Map<String, dynamic>>();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تعذر إضافة مرحلة الشراء: $e')),
            );
          }
        }
      }

      final ids = list.map((e) => e['stage_id'] as String).toList();
      Map<String, String> names = {};
      if (ids.isNotEmpty) {
        final namesRows = await Supabase.instance.client
            .from('manufacturing_stages')
            .select('id, stage_name')
            .inFilter('id', ids);
        for (final r in (namesRows as List)) {
          names[(r as Map)['id'] as String] = (r)['stage_name'] as String;
        }
      }

      final merged = list
          .map(
            (e) => {
              'stage_id': e['stage_id'],
              'order_no': e['order_no'],
              'stage_name': names[e['stage_id']] ?? e['stage_id'],
              'started_at': e['started_at'],
              'finished_at': e['finished_at'],
              'is_current': (e['is_current'] as bool?) ?? false,
              'manufacturer_id': e['manufacturer_id'],
            },
          )
          .toList();

      // Aggregate logs via RPC get_stage_logs_agg(op uuid)
      try {
        final agg = await Supabase.instance.client.rpc(
          'get_stage_logs_agg',
          params: {'op': widget.operationId},
        );
        final aggList = (agg as List?)?.cast<Map<String, dynamic>>() ?? [];
        final Map<String, Map<String, num>> aggByStage = {};
        num totalExpense = 0;
        num totalWaste = 0;
        bool rpcHasExpense = false;
        for (final a in aggList) {
          final sid = a['stage_id'] as String;
          aggByStage[sid] = {
            'receive': (a['total_receive'] ?? 0) as num,
            'deliver': (a['total_deliver'] ?? 0) as num,
            'waste': (a['total_waste'] ?? 0) as num,
            'expense': (a['total_expense'] ?? 0) as num,
          };
          final e = ((a['total_expense'] ?? 0) as num);
          if (e != 0) rpcHasExpense = true;
          totalExpense += e;
          totalWaste += ((a['total_waste'] ?? 0) as num);
        }
        // Fallback: explicitly sum expense logs ONLY if RPC lacks expense totals
        if (!rpcHasExpense) {
          try {
            final expRows = await Supabase.instance.client
                .from('operation_stage_logs')
                .select('stage_id, amount')
                .eq('operation_id', widget.operationId)
                .eq('log_type', 'expense');
            final expList = (expRows as List?)?.cast<Map<String, dynamic>>() ?? [];
            final Map<String, num> expByStage = {};
            num expTotal = 0;
            for (final r in expList) {
              final sid = (r['stage_id'] as String?) ?? '';
              if (sid.isEmpty) continue;
              final amtDyn = r['amount'];
              num amt = 0;
              if (amtDyn is num) {
                amt = amtDyn;
              } else if (amtDyn is String) {
                final p = num.tryParse(amtDyn);
                if (p != null) amt = p;
              }
              expByStage[sid] = (expByStage[sid] ?? 0) + amt;
              expTotal += amt;
            }
            // Merge into aggByStage (set expense if not provided by RPC)
            expByStage.forEach((sid, amt) {
              final prev = aggByStage[sid] ?? const {'receive': 0, 'deliver': 0, 'waste': 0, 'expense': 0};
              aggByStage[sid] = {
                'receive': prev['receive'] ?? 0,
                'deliver': prev['deliver'] ?? 0,
                'waste': prev['waste'] ?? 0,
                'expense': (prev['expense'] ?? 0) == 0 ? amt : (prev['expense'] ?? 0),
              };
            });
            totalExpense = expTotal;
          } catch (_) {}
        }
        for (var i = 0; i < merged.length; i++) {
          final sid = merged[i]['stage_id'] as String;
          final s =
              aggByStage[sid] ??
              const {'receive': 0, 'deliver': 0, 'waste': 0, 'expense': 0};
          merged[i] = {
            ...merged[i],
            'total_receive': s['receive'],
            'total_deliver': s['deliver'],
            'total_waste': s['waste'],
            'total_expense': s['expense'],
          };
        }
        _totalExpense = totalExpense;
        _totalWaste = totalWaste;
      } catch (_) {}

      // Auto-calc: waste unit purchase price = (expense of 'شراء الورق' stage) / (deliver of that stage)
      // Only for manufacturing operations
      try {
        final isCommercial = (() {
          final t = (_opType ?? '').toLowerCase();
          return t == 'commercial' || t.contains('commerc') || t.contains('تجار');
        })();
        if (isCommercial) {
          _wasteUnitCostPurchase = 0;
          _wasteUnitCostCtrl.text = '';
        } else {
        num computedUnit = 0;
        Map<String, dynamic>? paperStage;
        // Prefer exact match
        paperStage = merged.firstWhere(
          (e) => (e['stage_name']?.toString() ?? '').trim() == 'شراء الورق',
          orElse: () => {},
        );
        if (paperStage.isEmpty) {
          // Fallback: contains both words
          paperStage = merged.firstWhere(
            (e) {
              final n = (e['stage_name']?.toString() ?? '');
              return n.contains('شراء') && n.contains('ورق');
            },
            orElse: () => {},
          );
        }
        if (paperStage.isEmpty) {
          // As a final fallback, use a generic purchase stage if exists
          paperStage = merged.firstWhere(
            (e) => (e['stage_name']?.toString() ?? '').contains('شراء'),
            orElse: () => {},
          );
        }
        if (paperStage.isNotEmpty) {
          final exp = (paperStage['total_expense'] as num?) ?? 0;
          final del = (paperStage['total_deliver'] as num?) ?? 0;
          if (del != 0) {
            computedUnit = exp / del;
          }
        }
        _wasteUnitCostPurchase = computedUnit;
        _wasteUnitCostCtrl.text = _wasteUnitCostPurchase.toString();
        }
      } catch (_) {}

      setState(() => _rows = merged);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل مراحل العملية')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addQuantityLog({
    required String logType,
    required Map<String, dynamic> r,
  }) async {
    final ctrlQty = TextEditingController();
    final ctrlNote = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            logType == 'receive'
                ? 'إضافة استلام'
                : logType == 'deliver'
                ? 'إضافة تسليم'
                : 'إضافة هالك',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlQty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrlNote,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final qty = double.tryParse(ctrlQty.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الكمية غير صالحة')));
      return;
    }
    try {
      await Supabase.instance.client.from('operation_stage_logs').insert({
        'operation_id': widget.operationId,
        'stage_id': r['stage_id'],
        'order_no': r['order_no'],
        'log_type': logType,
        'qty': qty,
        'note': ctrlNote.text.trim().isEmpty ? null : ctrlNote.text.trim(),
      });
      // Recompute waste for current stage after any change (manufacturing only)
      await _recomputeWasteForStage(
        stageId: r['stage_id'] as String,
        orderNo: r['order_no'] as int,
        stageName: (r['stage_name']?.toString() ?? ''),
      );
      // إذا كان تسليم، أضف استلام للمرحلة التالية بنفس الكمية تلقائياً
      if (logType == 'deliver') {
        final nextRows = await Supabase.instance.client
            .from('operation_stages')
            .select('stage_id, order_no')
            .eq('operation_id', widget.operationId)
            .gt('order_no', r['order_no'] as int)
            .order('order_no', ascending: true)
            .limit(1);
        final list = (nextRows as List).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          final next = list.first;
          await Supabase.instance.client.from('operation_stage_logs').insert({
            'operation_id': widget.operationId,
            'stage_id': next['stage_id'],
            'order_no': next['order_no'],
            'log_type': 'receive',
            'qty': qty,
            'note': 'استلام تلقائي من تسليم المرحلة السابقة',
          });
          // Recompute waste for next stage after auto receive (manufacturing only)
          try {
            final nameRows = await Supabase.instance.client
                .from('manufacturing_stages')
                .select('stage_name')
                .eq('id', next['stage_id'] as String)
                .limit(1);
            final stageName = (nameRows is List && nameRows.isNotEmpty)
                ? ((nameRows.first as Map<String, dynamic>)['stage_name']?.toString() ?? '')
                : '';
            await _recomputeWasteForStage(
              stageId: next['stage_id'] as String,
              orderNo: next['order_no'] as int,
              stageName: stageName,
            );
          } catch (_) {}
        }
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }

  Future<void> _addExpenseLog(Map<String, dynamic> r) async {
    final ctrlAmount = TextEditingController();
    final ctrlNote = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إضافة مصروف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlAmount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrlNote,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final amount = double.tryParse(ctrlAmount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('المبلغ غير صالح')));
      return;
    }
    try {
      await Supabase.instance.client.from('operation_stage_logs').insert({
        'operation_id': widget.operationId,
        'stage_id': r['stage_id'],
        'order_no': r['order_no'],
        'log_type': 'expense',
        'amount': amount,
        'note': ctrlNote.text.trim().isEmpty ? null : ctrlNote.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool ro = widget.readOnly;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'الرجوع للرئيسية',
          onPressed: () {
            AppRouter.navigateToAndRemoveUntil(context, AppRouter.accountant);
          },
        ),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('مراحل العملية'),
              const SizedBox(width: 8),
              if (_isClosed)
                const Chip(
                  label: Text('مغلقة', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              if (ro) const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Chip(
                  label: Text('قراءة فقط', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('إجمالي المصروفات', style: TextStyle(fontSize: 10, height: 1)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_totalExpense',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('إجمالي الهالك', style: TextStyle(fontSize: 10, height: 1)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_totalWaste',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                  // Removed operation purchases card: purchases will be recorded per stage
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final r = _rows[i];
                        final started = r['started_at'] != null;
                        final finished = r['finished_at'] != null;
                        final isRunning = started && !finished;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _rows.length - 1 ? 0 : 8,
                          ),
                          child: Card(
                            color: isRunning
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.green.withOpacity(0.25)
                                      : Colors.green.shade200)
                                : null,
                            shape: isRunning
                                ? RoundedRectangleBorder(
                                    side: const BorderSide(
                                      color: Colors.green,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: ListTile(
                              dense: true,
                              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              leading: CircleAvatar(
                                child: Text('${r['order_no']}'),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r['stage_name'] as String,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  if (finished)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6.0),
                                      child: Chip(label: Text('مكتملة')),
                                    ),
                                ],
                              ),
                              subtitle: DefaultTextStyle.merge(
                                style: const TextStyle(fontSize: 12, height: 1.2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (started && !finished)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 2.0),
                                        child: Text('جارية'),
                                      )
                                    else if (!started)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 2.0),
                                        child: Text('لم تبدأ'),
                                      )
                                    else
                                      const SizedBox(height: 4),
                                    Container(
                                      height: 40, // Fixed height to prevent layout shifts
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildInfoChip(context, 'استلام', r['total_receive'] ?? 0),
                                            _buildInfoChip(context, 'تسليم', r['total_deliver'] ?? 0),
                                            _buildInfoChip(context, 'هالك', r['total_waste'] ?? 0),
                                            _buildInfoChip(context, 'مصروف', r['total_expense'] ?? 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Manufacturer and Actions Section
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Manufacturer Row
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 4.0),
                                              child: Text('المصنع:', style: TextStyle(fontSize: 11)),
                                            ),
                                            const SizedBox(width: 4),
                                            if (_loadingManufacturers)
                                              const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(strokeWidth: 1.5),
                                              )
                                            else
                                              Expanded(
                                                child: DropdownButtonFormField<String>(
                                                  isExpanded: true,
                                                  value: (r['manufacturer_id'] as String?),
                                                  style: const TextStyle(fontSize: 12, height: 1.1),
                                                  hint: const Text('بدون مصنع', style: TextStyle(fontSize: 12)),
                                                  decoration: const InputDecoration(
                                                    isDense: true,
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                                                  items: _manufacturers
                                                      .map((m) => DropdownMenuItem<String>(
                                                            value: m['id'] as String,
                                                            child: Text(
                                                              m['name'] as String,
                                                              style: const TextStyle(fontSize: 11),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ))
                                                      .toList(),
                                                  onChanged: (ro || _isClosed)
                                                      ? null
                                                      : (val) => _assignManufacturerToStage(
                                                            stageId: r['stage_id'] as String,
                                                            manufacturerId: val,
                                                          ),
                                                ),
                                              ),
                                            if ((r['manufacturer_id'] as String?) != null && !(ro || _isClosed))
                                              IconButton(
                                                tooltip: 'إزالة المصنع',
                                                icon: const Icon(Icons.clear, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _assignManufacturerToStage(
                                                  stageId: r['stage_id'] as String,
                                                  manufacturerId: null,
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Action Buttons Row
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton.icon(
                                                  icon: Icon(
                                                    (started && !finished) ? Icons.pause : Icons.play_arrow, 
                                                    size: 16
                                                  ),
                                                  label: Text(
                                                    (started && !finished) ? 'جارية' : 'بدء', 
                                                    style: const TextStyle(fontSize: 12)
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: ((ro) || _isClosed || finished || (started && !finished)) 
                                                      ? null 
                                                      : () => _startStage(r),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: FilledButton.icon(
                                                  icon: const Icon(Icons.add, size: 16),
                                                  label: const Text('إضافة', style: TextStyle(fontSize: 12)),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: (ro || _isClosed) ? null : () {
                                                    showMenu<String>(
                                                      context: context,
                                                      position: RelativeRect.fromLTRB(0, 0, 0, 0),
                                                      items: const [
                                                        PopupMenuItem(value: 'receive', child: Text('إضافة استلام')),
                                                        PopupMenuItem(value: 'deliver', child: Text('إضافة تسليم')),
                                                        PopupMenuItem(value: 'waste', child: Text('إضافة هالك')),
                                                        PopupMenuItem(value: 'expense', child: Text('إضافة مصروف')),
                                                      ],
                                                    ).then((v) {
                                                      if (v == 'receive' || v == 'deliver' || v == 'waste') {
                                                        _addQuantityLog(logType: v!, r: r);
                                                      } else if (v == 'expense') {
                                                        _addExpenseLog(r);
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: FilledButton.icon(
                                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                                  label: const Text('إنهاء', style: TextStyle(fontSize: 12)),
                                                  style: FilledButton.styleFrom(
                                                    visualDensity: VisualDensity.compact,
                                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  onPressed: ((ro) || _isClosed || !started || finished) 
                                                      ? null 
                                                      : () => _finishStage(r),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        );
                      }, childCount: _rows.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Card(
                        child: ExpansionTile(
                          title: const Text('الملخص المالي'),
                          initiallyExpanded: false,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Direct expenses (rename only)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('مصروفات مباشرة'),
                                      Text(_totalExpense.toString()),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Divider(height: 16),
                                  // Removed separate purchases total and combined expenses
                                  const SizedBox(height: 6),
                                  // Waste value using purchase unit cost
                                  Builder(
                                    builder: (ctx) {
                                      final t = (_opType ?? '').toLowerCase();
                                      final isCommercial = t == 'commercial' || t.contains('commerc') || t.contains('تجار');
                                      if (isCommercial) {
                                        return const SizedBox.shrink();
                                      }
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text('سعر شراء الفرخ'),
                                              ),
                                              SizedBox(
                                                width: 140,
                                                child: TextField(
                                                  controller: _wasteUnitCostCtrl,
                                                  readOnly: true,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    isDense: true,
                                                    border: OutlineInputBorder(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('قيمة الهالك (بسعر الشراء)'),
                                              Builder(
                                                builder: (ctx) {
                                                  final wasteValue = (_wasteUnitCostPurchase) * (_totalWaste);
                                                  return Text(wasteValue.toString());
                                                },
                                              ),
                                            ],
                                          ),
                                          const Divider(),
                                        ],
                                      );
                                    },
                                  ),
                                  // Indirect expense
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text('مصروفات غير مباشرة'),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: TextField(
                                          controller: _indirectCtrl,
                                          enabled: !(ro || _isClosed),
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (v) {
                                            _indirectExpense =
                                                num.tryParse(
                                                  v.replaceAll(',', '.'),
                                                ) ??
                                                0;
                                            setState(() {});
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  // Agreement unit price (read-only)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('سعر الوحدة (اتفاق)'),
                                      Text(_agreementUnitPrice.toString()),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Total delivered quantity (last stage only)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('إجمالي التسليم'),
                                      Builder(
                                        builder: (ctx) {
                                          final lastDeliver = _rows.isEmpty
                                              ? 0
                                              : (((_rows.last['total_deliver']) as num?) ?? 0);
                                          return Text(lastDeliver.toString());
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Total revenue (based on last stage deliver)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('إجمالي الإيراد'),
                                      Builder(
                                        builder: (ctx) {
                                          final lastDeliver = _rows.isEmpty
                                              ? 0
                                              : (((_rows.last['total_deliver']) as num?) ?? 0);
                                          final revenue = _agreementUnitPrice * lastDeliver;
                                          return Text(revenue.toString());
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  // Net profit calculation (using last stage deliver)
                                  Builder(
                                    builder: (ctx) {
                                      final lastDeliver = _rows.isEmpty
                                          ? 0
                                          : (((_rows.last['total_deliver']) as num?) ?? 0);
                                      final revenue = _agreementUnitPrice * lastDeliver;
                                      final wasteValue = _wasteUnitCostPurchase * _totalWaste;
                                      final totalCost = _totalExpense + wasteValue + _indirectExpense;
                                      final profit = revenue - totalCost;
                                      return Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('إجمالي التكلفة'),
                                              Text(totalCost.toStringAsFixed(2)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'صافي الربح',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                profit.toStringAsFixed(2),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: profit >= 0 ? Colors.green : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: FilledButton.icon(
                                      onPressed: (ro || _isClosed)
                                          ? null
                                          : _saveFinance,
                                      icon: const Icon(Icons.save),
                                      label: const Text('حفظ الملخص'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
