import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'dart:math' as math;

class ChangeOwnPasswordDialog extends StatefulWidget {
  const ChangeOwnPasswordDialog({super.key});

  @override
  State<ChangeOwnPasswordDialog> createState() =>
      _ChangeOwnPasswordDialogState();
}

class _ChangeOwnPasswordDialogState extends State<ChangeOwnPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop({
        'current': _currentPasswordController.text.trim(),
        'new': _newPasswordController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text('تغيير كلمة المرور'),
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
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: ' الحالية',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureCurrent = !_obscureCurrent),
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscureCurrent,
                  textDirection: TextDirection.ltr,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: 'هذا الحقل مطلوب',
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: ' الجديدة',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscureNew,
                  textDirection: TextDirection.ltr,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(
                      errorText: 'هذا الحقل مطلوب',
                    ),
                    FormBuilderValidators.minLength(
                      6,
                      errorText: 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'تأكيد ',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  obscureText: _obscureConfirm,
                  textDirection: TextDirection.ltr,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'هذا الحقل مطلوب';
                    if (v != _newPasswordController.text)
                      return 'كلمات المرور غير متطابقة';
                    return null;
                  },
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
        ElevatedButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }
}
