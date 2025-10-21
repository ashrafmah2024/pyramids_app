import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:postgrest/postgrest.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:pyramids/core/theme/app_theme.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({Key? key}) : super(key: key);

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _DescriptionCell extends StatelessWidget {
  final String description;
  const _DescriptionCell({required this.description});

  @override
  Widget build(BuildContext context) {
    if (description.trim().isEmpty) return const SizedBox.shrink();

    // Split into main part and diffs part using the first '|'
    String main = description;
    List<String> diffs = const [];
    final barIndex = description.indexOf('|');
    if (barIndex != -1) {
      main = description.substring(0, barIndex).trim();
      final rest = description.substring(barIndex + 1).trim();
      if (rest.isNotEmpty) {
        diffs = rest
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            main,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        IconButton(
          tooltip: 'تفاصيل',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          iconSize: 16,
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('تفاصيل العملية'),
                  content: SizedBox(
                    width: 460,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          main,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        if (diffs.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 420),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemBuilder: (context, index) => Text(
                                diffs[index],
                                textDirection: TextDirection.rtl,
                              ),
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 8),
                              itemCount: diffs.length,
                            ),
                          )
                        else
                          const Text('لا توجد تفاصيل إضافية'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق'),
                    ),
                  ],
                );
              },
            );
          },
          icon: const Icon(Icons.info_outline, color: Colors.blue),
        ),
      ],
    );
  }
}

enum _ManagerMenuAction { activityLog, notifications, toggleDarkMode, signOut }

