import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'dart:math' as math;

class UpdateOwnProfileDialog extends StatefulWidget {
  final String? fullName;
  final String? phoneNumber;
  const UpdateOwnProfileDialog({super.key, this.fullName, this.phoneNumber});

  @override
  State<UpdateOwnProfileDialog> createState() => _UpdateOwnProfileDialogState();
}

class _UpdateOwnProfileDialogState extends State<UpdateOwnProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.fullName ?? '');
    _phoneController = TextEditingController(text: widget.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('تعديل البيانات الشخصية'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(MediaQuery.of(context).size.width * 0.95, 720),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textDirection: TextDirection.rtl,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'هذا الحقل مطلوب'),
                  ]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف (اختياري)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
