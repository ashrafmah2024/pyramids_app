import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _didRedirect = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Redirect by role on first build after app reopen
    if (_didRedirect) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didRedirect) return;
      final auth = context.read<AuthProvider>();
      final role = auth.currentUser?.role.toLowerCase();
      String? target;
      if (role == 'manager') {
        target = AppRouter.manager;
      } else if (role == 'accountant') {
        target = AppRouter.accountant;
      }
      if (target != null && target != AppRouter.dashboard) {
        _didRedirect = true;
        context.go(target);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم', style: AppTextStyles.appBarTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 600
                          ? 4
                          : 2,
                      childAspectRatio: MediaQuery.of(context).size.width > 600
                          ? 1.1
                          : 0.9,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _DashboardTile(
                          icon: Icons.people_outline,
                          title: 'إدارة المستخدمين',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () => context.push(AppRouter.users),
                        ),
                        // يمكن إضافة بطاقات أخرى للميزات القادمة هنا
                      ],
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
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.primaryContainer;
    final foregroundColor = scheme.onPrimaryContainer;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: foregroundColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(color: foregroundColor),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
