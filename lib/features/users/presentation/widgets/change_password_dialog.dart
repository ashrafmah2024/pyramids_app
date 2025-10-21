import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

class ChangePasswordDialog extends StatefulWidget {
  final String userFullName;
  const ChangePasswordDialog({super.key, required this.userFullName});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_passwordController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تغيير كلمة المرور لـ ${widget.userFullName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                  icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              obscureText: _obscure1,
              textDirection: TextDirection.ltr,
              validator: FormBuilderValidators.compose([
                FormBuilderValidators.required(errorText: 'هذا الحقل مطلوب'),
                FormBuilderValidators.minLength(6, errorText: 'يجب أن تكون كلمة المرور 6 أحرف على الأقل'),
              ]),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                  icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              ),
              obscureText: _obscure2,
              textDirection: TextDirection.ltr,
              validator: (v) {
                if ((v ?? '').isEmpty) return 'هذا الحقل مطلوب';
                if (v != _passwordController.text) return 'كلمات المرور غير متطابقة';
                return null;
              },
            ),
          ],
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
        )
      ],
    );
  }
}
