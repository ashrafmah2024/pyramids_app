import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManufacturerPaymentScreen extends StatefulWidget {
  final String manufacturerId;
  const ManufacturerPaymentScreen({super.key, required this.manufacturerId});

  @override
  State<ManufacturerPaymentScreen> createState() => _ManufacturerPaymentScreenState();
}

class _ManufacturerPaymentScreenState extends State<ManufacturerPaymentScreen> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  Map<String, dynamic>? _manufacturer;

  @override
  void initState() {
    super.initState();
    _loadManufacturer();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManufacturer() async {
    try {
      final m = await Supabase.instance.client
          .from('manufacturers')
          .select('id,name,balance')
          .eq('id', widget.manufacturerId)
          .maybeSingle();
      if (m != null) setState(() => _manufacturer = Map<String, dynamic>.from(m as Map<String, dynamic>));
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المبلغ غير صالح')));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      // 1) Insert debit transaction (payment to manufacturer)
      await client.from('manufacturer_transactions').insert({
        'manufacturer_id': widget.manufacturerId,
        'operation_id': null,
        'stage_id': null,
        'amount': amount,
        'direction': 'debit',
        'currency': 'EGP',
        'notes': _notesCtrl.text.trim().isEmpty ? 'دفعة للمصنع' : _notesCtrl.text.trim(),
      });
      // 2) Update manufacturer balance (- amount)
      try {
        final row = await client
            .from('manufacturers')
            .select('balance')
            .eq('id', widget.manufacturerId)
            .maybeSingle();
        final cur = (row is Map<String, dynamic>) ? ((row['balance'] as num?) ?? 0) : 0;
        await client
            .from('manufacturers')
            .update({'balance': cur - amount})
            .eq('id', widget.manufacturerId);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الدفعة')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل حفظ الدفعة: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = 'دفعة للمصنع' + (_manufacturer?['name'] != null ? ' - ${_manufacturer!['name']}' : '');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text('حفظ الدفعة'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
