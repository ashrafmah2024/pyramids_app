import 'package:flutter/material.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
// Removed go_router import since navigation is handled via tabs
import 'package:pyramids/features/manufacturing/presentation/screens/operation_stages_screen.dart';

enum OperationType { commercial, manufacturing }

class NewOperationScreen extends StatefulWidget {
  final bool embedded; // when true, show form only (no internal tabs/appbar)
  final String? initialOperationId; // when provided, load this operation for editing
  final VoidCallback? onSaved; // optional: notify parent after save
  const NewOperationScreen({super.key, this.embedded = false, this.initialOperationId, this.onSaved});

  @override
  State<NewOperationScreen> createState() => _NewOperationScreenState();
}

class _NewOperationScreenState extends State<NewOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _operationCodeCtrl = TextEditingController();
  final _printingCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _unitPriceAgreedCtrl = TextEditingController();
  final _totalAgreedCtrl = TextEditingController();

  OperationType? _selectedType;
  DateTime? _saleDate;
  String? _selectedClientId;
  List<Map<String, dynamic>> _clients = [];
  bool _loadingClients = false;
  bool _generatingCode = false;
  String? _selectedProductTypeId;
  List<Map<String, dynamic>> _productTypes = [];
  bool _loadingProductTypes = false;
  int? _selectedUnitId;
  List<Map<String, dynamic>> _units = [];
  bool _loadingUnits = false;
  List<Map<String, dynamic>> _stages = [];
  bool _loadingStages = false;
  List<String> _selectedStageIds = [];
  bool _saving = false;
  String? _savedOperationId;
  String? _productTypeNameAr;
  TabController? _tabController;
  final _opCodeSearchCtrl = TextEditingController();
  bool _loadingRecentOps = false;
  List<Map<String, dynamic>> _recentOps = [];

  @override
  void dispose() {
    _operationCodeCtrl.dispose();
    _printingCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _unitPriceAgreedCtrl.dispose();
    _totalAgreedCtrl.dispose();
    _opCodeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _logOperationActivity(
    String action,
    String operationId, {
    String? details,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final displayName =
            user.email ?? user.userMetadata?['full_name'] ?? 'User';
        await supabase.from('activity_logs').insert({
          'user_id': user.id,
          'user_name': displayName,
          'action': action,
          'entity_type': 'OPERATION',
          'entity_id': operationId,
          'description': details ?? 'Operation $action',
          'ip_address': '',
          'user_agent': '',
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOperationIntoForm(String operationId) async {
    try {
      final op = await Supabase.instance.client
          .from('operations')
          .select(
            'id,type,operation_code,description,client_id,product_type_id,unit_id,agreement_qty,agreement_unit_price,agreement_total,delivery_date',
          )
          .eq('id', operationId)
          .maybeSingle();
      if (op == null) return;
      final m = (op as Map<String, dynamic>);
      setState(() {
        _savedOperationId = operationId;
        final t = (m['type'] as String?) ?? '';
        _selectedType = t == 'commercial'
            ? OperationType.commercial
            : OperationType.manufacturing;
        _operationCodeCtrl.text = (m['operation_code'] ?? '').toString();
        _printingCtrl.text = (m['description'] ?? '').toString();
        _selectedClientId = (m['client_id'])?.toString();
        _selectedProductTypeId = (m['product_type_id'])?.toString();
        _selectedUnitId = (m['unit_id'] is int)
            ? m['unit_id'] as int
            : int.tryParse('${m['unit_id']}');
        _qtyCtrl.text = (m['agreement_qty']?.toString() ?? '');
        _unitPriceAgreedCtrl.text =
            (m['agreement_unit_price']?.toString() ?? '');
        _totalAgreedCtrl.text = (m['agreement_total']?.toString() ?? '');
        final d = m['delivery_date']?.toString();
        _saleDate = d == null || d.isEmpty ? null : DateTime.tryParse(d);
      });
      // Ensure product types list is loaded to populate dropdown
      await _loadProductTypes();
      // Load product type name
      if (_selectedProductTypeId != null) {
        try {
          final br = await Supabase.instance.client
              .from('business_fields')
              .select('id,name_ar')
              .eq('id', _selectedProductTypeId!)
              .maybeSingle();
          if (br != null) {
            setState(
              () => _productTypeNameAr = (br as Map<String, dynamic>)['name_ar']
                  ?.toString(),
            );
          }
        } catch (_) {}
      } else {
        await _loadAutoProductType();
      }
      // Load selected stages
      try {
        final rows = await Supabase.instance.client
            .from('operation_stages')
            .select('stage_id,order_no')
            .eq('operation_id', operationId)
            .order('order_no');
        final list = (rows as List).cast<Map<String, dynamic>>();
        setState(() {
          _selectedStageIds = list
              .map((e) => (e['stage_id'] as String))
              .toList();
        });
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 0));
      _tabController?.animateTo(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحميل العملية: $e')));
      }
    }
  }

  void _onNewOperation() {
    setState(() {
      _formKey.currentState?.reset();
      _operationCodeCtrl.clear();
      _printingCtrl.clear();
      _priceCtrl.clear();
      _qtyCtrl.clear();
      _unitPriceAgreedCtrl.clear();
      _totalAgreedCtrl.clear();
      _saleDate = null;
      _selectedClientId = null;
      _selectedType = null;
      _selectedProductTypeId = null;
      _productTypeNameAr = null;
      _selectedUnitId = null;
      _selectedStageIds.clear();
      _savedOperationId = null;
    });
    _tabController?.animateTo(0);
  }

  Future<void> _loadRecentOperations() async {
    setState(() => _loadingRecentOps = true);
    try {
      final rows = await Supabase.instance.client
          .from('operations')
          .select('id, operation_code, description, type, created_at')
          .order('created_at', ascending: false)
          .limit(20);
      final list = (rows as List).cast<Map<String, dynamic>>();
      setState(() => _recentOps = list);
    } catch (_) {
      // ignore quietly
    } finally {
      if (mounted) setState(() => _loadingRecentOps = false);
    }
  }

  Future<void> _searchOperationByCode() async {
    final code = _opCodeSearchCtrl.text.trim();
    if (code.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('operations')
          .select('id')
          .eq('operation_code', code)
          .maybeSingle();
      if (row != null) {
        setState(
          () =>
              _savedOperationId = (row as Map<String, dynamic>)['id'] as String,
        );
        await Future.delayed(const Duration(milliseconds: 0));
        _tabController?.animateTo(1);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم العثور على عملية بهذا الكود')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر البحث: $e')));
      }
    }
  }

  Future<void> _loadAutoProductType() async {
    if (_selectedType == null) return;
    setState(() => _loadingProductTypes = true);
    try {
      final cat = _selectedType == OperationType.commercial ? 'com' : 'man';
      final row = await Supabase.instance.client
          .from('business_fields')
          .select('id,name_ar,cat')
          .eq('cat', cat)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final m = (row as Map<String, dynamic>);
        setState(() {
          _selectedProductTypeId = m['id']?.toString();
          _productTypeNameAr = m['name_ar']?.toString();
        });
      } else {
        setState(() {
          _selectedProductTypeId = null;
          _productTypeNameAr = null;
        });
      }
    } catch (_) {
      setState(() {
        _selectedProductTypeId = null;
        _productTypeNameAr = null;
      });
    } finally {
      if (mounted) setState(() => _loadingProductTypes = false);
    }
  }

  Future<void> _loadProductTypes() async {
    if (_selectedType == null) {
      setState(() {
        _productTypes = [];
      });
      return;
    }
    setState(() => _loadingProductTypes = true);
    try {
      final cat = _selectedType == OperationType.commercial ? 'com' : 'man';
      final data = await Supabase.instance.client
          .from('business_fields')
          .select('id,name_ar,cat')
          .eq('cat', cat);
      final list = (data as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['id'] != null && e['name_ar'] != null)
          .toList();
      setState(() {
        _productTypes = list;
      });
    } catch (_) {
      setState(() {
        _productTypes = [];
      });
    } finally {
      if (mounted) setState(() => _loadingProductTypes = false);
    }
  }

  Future<void> _loadUnits() async {
    setState(() => _loadingUnits = true);
    try {
      final data = await Supabase.instance.client
          .from('units')
          .select('id,name_ar')
          .order('name_ar')
          .limit(200);
      final list = (data as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['id'] != null && e['name_ar'] != null)
          .toList();
      setState(() => _units = list);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحميل الوحدات')));
    } finally {
      if (mounted) setState(() => _loadingUnits = false);
    }
  }

  Future<void> _loadManufacturingStages() async {
    setState(() => _loadingStages = true);
    try {
      final data = await Supabase.instance.client
          .from('manufacturing_stages')
          .select('id,stage_name,is_active')
          .order('stage_name');
      final list = (data as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['id'] != null && e['stage_name'] != null)
          .toList();
      setState(() => _stages = list);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحميل مراحل التصنيع')));
    } finally {
      if (mounted) setState(() => _loadingStages = false);
    }
  }

  Future<void> _createNewStage(String name) async {
    try {
      final inserted = await Supabase.instance.client
          .from('manufacturing_stages')
          .insert({'stage_name': name})
          .select('id,stage_name')
          .single();
      final m = (inserted as Map<String, dynamic>);
      setState(() {
        _stages.add(m);
        final id = m['id'] as String;
        if (!_selectedStageIds.contains(id)) {
          _selectedStageIds.add(id);
        }
      });
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر إضافة المرحلة')));
    }
  }

  String _dateStamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<Set<String>> _usedDailySuffixes(String base) async {
    try {
      final rows = await Supabase.instance.client
          .from('operations')
          .select('operation_code')
          .like('operation_code', '${base}-%');
      final list = (rows as List).cast<Map<String, dynamic>>();
      final used = <String>{};
      for (final m in list) {
        final code = (m['operation_code'] ?? '').toString();
        final parts = code.split('-');
        if (parts.length == 2) {
          final suf = parts[1];
          if (suf.length == 3 && int.tryParse(suf) != null) {
            used.add(suf);
          }
        }
      }
      return used;
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _autoFillOperationCode() async {
    if (_selectedType == null) return;
    setState(() => _generatingCode = true);
    try {
      final now = DateTime.now();
      final prefix = _selectedType == OperationType.commercial ? 'COM' : 'MAN';
      final base = '$prefix${_dateStamp(now)}';

      // Collect used 3-digit suffixes for today
      final used = await _usedDailySuffixes(base);
      if (used.length >= 1000) {
        // All 000-999 are used today
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن توليد كود: كل الأرقام مستخدمة اليوم')),
        );
        return;
      }

      final rnd = Random.secure();
      // Try up to 50 random picks, then fallback to first free
      for (var i = 0; i < 50; i++) {
        final n = rnd.nextInt(1000);
        final suf = n.toString().padLeft(3, '0');
        if (!used.contains(suf)) {
          // Double-check uniqueness in DB for safety
          final candidate = '$base-$suf';
          try {
            final exists = await Supabase.instance.client
                .from('operations')
                .select('id')
                .eq('operation_code', candidate)
                .limit(1);
            final list = (exists as List);
            if (list.isEmpty) {
              _operationCodeCtrl.text = candidate;
              setState(() {});
              return;
            }
          } catch (_) {
            // On check error, still use the candidate
            _operationCodeCtrl.text = candidate;
            setState(() {});
            return;
          }
        }
      }
      // Fallback: pick the first available suffix sequentially
      for (var n = 0; n < 1000; n++) {
        final suf = n.toString().padLeft(3, '0');
        if (!used.contains(suf)) {
          _operationCodeCtrl.text = '$base-$suf';
          setState(() {});
          return;
        }
      }
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadUnits();
    _loadManufacturingStages();
    _loadProductTypes();
    _loadRecentOperations();
    // Auto-load operation if provided via route
    final id = widget.initialOperationId;
    if (id != null && id.isNotEmpty) {
      // Delay to ensure _tabController is ready when not embedded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOperationIntoForm(id);
      });
    }
  }

  Future<void> _loadClients() async {
    setState(() => _loadingClients = true);
    try {
      final data = await Supabase.instance.client
          .from('clients')
          .select('id,name')
          .eq('is_active', true)
          .order('name')
          .limit(200);
      final list = (data as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['id'] != null && e['name'] != null)
          .toList();
      setState(() => _clients = list);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحميل العملاء')));
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  // Removed _loadProductTypes: product type now auto-loads from business_fields

  Future<void> _onSaveDraft() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    try {
      final wasNew = _savedOperationId == null;
      if (_selectedType == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('اختر نوع العملية')));
        return;
      }
      if (!_formKey.currentState!.validate()) {
        return;
      }

      if (_operationCodeCtrl.text.trim().isEmpty) {
        await _autoFillOperationCode();
      }
      final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.'));
      final unitPrice = double.tryParse(
        _unitPriceAgreedCtrl.text.replaceAll(',', '.'),
      );
      final total = double.tryParse(_totalAgreedCtrl.text.replaceAll(',', '.'));

      Map<String, dynamic> buildPayload() => <String, dynamic>{
        'type': _selectedType == OperationType.commercial
            ? 'commercial'
            : 'manufacturing',
        if (_operationCodeCtrl.text.trim().isNotEmpty)
          'operation_code': _operationCodeCtrl.text.trim(),
        if (_printingCtrl.text.trim().isNotEmpty)
          'description': _printingCtrl.text.trim(),
        'client_id': _selectedClientId,
        'product_type_id': _selectedProductTypeId,
        'unit_id': _selectedUnitId,
        'agreement_qty': qty,
        'agreement_unit_price': unitPrice,
        'agreement_total': total,
        if (_saleDate != null) 'delivery_date': _saleDate!.toIso8601String(),
      };

      // Capture old state for diffing when updating
      Map<String, dynamic>? _oldRow;
      List<String> _oldStageIds = [];

      String operationId;
      if (_savedOperationId != null) {
        // Update existing operation
        try {
          final prev = await Supabase.instance.client
              .from('operations')
              .select(
                'id,type,operation_code,description,client_id,product_type_id,unit_id,agreement_qty,agreement_unit_price,agreement_total,delivery_date',
              )
              .eq('id', _savedOperationId!)
              .maybeSingle();
          if (prev != null) {
            _oldRow = Map<String, dynamic>.from(prev as Map<String, dynamic>);
          }
          if (_selectedType == OperationType.manufacturing) {
            final rows = await Supabase.instance.client
                .from('operation_stages')
                .select('stage_id,order_no')
                .eq('operation_id', _savedOperationId!)
                .order('order_no');
            _oldStageIds = (rows as List)
                .map((e) => (e as Map<String, dynamic>)['stage_id'] as String)
                .toList();
          }
        } catch (_) {}
        await Supabase.instance.client
            .from('operations')
            .update(buildPayload())
            .eq('id', _savedOperationId!);
        operationId = _savedOperationId!;
      } else {
        final op = await Supabase.instance.client
            .from('operations')
            .insert(buildPayload())
            .select('id')
            .single();
        operationId = (op as Map<String, dynamic>)['id'] as String;
      }

      if (_selectedStageIds.isNotEmpty) {
        // Replace stages for update or insert
        await Supabase.instance.client
            .from('operation_stages')
            .delete()
            .eq('operation_id', operationId);
        if (_selectedStageIds.isNotEmpty) {
          // Ensure delivery stage is last
          final ids = List<String>.from(_selectedStageIds);
          final delivery = <String>[];
          final others = <String>[];
          for (final sid in ids) {
            final st = _stages.firstWhere(
              (s) => s['id'] == sid,
              orElse: () => {'stage_name': ''},
            );
            final name = (st['stage_name'] ?? '').toString();
            if (name.contains('تسليم')) {
              delivery.add(sid);
            } else {
              others.add(sid);
            }
          }
          final ordered = [...others, ...delivery];
          final rows = <Map<String, dynamic>>[];
          for (var i = 0; i < ordered.length; i++) {
            final sid = ordered[i];
            final st = _stages.firstWhere(
              (s) => s['id'] == sid,
              orElse: () => {'stage_name': 'مرحلة'},
            );
            rows.add({
              'operation_id': operationId,
              'stage_id': sid,
              'order_no': i + 1,
              'name': (st['stage_name'] ?? 'مرحلة').toString(),
            });
          }
          await Supabase.instance.client.from('operation_stages').insert(rows);
        }
      }

      final opLabel = _operationCodeCtrl.text.trim().isEmpty
          ? operationId
          : _operationCodeCtrl.text.trim();

      String details;
      if (wasNew) {
        details = 'Create operation $opLabel';
      } else {
        final changes = <String>[];
        try {
          final payload = buildPayload();
          final keys = <String>[
            'type',
            'operation_code',
            'description',
            'client_id',
            'product_type_id',
            'unit_id',
            'agreement_qty',
            'agreement_unit_price',
            'agreement_total',
            'delivery_date',
          ];
          for (final k in keys) {
            final oldV = _oldRow?[k];
            final newV = payload[k];
            final oldStr = oldV?.toString() ?? '';
            final newStr = newV?.toString() ?? '';
            if (oldStr != newStr) {
              changes.add('$k: ${oldV ?? '-'} -> ${newV ?? '-'}');
            }
          }
          if (_selectedType == OperationType.manufacturing && _oldStageIds.isNotEmpty) {
            final newStages = List<String>.from(_selectedStageIds);
            final added = newStages.where((s) => !_oldStageIds.contains(s)).toList();
            final removed = _oldStageIds.where((s) => !newStages.contains(s)).toList();
            if (added.isNotEmpty) {
              changes.add('stages_added: ${added.join(' > ')}');
            }
            if (removed.isNotEmpty) {
              changes.add('stages_removed: ${removed.join(' > ')}');
            }
            if (added.isEmpty && removed.isEmpty && newStages.length == _oldStageIds.length) {
              // possible reorder
              bool sameOrder = true;
              for (var i = 0; i < newStages.length; i++) {
                if (newStages[i] != _oldStageIds[i]) {
                  sameOrder = false;
                  break;
                }
              }
              if (!sameOrder) {
                changes.add('stages_reordered: ${_oldStageIds.join(' > ')} -> ${newStages.join(' > ')}');
              }
            }
          }
        } catch (_) {}
        details = changes.isNotEmpty
            ? 'Update operation $opLabel | ' + changes.join(', ')
            : 'Update operation $opLabel';
      }

      await _logOperationActivity(
        wasNew ? 'CREATE' : 'UPDATE',
        operationId,
        details: details,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _savedOperationId != null ? 'تم تحديث العملية' : 'تم حفظ المسودة',
          ),
        ),
      );

      if (!mounted) {
        return;
      }
      if (widget.embedded) {
        // After save in embedded mode, clear the form for a new operation
        try {
          widget.onSaved?.call();
        } catch (_) {}
        _onNewOperation();
      } else if (!wasNew && _selectedType == OperationType.manufacturing) {
        setState(() {
          _savedOperationId = operationId;
        });
        await Future<void>.delayed(const Duration(milliseconds: 0));
        if (!mounted) {
          return;
        }
        _tabController?.animateTo(1);
      } else if (wasNew) {
        // For new operations in non-embedded mode, prepare for a new entry
        try {
          widget.onSaved?.call();
        } catch (_) {}
        _onNewOperation();
      }
    } catch (e) {
      final msg = e.toString();
      final dup =
          msg.contains('duplicate key value') ||
          msg.contains('operations_operation_code_key') ||
          msg.contains('23505');
      if (dup) {
        // regenerate and retry up to 5 times
        final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.'));
        final unitPrice = double.tryParse(
          _unitPriceAgreedCtrl.text.replaceAll(',', '.'),
        );
        final total = double.tryParse(
          _totalAgreedCtrl.text.replaceAll(',', '.'),
        );
        for (var attempt = 0; attempt < 5; attempt++) {
          await _autoFillOperationCode();
          try {
            final op2 = await Supabase.instance.client
                .from('operations')
                .insert({
                  'type': _selectedType == OperationType.commercial
                      ? 'commercial'
                      : 'manufacturing',
                  'operation_code': _operationCodeCtrl.text.trim(),
                  if (_printingCtrl.text.trim().isNotEmpty)
                    'description': _printingCtrl.text.trim(),
                  'client_id': _selectedClientId,
                  'product_type_id': _selectedProductTypeId,
                  'unit_id': _selectedUnitId,
                  'agreement_qty': qty,
                  'agreement_unit_price': unitPrice,
                  'agreement_total': total,
                  if (_saleDate != null)
                    'delivery_date': _saleDate!.toIso8601String(),
                })
                .select('id')
                .single();

            final operationId = (op2 as Map<String, dynamic>)['id'] as String;
            if (_selectedStageIds.isNotEmpty) {
              // Ensure delivery stage is last
              final ids = List<String>.from(_selectedStageIds);
              final delivery = <String>[];
              final others = <String>[];
              for (final sid in ids) {
                final st = _stages.firstWhere(
                  (s) => s['id'] == sid,
                  orElse: () => {'stage_name': ''},
                );
                final name = (st['stage_name'] ?? '').toString();
                if (name.contains('تسليم')) {
                  delivery.add(sid);
                } else {
                  others.add(sid);
                }
              }
              final ordered = [...others, ...delivery];
              final rows = <Map<String, dynamic>>[];
              for (var i = 0; i < ordered.length; i++) {
                final sid = ordered[i];
                final st = _stages.firstWhere(
                  (s) => s['id'] == sid,
                  orElse: () => {'stage_name': 'مرحلة'},
                );
                rows.add({
                  'operation_id': operationId,
                  'stage_id': sid,
                  'order_no': i + 1,
                  'name': (st['stage_name'] ?? 'مرحلة').toString(),
                });
              }
              await Supabase.instance.client
                  .from('operation_stages')
                  .insert(rows);
            }

            final opLabel = _operationCodeCtrl.text.trim().isEmpty
                ? operationId
                : _operationCodeCtrl.text.trim();
            await _logOperationActivity(
              'CREATE',
              operationId,
              details: 'Create operation $opLabel',
            );

            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم حفظ المسودة (كود جديد)')),
            );
            if (_selectedType == OperationType.manufacturing) {
              setState(() {
                _savedOperationId = operationId;
              });
              await Future<void>.delayed(const Duration(milliseconds: 0));
              if (!mounted) {
                return;
              }
              _tabController?.animateTo(1);
            }
            try {
              widget.onSaved?.call();
            } catch (_) {}
            return; // success
          } catch (err) {
            final emsg = err.toString();
            final stillDup =
                emsg.contains('duplicate key value') ||
                emsg.contains('operations_operation_code_key') ||
                emsg.contains('23505');
            if (!stillDup) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('فشل حفظ المسودة: $err')));
              return;
            }
            // else continue loop and retry
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر توليد كود فريد بعد محاولات متعددة'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل حفظ المسودة: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      } else {
        _saving = false;
      }
    }
  }

  void _onConfirmSale() async {
    if (_selectedType != OperationType.commercial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأكيد البيع متاح للعملية التجارية فقط')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تأكيد البيع')));
  }

  Future<void> _pickSaleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _saleDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _saleDate = picked);
    }
  }

  Widget _buildTextField(
    TextEditingController controller, {
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int? maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  void _recalcAgreementTotal() {
    final q = double.tryParse(_qtyCtrl.text.replaceAll(',', '.'));
    final up = double.tryParse(_unitPriceAgreedCtrl.text.replaceAll(',', '.'));
    if (q != null && up != null) {
      final tot = q * up;
      _totalAgreedCtrl.text = tot.toStringAsFixed(2);
    } else {
      _totalAgreedCtrl.text = '';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      // Single form content without internal tabs/app bar
      return Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<OperationType>(
                  value: _selectedType,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: OperationType.commercial,
                      child: Text('عملية تجارية'),
                    ),
                    DropdownMenuItem(
                      value: OperationType.manufacturing,
                      child: Text('عملية تصنيعية'),
                    ),
                  ],
                  onChanged: (v) async {
                    setState(() {
                      _selectedType = v;
                      _selectedProductTypeId = null;
                      _productTypeNameAr = null;
                    });
                    await _autoFillOperationCode();
                    await _loadProductTypes();
                  },
                  validator: (v) => v == null ? 'مطلوب' : null,
                  decoration: const InputDecoration(
                    labelText: 'نوع العملية',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedClientId,
                  isExpanded: true,
                  items: _clients
                      .map(
                        (c) => DropdownMenuItem<String>(
                          value: c['id'] as String,
                          child: Text(
                            c['name'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged:
                      _loadingClients ? null : (v) => setState(() => _selectedClientId = v),
                  validator: (v) => v == null ? 'مطلوب' : null,
                  decoration: InputDecoration(
                    labelText: _loadingClients ? 'جارٍ تحميل العملاء...' : 'العميل',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              _buildTextField(
                _operationCodeCtrl,
                label: _generatingCode ? 'جاري توليد الكود...' : 'كود العملية (اختياري)',
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedProductTypeId,
                  isExpanded: true,
                  items: _productTypes
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e['id']?.toString(),
                          child: Text(
                            (e['name_ar'] ?? '').toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingProductTypes
                      ? null
                      : (v) => setState(() {
                            _selectedProductTypeId = v;
                            final sel = _productTypes.firstWhere(
                              (p) => p['id']?.toString() == v,
                              orElse: () => {},
                            );
                            _productTypeNameAr = sel['name_ar']?.toString();
                          }),
                  validator: (v) => v == null ? 'مطلوب' : null,
                  decoration: InputDecoration(
                    labelText: _loadingProductTypes
                        ? 'جارٍ تحميل أنواع المنتج...'
                        : 'نوع المنتج',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              _buildTextField(
                _printingCtrl,
                label: 'اسم العملية',
                maxLines: 2,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<int>(
                  value: _selectedUnitId,
                  isExpanded: true,
                  items: _units
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e['id'] as int,
                          child: Text(
                            e['name_ar'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _loadingUnits ? null : (v) => setState(() => _selectedUnitId = v),
                  validator: (v) => v == null ? 'مطلوب' : null,
                  decoration: InputDecoration(
                    labelText: _loadingUnits ? 'جارٍ تحميل الوحدات...' : 'الوحدة',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _qtyCtrl,
                      label: 'الكمية',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _unitPriceAgreedCtrl,
                      label: 'سعر متفق عليه',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _recalcAgreementTotal(),
                    ),
                  ),
                ],
              ),
              _buildTextField(
                _totalAgreedCtrl,
                label: 'الإجمالي المتفق عليه (يحسب تلقائياً)',
                readOnly: true,
              ),
              if (_selectedType != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مراحل التصنيع'),
                      if (_selectedType == OperationType.manufacturing)
                        TextButton(
                          onPressed: () async {
                            final ctrl = TextEditingController();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) {
                                return AlertDialog(
                                  title: const Text('إضافة مرحلة'),
                                  content: TextField(
                                    controller: ctrl,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم المرحلة',
                                      border: OutlineInputBorder(),
                                    ),
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
                            if (ok == true) {
                              final name = ctrl.text.trim();
                              if (name.isNotEmpty) await _createNewStage(name);
                            }
                          },
                          child: const Text('إضافة مرحلة'),
                        ),
                    ],
                  ),
                ),
                if (_loadingStages)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: 
                          ((_selectedType == OperationType.manufacturing)
                                  ? _stages
                                  : _stages
                                      .where((s) {
                                        final n = (s['stage_name'] as String?) ?? '';
                                        return n == 'شراء من مورد' || n.contains('تسليم');
                                      })
                                      .toList())
                              .map((s) {
                        final id = s['id'] as String;
                        final name = s['stage_name'] as String;
                        final selected = _selectedStageIds.contains(id);
                        return FilterChip(
                          label: Text(name),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                if (!_selectedStageIds.contains(id)) {
                                  _selectedStageIds.add(id);
                                }
                              } else {
                                _selectedStageIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  Column(
                    children: _selectedStageIds.asMap().entries.map((e) {
                      final idx = e.key;
                      final id = e.value;
                      final stage = _stages.firstWhere(
                        (s) => s['id'] == id,
                        orElse: () => {'stage_name': 'مرحلة غير معروفة'},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(stage['stage_name'] as String)),
                            IconButton(
                              onPressed: idx == 0
                                  ? null
                                  : () {
                                      setState(() {
                                        final tmp = _selectedStageIds[idx - 1];
                                        _selectedStageIds[idx - 1] = _selectedStageIds[idx];
                                        _selectedStageIds[idx] = tmp;
                                      });
                                    },
                              icon: const Icon(Icons.arrow_upward),
                              tooltip: 'أعلى',
                            ),
                            IconButton(
                              onPressed: idx == _selectedStageIds.length - 1
                                  ? null
                                  : () {
                                      setState(() {
                                        final tmp = _selectedStageIds[idx + 1];
                                        _selectedStageIds[idx + 1] = _selectedStageIds[idx];
                                        _selectedStageIds[idx] = tmp;
                                      });
                                    },
                              icon: const Icon(Icons.arrow_downward),
                              tooltip: 'أسفل',
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStageIds.removeAt(idx);
                                });
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'إزالة',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickSaleDate,
                      icon: const Icon(Icons.event),
                      label: Text(
                        _saleDate == null ? 'تاريخ التسليم' : _saleDate!.toString().split(' ').first,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _onSaveDraft,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Default behavior with internal tabs
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (tabCtx) {
          _tabController = DefaultTabController.of(tabCtx);
          return AnimatedBuilder(
            animation: _tabController!,
            builder: (_, __) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('عملية جديدة'),
                  actions: [
                    TextButton(
                      onPressed: _saving ? null : _onSaveDraft,
                      child: const Text('حفظ مسودة'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _onNewOperation,
                      child: const Text('عملية جديدة'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'عملية جديدة'),
                      Tab(text: 'مراحل العملية'),
                    ],
                  ),
                ),
                bottomNavigationBar: (_tabController?.index == 0)
                    ? SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _onSaveDraft,
                              icon: const Icon(Icons.save),
                              label: const Text('حفظ'),
                            ),
                          ),
                        ),
                      )
                    : null,
                body: TabBarView(
                  children: [
                    Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: DropdownButtonFormField<OperationType>(
                                value: _selectedType,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: OperationType.commercial,
                                    child: Text('عملية تجارية'),
                                  ),
                                  DropdownMenuItem(
                                    value: OperationType.manufacturing,
                                    child: Text('عملية تصنيعية'),
                                  ),
                                ],
                                onChanged: (v) async {
                                  setState(() {
                                    _selectedType = v;
                                    _selectedProductTypeId = null;
                                    _productTypeNameAr = null;
                                  });
                                  await _autoFillOperationCode();
                                  await _loadProductTypes();
                                },
                                validator: (v) => v == null ? 'مطلوب' : null,
                                decoration: const InputDecoration(
                                  labelText: 'نوع العملية',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: DropdownButtonFormField<String>(
                                value: _selectedClientId,
                                isExpanded: true,
                                items: _clients
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c['id'] as String,
                                        child: Text(
                                          c['name'] as String,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loadingClients
                                    ? null
                                    : (v) =>
                                          setState(() => _selectedClientId = v),
                                validator: (v) => v == null ? 'مطلوب' : null,
                                decoration: InputDecoration(
                                  labelText: _loadingClients
                                      ? 'جارٍ تحميل العملاء...'
                                      : 'العميل',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            _buildTextField(
                              _operationCodeCtrl,
                              label: _generatingCode
                                  ? 'جاري توليد الكود...'
                                  : 'كود العملية (اختياري)',
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: DropdownButtonFormField<String>(
                                value: _selectedProductTypeId,
                                isExpanded: true,
                                items: _productTypes
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e['id']?.toString(),
                                        child: Text(
                                          (e['name_ar'] ?? '').toString(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loadingProductTypes
                                    ? null
                                    : (v) => setState(() {
                                          _selectedProductTypeId = v;
                                          final sel = _productTypes.firstWhere(
                                            (p) => p['id']?.toString() == v,
                                            orElse: () => {},
                                          );
                                          _productTypeNameAr = sel['name_ar']?.toString();
                                        }),
                                validator: (v) => v == null ? 'مطلوب' : null,
                                decoration: InputDecoration(
                                  labelText: _loadingProductTypes
                                      ? 'جارٍ تحميل أنواع المنتج...'
                                      : 'نوع المنتج',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            _buildTextField(
                              _printingCtrl,
                              label: 'اسم العملية',
                              maxLines: 2,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: DropdownButtonFormField<int>(
                                value: _selectedUnitId,
                                isExpanded: true,
                                items: _units
                                    .map(
                                      (e) => DropdownMenuItem<int>(
                                        value: e['id'] as int,
                                        child: Text(
                                          e['name_ar'] as String,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loadingUnits
                                    ? null
                                    : (v) =>
                                          setState(() => _selectedUnitId = v),
                                validator: (v) => v == null ? 'مطلوب' : null,
                                decoration: InputDecoration(
                                  labelText: _loadingUnits
                                      ? 'جارٍ تحميل الوحدات...'
                                      : 'الوحدة',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    _qtyCtrl,
                                    label: 'الكمية',
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty)
                                        return 'مطلوب';
                                      final n = double.tryParse(
                                        v.replaceAll(',', '.'),
                                      );
                                      if (n == null || n <= 0)
                                        return 'غير صالح';
                                      return null;
                                    },
                                    onChanged: (_) => _recalcAgreementTotal(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextField(
                                    _unitPriceAgreedCtrl,
                                    label: 'سعر الوحدة (اتفاق)',
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => _recalcAgreementTotal(),
                                  ),
                                ),
                              ],
                            ),
                            _buildTextField(
                              _totalAgreedCtrl,
                              label: 'الإجمالي (اتفاق)',
                              keyboardType: TextInputType.number,
                              readOnly: true,
                            ),
                            if (_selectedType ==
                                OperationType.manufacturing) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('مراحل التصنيع'),
                                    TextButton(
                                      onPressed: () async {
                                        final ctrl = TextEditingController();
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) {
                                            return AlertDialog(
                                              title: const Text('إضافة مرحلة'),
                                              content: TextField(
                                                controller: ctrl,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'اسم المرحلة',
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text('إلغاء'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: const Text('حفظ'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (ok == true) {
                                          final name = ctrl.text.trim();
                                          if (name.isNotEmpty)
                                            await _createNewStage(name);
                                        }
                                      },
                                      child: const Text('إضافة مرحلة'),
                                    ),
                                  ],
                                ),
                              ),
                              if (_loadingStages)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _stages.map((s) {
                                      final id = s['id'] as String;
                                      final name = s['stage_name'] as String;
                                      final selected = _selectedStageIds
                                          .contains(id);
                                      return FilterChip(
                                        label: Text(name),
                                        selected: selected,
                                        onSelected: (val) {
                                          setState(() {
                                            if (val) {
                                              if (!_selectedStageIds.contains(
                                                id,
                                              )) {
                                                _selectedStageIds.add(id);
                                              }
                                            } else {
                                              _selectedStageIds.remove(id);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Column(
                                  children: _selectedStageIds.asMap().entries.map((
                                    e,
                                  ) {
                                    final idx = e.key;
                                    final id = e.value;
                                    final stage = _stages.firstWhere(
                                      (s) => s['id'] == id,
                                      orElse: () => {
                                        'stage_name': 'مرحلة غير معروفة',
                                      },
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              stage['stage_name'] as String,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: idx == 0
                                                ? null
                                                : () {
                                                    setState(() {
                                                      final tmp =
                                                          _selectedStageIds[idx -
                                                              1];
                                                      _selectedStageIds[idx -
                                                              1] =
                                                          _selectedStageIds[idx];
                                                      _selectedStageIds[idx] =
                                                          tmp;
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.arrow_upward,
                                            ),
                                            tooltip: 'أعلى',
                                          ),
                                          IconButton(
                                            onPressed:
                                                idx ==
                                                    _selectedStageIds.length - 1
                                                ? null
                                                : () {
                                                    setState(() {
                                                      final tmp =
                                                          _selectedStageIds[idx +
                                                              1];
                                                      _selectedStageIds[idx +
                                                              1] =
                                                          _selectedStageIds[idx];
                                                      _selectedStageIds[idx] =
                                                          tmp;
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.arrow_downward,
                                            ),
                                            tooltip: 'أسفل',
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _selectedStageIds.removeAt(idx);
                                              });
                                            },
                                            icon: const Icon(Icons.close),
                                            tooltip: 'إزالة',
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'تاريخ التسليم (اختياري)',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: _pickSaleDate,
                                      child: Text(
                                        _saleDate == null
                                            ? 'لم يتم التحديد'
                                            : _saleDate!
                                                  .toLocal()
                                                  .toString()
                                                  .split(' ')
                                                  .first,
                                        textAlign: TextAlign.start,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _opCodeSearchCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'ابحث بكود العملية',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  onSubmitted: (_) => _searchOperationByCode(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _searchOperationByCode,
                                child: const Text('عرض'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('العمليات'),
                              IconButton(
                                onPressed: _loadingRecentOps
                                    ? null
                                    : _loadRecentOperations,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'تحديث',
                              ),
                            ],
                          ),
                          if (_loadingRecentOps)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            SizedBox(
                              height: 160,
                              child: ListView.separated(
                                itemCount: _recentOps.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (ctx, i) {
                                  final r = _recentOps[i];
                                  final code =
                                      (r['operation_code'] ?? '') as String? ??
                                      '';
                                  final desc =
                                      (r['description'] ?? '') as String? ?? '';
                                  final type =
                                      (r['type'] ?? '') as String? ?? '';
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      code.isEmpty ? '(بدون كود)' : code,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${type.isEmpty ? '' : '$type - '}$desc',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      setState(
                                        () => _savedOperationId =
                                            r['id'] as String,
                                      );
                                    },
                                    trailing: IconButton(
                                      tooltip: 'تحميل للنموذج',
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _loadOperationIntoForm(
                                        r['id'] as String,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _savedOperationId == null
                                ? const Center(
                                    child: Text('اختر عملية لعرض مراحلها'),
                                  )
                                : OperationStagesScreen(
                                    operationId: _savedOperationId!,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
