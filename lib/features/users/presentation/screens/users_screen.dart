import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:pyramids/features/users/domain/entities/user.dart';
import 'package:pyramids/features/users/presentation/providers/user_provider.dart';
import 'package:pyramids/features/users/presentation/widgets/user_form_dialog.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:pyramids/features/users/domain/entities/user_role.dart';
import 'package:pyramids/features/users/presentation/widgets/change_password_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _filteredUsers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Load users when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUsers();
    });
  }

  Future<void> _changePassword(User user) async {
    final auth = context.read<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    final currentUserId = auth.currentUser?.id;
    final canChange = (role == 'admin') ||
        (role == 'manager' && user.role != UserRole.admin) ||
        (user.id == currentUserId);
    if (!canChange) return;

    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) => ChangePasswordDialog(userFullName: user.fullName),
    );

    if (newPassword != null && newPassword.isNotEmpty) {
      final provider = context.read<UserProvider>();
      final ok = await provider.changeUserPassword(
        userId: user.id,
        newPassword: newPassword,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'فشل تغيير كلمة المرور')),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final users = context.watch<UserProvider>().users;
    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    final currentUserId = auth.currentUser?.id;
    final isAdminManager = role == 'admin' || role == 'manager';

    List<User> visibleUsers;
    if (role == 'admin') {
      visibleUsers = users;
    } else if (role == 'manager') {
      // المدير يرى الجميع ما عدا مستخدمي admin
      visibleUsers = users.where((u) => u.role != UserRole.admin).toList();
    } else {
      visibleUsers = users.where((u) => u.id == currentUserId).toList();
    }
    _filteredUsers = _filterUsers(visibleUsers, _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<User> _filterUsers(List<User> users, String query) {
    if (query.isEmpty) return users;
    final lowerCaseQuery = query.toLowerCase();
    return users.where((user) {
      return user.fullName.toLowerCase().contains(lowerCaseQuery) ||
          user.email.toLowerCase().contains(lowerCaseQuery) ||
          user.username.toLowerCase().contains(lowerCaseQuery) ||
          user.phoneNumber?.toLowerCase().contains(lowerCaseQuery) == true;
    }).toList();
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مشرف';
      case UserRole.manager:
        return 'مدير';
      case UserRole.accountant:
        return 'محاسب';
      case UserRole.sales:
        return 'مبيعات';
      case UserRole.warehouse:
        return 'المخزون';
      case UserRole.viewer:
        return 'عرض فقط';
    }
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.redAccent;
      case UserRole.manager:
        return Colors.indigo;
      case UserRole.accountant:
        return Colors.teal;
      case UserRole.sales:
        return Colors.orange;
      case UserRole.warehouse:
        return Colors.brown;
      case UserRole.viewer:
        return Colors.grey;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      final auth = context.read<AuthProvider>();
      final role = auth.currentUser?.role ?? '';
      final currentUserId = auth.currentUser?.id;
      final isAdminManager = role == 'admin' || role == 'manager';
      final allUsers = context.read<UserProvider>().users;
      List<User> visibleUsers;
      if (role == 'admin') {
        visibleUsers = allUsers;
      } else if (role == 'manager') {
        visibleUsers = allUsers.where((u) => u.role != UserRole.admin).toList();
      } else {
        visibleUsers = allUsers.where((u) => u.id == currentUserId).toList();
      }
      _filteredUsers = _filterUsers(visibleUsers, query);
    });
  }

  Future<void> _showUserForm({User? user}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UserFormDialog(user: user),
    );

    if (result == true) {
      // Refresh the users list after adding/updating a user
      await context.read<UserProvider>().loadUsers();
    }
  }

  Future<void> _confirmDelete(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text('هل أنت متأكد من حذف المستخدم $userName؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<UserProvider>();
      final ok = await provider.deleteUser(userId);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المستخدم بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'فشل حذف المستخدم')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final theme = Theme.of(context);

    final auth = context.watch<AuthProvider>();
    final role = auth.currentUser?.role ?? '';
    final currentUserId = auth.currentUser?.id;
    final isAdminManager = role == 'admin' || role == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          if (isAdminManager)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showUserForm(),
              tooltip: 'إضافة مستخدم جديد',
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'بحث...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (userProvider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (userProvider.error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'حدث خطأ: ${userProvider.error}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    else if (_filteredUsers.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('لا توجد مستخدمين لعرضهم'),
                        ),
                      )
                    else
                      ListView.builder(
                        itemCount: _filteredUsers.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return Directionality(
                            textDirection: TextDirection.ltr,
                            child: InkWell(
                              onTap: () {
                                if ((role == 'admin') ||
                                    (role == 'manager' && user.role != UserRole.admin) ||
                                    (user.id == currentUserId)) {
                                  _showUserDetails(user);
                                }
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 0.0,
                                  vertical: 4.0,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: theme.dividerColor),
                                ),
                                child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                                          child: Text(
                                            user.fullName[0].toUpperCase(),
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            user.fullName,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _roleColor(user.role).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: _roleColor(user.role).withOpacity(0.4)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified_user, size: 14, color: _roleColor(user.role)),
                                              const SizedBox(width: 4),
                                              Text(
                                                _roleLabel(user.role),
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: _roleColor(user.role),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.email,
                                      style: theme.textTheme.bodySmall,
                                      textDirection: TextDirection.ltr,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            if ((role == 'admin') ||
                                                (role == 'manager' && user.role != UserRole.admin) ||
                                                (user.id == currentUserId))
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(40, 36),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  side: const BorderSide(color: Colors.indigo),
                                                  foregroundColor: Colors.indigo,
                                                ),
                                                onPressed: () => _showUserForm(user: user),
                                                child: const Icon(
                                                  Icons.edit_outlined,
                                                  color: Colors.indigo,
                                                ),
                                              ),
                                            if ((role == 'admin') ||
                                                (role == 'manager' && user.role != UserRole.admin) ||
                                                (user.id == currentUserId))
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(40, 36),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  side: const BorderSide(color: Colors.orange),
                                                  foregroundColor: Colors.orange,
                                                ),
                                                onPressed: () => _changePassword(user),
                                                child: const Icon(
                                                  Icons.lock_reset_outlined,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            if ((role == 'admin') ||
                                                (role == 'manager' && user.role != UserRole.admin))
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(40, 36),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  side: const BorderSide(color: Colors.redAccent),
                                                  foregroundColor: Colors.redAccent,
                                                ),
                                                onPressed: () => _confirmDelete(user.id, user.fullName),
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showUserDetails(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  user.fullName[0].toUpperCase(),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            _buildDetailRow('الاسم الكامل', user.fullName),
            _buildDetailRow('البريد الإلكتروني', user.email),
            if (user.phoneNumber != null)
              _buildDetailRow('رقم الهاتف', user.phoneNumber!),
            _buildDetailRow('الدور', _roleLabel(user.role)),
            _buildDetailRow(
                'الحالة', user.status.toString().split('.').last),
            _buildDetailRow('تاريخ الإنشاء',
                '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}'),
            if (user.lastLoginAt != null)
              _buildDetailRow('آخر ظهور',
                  '${user.lastLoginAt!.day}/${user.lastLoginAt!.month}/${user.lastLoginAt!.year}'),
            FutureBuilder<Map<String, dynamic>?>(
              future: (() async {
                try {
                  final supabase = context.read<SupabaseService>().client;
                  final data = await supabase
                      .from('activity_logs')
                      .select('action,description,created_at')
                      .eq('user_id', user.id)
                      .order('created_at', ascending: false)
                      .limit(1)
                      .maybeSingle();
                  return data;
                } catch (_) {
                  return null;
                }
              })(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                final m = snap.data;
                String value;
                if (m == null) {
                  value = 'لا يوجد';
                } else {
                  final action = (m['action'] ?? '').toString();
                  final desc = (m['description'] ?? '').toString();
                  final dateStr = (m['created_at'] ?? '').toString();
                  final datePart = dateStr.contains('T') ? dateStr.split('T').first : dateStr;
                  value = <String>[action, if (desc.isNotEmpty) desc, datePart]
                      .where((e) => e.isNotEmpty)
                      .join(' - ');
                }
                return _buildDetailRow('آخر عملية', value);
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
