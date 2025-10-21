import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pyramids/features/auth/presentation/widgets/change_own_password_dialog.dart';
import 'package:pyramids/features/auth/presentation/widgets/update_own_profile_dialog.dart';
import 'package:pyramids/core/theme/app_theme.dart';

class AccountantScreen extends StatelessWidget {
  const AccountantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final width = MediaQuery.of(context).size.width;

    return Consumer<AppTheme>(
      builder: (context, appTheme, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: colorScheme.primary,
            centerTitle: true,
            elevation: 0,
            iconTheme: IconThemeData(color: colorScheme.onPrimary),
            title: Text(
              'شاشة المحاسب',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'الوضع الليلي',
                icon: Icon(
                  appTheme.isDarkMode
                      ? Icons.light_mode
                      : Icons.nightlight_round,
                  color: colorScheme.onPrimary,
                ),
                onPressed: () {
                  appTheme.toggleTheme();
                },
              ),
              IconButton(
                tooltip: 'التنبيهات',
                icon: Icon(
                  Icons.notifications_none,
                  color: colorScheme.onPrimary,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('لا توجد تنبيهات جديدة')),
                  );
                },
              ),
              IconButton(
                tooltip: 'تحديث',
                icon: Icon(Icons.refresh, color: colorScheme.onPrimary),
                onPressed: () async {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم التحديث بنجاح')),
                  );
                },
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home),
                    title: const Text(
                      'الصفحة الرئيسية',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      AppRouter.navigateToAndRemoveUntil(
                        context,
                        AppRouter.dashboard,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text(
                      'الإعدادات',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (context) => UpdateOwnProfileDialog(
                          fullName: user?.fullName,
                          phoneNumber: user?.phoneNumber,
                        ),
                      );
                      if (result != null) {
                        try {
                          await auth.updateProfile(
                            fullName: result['fullName'],
                            phoneNumber: (result['phoneNumber'] ?? '').isEmpty
                                ? null
                                : result['phoneNumber'],
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم حفظ البيانات بنجاح'),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(auth.error ?? 'فشل حفظ البيانات'),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_reset_outlined),
                    title: const Text(
                      'تغيير كلمة المرور',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (context) => const ChangeOwnPasswordDialog(),
                      );
                      final current = result?['current'] ?? '';
                      final next = result?['new'] ?? '';
                      if (current.isNotEmpty && next.isNotEmpty) {
                        try {
                          await auth.changePassword(current, next);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تغيير كلمة المرور بنجاح'),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  auth.error ?? 'فشل تغيير كلمة المرور',
                                ),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(fontFamily: 'Cairo'),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                      } catch (_) {}
                      try {
                        await auth.signOut();
                      } catch (_) {}
                      if (context.mounted) {
                        AppRouter.navigateToAndRemoveUntil(
                          context,
                          AppRouter.login,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'Cairo'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'مرحباً ${user?.fullName ?? ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 16),
                      _SummarySection(),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: width < 400 ? 1 : 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _AccountantTile(
                            icon: Icons.work_outline,
                            color: Colors.indigo,
                            title: 'العمليات (قراءة فقط)',
                            onTap: () {
                              AppRouter.navigateTo(
                                context,
                                '${AppRouter.operations}?readonly=1',
                              );
                            },
                          ),
                          _AccountantTile(
                            icon: Icons.receipt_long,
                            color: Colors.blue,
                            title: 'الفواتير والمشتريات',
                            onTap: () {
                              AppRouter.navigateTo(
                                context,
                                AppRouter.accountingInvoices,
                              );
                            },
                          ),
                          _AccountantTile(
                            icon: Icons.money_off,
                            color: Colors.redAccent,
                            title: 'النفقات العامة',
                            onTap: () {
                              AppRouter.navigateTo(
                                context,
                                AppRouter.accountingExpenses,
                              );
                            },
                          ),
                          _AccountantTile(
                            icon: Icons.account_balance_wallet,
                            color: Colors.green,
                            title: 'المدفوعات والتحصيل',
                            onTap: () {
                              AppRouter.navigateTo(
                                context,
                                AppRouter.accountingPayments,
                              );
                            },
                          ),
                          _AccountantTile(
                            icon: Icons.people,
                            color: Colors.teal,
                            title: 'كشوف حساب',
                            onTap: () {
                              AppRouter.navigateTo(
                                context,
                                AppRouter.partners,
                              );
                            },
                          ),
                          _AccountantTile(
                            icon: Icons.bar_chart,
                            color: Colors.orange,
                            title: 'التقارير المالية',
                            onTap: () {
                              AppRouter.navigateTo(
                                context,
                                AppRouter.accountingReports,
                              );
                            },
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
      },
    );
  }
}

class _SummarySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 400;
    final cards = [
      const _SummaryCard(
        title: 'إجمالي الإيرادات',
        amount: '0.00',
        color: Colors.green,
        icon: Icons.trending_up,
      ),
      const _SummaryCard(
        title: 'إجمالي المصروفات',
        amount: '0.00',
        color: Colors.redAccent,
        icon: Icons.trending_down,
      ),
      const _SummaryCard(
        title: 'الرصيد الحالي',
        amount: '0.00',
        color: Colors.blue,
        icon: Icons.account_balance,
      ),
    ];

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          cards[0],
          const SizedBox(height: 8),
          cards[1],
          const SizedBox(height: 8),
          cards[2],
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        cards[2],
        const SizedBox(width: 12),
        cards[1],
        const SizedBox(width: 12),
        cards[0],
      ],
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final String title;
  final String amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return IntrinsicWidth(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: _hover ? 10 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.amount} ج.م',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

class _AccountantTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AccountantTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AccountantTile> createState() => _AccountantTileState();
}

class _AccountantTileState extends State<_AccountantTile> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isHovered ? 0.05 : 0.02),
                  blurRadius: _isHovered ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 96),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
