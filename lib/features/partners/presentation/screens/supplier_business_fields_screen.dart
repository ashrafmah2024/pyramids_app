import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/business_field.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_field.dart';
import '../providers/partners_provider.dart';

class SupplierBusinessFieldsScreen extends StatefulWidget {
  final Supplier supplier;
  const SupplierBusinessFieldsScreen({super.key, required this.supplier});

  @override
  State<SupplierBusinessFieldsScreen> createState() => _SupplierBusinessFieldsScreenState();
}

class _SupplierBusinessFieldsScreenState extends State<SupplierBusinessFieldsScreen> {
  late List<String> _selectedFieldIds = [];
  late List<BusinessField> _availableFields = [];
  late List<SupplierField> _currentFields = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final prov = context.read<PartnersProvider>();

    // تحميل المجالات الحالية للمورد
    final currentFieldsEither = await prov.getSupplierFields(widget.supplier.id);
    currentFieldsEither.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل مجالات المورد: $l')),
      ),
      (fields) {
        setState(() {
          _currentFields = fields;
          _selectedFieldIds = fields.map((f) => f.fieldId).whereType<String>().toList();
        });
      },
    );

    // تحميل جميع مجالات المورد المتاحة
    final allFieldsEither = await prov.getSupplierFieldDefinitions();
    allFieldsEither.fold(
      (l) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المجالات: $l')),
      ),
      (fields) {
        setState(() {
          _availableFields = fields;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مجالات ${widget.supplier.name}'),
        actions: [
          IconButton(
            tooltip: 'إضافة مجال',
            onPressed: _isLoading
                ? null
                : () async {
                    final created = await _showAddSupplierFieldDialog(context);
                    if (created != null) {
                      setState(() {
                        _availableFields.insert(0, created);
                        _selectedFieldIds.add(created.id);
                      });
                    }
                  },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'حفظ التغييرات',
            onPressed: _isLoading ? null : _saveChanges,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختر المجالات التي يعمل بها المورد:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ..._availableFields.map((field) => CheckboxListTile(
                    title: Text(field.nameAr),
                    subtitle: field.description != null ? Text(field.description!) : null,
                    value: _selectedFieldIds.contains(field.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedFieldIds.add(field.id);
                        } else {
                          _selectedFieldIds.remove(field.id);
                        }
                      });
                    },
                  )),
                  if (_availableFields.isEmpty)
                    const Center(
                      child: Text('لا توجد مجالات متاحة'),
                    ),
                ],
              ),
            ),
    );
  }

  Future<BusinessField?> _showAddSupplierFieldDialog(BuildContext context) async {
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    BusinessField? created;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إضافة مجال مورد جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameArCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم بالعربية *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameEnCtrl,
                  decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'وصف'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () async {
                final nameAr = nameArCtrl.text.trim();
                if (nameAr.isEmpty) return;
                final prov = context.read<PartnersProvider>();
                final res = await prov.createSupplierBusinessField(
                  nameAr: nameAr,
                  nameEn: nameEnCtrl.text.trim().isEmpty ? null : nameEnCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                );
                res.fold(
                  (l) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل إنشاء المجال: $l')),
                    );
                  },
                  (field) {
                    created = field;
                    Navigator.of(ctx).pop();
                  },
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    return created;
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    final prov = context.read<PartnersProvider>();
    // تحقق من أن كل المعرفات موجودة فعلاً في supplier_fields
    final defsEither = await prov.getSupplierFieldDefinitions();
    final defs = defsEither.fold<List<BusinessField>>((l) => const [], (r) => r);
    final validSet = defs.map((e) => e.id).toSet();
    final filteredIds = _selectedFieldIds.where((id) => validSet.contains(id)).toList();

    final success = await prov.updateSupplierBusinessFields(
      supplierId: widget.supplier.id,
      fieldIds: filteredIds,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        final diff = _selectedFieldIds.length - filteredIds.length;
        if (diff > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم حفظ ${filteredIds.length} مجال. تم تجاهل ${diff} مجال غير موجود في جدول الموردين.')),
          );
        }
        Navigator.of(context).pop(true);
      } else {
        final err = prov.error ?? 'حدث خطأ أثناء حفظ التغييرات';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.toString())),
        );
      }
    }
  }
}
