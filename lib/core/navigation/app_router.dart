import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pyramids/features/auth/presentation/screens/login_screen.dart';
import 'package:pyramids/features/accounting/presentation/screens/accountant_screen.dart';
import 'package:pyramids/features/management/presentation/screens/manager_screen.dart';
import 'package:pyramids/features/users/presentation/screens/users_screen.dart';
import 'package:pyramids/features/partners/presentation/screens/partners_screen.dart';
import 'package:pyramids/features/partners/presentation/screens/business_fields_screen.dart';
import 'package:pyramids/features/manufacturing/presentation/screens/new_operation_screen.dart';
import 'package:pyramids/features/manufacturing/presentation/screens/operation_stages_screen.dart' as manufacturing;
import 'package:pyramids/features/purchases/presentation/screens/purchases_screen.dart';
import 'package:pyramids/features/operations/presentation/screens/operations_screen.dart';
import 'package:pyramids/features/manufacturers/presentation/screens/manufacturer_statement_screen.dart';
import 'package:pyramids/features/manufacturers/presentation/screens/manufacturer_payment_screen.dart';
import 'package:pyramids/features/operations/presentation/screens/operation_details_screen.dart';

class AppRouter {
  // Routes
  static const String dashboard = '/dashboard';
  static const String login = '/';
  static const String accountant = '/accountant';
  static const String manager = '/manager';
  static const String activityLog = '/activity-log';
  static const String accountingInvoices = '/accounting/invoices';
  static const String accountingExpenses = '/accounting/expenses';
  static const String accountingPayments = '/accounting/payments';
  static const String accountingCustomers = '/accounting/customers';
  static const String accountingReports = '/accounting/reports';
  static const String users = '/users';
  static const String partners = '/partners';
  static const String fields = '/fields';
  static const String manufacturingNewOperation = '/manufacturing/new-operation';
  static const String manufacturingOperationStages = '/operations/:id/stages';
  static const String purchases = '/purchases';
  static const String operations = '/operations';
  static const String operationDetails = '/operations/:id/details';

  // GoRouter configuration
  static final router = GoRouter(
    initialLocation: login,
    routes: [
      GoRoute(path: login, builder: (context, state) => const LoginScreen()),
      // Removed dashboard route: use role-based routes instead
      GoRoute(
        path: accountant,
        builder: (context, state) => AccountantScreen(),
      ),
      GoRoute(
        path: manager,
        builder: (context, state) => const ManagerScreen(),
      ),
      GoRoute(
        path: users,
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: partners,
        builder: (context, state) => const PartnersScreen(),
      ),
      GoRoute(
        path: fields,
        builder: (context, state) => const BusinessFieldsScreen(),
      ),
      GoRoute(
        path: purchases,
        builder: (context, state) => const PurchasesScreen(),
      ),
      GoRoute(
        path: operations,
        builder: (context, state) {
          final ro = (state.uri.queryParameters['readonly'] == '1');
          return OperationsScreen(readOnly: ro);
        },
      ),
      GoRoute(
        path: operationDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return OperationDetailsScreen(operationId: id);
        },
      ),
      GoRoute(
        path: accountingInvoices,
        builder: (context, state) => const PurchasesScreen(),
      ),
      // alias for singular path
      GoRoute(
        path: '/operation',
        builder: (context, state) {
          final ro = (state.uri.queryParameters['readonly'] == '1');
          return OperationsScreen(readOnly: ro);
        },
      ),
      GoRoute(
        path: manufacturingNewOperation,
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return NewOperationScreen(initialOperationId: id);
        },
      ),
      GoRoute(
        path: manufacturingOperationStages,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return manufacturing.OperationStagesScreen(operationId: id);
        },
      ),
      GoRoute(
        path: '/manufacturers/:id/statement',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ManufacturerStatementScreen(manufacturerId: id);
        },
      ),
      GoRoute(
        path: '/manufacturers/:id/payments',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ManufacturerPaymentScreen(manufacturerId: id);
        },
      ),
      GoRoute(
        path: activityLog,
        builder: (context, state) => const ActivityLogScreen(),
      ),
      // Add other routes here
    ],
  );

  // Navigation methods
  static void navigateTo(BuildContext context, String routeName) {
    context.go(routeName);
  }

  static void navigateToAndRemoveUntil(
    BuildContext context,
    String routeName, {
    bool Function(Route<dynamic>)? predicate,
  }) {
    context.go(routeName);
    // If you need to remove routes, you can use:
    // context.go(routeName);
    // Then pop all routes until the predicate is true
  }

  static void goBack(BuildContext context) {
    context.pop();
  }
}

// For backward compatibility
extension AppRouterLegacy on AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case AppRouter.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case AppRouter.dashboard:
        // For backward compatibility, redirect dashboard to ManagerScreen
        return MaterialPageRoute(
          builder: (_) => const ManagerScreen(),
          settings: settings,
        );
      case AppRouter.accountant:
        return MaterialPageRoute(
          builder: (_) => AccountantScreen(),
          settings: settings,
        );
      case AppRouter.manager:
        return MaterialPageRoute(
          builder: (_) => const ManagerScreen(),
          settings: settings,
        );
      case AppRouter.activityLog:
        return MaterialPageRoute(
          builder: (_) => const ActivityLogScreen(),
          settings: settings,
        );
      case AppRouter.accountingInvoices:
        return MaterialPageRoute(
          builder: (_) => const PurchasesScreen(),
          settings: settings,
        );
      case AppRouter.accountingExpenses:
        return MaterialPageRoute(
          builder: (_) => _PlaceholderScreen(title: 'النفقات العامة'),
          settings: settings,
        );
      case AppRouter.accountingPayments:
        return MaterialPageRoute(
          builder: (_) => _PlaceholderScreen(title: 'المدفوعات والتحصيل'),
          settings: settings,
        );
      case AppRouter.accountingCustomers:
        return MaterialPageRoute(
          builder: (_) => _PlaceholderScreen(title: 'كشف حساب العملاء'),
          settings: settings,
        );
      case AppRouter.accountingReports:
        return MaterialPageRoute(
          builder: (_) => _PlaceholderScreen(title: 'التقارير المالية'),
          settings: settings,
        );
      case AppRouter.partners:
        return MaterialPageRoute(
          builder: (_) => const PartnersScreen(),
          settings: settings,
        );
      case AppRouter.fields:
        return MaterialPageRoute(
          builder: (_) => const BusinessFieldsScreen(),
          settings: settings,
        );
      case AppRouter.purchases:
        return MaterialPageRoute(
          builder: (_) => const PurchasesScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('خطأ')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('لا يوجد مسار محدد لـ ${settings.name}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRouter.manager,
                    ),
                    child: const Text('العودة للرئيسية'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  static void navigateTo(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  static void navigateToAndRemoveUntil(
    BuildContext context,
    String routeName, {
    bool Function(Route<dynamic>)? predicate,
  }) {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(routeName, predicate ?? (route) => false);
  }

  static void goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
