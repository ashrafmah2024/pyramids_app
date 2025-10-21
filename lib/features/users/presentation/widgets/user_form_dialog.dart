import 'package:flutter/material.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:pyramids/features/users/domain/entities/user.dart';
import 'package:pyramids/features/users/domain/entities/user_role.dart';
import 'package:pyramids/features/users/domain/entities/user_status.dart';
import 'package:pyramids/features/users/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';

class UserFormDialog extends StatefulWidget {
  final User? user;

  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  
  // أدوار ديناميكية من جدول roles
  List<Map<String, String>> _roles = []; // [{slug: 'admin', name_ar: 'مدير النظام'}]
  String? _selectedRoleSlug; // نخزن slug المختار
  bool _isLoadingRoles = false;

  UserStatus _selectedStatus = UserStatus.active;
  bool _isEditMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.user != null;
    
    _fullNameController = TextEditingController(text: widget.user?.fullName ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _phoneNumberController = TextEditingController(text: widget.user?.phoneNumber ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    
    if (_isEditMode) {
      _selectedRoleSlug = widget.user!.role.toString().split('.').last;
      _selectedStatus = widget.user!.status;
    }

    // حمّل قائمة الأدوار من Supabase
    _loadRoles();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoadingRoles = true);
    try {
      final client = Supabase.instance.client;
      // نجلب الأدوار النشطة فقط، ونستعمل name_ar للعرض وslug للقيمة
      final data = await client
          .from('roles')
          .select('slug, name_ar')
          .eq('is_active', true)
          .order('name_ar');

      final roles = (data as List)
          .map((e) => {
                'slug': (e['slug'] ?? '').toString(),
                'name_ar': (e['name_ar'] ?? '').toString(),
              })
          .where((e) => e['slug']!.isNotEmpty)
          .toList();

      // إن لم يكن هناك اختيار مسبق، اختر viewer إن وجد وإلا أول عنصر
      String? initialSlug = _selectedRoleSlug;
      if (initialSlug == null || initialSlug.isEmpty) {
        if (roles.any((r) => r['slug'] == 'viewer')) {
          initialSlug = 'viewer';
        } else if (roles.isNotEmpty) {
          initialSlug = roles.first['slug'];
        }
      }

      setState(() {
        _roles = roles;
        _selectedRoleSlug = initialSlug;
      });
    } catch (e) {
      // في حال الفشل، احتفظ بالقائمة الفارغة
    } finally {
      if (mounted) setState(() => _isLoadingRoles = false);
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final userProvider = context.read<UserProvider>();
      final auth = context.read<AuthProvider>();
      final currentRole = auth.currentUser?.role ?? '';
      final isAdminManager = currentRole == 'admin' || currentRole == 'manager';
      
      // تحديد الدور المرسل:
      // - إن كان إداري/مدير: استخدم الاختيار من القائمة
      // - غير ذلك: احتفظ بدور المستخدم الحالي عند التعديل
      UserRole roleEnum;
      if (isAdminManager) {
        roleEnum = UserRole.values.firstWhere(
          (e) => e.toString() == 'UserRole.${_selectedRoleSlug ?? 'viewer'}',
          orElse: () => UserRole.viewer,
        );
      } else {
        roleEnum = widget.user?.role ?? UserRole.viewer;
      }

      final user = User(
        id: widget.user?.id ?? '',
        fullName: _fullNameController.text.trim(),
        username: _emailController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim().isNotEmpty
            ? _phoneNumberController.text.trim()
            : null,
        passwordHash: _passwordController.text.isNotEmpty
            ? _passwordController.text // In a real app, hash this password
            : widget.user?.passwordHash ?? '',
        role: roleEnum,
        status: _selectedStatus,
        createdAt: widget.user?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        lastLoginAt: widget.user?.lastLoginAt,
        lastLoginIp: widget.user?.lastLoginIp,
        lastLoginDevice: widget.user?.lastLoginDevice,
        lastLoginLocation: widget.user?.lastLoginLocation,
      );

      bool success;
      if (_isEditMode) {
        success = await userProvider.updateUser(user);
      } else {
        success = await userProvider.createUser(user);
      }

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final currentRole = auth.currentUser?.role ?? '';
    final isAdminManager = currentRole == 'admin' || currentRole == 'manager';
    
    return AlertDialog(
      title: Text(_isEditMode ? 'تعديل المستخدم' : 'إضافة مستخدم جديد'),
      content: SingleChildScrollView(
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
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                readOnly: !_isEditMode ? false : !isAdminManager, // لغير الإداريين أثناء التعديل اجعله للعرض فقط
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(errorText: 'هذا الحقل مطلوب'),
                  FormBuilderValidators.email(errorText: 'بريد إلكتروني غير صالح'),
                ]),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف (اختياري)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
              ),
              if (!_isEditMode) ...[
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  validator: FormBuilderValidators.compose([
                    if (!_isEditMode)
                      FormBuilderValidators.required(
                          errorText: 'هذا الحقل مطلوب'),
                    if (!_isEditMode && _passwordController.text.isNotEmpty)
                      FormBuilderValidators.minLength(6,
                          errorText: 'يجب أن تكون كلمة المرور 6 أحرف على الأقل'),
                  ]),
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  textDirection: TextDirection.ltr,
                  validator: (value) {
                    if (!_isEditMode && value!.isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    if (value != _passwordController.text) {
                      return 'كلمات المرور غير متطابقة';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16.0),
              // قائمة الأدوار تظهر فقط للإداريين والمدراء
              if (isAdminManager)
                DropdownButtonFormField<String>(
                  value: _selectedRoleSlug,
                  decoration: const InputDecoration(
                    labelText: 'الدور',
                    prefixIcon: Icon(Icons.people_outline),
                  ),
                  items: _roles.map((r) {
                    return DropdownMenuItem<String>(
                      value: r['slug'],
                      child: Text(r['name_ar'] ?? r['slug']!),
                    );
                  }).toList(),
                  onChanged: _isLoadingRoles
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRoleSlug = value;
                          });
                        },
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'هذا الحقل مطلوب'),
                  ]),
                ),
              const SizedBox(height: 16.0),
              if (_isEditMode && isAdminManager)
                DropdownButtonFormField<UserStatus>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    prefixIcon: Icon(Icons.circle_outlined),
                  ),
                  items: UserStatus.values.map((status) {
                    return DropdownMenuItem<UserStatus>(
                      value: status,
                      child: Text(_getStatusDisplayName(status)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    }
                  },
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(errorText: 'هذا الحقل مطلوب'),
                  ]),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text(_isEditMode ? 'حفظ التغييرات' : 'إضافة مستخدم'),
        ),
      ],
    );
  }

  String _getStatusDisplayName(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return 'نشط';
      case UserStatus.inactive:
        return 'غير نشط';
      case UserStatus.suspended:
        return 'موقوف';
      case UserStatus.pending:
        return 'في انتظار التفعيل';
      default:
        return status.toString().split('.').last;
    }
  }
 }