List<DataRow> _buildRows(List<Map<String, dynamic>> items) {
  return items.map((m) {
    final createdAt = (m['created_at'] ?? '').toString();
    final userName = (m['user_name'] ?? '').toString();
    final action = (m['action'] ?? '').toString();
    final description = (m['description'] ?? '').toString();
    final entityType = (m['entity_type'] ?? '').toString();
    final entityId = (m['entity_id'] ?? '').toString();
    final ip = (m['ip_address'] ?? '').toString();
    final ua = (m['user_agent'] ?? '').toString();
    return DataRow(
      cells: [
        DataCell(Text(createdAt.split('.').first.replaceFirst('T', ' '))),
        DataCell(Text(userName)),
        DataCell(Text(action)),
        DataCell(
          SizedBox(
            width: 320,
            child: _DescriptionCell(description: description),
          ),
        ),
        DataCell(Text(entityType)),
        DataCell(Text(entityId)),
        DataCell(Text(ip)),
        DataCell(Text(ua)),
      ],
    );
  }).toList();
}

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({Key? key}) : super(key: key);

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _logs = [];
  String _query = '';
  DateTime? _selectedDate;
  DateTimeRange? _selectedRange;
  final TextEditingController _searchController = TextEditingController();

  // ترقيم الصفحات
  final int _rowsPerPage = 25;
  int _currentPage = 0;

  // لقطة آخر حالة للفلاتر للتراجع
  String _lastQuery = '';
  DateTime? _lastDate;
  DateTimeRange? _lastRange;

  void _saveFiltersSnapshot() {
    _lastQuery = _query;
    _lastDate = _selectedDate;
    _lastRange = _selectedRange;
  }

  bool get _canUndoFilters {
    return _lastQuery != _query ||
        _lastDate != _selectedDate ||
        _lastRange != _selectedRange;
  }

  void _undoFilters() {
    if (!_canUndoFilters) return;
    setState(() {
      _query = _lastQuery;
      _selectedDate = _lastDate;
      _selectedRange = _lastRange;
      _searchController.text = _query;
    });
    _fetchLogs();
  }

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = context.read<SupabaseService>().client;
      var query = supabase
          .from('activity_logs')
          .select(
            'id,user_id,user_name,action,description,entity_type,entity_id,ip_address,user_agent,created_at',
          );

      // تطبيق فلاتر التاريخ على مستوى الخادم إن أمكن
      if (_selectedDate != null) {
        final start = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
        final end = start.add(const Duration(days: 1));
        query = query
            .filter('created_at', 'gte', start.toUtc().toIso8601String())
            .filter('created_at', 'lt', end.toUtc().toIso8601String());
      } else if (_selectedRange != null) {
        final start = DateTime(
          _selectedRange!.start.year,
          _selectedRange!.start.month,
          _selectedRange!.start.day,
        );
        final endExclusive = DateTime(
          _selectedRange!.end.year,
          _selectedRange!.end.month,
          _selectedRange!.end.day,
        ).add(const Duration(days: 1));
        query = query
            .filter('created_at', 'gte', start.toUtc().toIso8601String())
            .filter('created_at', 'lt', endExclusive.toUtc().toIso8601String());
      }

      // ترتيب بعد تطبيق الفلاتر ثم حد أقصى 500 صف
      final data = await query.order('created_at', ascending: false).limit(500);
      final list = (data as List).cast<Map<String, dynamic>>();
      setState(() {
        _logs = list;
        _currentPage = 0; // إعادة الضبط عند تغيير البيانات
      });
    } on PostgrestException catch (e) {
      // إخفاء رسالة صلاحيات users فقط، وإظهار غيرها للتشخيص (مثل activity_logs)
      final isUsersPerm =
          e.code == '42501' &&
          (e.message?.toLowerCase().contains('table users') ?? false);
      setState(() {
        _error = isUsersPerm ? null : (e.message ?? e.toString());
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_query.trim().isEmpty) return _logs;
    final q = _query.toLowerCase();
    return _logs.where((m) {
      final user = (m['user_name'] ?? '').toString().toLowerCase();
      final action = (m['action'] ?? '').toString().toLowerCase();
      final desc = (m['description'] ?? '').toString().toLowerCase();
      return user.contains(q) || action.contains(q) || desc.contains(q);
    }).toList();
  }

  int get _pageCount {
    final total = _filteredLogs.length;
    if (total == 0) return 1;
    return ((total + _rowsPerPage - 1) / _rowsPerPage).floor();
  }

  List<Map<String, dynamic>> get _pagedLogs {
    final logs = _filteredLogs;
    final start = _currentPage * _rowsPerPage;
    if (start >= logs.length) return [];
    int end = start + _rowsPerPage;
    if (end > logs.length) end = logs.length;
    return logs.sublist(start, end);
  }

  void _goToPage(int page) {
    if (page < 0) page = 0;
    if (page >= _pageCount) page = _pageCount - 1;
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() => _goToPage(_currentPage + 1);
  void _prevPage() => _goToPage(_currentPage - 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'رجوع',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRouter.manager);
            }
          },
        ),
        title: const Text('سجل النشاطات'),
        actions: [
          IconButton(
            onPressed: _canUndoFilters ? _undoFilters : null,
            icon: const Icon(Icons.undo),
            tooltip: 'تراجع',
          ),
          IconButton(
            onPressed: _loading ? null : _fetchLogs,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // شريط الفلاتر
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // حقل البحث بعرض كامل في سطر مستقل
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'بحث باسم المستخدم / الإجراء / الوصف',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        _query = v;
                        _currentPage = 0; // إعادة الضبط عند تغيير البحث
                      }),
                      textInputAction: TextInputAction.search,
                    ),
                    const SizedBox(height: 8),
                    // أزرار التواريخ والتهيئة تلتف تلقائيًا لتجنب Overflow
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            _saveFiltersSnapshot();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                                _selectedRange = null;
                                _currentPage =
                                    0; // إعادة الضبط عند تغيير الفلاتر
                              });
                              _fetchLogs();
                            }
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            _selectedDate == null
                                ? 'تاريخ محدد'
                                : _selectedDate!.toString().split(' ').first,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            _saveFiltersSnapshot();
                            final now = DateTime.now();
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDateRange:
                                  _selectedRange ??
                                  DateTimeRange(
                                    start: now.subtract(
                                      const Duration(days: 7),
                                    ),
                                    end: now,
                                  ),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedRange = picked;
                                _selectedDate = null;
                                _currentPage =
                                    0; // إعادة الضبط عند تغيير الفلاتر
                              });
                              _fetchLogs();
                            }
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _selectedRange == null
                                ? 'مدى تاريخي'
                                : '${_selectedRange!.start.toString().split(' ').first} → ${_selectedRange!.end.toString().split(' ').first}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_loading) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ] else ...[
                  // تمرير أفقي فقط للجدول، والتمرير الرأسي عبر الصفحة الأم
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 1000),
                      child: DataTable(
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        columnSpacing: 8,
                        dataRowMinHeight: 36,
                        dataRowMaxHeight: 56,
                        columns: const [
                          DataColumn(label: Text('الوقت')),
                          DataColumn(label: Text('المستخدم')),
                          DataColumn(label: Text('الإجراء')),
                          DataColumn(label: Text('الوصف')),
                          DataColumn(label: Text('الكيان')),
                          DataColumn(label: Text('معرّف الكيان')),
                          DataColumn(label: Text('IP')),
                          DataColumn(label: Text('User Agent')),
                        ],
                        rows: _buildRows(_pagedLogs),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // عناصر التحكم في ترقيم الصفحات (تمرير أفقي لتفادي Overflow)
                  Builder(
                    builder: (context) {
                      final total = _filteredLogs.length;
                      final start = total == 0
                          ? 0
                          : (_currentPage * _rowsPerPage) + 1;
                      final end = total == 0
                          ? 0
                          : (_currentPage * _rowsPerPage) + _pagedLogs.length;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text('عرض $start–$end من $total'),
                            const SizedBox(width: 12),
                            IconButton(
                              tooltip: 'الأولى',
                              onPressed: _currentPage > 0
                                  ? () => _goToPage(0)
                                  : null,
                              icon: const Icon(Icons.first_page),
                            ),
                            IconButton(
                              tooltip: 'السابق',
                              onPressed: _currentPage > 0 ? _prevPage : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                            Text('${_currentPage + 1} / $_pageCount'),
                            IconButton(
                              tooltip: 'التالي',
                              onPressed: (_currentPage + 1) < _pageCount
                                  ? _nextPage
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: 'الأخيرة',
                              onPressed: (_currentPage + 1) < _pageCount
                                  ? () => _goToPage(_pageCount - 1)
                                  : null,
                              icon: const Icon(Icons.last_page),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_filteredLogs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(child: Text('لا توجد سجلات لعرضها')),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _LogTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final userName = (item['user_name'] ?? '').toString();
    final action = (item['action'] ?? '').toString();
    final description = (item['description'] ?? '').toString();
    final createdAt = (item['created_at'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.history, color: Colors.blueGrey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          userName.isEmpty ? 'مستخدم غير معروف' : userName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        createdAt,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(action),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (description.isNotEmpty) Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerScreenState extends State<ManagerScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openNotifications() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  Future<void> _signOut() async {
    try {
      // أغلق أي Drawer مفتوح قبل التوجيه
      _scaffoldKey.currentState?.closeEndDrawer();

      // الأفضل استخدام AuthProvider لمسح الحالة ثم التوجيه
      try {
        final authProvider = context.read<AuthProvider>();
        await authProvider.signOut();
      } catch (_) {
        // في حال عدم توفر المزود، نستخدم الخدمة مباشرة
        await context.read<SupabaseService>().signOut();
      }

      // انتظار قصير لتثبيت حدث onAuthStateChange ومنع إعادة التوجيه العكسي
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      context.go(AppRouter.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تسجيل الخروج: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final brightness = Theme.of(context).brightness;
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: const Text(
                'شاشة المدير العام',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                PopupMenuButton<_ManagerMenuAction>(
                  tooltip: 'القائمة',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case _ManagerMenuAction.signOut:
                        _signOut();
                        break;
                      case _ManagerMenuAction.notifications:
                        _openNotifications();
                        break;
                      case _ManagerMenuAction.toggleDarkMode:
                        context.read<AppTheme>().toggleTheme();
                        break;
                      case _ManagerMenuAction.activityLog:
                        context.go(AppRouter.activityLog);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<_ManagerMenuAction>(
                      value: _ManagerMenuAction.activityLog,
                      child: const ListTile(
                        leading: Icon(Icons.history),
                        title: Text('سجل النشاطات'),
                      ),
                    ),
                    PopupMenuItem<_ManagerMenuAction>(
                      value: _ManagerMenuAction.notifications,
                      child: const ListTile(
                        leading: Icon(Icons.notifications_outlined),
                        title: Text('الإشعارات'),
                      ),
                    ),
                    PopupMenuItem<_ManagerMenuAction>(
                      value: _ManagerMenuAction.toggleDarkMode,
                      child: ListTile(
                        leading: const Icon(Icons.dark_mode_outlined),
                        title: Text(
                          brightness == Brightness.dark
                              ? 'إيقاف الوضع الليلي'
                              : 'تشغيل الوضع الليلي',
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<_ManagerMenuAction>(
                      value: _ManagerMenuAction.signOut,
                      child: const ListTile(
                        leading: Icon(Icons.logout, color: Colors.redAccent),
                        title: Text('تسجيل الخروج'),
                      ),
                    ),
                  ],
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                labelColor:
                    Theme.of(context).appBarTheme.foregroundColor ??
                    Colors.white,
                unselectedLabelColor:
                    (Theme.of(context).appBarTheme.foregroundColor ??
                            Colors.white)
                        .withOpacity(0.7),
                indicatorColor:
                    Theme.of(context).appBarTheme.foregroundColor ??
                    Colors.white,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_outlined),
                    text: 'لوحة التحكم',
                  ),
                  Tab(
                    icon: Icon(Icons.settings_outlined),
                    text: 'الإدارة والإعدادات',
                  ),
                ],
              ),
            ),
            endDrawer: Drawer(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'مركز الإشعارات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final items = [
                            ('إشعار', 'تمت إضافة عميل جديد'),
                            ('تنبيه', 'انخفاض مخزون منتج: رول سوليتيب'),
                            ('إجراء', 'تذكير بدفع مستحقات مورد'),
                            ('إشعار', 'فاتورة مبيعات جديدة رقم #1024'),
                          ];
                          final item = items[index % items.length];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary.withOpacity(0.2),
                              child: const Icon(
                                Icons.notifications,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item.$1,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              item.$2,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: const Text(
                              'قبل قليل',
                              style: TextStyle(fontSize: 12),
                            ),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, thickness: 1),
                        itemCount: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: TabBarView(
              children: const [_DashboardTab(), _ManagementTab()],
            ),
          );
        },
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange:
          _range ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null) {
      setState(() => _range = picked);
    }
  }

  void _clearRange() {
    setState(() => _range = null);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _range == null
                            ? 'اختر مدى تاريخي'
                            : '${_range!.start.toString().split(' ').first} → ${_range!.end.toString().split(' ').first}',
                      ),
                    ),
                    if (_range != null)
                      OutlinedButton.icon(
                        onPressed: _clearRange,
                        icon: const Icon(Icons.clear),
                        label: const Text('مسح المدى'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _FinanceSummary(range: _range),
                const SizedBox(height: 20),
                _ChartsSection(range: _range),
                const SizedBox(height: 20),
                _GrowthCard(range: _range),
              ],
            ),
          ),
          _LatestEntities(range: _range),
          const SizedBox(height: 16),
          _SmartAlerts(range: _range),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ManagementTab extends StatelessWidget {
  const _ManagementTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      _MgmtItem(
        'العمليات',
        Icons.factory_outlined,
        Colors.teal,
        AppRouter.operations,
      ),
      _MgmtItem('إدارة المستخدمين', Icons.people_alt, Colors.indigo, '/users'),
      _MgmtItem('إدارة الصلاحيات', Icons.security, Colors.teal, '/roles'),
      _MgmtItem(
        'إدارة الحسابات',
        Icons.receipt_long,
        Colors.blueGrey,
        '/partners',
      ),
      _MgmtItem('إدارة المجالات', Icons.category, Colors.deepPurple, '/fields'),
      _MgmtItem(
        'المشتريات والمبيعات',
        Icons.request_quote,
        Colors.blue,
        AppRouter.purchases,
      ),
      _MgmtItem('إدارة المخزون', Icons.inventory_2, Colors.brown, '/inventory'),
      _MgmtItem(
        'النفقات',
        CupertinoIcons.doc_plaintext,
        Colors.orange,
        '/expenses',
      ),
      _MgmtItem('الإعدادات', Icons.settings, Colors.grey, '/settings'),
      _MgmtItem('النسخ الاحتياطي', Icons.backup, Colors.green, '/backup'),
      _MgmtItem(
        'سجل النشاطات',
        Icons.history,
        Colors.redAccent,
        '/activity-log',
      ),
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: items
                  .map(
                    (item) => _MgmtCard(
                      title: item.title,
                      icon: item.icon,
                      color: item.color,
                      routeName: item.route,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceSummary extends StatelessWidget {
  final DateTimeRange? range;
  const _FinanceSummary({Key? key, this.range}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final chips = [
      (
        'إجمالي الإيرادات',
        '250,000',
        Icons.payments_outlined,
        const Color(0xFF1B5E20),
      ),
      (
        'إجمالي المصروفات',
        '180,000',
        Icons.outbond_outlined,
        const Color(0xFFB71C1C),
      ),
      ('إجمالي الأرباح', '70,000', Icons.trending_up, const Color(0xFF2E7D32)),
      ('إجمالي العمليات', '1,240', Icons.autorenew, const Color(0xFF1565C0)),
    ];

    return Column(
      children: chips
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: e.$4.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(e.$3, color: e.$4, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.$1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                e.$2,
                                style: const TextStyle(
                                  fontSize: 18,
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
            ),
          )
          .toList(),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  final DateTimeRange? range;
  const _ChartsSection({Key? key, this.range}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(CupertinoIcons.chart_bar_alt_fill, size: 20),
            SizedBox(width: 8),
            Text('مخططات شهرية'),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _MiniBarChart(
              titleLeft: 'الإيرادات',
              titleRight: 'المصروفات',
              colorLeft: Colors.green,
              colorRight: Colors.redAccent,
              leftValues: const [60, 50, 70, 65, 80, 75],
              rightValues: const [40, 55, 50, 60, 45, 50],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _MiniBarChart(
              titleLeft: 'عمليات التصنيع',
              titleRight: 'عمليات المبيعات',
              colorLeft: Colors.indigo,
              colorRight: Colors.orange,
              leftValues: const [30, 45, 50, 40, 55, 60],
              rightValues: const [20, 25, 35, 30, 40, 45],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final String titleLeft;
  final String titleRight;
  final Color colorLeft;
  final Color colorRight;
  final List<int> leftValues;
  final List<int> rightValues;
  const _MiniBarChart({
    required this.titleLeft,
    required this.titleRight,
    required this.colorLeft,
    required this.colorRight,
    required this.leftValues,
    required this.rightValues,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = (leftValues + rightValues)
        .fold<int>(0, (m, v) => v > m ? v : m)
        .toDouble();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorLeft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    titleLeft,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorRight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    titleRight,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(leftValues.length, (i) {
            final l = leftValues[i].toDouble();
            final r = rightValues[i].toDouble();
            final lh = (l / maxVal) * 90 + 10;
            final rh = (r / maxVal) * 90 + 10;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: lh,
                      decoration: BoxDecoration(
                        color: colorLeft.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: rh,
                      decoration: BoxDecoration(
                        color: colorRight.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _GrowthCard extends StatelessWidget {
  final DateTimeRange? range;
  const _GrowthCard({Key? key, this.range}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            Icon(Icons.trending_up, color: Colors.green),
            SizedBox(width: 12),
            Expanded(child: Text('نمو +12% عن الشهر الماضي')),
          ],
        ),
      ),
    );
  }
}

class _LatestEntities extends StatelessWidget {
  final DateTimeRange? range;
  const _LatestEntities({Key? key, this.range}) : super(key: key);

  bool _inRange(DateTime d) {
    if (range == null) return true;
    final start = DateTime(
      range!.start.year,
      range!.start.month,
      range!.start.day,
    );
    final end = DateTime(
      range!.end.year,
      range!.end.month,
      range!.end.day,
    ).add(const Duration(days: 1));
    return !d.isBefore(start) && d.isBefore(end);
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('عميل', 'بلاستيك', '2025-10-05'),
      ('مورد', 'استيكرات', '2025-10-04'),
      ('عميل', 'كرتون', '2025-10-03'),
      ('مورد', 'سوليتيب', '2025-10-02'),
    ];
    final filtered = rows.where((e) {
      try {
        final d = DateTime.parse(e.$3);
        return _inRange(d);
      } catch (_) {
        return true;
      }
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.group_add_outlined, size: 20),
                SizedBox(width: 8),
                Text('أحدث العملاء والموردين'),
              ],
            ),
            const SizedBox(height: 12),
            ...filtered.map(
              (e) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    e.$1 == 'عميل' ? Icons.person : Icons.local_shipping,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text('${e.$1} – ${e.$2}'),
                subtitle: Text(e.$3),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartAlerts extends StatelessWidget {
  final DateTimeRange? range;
  const _SmartAlerts({Key? key, this.range}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final alerts = [
      (Icons.watch_later_outlined, 'عملاء متأخرون في السداد'),
      (Icons.payments_rounded, 'موردون لم تُدفع مستحقاتهم'),
      (Icons.warning_amber_outlined, 'أصناف منخفضة الكمية في المخزون'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: alerts
              .map(
                (e) => ListTile(
                  leading: Icon(e.$1, color: Colors.orange),
                  title: Text(e.$2),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MgmtItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _MgmtItem(this.title, this.icon, this.color, this.route);
}

class _MgmtCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String routeName;
  const _MgmtCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push(routeName);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 120, // ارتفاع ثابت للكارت
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
