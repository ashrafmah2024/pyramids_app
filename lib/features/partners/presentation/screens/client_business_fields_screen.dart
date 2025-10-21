import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/business_field.dart';
import '../../domain/entities/client.dart';
import '../providers/partners_provider.dart';

class ClientBusinessFieldsScreen extends StatefulWidget {
  final Client client;
  
  const ClientBusinessFieldsScreen({
    Key? key,
    required this.client,
  }) : super(key: key);

  @override
  State<ClientBusinessFieldsScreen> createState() => _ClientBusinessFieldsScreenState();
}

class _ClientBusinessFieldsScreenState extends State<ClientBusinessFieldsScreen> {
  late List<BusinessField> _selectedFields;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedFields = List.from(widget.client.businessFields);
  }

  void _toggleField(BusinessField field) {
    setState(() {
      if (_selectedFields.any((f) => f.id == field.id)) {
        _selectedFields.removeWhere((f) => f.id == field.id);
      } else {
        _selectedFields.add(field);
      }
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await context.read<PartnersProvider>().updateClientBusinessFields(
            clientId: widget.client.id,
            fieldIds: _selectedFields.map((f) => f.id).toList(),
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل في تحديث المجالات: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.client.name} - المجالات'),
        actions: [
          IconButton(
            tooltip: 'إضافة مجال',
            onPressed: _isSaving
                ? null
                : () async {
                    final created = await _showAddClientFieldDialog(context);
                    if (created != null) {
                      // حدّث قائمة الحقول العامة ثم اختر الحقل الجديد
                      await context.read<PartnersProvider>().loadAll();
                      setState(() {
                        if (!_selectedFields.any((f) => f.id == created.id)) {
                          _selectedFields.add(created);
                        }
                      });
                    }
                  },
            icon: const Icon(Icons.add),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(left: 16.0, right: 8.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            TextButton(
              onPressed: _saveChanges,
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Consumer<PartnersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }

          final fields = provider.fields;
          
          if (fields.isEmpty) {
            return const Center(child: Text('لا توجد مجالات متاحة'));
          }

          return ListView.builder(
            itemCount: fields.length,
            itemBuilder: (context, index) {
              final field = fields[index];
              final isSelected = _selectedFields.any((f) => f.id == field.id);
              
              return CheckboxListTile(
                title: Text(field.nameAr),
                subtitle: field.nameEn != null ? Text(field.nameEn!) : null,
                value: isSelected,
                onChanged: (_) => _toggleField(field),
                secondary: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<BusinessField?> _showAddClientFieldDialog(BuildContext context) async {
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    BusinessField? created;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('إضافة مجال عميل جديد'),
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
                final res = await prov.createClientBusinessField(
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
}
