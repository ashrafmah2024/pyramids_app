import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/features/manufacturers/presentation/pages/manufacturers_tab.dart';
import 'package:pyramids/features/manufacturers/presentation/providers/manufacturers_provider.dart';
import '../../domain/entities/business_field.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/supplier.dart';
import '../providers/partners_provider.dart';
import '../providers/supplier_account_statement_provider.dart';
import '../providers/client_account_statement_provider.dart';
import 'client_business_fields_screen.dart';
import 'supplier_business_fields_screen.dart';
import 'supplier_account_statement_screen.dart';
import 'client_account_statement_screen.dart';
import 'client_payments_screen.dart';
import 'supplier_payments_screen.dart';
final Map<String, Future<List<String>>> _supplierFieldsFutureCache = {};

class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Clear cached futures to prevent reusing any failed futures from previous sessions
    _supplierFieldsFutureCache.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PartnersProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getAppBarTitle(int index) {
    switch (index) {
      case 0:
        return 'إدارة حسابات العملاء';
      case 1:
        return 'إدارة حسابات الموردين';
      case 2:
        return 'إدارة حسابات المصنّعين';
      default:
        return 'إدارة الحسابات';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user's role from AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isManager = authProvider.currentUser?.role.toLowerCase() == 'manager';
    
    return WillPopScope(
      onWillPop: () async {
        final targetRoute = isManager ? AppRouter.manager : AppRouter.accountant;
        AppRouter.navigateToAndRemoveUntil(context, targetRoute);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final targetRoute = isManager ? AppRouter.manager : AppRouter.accountant;
              AppRouter.navigateToAndRemoveUntil(context, targetRoute);
            },
          ),
          title: AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, child) {
              final index = (_tabController.animation!.value + 0.5).toInt();
              return Text(_getAppBarTitle(index));
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              color: Theme.of(context).appBarTheme.backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                tabs: List.generate(3, (index) {
                  final (textColor, bgColor, icon) = _getTabStyle(index, context);
                  final isSelected = _tabController.index == index;
                  final textStyle = TextStyle(
                    color: isSelected ? Colors.white : textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  );
                  
                  return Tab(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? textColor : bgColor,
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : textColor.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: isSelected ? Colors.white : textColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            [
                              'العملاء',
                              'الموردين',
                              'المصنّعين',
                            ][index],
                            style: textStyle,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Clients Tab
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue[900]!.withOpacity(0.2)
                          : Colors.blue[50]!,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: const _ClientsTab(),
              ),
              // Suppliers Tab
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.green[900]!.withOpacity(0.2)
                          : Colors.green[50]!,
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: const _SuppliersTab(),
              ),
              // Manufacturers Tab
              ChangeNotifierProvider<ManufacturersProvider>(
                create: (_) => ManufacturersProvider(Supabase.instance.client)..load(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange[900]!.withOpacity(0.2)
                            : Colors.orange[50]!,
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                  child: const ManufacturersTab(),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final idx = _tabController.index;
            return FloatingActionButton.extended(
              onPressed: () async {
                if (idx == 0) {
                  await showDialog(
                    context: context,
                    builder: (_) => const _CreateClientDialog(),
                  );
                } else if (idx == 1) {
                  await showDialog(
                    context: context,
                    builder: (_) => _CreateSupplierDialog(),
                  );
                } else {
                  // TODO: Implement manufacturer creation dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('إضافة المصنّعين ستتوفر قريباً')),
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: Text(idx == 0 ? 'إضافة عميل' : idx == 1 ? 'إضافة مورد' : 'إضافة مصنع'),
            );
          },
        ),
      ),
    );
  }

  // Helper method to get tab color based on index and theme
  (Color, Color, IconData) _getTabStyle(int index, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final styles = <(Color, Color, IconData)>[
      // Clients
      isDark 
          ? (Colors.blue[200]!, Colors.blue[900]!, Icons.person_outline)
          : (Colors.blue[800]!, Colors.blue[50]!, Icons.person_outline),
      
      // Suppliers
      isDark 
          ? (Colors.green[200]!, Colors.green[900]!, Icons.local_shipping_outlined)
          : (Colors.green[800]!, Colors.green[50]!, Icons.local_shipping_outlined),
      
      // Manufacturers
      isDark
          ? (Colors.purple[200]!, Colors.purple[900]!, Icons.factory_outlined)
          : (Colors.purple[800]!, Colors.purple[50]!, Icons.factory_outlined),
    ];

    return styles[index % styles.length];
  }
}

extension on _SupplierTile {
  Future<List<String>> _loadSupplierFieldNames(BuildContext context, String supplierId) async {
    final prov = context.read<PartnersProvider>();
    final assignedEither = await prov.getSupplierFields(supplierId);
    final ids = assignedEither.fold<List<String>>(
      (l) => const [],
      (rows) => rows.map((e) => e.fieldId).whereType<String>().toList(),
    );
    if (ids.isEmpty) return [];
    final defsEither = await prov.getSupplierFieldDefinitions();
    final defs = defsEither.fold<List<BusinessField>>((l) => const [], (r) => r);
    final byId = {for (final d in defs) d.id: d.nameAr};
    return ids.map((id) => byId[id]).whereType<String>().toList();
  }
}

class _ClientsTab extends StatelessWidget {
  const _ClientsTab();
  @override
  Widget build(BuildContext context) {
    return Consumer<PartnersProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading) return const Center(child: CircularProgressIndicator());
        if (prov.error != null) return Center(child: Text(prov.error!));
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث العملاء...'),
                  onChanged: prov.setClientSearch,
                ),
                const SizedBox(height: 12),
                _FieldsFilter(
                  fields: prov.fields,
                  onChanged: prov.setClientFieldFilter,
                ),
                const SizedBox(height: 12),
                ...prov.clients.map((c) => _ClientTile(c)).toList(),
                if (prov.clients.isEmpty) const Text('لا توجد بيانات'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuppliersTab extends StatelessWidget {
  const _SuppliersTab();
  @override
  Widget build(BuildContext context) {
    return Consumer<PartnersProvider>(
      builder: (context, prov, _) {
        if (prov.isLoading) return const Center(child: CircularProgressIndicator());
        if (prov.error != null) return Center(child: Text(prov.error!));
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'بحث الموردين...'),
                  onChanged: prov.setSupplierSearch,
                ),
                const SizedBox(height: 12),
                _FieldsFilter(
                  fields: prov.fields,
                  onChanged: prov.setSupplierFieldFilter,
                ),
                const SizedBox(height: 12),
                ...prov.suppliers.map((s) => _SupplierTile(s)).toList(),
                if (prov.suppliers.isEmpty) const Text('لا توجد بيانات'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FieldsFilter extends StatelessWidget {
  final List<BusinessField> fields;
  final ValueChanged<String?> onChanged;
  const _FieldsFilter({required this.fields, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      isExpanded: true,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list), labelText: 'تصفية حسب المجال'),
      value: null,
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
        ...fields.map((f) => DropdownMenuItem<String?>(value: f.id, child: Text(f.nameAr))).toList(),
      ],
      onChanged: onChanged,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client c;
  const _ClientTile(this.c);
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(0),
        onTap: () {
          // تم إلغاء فتح شاشة المجالات عند الضغط على الكارت
          // يمكن إضافة وظيفة أخرى هنا إذا لزم الأمر
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الكارت مع الاسم والنقاط الثلاث في نفس السطر
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => _EditClientDialog(client: c),
                          );
                          if (ok == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ بيانات العميل')),
                            );
                          }
                          break;
                        case 'payments':
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ClientPaymentsScreen(client: c),
                            ),
                          );
                          break;
                        case 'edit_fields':
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => ClientBusinessFieldsScreen(client: c),
                            ),
                          );
                          if (result == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تحديث مجالات العميل بنجاح')),
                            );
                          }
                          break;
                        case 'statement':
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider<ClientAccountStatementProvider>(
                                create: (_) => ClientAccountStatementProvider()..initializeWithClient(c),
                                child: ClientAccountStatementScreen(client: c),
                              ),
                            ),
                          );
                          break;
                        case 'statistics':
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('إحصائيات العميل ${c.name} ستتوفر قريباً')),
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('تعديل البيانات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'payments',
                        child: Row(
                          children: [
                            Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('الدفعات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit_fields',
                        child: Row(
                          children: [
                            Icon(Icons.business_center, color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 8),
                            Text('تعديل المجالات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'statement',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('كشف الحساب', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'statistics',
                        child: Row(
                          children: [
                            Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('الإحصائيات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),

              // معلومات العميل مع الأيقونات (كل معلومة في سطر منفصل)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // تم إخفاء الهاتف والبريد بناءً على الطلب

                  // مجالات العمل
                  if (c.businessFields.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: _InfoRow(
                        icon: Icons.business,
                        iconColor: Theme.of(context).colorScheme.secondary,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: c.businessFields
                              .map((f) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      f.nameAr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),

                  // الرصيد
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: context.read<PartnersProvider>().getClientFullSummary(c.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 20,
                            child: LinearProgressIndicator(minHeight: 2),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final summary = snapshot.data!;
                        final totalSales = (summary['total_sales'] as num?)?.toDouble() ?? 0.0;
                        final totalPayments = (summary['total_payments'] as num?)?.toDouble() ?? 0.0;
                        final balance = (summary['balance'] as num?)?.toDouble() ?? 0.0;

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoRow(
                                    icon: Icons.shopping_cart,
                                    iconColor: Colors.green,
                                    child: Text(
                                      'م: ${totalSales.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoRow(
                                    icon: Icons.payment,
                                    iconColor: Colors.blue,
                                    child: Text(
                                      'د: ${totalPayments.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _InfoRow(
                              icon: Icons.account_balance,
                              iconColor: balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                              child: Row(
                                children: [
                                  Text(
                                    'رصيد: ${balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (balance < 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'مدين',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final Supplier s;
  const _SupplierTile(this.s);
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(0),
        onTap: () {
          // يمكن إضافة وظيفة عند الضغط على الكارت
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رأس الكارت مع الاسم والنقاط الثلاث في نفس السطر
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المورد
                  Expanded(
                    child: Text(
                      s.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.2, // تحسين المسافة بين الأسطر
                      ),
                      maxLines: 2, // يسمح بسطرين كحد أقصى
                      overflow: TextOverflow.ellipsis, // إظهار علامات الحذف إذا تجاوز النص سطرين
                    ),
                  ),
                  const SizedBox(width: 8), // مسافة بين الاسم والنقاط
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => _EditSupplierDialog(supplier: s),
                          );
                          if (ok == true && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ بيانات المورد')),
                            );
                          }
                          break;
                        case 'edit_fields':
                          final result = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => SupplierBusinessFieldsScreen(supplier: s),
                            ),
                          );
                          if (result == true && context.mounted) {
                            // إعادة تحميل البيانات وتفريغ كاش المجالات لهذا المورد لإظهار آخر التغييرات
                            _supplierFieldsFutureCache.remove(s.id);
                            await context.read<PartnersProvider>().loadAll();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تحديث مجالات المورد بنجاح')),
                            );
                          }
                          break;
                        case 'statement':
                          // Initialize the provider with the supplier before navigating
                          final provider = context.read<SupplierAccountStatementProvider>();
                          provider.initializeWithSupplier(s);

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SupplierAccountStatementScreen(supplier: s),
                            ),
                          );
                          break;
                        case 'statistics':
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('إحصائيات المورد ${s.name} ستتوفر قريباً')),
                          );
                          break;
                        case 'payments':
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SupplierPaymentsScreen(supplier: s),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('تعديل البيانات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit_fields',
                        child: Row(
                          children: [
                            Icon(Icons.business_center, color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 8),
                            Text('تعديل المجالات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'statement',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('كشف الحساب', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'statistics',
                        child: Row(
                          children: [
                            Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('الإحصائيات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'payments',
                        child: Row(
                          children: [
                            Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('الدفعات', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                            const SizedBox(width: 8),
                            Text('حذف', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                    icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),

              // معلومات المورد مع الأيقونات (كل معلومة في سطر منفصل)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // تم إخفاء الهاتف والبريد بناءً على الطلب

                  FutureBuilder<List<String>>(
                    future: _supplierFieldsFutureCache.putIfAbsent(
                      s.id,
                      () => _loadSupplierFieldNames(context, s.id),
                    ),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2));
                      }
                      if (snap.hasError) {
                        return const SizedBox.shrink();
                      }
                      final names = snap.data ?? const [];
                      if (names.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _InfoRow(
                          icon: Icons.business,
                          iconColor: Theme.of(context).colorScheme.secondary,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: names
                                .map((n) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        n,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),

                  // إجمالي المشتريات والدفعات والرصيد
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: context.read<PartnersProvider>().getSupplierFullSummary(s.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 20,
                            child: LinearProgressIndicator(minHeight: 2),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final summary = snapshot.data!;
                        final totalPurchases = summary['total_purchases'] as double? ?? 0.0;
                        final totalPayments = summary['total_payments'] as double? ?? 0.0;
                        final balance = summary['balance'] as double? ?? 0.0;

                        return Column(
                          children: [
                            // إجمالي المشتريات والدفعات في نفس السطر
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoRow(
                                    icon: Icons.shopping_cart,
                                    iconColor: Colors.green,
                                    child: Text(
                                      'م: ${totalPurchases.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InfoRow(
                                    icon: Icons.payment,
                                    iconColor: Colors.blue,
                                    child: Text(
                                      'د: ${totalPayments.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // الرصيد في سطر منفصل
                            _InfoRow(
                              icon: Icons.account_balance,
                              iconColor: balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                              child: Row(
                                children: [
                                  Text(
                                    'رصيد: ${balance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (balance < 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'مدين',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog();
  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _tax = TextEditingController();
  final _notes = TextEditingController();
  final _balance = TextEditingController(text: '0');
  bool _isActive = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _tax.dispose();
    _notes.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PartnersProvider>();
    return Dialog(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إضافة عميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balance,
                    decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('نشط'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: prov.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final ok = await prov.addClient(
                                    name: _name.text.trim(),
                                    phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                                    email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                                    address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                                    taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
                                    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                                    isActive: _isActive,
                                    balance: num.tryParse(_balance.text.trim()) ?? 0,
                                  );
                                  if (!mounted) return;
                                  if (ok) Navigator.of(context).pop();
                                },
                          child: Text(prov.isLoading ? 'جارٍ الحفظ...' : 'حفظ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                  if (prov.error != null) ...[
                    const SizedBox(height: 8),
                    Text(prov.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateSupplierDialog extends StatefulWidget {
  const _CreateSupplierDialog();
  @override
  State<_CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends State<_CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _tax = TextEditingController();
  final _notes = TextEditingController();
  final _balance = TextEditingController(text: '0');
  bool _isActive = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _tax.dispose();
    _notes.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PartnersProvider>();
    return Dialog(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إضافة مورد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balance,
                    decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('نشط'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: prov.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final ok = await prov.addSupplier(
                                    name: _name.text.trim(),
                                    phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                                    email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                                    address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                                    taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
                                    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                                    isActive: _isActive,
                                    balance: num.tryParse(_balance.text.trim()) ?? 0,
                                  );
                                  if (!mounted) return;
                                  if (ok) Navigator.of(context).pop();
                                },
                          child: Text(prov.isLoading ? 'جارٍ الحفظ...' : 'حفظ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                  if (prov.error != null) ...[
                    const SizedBox(height: 8),
                    Text(prov.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditSupplierDialog extends StatefulWidget {
  final Supplier supplier;
  const _EditSupplierDialog({required this.supplier});
  @override
  State<_EditSupplierDialog> createState() => _EditSupplierDialogState();
}

class _EditSupplierDialogState extends State<_EditSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.supplier.name);
  late final TextEditingController _phone = TextEditingController(text: widget.supplier.phone ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.supplier.email ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.supplier.address ?? '');
  late final TextEditingController _tax = TextEditingController(text: widget.supplier.taxNumber ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.supplier.notes ?? '');
  late final TextEditingController _balance = TextEditingController(text: widget.supplier.balance.toString());
  late bool _isActive = widget.supplier.isActive;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _tax.dispose();
    _notes.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PartnersProvider>();
    return Dialog(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تعديل بيانات المورد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balance,
                    decoration: const InputDecoration(labelText: 'الرصيد'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('نشط'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: prov.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final ok = await prov.updateSupplier(
                                    id: widget.supplier.id,
                                    name: _name.text.trim(),
                                    phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                                    email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                                    address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                                    taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
                                    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                                    isActive: _isActive,
                                    balance: num.tryParse(_balance.text.trim()) ?? widget.supplier.balance,
                                  );
                                  if (!mounted) return;
                                  if (ok) Navigator.of(context).pop(true);
                                },
                          child: Text(prov.isLoading ? 'جارٍ الحفظ...' : 'حفظ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                  if (prov.error != null) ...[
                    const SizedBox(height: 8),
                    Text(prov.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditClientDialog extends StatefulWidget {
  final Client client;
  const _EditClientDialog({required this.client});
  @override
  State<_EditClientDialog> createState() => _EditClientDialogState();
}

class _EditClientDialogState extends State<_EditClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.client.name);
  late final TextEditingController _phone = TextEditingController(text: widget.client.phone ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.client.email ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.client.address ?? '');
  late final TextEditingController _tax = TextEditingController(text: widget.client.taxNumber ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.client.notes ?? '');
  late final TextEditingController _balance = TextEditingController(text: widget.client.balance.toString());
  late bool _isActive = widget.client.isActive;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _tax.dispose();
    _notes.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<PartnersProvider>();
    return Dialog(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تعديل بيانات العميل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(labelText: 'العنوان'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tax,
                    decoration: const InputDecoration(labelText: 'الرقم الضريبي'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _balance,
                    decoration: const InputDecoration(labelText: 'الرصيد'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('نشط'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: prov.isLoading
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  final ok = await prov.updateClient(
                                    id: widget.client.id,
                                    name: _name.text.trim(),
                                    phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                                    email: _email.text.trim().isEmpty ? null : _email.text.trim(),
                                    address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                                    taxNumber: _tax.text.trim().isEmpty ? null : _tax.text.trim(),
                                    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                                    isActive: _isActive,
                                    balance: num.tryParse(_balance.text.trim()) ?? widget.client.balance,
                                  );
                                  if (!mounted) return;
                                  if (ok) Navigator.of(context).pop(true);
                                },
                          child: Text(prov.isLoading ? 'جارٍ الحفظ...' : 'حفظ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  ),
                  if (prov.error != null) ...[
                    const SizedBox(height: 8),
                    Text(prov.error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
