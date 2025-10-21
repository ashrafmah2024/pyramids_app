import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pyramids/features/auth/presentation/screens/login_screen.dart';
import 'package:pyramids/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:pyramids/features/users/presentation/screens/test_users_screen.dart';
import 'package:pyramids/features/accounting/presentation/screens/accountant_screen.dart';
import 'package:pyramids/features/management/presentation/screens/manager_screen.dart';

class AppRouter {
  static const String dashboard = '/dashboard';
  static const String login = '/';
  static const String testUsers = '/test-users';
  static const String accountant = '/accountant';
  static const String manager = '/manager';
  static const String accountingInvoices = '/accounting/invoices';
  static const String accountingExpenses = '/accounting/expenses';
  static const String accountingPayments = '/accounting/payments';
  static const String accountingCustomers = '/accounting/customers';
  static const String accountingReports = '/accounting/reports';

  static final GoRouter router = GoRouter(
    initialLocation: login,
    routes: [
      GoRoute(
        path: login,
        pageBuilder: (context, state) => const MaterialPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: dashboard,
        pageBuilder: (context, state) => const MaterialPage(
          child: DashboardScreen(),
        ),
      ),
      GoRoute(
        path: testUsers,
        pageBuilder: (context, state) => const MaterialPage(
          child: TestUsersScreen(),
        ),
      ),
      GoRoute(
        path: accountant,
        pageBuilder: (context, state) => const MaterialPage(
          child: AccountantScreen(),
        ),
      ),
      GoRoute(
        path: manager,
        pageBuilder: (context, state) => const MaterialPage(
          child: ManagerScreen(),
        ),
      ),
      // يمكنك إضافة المزيد من المسارات هنا
    ],
    errorPageBuilder: (context, state) => MaterialPage(
      child: Scaffold(
        body: Center(
          child: Text('الصفحة غير موجودة: ${state.uri.path}'),
        ),
      ),
    ),
  );
}
