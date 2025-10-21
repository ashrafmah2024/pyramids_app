import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:go_router/go_router.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:pyramids/features/purchases/domain/entities/purchase_entity.dart';
import 'package:pyramids/features/purchases/presentation/screens/add_purchase_screen.dart';
import 'purchase_details_screen.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final _isLoading = ValueNotifier<bool>(true);
  final _purchases = ValueNotifier<List<Map<String, dynamic>>>([]);
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allPurchases = [];
  DateTime? _filterFrom;
  DateTime? _filterTo;
  DateTime? _filterExact;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
    _searchController.addListener(_applyFilters);
  }

  Future<void> _loadPurchases() async {
    try {
      _isLoading.value = true;
      
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('purchases')
          .select('*, suppliers!left(name)')
          .order('purchase_date', ascending: false);
      
      if (mounted) {
        _allPurchases = (response as List).cast<Map<String, dynamic>>();
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الفواتير: $e')),
        );
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  // دالة مساعدة لتحويل حقول التاريخ
  void _convertDateFields(Map<String, dynamic> data) {
    final dateFields = ['purchase_date', 'payment_date', 'due_date'];
    
    for (final field in dateFields) {
      if (data[field] is String) {
        try {
          data[field] = DateTime.parse(data[field]);
        } catch (e) {
          debugPrint('Error parsing $field: $e');
          data[field] = null;
        }
      }
    }
  }

  Future<void> _refreshPurchases() async {
    if (mounted) {
      await _loadPurchases();
    }
  }

  @override
  void dispose() {
    _isLoading.dispose();
    _purchases.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(_allPurchases);

    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      data = data.where((p) {
        final ref = (p['reference_number']?.toString() ?? '').toLowerCase();
        final inv = (p['invoice_number']?.toString() ?? '').toLowerCase();
        final item = (p['item']?.toString() ?? '').toLowerCase();
        final supplier = (p['suppliers'] is Map && p['suppliers']?['name'] != null)
            ? p['suppliers']['name'].toString().toLowerCase()
            : '';
        return ref.contains(q) || inv.contains(q) || item.contains(q) || supplier.contains(q);
      }).toList();
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        final d = DateTime.parse(v.toString());
        return DateTime(d.year, d.month, d.day);
      } catch (_) {
        return null;
      }
    }

    if (_filterExact != null) {
      final exact = DateTime(_filterExact!.year, _filterExact!.month, _filterExact!.day);
      data = data.where((p) {
        final d = parseDate(p['purchase_date']);
        return d != null && d == exact;
      }).toList();
    } else {
      if (_filterFrom != null) {
        final from = DateTime(_filterFrom!.year, _filterFrom!.month, _filterFrom!.day);
        data = data.where((p) {
          final d = parseDate(p['purchase_date']);
          return d != null && (d.isAtSameMomentAs(from) || d.isAfter(from));
        }).toList();
      }
      if (_filterTo != null) {
        final to = DateTime(_filterTo!.year, _filterTo!.month, _filterTo!.day);
        data = data.where((p) {
          final d = parseDate(p['purchase_date']);
          return d != null && (d.isAtSameMomentAs(to) || d.isBefore(to));
        }).toList();
      }
    }

    // ترتيب: الفواتير المتأخرة وغير المسددة في الأعلى
    final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    bool isOverdueUnpaid(Map<String, dynamic> p) {
      final due = parseDate(p['due_date']);
      final status = (p['status'] ?? p['status_code'] ?? '').toString().toLowerCase();
      final dueAmt = (p['amount_due'] as num?)?.toDouble() ?? 0.0;
      final notCompleted = status != 'completed' && status != 'مدفوع';
      return due != null && due.isBefore(today) && dueAmt > 0 && notCompleted;
    }
    final overdue = data.where(isOverdueUnpaid).toList()
      ..sort((a, b) {
        final ad = parseDate(a['due_date']);
        final bd = parseDate(b['due_date']);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    final others = data.where((p) => !isOverdueUnpaid(p)).toList();
    _purchases.value = [...overdue, ...others];
  }


  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    DateTimeRange? initialRange;
    if (_filterExact != null) {
      final d = DateTime(_filterExact!.year, _filterExact!.month, _filterExact!.day);
      initialRange = DateTimeRange(start: d, end: d);
    } else if (_filterFrom != null && _filterTo != null) {
      final from = DateTime(_filterFrom!.year, _filterFrom!.month, _filterFrom!.day);
      final to = DateTime(_filterTo!.year, _filterTo!.month, _filterTo!.day);
      initialRange = DateTimeRange(start: from, end: to);
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      currentDate: _filterExact ?? _filterFrom ?? _filterTo ?? now,
      saveText: 'تم',
    );

    if (picked != null) {
      final start = DateTime(picked.start.year, picked.start.month, picked.start.day);
      final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
      final isSameDay = start.year == end.year && start.month == end.month && start.day == end.day;
      setState(() {
        if (isSameDay) {
          _filterExact = start;
          _filterFrom = null;
          _filterTo = null;
        } else {
          _filterExact = null;
          _filterFrom = start;
          _filterTo = end;
        }
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _filterExact = null;
      _filterFrom = null;
      _filterTo = null;
    });
    _applyFilters();
  }

  Color _statusColor(Map<String, dynamic> p) {
    final colorHex = p['status_color']?.toString();
    final code = (p['status_code'] ?? p['status'] ?? 'draft').toString().toLowerCase();
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    switch (code) {
      case 'completed':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'draft':
      default:
        return Colors.grey;
    }
  }

  String _statusText(Map<String, dynamic> p) {
    // عرض status_code مباشرة بدلاً من النص المترجم
    return (p['status_code'] ?? p['status'] ?? 'draft').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فواتير المشتريات'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                // Fallback to role-based home when there's nothing to pop
                final role = context.read<AuthProvider>().currentUser?.role.toLowerCase();
                if (role == 'accountant') {
                  context.go(AppRouter.accountant);
                } else if (role == 'manager') {
                  context.go(AppRouter.manager);
                } else {
                  context.go(AppRouter.login);
                }
              }
            },
            tooltip: 'رجوع',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddPurchaseScreen(),
                  ),
                );
                await _refreshPurchases();
              },
              tooltip: 'فاتورة جديدة',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPurchases,
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: ValueListenableBuilder<bool>(
          valueListenable: _isLoading,
          builder: (context, isLoading, _) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _purchases,
              builder: (context, purchases, _) {
                if (purchases.isEmpty) {
                  return const _EmptyState();
                }

                return RefreshIndicator(
                  onRefresh: _refreshPurchases,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: purchases.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'بحث بالكلمات (المرجع/الفاتورة/المورد/البيان)',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _pickDateRange,
                                      icon: const Icon(Icons.date_range),
                                      label: Text(
                                        _filterExact != null
                                            ? 'التاريخ: ${intl.DateFormat('dd/MM').format(_filterExact!)}'
                                            : (_filterFrom != null && _filterTo != null)
                                                ? 'من ${intl.DateFormat('dd/MM').format(_filterFrom!)} إلى ${intl.DateFormat('dd/MM').format(_filterTo!)}'
                                                : 'اختر التاريخ/الفترة',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _clearFilters,
                                    tooltip: 'مسح الفلاتر',
                                    icon: const Icon(Icons.clear_all),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      final purchase = purchases[index - 1];
                      final supplier = purchase['suppliers'] as Map<String, dynamic>?;
                      
                      // إبراز الفاتورة المتأخرة باللون الأحمر ووضعها في الأعلى (تم في _applyFilters)
                      final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                      DateTime? _toDate(dynamic v) {
                        if (v == null) return null;
                        try {
                          final d = DateTime.parse(v.toString());
                          return DateTime(d.year, d.month, d.day);
                        } catch (_) { return null; }
                      }
                      bool overdueUnpaid(Map<String, dynamic> p) {
                        final due = _toDate(p['due_date']);
                        final status = (p['status'] ?? p['status_code'] ?? '').toString().toLowerCase();
                        final dueAmt = (p['amount_due'] as num?)?.toDouble() ?? 0.0;
                        final notCompleted = status != 'completed' && status != 'مدفوع';
                        return due != null && due.isBefore(today) && dueAmt > 0 && notCompleted;
                      }
                      final isOverdueCard = overdueUnpaid(purchase);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: isOverdueCard ? Colors.red.shade50 : null,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: isOverdueCard ? Colors.red : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            try {
                              // إنشاء نسخة جديدة من البيانات
                              final purchaseData = Map<String, dynamic>.from(purchase);
                              
                              // إضافة بيانات المورد إذا كانت متوفرة
                              if (purchase['suppliers'] != null) {
                                purchaseData['supplier_name'] = purchase['suppliers'] is Map 
                                    ? purchase['suppliers']['name']
                                    : null;
                              }

                              // تحويل التواريخ إذا كانت من النوع String
                              _convertDateFields(purchaseData);
                              
                              // التأكد من أن الويدجيت ما زالت في الشجرة
                              if (!mounted) return;
                              
                              // الانتقال إلى شاشة تفاصيل الفاتورة
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PurchaseDetailsScreen(
                                    purchase: PurchaseEntity.fromJson(purchaseData),
                                  ),
                                ),
                              ).then((_) => _refreshPurchases());
                            } catch (e, stackTrace) {
                              debugPrint('Error navigating to purchase details: $e');
                              debugPrint('Stack trace: $stackTrace');
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('حدث خطأ أثناء فتح تفاصيل الفاتورة'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'فاتورة #${purchase['reference_number'] ?? 'غير معروف'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () {
                                            // الانتقال إلى شاشة التعديل
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AddPurchaseScreen(
                                                  purchase: purchase,
                                                ),
                                              ),
                                            ).then((_) => _refreshPurchases());
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'تعديل',
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_ios, size: 16),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'البيان: ${
                                    (purchase['item'] is String && (purchase['item'] as String).trim().isNotEmpty)
                                      ? (purchase['item'] as String)
                                      : 'بدون بيان'
                                  }',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'المورد: ${supplier != null && supplier is Map ? (supplier['name'] ?? 'بدون اسم') : 'بدون مورد'}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'التاريخ: ${purchase['purchase_date'] != null ? intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(purchase['purchase_date'])) : 'غير محدد'}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الإجمالي: ${purchase['total_amount']} جنيه',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'المدفوع: ${purchase['amount_paid'] ?? 0} جنيه',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'المتبقي: ${purchase['amount_due'] ?? 0} جنيه',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (_) {
                                    final color = _statusColor(purchase);
                                    final text = _statusText(purchase);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.08),
                                        border: Border.all(color: color),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        text,
                                        style: TextStyle(color: color, fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
        // تمت إزالة الزر العائم ونُقلت الوظيفة إلى زر داخل AppBar
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // يمكنك تمرير دالة التحديث من الشاشة الأم إذا لزم الأمر
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد فواتير مشتريات حتى الآن',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ابدأ بإنشاء أول فاتورة مشتريات بالضغط على الزر بالأسفل',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                    textAlign: TextAlign.center,
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