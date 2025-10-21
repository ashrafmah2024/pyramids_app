import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/client.dart';

class AddClientPaymentScreen extends StatefulWidget {
  final Client client;
  const AddClientPaymentScreen({super.key, required this.client});

  @override
  State<AddClientPaymentScreen> createState() => _AddClientPaymentScreenState();
}

class _AddClientPaymentScreenState extends State<AddClientPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _operationRefCtrl = TextEditingController();
  String _currency = 'EGP';
  DateTime _date = DateTime.now();
  bool _loading = false;

  final _currencies = const ['EGP', 'USD', 'EUR'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _operationRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول أولاً');

      final data = {
        'client_id': widget.client.id,
        'amount': double.parse(_amountCtrl.text.trim()),
        'direction': 'credit',
        'currency': _currency,
        'created_at': _date.toUtc().toIso8601String(),
        'created_by': user.id,
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        if (_operationRefCtrl.text.trim().isNotEmpty) 'operation_id': _operationRefCtrl.text.trim(),
      };

      await Supabase.instance.client
          .from('client_transactions')
          .insert(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الدفعة')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ الدفعة: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('إضافة دفعة لـ ${widget.client.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'المبلغ مطلوب';
                    final d = double.tryParse(v.trim());
                    if (d == null || d <= 0) return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(labelText: 'العملة', border: OutlineInputBorder()),
                  items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'التاريخ', border: OutlineInputBorder()),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(_date.toLocal().toString().split(' ').first),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _operationRefCtrl,
                  decoration: const InputDecoration(labelText: 'مرجع العملية (اختياري)', prefixIcon: Icon(Icons.tag), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)', prefixIcon: Icon(Icons.note), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _save,
                    child: _loading ? const CircularProgressIndicator() : const Text('حفظ'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
