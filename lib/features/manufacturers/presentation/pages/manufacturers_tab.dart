import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/manufacturers_provider.dart';
import '../../../manufacturers/data/models/manufacturer.dart';
import '../../../manufacturers/data/datasources/stages_remote_data_source.dart';

class ManufacturersTab extends StatefulWidget {
  const ManufacturersTab({super.key});

  @override
  State<ManufacturersTab> createState() => _ManufacturersTabState();
}

class _EditManufacturerStagesDialog extends StatefulWidget {
  final String manufacturerId;
  final String manufacturerName;
  const _EditManufacturerStagesDialog({required this.manufacturerId, required this.manufacturerName});

  @override
  State<_EditManufacturerStagesDialog> createState() => _EditManufacturerStagesDialogState();
}

class _EditManufacturerStagesDialogState extends State<_EditManufacturerStagesDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _allStages = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prov = context.read<ManufacturersProvider>();
      final ds = StagesRemoteDataSource(Supabase.instance.client);
      final all = await ds.listActiveStages(); // [{id, stage_name}]
      final current = await prov.getStages(widget.manufacturerId); // [stage_id]
      setState(() {
        _allStages = all;
        _selectedIds..clear()..addAll(current);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('تعديل مراحل المصنع: ${widget.manufacturerName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      tooltip: 'إضافة مرحلة جديدة',
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final createdName = await showDialog<String>(
                          context: context,
                          builder: (_) => const _AddStageDialog(),
                        );
                        if (createdName != null && createdName.trim().isNotEmpty) {
                          await _load();
                          // حدد المرحلة الجديدة تلقائيًا بناءً على الاسم
                          final match = _allStages.firstWhere(
                            (e) => (e['stage_name'] as String).trim() == createdName.trim(),
                            orElse: () => {},
                          );
                          if (match.isNotEmpty) {
                            final id = match['id'] as String;
                            setState(() { _selectedIds.add(id); });
                          }
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _allStages.length,
                    itemBuilder: (ctx, i) {
                      final s = _allStages[i];
                      final id = s['id'] as String;
                      final name = s['stage_name'] as String;
                      final sel = _selectedIds.contains(id);
                      return CheckboxListTile(
                        value: sel,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) _selectedIds.add(id); else _selectedIds.remove(id);
                          });
                        },
                        title: Text(name),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : () async {
                        final prov = context.read<ManufacturersProvider>();
                        final ok = await prov.setStages(widget.manufacturerId, _selectedIds.toList());
                        if (ok && context.mounted) {
                          Navigator.pop(context, true);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المراحل')));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ المراحل')));
                        }
                      },
                      child: const Text('حفظ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ])
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _AddStageDialog extends StatefulWidget {
  const _AddStageDialog();
  @override
  State<_AddStageDialog> createState() => _AddStageDialogState();
}

class _AddStageDialogState extends State<_AddStageDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _isActive = true;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إضافة مرحلة تصنيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم المرحلة'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _desc,
                  decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('نشط'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!_formKey.currentState!.validate()) return;
                        try {
                          final ds = StagesRemoteDataSource(Supabase.instance.client);
                          await ds.createStage(stageName: _name.text.trim(), description: _desc.text.trim().isEmpty ? null : _desc.text.trim(), isActive: _isActive);
                          if (context.mounted) Navigator.pop(context, _name.text.trim());
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إضافة المرحلة: $e')));
                          }
                        }
                      },
                      child: const Text('حفظ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                ])
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<String>> _loadStageNames(BuildContext context, String manufacturerId) async {
    final prov = context.read<ManufacturersProvider>();
    final stageIds = await prov.getStages(manufacturerId);
    if (stageIds.isEmpty) return [];
    final ds = StagesRemoteDataSource(Supabase.instance.client);
    final all = await ds.listActiveStages(); // [{id, stage_name}]
    final byId = {for (final e in all) (e['id'] as String): (e['stage_name'] as String)};
    return stageIds.map((id) => byId[id]).whereType<String>().toList();
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

class CreateManufacturerDialog extends StatefulWidget {
  const CreateManufacturerDialog({super.key});

  @override
  State<CreateManufacturerDialog> createState() => _CreateManufacturerDialogState();
}

class _CreateManufacturerDialogState extends State<CreateManufacturerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _balance = TextEditingController(text: '0');
  final _tax = TextEditingController();
  String? _type;
  List<String> _types = [];
  bool _loadingTypes = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final ds = StagesRemoteDataSource(Supabase.instance.client);
      final names = await ds.listActiveStageNames();
      setState(() {
        _types = names;
        _loadingTypes = false;
      });
    } catch (_) {
      setState(() => _loadingTypes = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _balance.dispose();
    _tax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManufacturersProvider>(
      builder: (context, prov, _) {
        return Dialog(
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Text('إضافة مصنع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'الاسم'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phone,
                          decoration: const InputDecoration(labelText: 'الهاتف'),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _type,
                                decoration: const InputDecoration(labelText: 'النوع'),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('بدون')),
                                  ..._types.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))).toList(),
                                ],
                                onChanged: (v) => setState(() => _type = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'إضافة مرحلة جديدة',
                              onPressed: () async {
                                final created = await showDialog<String>(
                                  context: context,
                                  builder: (_) => const _AddStageDialog(),
                                );
                                if (created != null && created.isNotEmpty) {
                                  await _loadTypes();
                                  setState(() => _type = created);
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (_loadingTypes) const Padding(
                          padding: EdgeInsets.only(top: 6.0),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(labelText: 'العنوان'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _tax,
                          decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _balance,
                          decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;
                                final ok = await prov.create(
                                  ManufacturerInput(
                                    name: _name.text.trim(),
                                    phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                                    email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                                    address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                                    balance: double.tryParse(_balance.text.trim()) ?? 0.0,
                                    type: _type,
                                    taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
                                  ),
                                );
                                if (ok && context.mounted) {
                                  Navigator.pop(context, true);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إضافة المصنع')));
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل إضافة المصنع')));
                                }
                              },
                              child: const Text('حفظ'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                          ),
                        ])
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
  }
}

class _ManufacturersTabState extends State<ManufacturersTab> {
  final _searchCtrl = TextEditingController();
  String? _typeFilter;
  List<String> _types = [];
  bool _loadingTypes = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final ds = StagesRemoteDataSource(Supabase.instance.client);
      final names = await ds.listActiveStageNames();
      setState(() {
        _types = names;
        _loadingTypes = false;
      });
    } catch (_) {
      setState(() => _loadingTypes = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ManufacturersProvider>(
      builder: (context, prov, _) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث المصنّعين...'),
                  onChanged: prov.setSearch,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list), labelText: 'تصفية حسب النوع'),
                  value: _typeFilter,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
                    ..._types.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))).toList(),
                  ],
                  onChanged: (v) {
                    setState(() => _typeFilter = v);
                    prov.setTypeFilter(v);
                  },
                ),
                if (_loadingTypes) const Padding(
                  padding: EdgeInsets.only(top: 6.0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                const SizedBox(height: 12),
                if (prov.isLoading) const Center(child: CircularProgressIndicator()),
                if (!prov.isLoading && prov.error != null) Text(prov.error!),
                if (!prov.isLoading && prov.error == null) ...[
                  ...prov.items.map((m) => _ManufacturerTile(m)).toList(),
                  if (prov.items.isEmpty) const Text('لا توجد بيانات'),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManufacturerTile extends StatelessWidget {
  final Manufacturer m;
  const _ManufacturerTile(this.m);

  @override
  Widget build(BuildContext context) {
    final prov = context.read<ManufacturersProvider>();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(0),
        onTap: () {
          // يمكن إضافة وظيفة عند الضغط على الكارت لاحقاً
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الكارت مع الاسم والنقاط الثلاث في نفس السطر
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المصنع
                  Expanded(
                    child: Text(
                      m.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.2,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          await showDialog(
                            context: context,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<ManufacturersProvider>(),
                              child: _EditManufacturerDialog(m: m),
                            ),
                          );
                          break;
                        case 'edit_fields':
                          await showDialog<bool>(
                            context: context,
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<ManufacturersProvider>(),
                              child: _EditManufacturerStagesDialog(manufacturerId: m.id, manufacturerName: m.name),
                            ),
                          );
                          break;
                        case 'statement':
                          if (context.mounted) {
                            context.push('/manufacturers/${m.id}/statement');
                          }
                          break;
                        case 'statistics':
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('إحصائيات المصنع ${m.name} ستتوفر قريباً')),
                          );
                          break;
                        case 'payments':
                          if (context.mounted) {
                            context.push('/manufacturers/${m.id}/payments');
                          }
                          break;
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('تأكيد الحذف'),
                              content: Text('هل أنت متأكد من حذف ${m.name}؟'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final ok = await prov.deleteOne(m.id);
                            if (ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المصنع')));
                            }
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('تعديل البيانات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit_fields',
                        child: Row(
                          children: [
                            Icon(Icons.business_center, color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 8),
                            Text('تعديل المجالات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'statement',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('كشف الحساب', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'statistics',
                        child: Row(
                          children: [
                            Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('الإحصائيات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'payments',
                        child: Row(
                          children: [
                            Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('الدفعات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 8),
              // إجمالي العمليات والدفعات
              FutureBuilder<Map<String, dynamic>>(
                future: prov.getManufacturerFullSummary(m.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 20,
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final data = snapshot.data!;
                  final totalOps = (data['total_operations'] as num?)?.toDouble() ?? 0.0;
                  final totalPays = (data['total_payments'] as num?)?.toDouble() ?? 0.0;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoRow(
                              icon: Icons.precision_manufacturing,
                              iconColor: Colors.green,
                              child: Text(
                                'م: ${totalOps.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoRow(
                              icon: Icons.payment,
                              iconColor: Colors.blue,
                              child: Text(
                                'د: ${totalPays.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              // الرصيد
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: _InfoRow(
                  icon: Icons.account_balance,
                  iconColor: m.balance < 0
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  child: Row(
                    children: [
                      Text(
                        'رصيد: ${m.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: m.balance < 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (m.balance < 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'مدين',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // مجالات/مراحل المصنع بأسلوب حبات مشابه للمورد باستخدام _InfoRow
              FutureBuilder<List<String>>(
                future: _loadStageNames(context, m.id),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2));
                  }
                  if (snap.hasError) {
                    return const SizedBox.shrink();
                  }
                  final names = snap.data ?? const [];
                  if (names.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _InfoRow(
                      icon: Icons.business,
                      iconColor: Theme.of(context).colorScheme.secondary,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: names
                            .map((n) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    n,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  );
                },
              ),
              if (m.taxNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.numbers, size: 18),
                      const SizedBox(width: 8),
                      Text('الرقم الضريبي: ${m.taxNumber!}')
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _loadStageNames(BuildContext context, String manufacturerId) async {
    final prov = context.read<ManufacturersProvider>();
    final stageIds = await prov.getStages(manufacturerId); // [uuid]
    if (stageIds.isEmpty) return [];
    final ds = StagesRemoteDataSource(Supabase.instance.client);
    final all = await ds.listActiveStages(); // [{id, stage_name}]
    final byId = {for (final e in all) (e['id'] as String): (e['stage_name'] as String)};
    return stageIds.map((id) => byId[id]).whereType<String>().toList();
  }
}

class _EditManufacturerDialog extends StatefulWidget {
  final Manufacturer m;
  const _EditManufacturerDialog({required this.m});

  @override
  State<_EditManufacturerDialog> createState() => _EditManufacturerDialogState();
}

class _EditManufacturerDialogState extends State<_EditManufacturerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _balance;
  late final TextEditingController _tax;
  

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.m.name);
    _phone = TextEditingController(text: widget.m.phone ?? '');
    _email = TextEditingController(text: widget.m.email ?? '');
    _address = TextEditingController(text: widget.m.address ?? '');
    _balance = TextEditingController(text: widget.m.balance.toString());
    _tax = TextEditingController(text: widget.m.taxNumber ?? '');
    
  }

  

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _balance.dispose();
    _tax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ManufacturersProvider>();
    return Dialog(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تعديل مصنع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balance,
                    decoration: const InputDecoration(labelText: 'الرصيد'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;
                          final ok = await prov.updateOne(
                            widget.m.id,
                            ManufacturerInput(
                              name: _name.text.trim(),
                              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                              email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                              address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                              balance: double.tryParse(_balance.text.trim()) ?? 0.0,
                              
                              taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
                            ),
                          );
                          if (ok && context.mounted) {
                            Navigator.pop(context, true);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ بيانات المصنع')));
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل حفظ بيانات المصنع')));
                          }
                        },
                        child: const Text('حفظ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                  ])
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
