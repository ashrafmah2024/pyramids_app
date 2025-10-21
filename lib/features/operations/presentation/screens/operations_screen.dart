import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:pyramids/features/manufacturing/presentation/screens/new_operation_screen.dart';
import 'package:pyramids/features/manufacturing/presentation/screens/operation_stages_screen.dart' as manufacturing;

class OperationsScreen extends StatefulWidget {
  final bool readOnly;
  const OperationsScreen({Key? key, this.readOnly = false}) : super(key: key);

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all'; // all | commercial | manufacturing
  String _query = '';
  final _searchCtrl = TextEditingController();
  String? _selectedForStages;
  bool _closing = false;
  String? _editOperationId;
  TabController? _tabs;
  Map<String, String> _clientsById = {};

  Future<void> _logOperationActivity(
    String action,
    String operationId, {
    String? details,
  }) async {
    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;
      if (user != null) {
        final displayName = user.email ?? user.userMetadata?['full_name'] ?? 'User';
        await client.from('activity_logs').insert({
          'user_id': user.id,
          'user_name': displayName,
          'action': action,
          'entity_type': 'OPERATION',
          'entity_id': operationId,
          'description': details ?? 'Operation $action',
          'ip_address': '',
          'user_agent': '',
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = SupabaseService().client;
      final res = await client
          .from('operations')
          .select('id, operation_code, type, status, is_closed, created_at, description, client_id')
          .order('created_at', ascending: false);
      final list = (res is List)
          ? res.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      // batch load client names for listed operations
      final ids = list
          .map((e) => e['client_id']?.toString())
          .where((v) => v != null && v!.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      Map<String, String> clientsMap = {};
      if (ids.isNotEmpty) {
        try {
          final rows = await client
              .from('clients')
              .select('id, name')
              .inFilter('id', ids);
          if (rows is List) {
            for (final r in rows) {
              final m = Map<String, dynamic>.from(r as Map);
              final id = m['id']?.toString();
              final name = m['name']?.toString();
              if (id != null && name != null) {
                clientsMap[id] = name;
              }
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _all = list;
        _clientsById = clientsMap;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    Iterable<Map<String, dynamic>> it = _all;
    if (_filter != 'all') {
      final f = _filter.toLowerCase();
      it = it.where((op) {
        final t = (op['type']?.toString() ?? '').toLowerCase();
        if (f == 'manufacturing') {
          return t == 'manufacturing' || t == 'industrial' || t.contains('manufact') || t.contains('صنا');
        }
        if (f == 'commercial') {
          return t == 'commercial' || t.contains('commercial') || t.contains('تجار');
        }
        return true;
      });
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((op) {
        final code = (op['operation_code']?.toString() ?? '').toLowerCase();
        final type = (op['type']?.toString() ?? '').toLowerCase();
        final status = (op['status']?.toString() ?? '').toLowerCase();
        final isClosed = (op['is_closed'] == true);
        final derived = isClosed ? 'closed مغلقة' : 'open مفتوحة pending قيد';
        return code.contains(q) || type.contains(q) || status.contains(q) || derived.contains(q);
      });
    }
    return it.toList();
  }

  Future<void> _closeOperation(String id) async {
    if (_closing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنهاء العملية'),
        content: const Text('هل تريد إنهاء هذه العملية؟ سيتم اعتبارها مغلقة.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _closing = true);
    try {
      final client = SupabaseService().client;
      await client.from('operations').update({'is_closed': true}).eq('id', id);
      await _logOperationActivity('CLOSE', id, details: 'Close operation $id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنهاء العملية')));
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل إنهاء العملية: $e')));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  void _navigateBack() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userRole = auth.currentUser?.role?.toLowerCase() ?? '';
    
    if (userRole == 'accountant') {
      context.go(AppRouter.accountant);
    } else {
      // Default to manager dashboard for all other roles
      context.go(AppRouter.manager);
    }
  }

  Future<bool> _onWillPop() async {
    // Check if we're in the first tab, if not, go to first tab
    if (_tabs != null && _tabs!.index != 0) {
      _tabs!.animateTo(0);
      return false;
    }
    _navigateBack();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool ro = widget.readOnly;
    return WillPopScope(
      onWillPop: _onWillPop,
      child: DefaultTabController(
        length: ro ? 2 : 3,
        child: Builder(
          builder: (tabCtx) {
            _tabs = DefaultTabController.of(tabCtx);
            final isFromAccountant = ModalRoute.of(context)?.settings.name?.contains('accountant') ?? false;
            return Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                ),
                title: Text(ro ? 'العمليات (قراءة فقط)' : 'العمليات'),
                bottom: TabBar(
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'كل العمليات', icon: Icon(Icons.view_list)),
                    const Tab(text: 'مراحل العملية', icon: Icon(Icons.stacked_bar_chart)),
                    if (!ro)
                      const Tab(text: 'عملية جديدة', icon: Icon(Icons.add_circle_outline)),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: _loading ? null : _fetch,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                  )
                ],
              ),
              body: SafeArea(
                child: TabBarView(
                  children: [
                    // Tab 1: List all operations
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  decoration: const InputDecoration(
                                    hintText: 'بحث برقم العملية أو النوع أو الحالة',
                                    prefixIcon: Icon(Icons.search),
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => setState(() => _query = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _filter,
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                                  DropdownMenuItem(value: 'commercial', child: Text('تجارية')),
                                  DropdownMenuItem(value: 'manufacturing', child: Text('صناعية')),
                                ],
                                onChanged: (v) => setState(() => _filter = v ?? 'all'),
                              ),
                            ],
                          ),
                        ),
                        if (_loading)
                          const Expanded(child: Center(child: CircularProgressIndicator()))
                        else if (_error != null)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(_error!, style: const TextStyle(color: Colors.red)),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: _filtered.isEmpty
                                ? const Center(child: Text('لا توجد عمليات'))
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _filtered.length,
                                    itemBuilder: (ctx, i) {
                                      final op = _filtered[i];
                                      final id = op['id']?.toString() ?? '';
                                      final code = op['operation_code']?.toString() ?? '';
                                      final type = op['type']?.toString() ?? '';
                                      final desc = op['description']?.toString() ?? '';
                                      final clientId = op['client_id']?.toString() ?? '';
                                      final clientName = _clientsById[clientId] ?? '';
                                      final isClosed = (op['is_closed'] == true);
                                      final statusText = isClosed ? 'مغلقة' : 'مفتوحة';
                                      final statusColor = isClosed ? Colors.red : Colors.green;
                                      final statusBg = statusColor.withOpacity(0.12);
                                      
                                      return Card(
                                        color: statusBg,
                                        surfaceTintColor: Colors.transparent,
                                        child: ListTile(
                                          leading: CircleAvatar(child: Text((i + 1).toString())),
                                          title: Text(code.isEmpty ? id : code),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Chip(
                                                label: Text(
                                                  statusText,
                                                  style: const TextStyle(color: Colors.white),
                                                ),
                                                backgroundColor: statusColor,
                                                shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
                                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  desc,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                          trailing: PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (id.isEmpty) return;
                                              switch (value) {
                                                case 'details':
                                                  context.go('/operations/$id/details');
                                                  break;
                                                case 'stages':
                                                  setState(() => _selectedForStages = id);
                                                  final ctrl = DefaultTabController.of(context);
                                                  if (ctrl != null) ctrl.animateTo(1);
                                                  break;
                                                case 'edit':
                                                  setState(() => _editOperationId = id);
                                                  final ctrl = DefaultTabController.of(context);
                                                  if (ctrl != null) ctrl.animateTo(2);
                                                  break;
                                                case 'close':
                                                  _closeOperation(id);
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'details',
                                                child: Text('عرض التفاصيل'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'stages',
                                                child: Text('مراحل العملية'),
                                              ),
                                              if (!widget.readOnly)
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Text('تعديل'),
                                                ),
                                              if (!isClosed)
                                                const PopupMenuItem(
                                                  value: 'close',
                                                  child: Text('إنهاء العملية'),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                      ],
                    ),
                    // Tab 2: Operation stages (select operation first)
                    _selectedForStages == null
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'اختر عملية من تبويب "كل العمليات" لعرض مراحلها هنا',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : manufacturing.OperationStagesScreen(
                            operationId: _selectedForStages!,
                            readOnly: ro,
                          ),
                    // Tab 3: New operation (embedded single-form)
                    if (!widget.readOnly)
                      NewOperationScreen(
                        key: ValueKey(_editOperationId ?? 'new'),
                        embedded: true,
                        onSaved: () {
                          _fetch();
                          if (_tabs != null) {
                            _tabs!.animateTo(0);
                          }
                          setState(() => _editOperationId = null);
                        },
                        initialOperationId: _editOperationId,
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
