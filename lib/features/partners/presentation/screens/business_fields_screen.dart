import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:go_router/go_router.dart';

class BusinessFieldsScreen extends StatefulWidget {
  const BusinessFieldsScreen({Key? key}) : super(key: key);

  @override
  State<BusinessFieldsScreen> createState() => _BusinessFieldsScreenState();
}

class _BusinessFieldsScreenState extends State<BusinessFieldsScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _query = '';

  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = context.read<SupabaseService>().client;
      final res = await supabase
          .from('business_fields')
          .select('id,name_ar,name_en,description,is_active,created_at')
          .order('name_ar');
      setState(() {
        _items = (res as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((m) {
      final a = (m['name_ar'] ?? '').toString().toLowerCase();
      final b = (m['name_en'] ?? '').toString().toLowerCase();
      final d = (m['description'] ?? '').toString().toLowerCase();
      return a.contains(q) || b.contains(q) || d.contains(q);
    }).toList();
  }

  Future<void> _createOrEdit({Map<String, dynamic>? current}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _UpsertFieldDialog(current: current),
    );
    if (result == true) {
      await _fetch();
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item) async {
    try {
      final supabase = context.read<SupabaseService>().client;
      final updated = !(item['is_active'] as bool? ?? true);
      await supabase
          .from('business_fields')
          .update({'is_active': updated})
          .eq('id', item['id']);
      await _fetch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذا المجال؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final supabase = context.read<SupabaseService>().client;
      await supabase.from('business_fields').delete().eq('id', id);
      await _fetch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المجالات'),
        leading: IconButton(
          onPressed: () {
            // استخدام GoRouter
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.manager);
            }
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: 'رجوع',
        ),
        actions: [
          IconButton(
            onPressed: () => _createOrEdit(),
            icon: const Icon(Icons.add),
            tooltip: 'إضافة مجال',
          ),
          IconButton(
            onPressed: _loading ? null : _fetch,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم المجال أو الوصف...',
                    prefixIcon: Icon(Icons.search),
                    filled: true,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                if (_loading) const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (!_loading && _error == null) ...[
                  ..._filtered.map((m) => _FieldTile(
                        item: m,
                        onEdit: () => _createOrEdit(current: m),
                        onToggleActive: () => _toggleActive(m),
                        onDelete: () => _delete(m['id'] as String),
                      )),
                  if (_filtered.isEmpty) const Center(child: Text('لا توجد بيانات')),
                ],
              ],
            ),
          ),
        ),
      ),
      // تمت إزالة زر الإضافة العائم ونُقل إلى AppBar كأيقونة
    );
  }
}

class _FieldTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  const _FieldTile({required this.item, required this.onEdit, required this.onToggleActive, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final nameAr = (item['name_ar'] ?? '').toString();
    final desc = (item['description'] ?? '').toString();
    final active = (item['is_active'] as bool?) ?? true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.category, color: Colors.deepPurple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nameAr,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (active ? Colors.green : Colors.grey).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(active ? 'نشط' : 'غير نشط'),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(desc),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit),
                        tooltip: 'تعديل',
                      ),
                      IconButton(
                        onPressed: onToggleActive,
                        icon: const Icon(Icons.toggle_on),
                        tooltip: 'تبديل الحالة',
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'حذف',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpsertFieldDialog extends StatefulWidget {
  final Map<String, dynamic>? current;
  const _UpsertFieldDialog({this.current});
  @override
  State<_UpsertFieldDialog> createState() => _UpsertFieldDialogState();
}

class _UpsertFieldDialogState extends State<_UpsertFieldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _desc = TextEditingController();
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final cur = widget.current;
    if (cur != null) {
      _nameAr.text = (cur['name_ar'] ?? '').toString();
      _nameEn.text = (cur['name_en'] ?? '').toString();
      _desc.text = (cur['description'] ?? '').toString();
      _isActive = (cur['is_active'] as bool?) ?? true;
    }
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final supabase = context.read<SupabaseService>().client;
      final data = <String, dynamic>{
        'name_ar': _nameAr.text.trim(),
        'name_en': _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'is_active': _isActive,
      }..removeWhere((k, v) => v == null);

      if (widget.current == null) {
        final res = await supabase.from('business_fields').insert(data).select().maybeSingle();
        if (res == null) {
          throw Exception('تم الإدراج لكن لم يتم عرض الصف بسبب سياسات RLS');
        }
      } else {
        await supabase.from('business_fields').update(data).eq('id', widget.current!['id']);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.current != null;
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
                  Text(isEdit ? 'تعديل مجال' : 'إضافة مجال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameAr,
                    decoration: const InputDecoration(labelText: 'الاسم (عربي)'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم العربي مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameEn,
                    decoration: const InputDecoration(labelText: 'الاسم (إنجليزي) - اختياري'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(labelText: 'الوصف - اختياري'),
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          child: const Text('حفظ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
