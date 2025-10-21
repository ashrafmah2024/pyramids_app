import 'package:flutter/material.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:postgrest/postgrest.dart' show PostgrestException;
import 'package:pyramids/features/purchases/presentation/screens/add_edit_expense_screen.dart';
import 'package:pyramids/features/purchases/presentation/screens/expenses_list_screen.dart';
import 'package:pyramids/features/purchases/presentation/screens/cost_allocation_screen.dart';
import 'dart:async';
import 'dart:ui' as ui;

class AddPurchaseScreen extends StatefulWidget {
  final Map<String, dynamic>? purchase;

  const AddPurchaseScreen({super.key, this.purchase})
    : assert(purchase == null || purchase is Map<String, dynamic>);

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Field Controllers
  final _referenceNumberCtrl = TextEditingController();
  final _invoiceNumberCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _unitPriceCtrl = TextEditingController(text: '0.0');
  final _subtotalCtrl = TextEditingController(text: '0.0');
  final _discountPercentCtrl = TextEditingController(text: '0.0');
  final _discountAmountCtrl = TextEditingController(text: '0.0');
  final _taxPercentCtrl = TextEditingController(text: '0.0');
  final _taxAmountCtrl = TextEditingController(text: '0.0');
  final _taxDiscountPercentCtrl = TextEditingController(text: '0.0');
  final _taxDiscountAmountCtrl = TextEditingController(text: '0.0');
  final _totalAmountCtrl = TextEditingController(text: '0.0');
  final _amountPaidCtrl = TextEditingController(text: '0.0');
  final _amountDueCtrl = TextEditingController(text: '0.0');
  final _notesArCtrl = TextEditingController();
  final _notesEnCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  
  // Commercial/Manufacturing Operation Fields
  String? _selectedOperationId;
  String? _selectedOperationType = 'commercial';
  List<Map<String, dynamic>> _operations = [];
  bool _isLoadingOperations = false;
  // Operation Stage Fields
  String? _selectedStageId;
  List<Map<String, dynamic>> _stages = [];
  bool _isLoadingStages = false;

  // Form State
  DateTime? _purchaseDate = DateTime.now();
  DateTime? _dueDate;
  // Status values must match the database's purchases_status_check constraint
  List<Map<String, dynamic>> _dbStatuses = [];
  String? _selectedStatusCode;
  bool _isLoadingStatuses = false;
  String _status = 'draft';
  bool _isSaving = false;
  bool _isTaxable = false;
  // Removed unused variables as we're using the text controllers directly

  // Payment Methods
  List<Map<String, dynamic>> _paymentMethods = [];
  String? _selectedPaymentMethodId;
  bool _isLoadingPaymentMethods = false;
  bool _isInitialized = false;
  bool _isCalculatingAmounts = false;
  bool _isProgrammaticUpdate = false;
  String? _lastAutoStatusSignature;
  Timer? _amountPaidDebounce;
  bool _userChoseCancelled = false;

  // Suppliers
  List<Map<String, dynamic>> _suppliers = [];
  String? _selectedSupplierId;
  bool _isLoadingSuppliers = false;

  // Units
  List<Map<String, dynamic>> _units = [];
  String? _selectedUnitId;
  bool _isLoadingUnits = false;

  // Reference number generation
  int _dailySequence = 1;
  // Remove unused _lastSequenceDate
  bool _isLoadingReference = false;

  // Generate reference number in format: PURYYYYMMDDXXX
  String _generateReferenceNumber() {
    final dateToUse = _purchaseDate ?? DateTime.now();
    final date =
        '${dateToUse.year}${dateToUse.month.toString().padLeft(2, '0')}${dateToUse.day.toString().padLeft(2, '0')}';
    // If we don't have a sequence yet, set it to 1
    if (_dailySequence == 0) {
      _dailySequence = 1;
    }
    final sequence = _dailySequence.toString().padLeft(3, '0');
    return 'PUR$date$sequence';
  }

  // Get order_no for a stage within an operation
  Future<int?> _getStageOrderNo(String operationId, String stageId) async {
    try {
      final client = SupabaseService().client;
      final r = await client
          .from('operation_stages')
          .select('order_no')
          .eq('operation_id', operationId)
          .eq('stage_id', stageId)
          .maybeSingle();
      if (r is Map<String, dynamic>) {
        final on = r['order_no'];
        if (on is int) return on;
        if (on is num) return on.toInt();
      }
    } catch (_) {}
    return null;
  }

  // Insert an expense log row for a stage
  Future<void> _addStageExpense({
    required String operationId,
    required String stageId,
    required int orderNo,
    required double amount,
    required String note,
  }) async {
    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;
      final payload = {
        'operation_id': operationId,
        'stage_id': stageId,
        'order_no': orderNo,
        'log_type': 'expense',
        'amount': amount,
        'note': note,
        if (user != null) 'created_by': user.id,
      };
      debugPrint('Adding stage expense: '+payload.toString());
      await client.from('operation_stage_logs').insert(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة مصروف للمرحلة بقيمة $amount')),
        );
      }
    } catch (e) {
      debugPrint('Failed to add stage expense: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إضافة مصروف للمرحلة: $e')),
        );
      }
    }
  }

  // Load stages for a specific operation
  Future<void> _loadStagesForOperation(String operationId) async {
    if (_isLoadingStages) return;
    if (!mounted) return;
    setState(() {
      _isLoadingStages = true;
      _stages = [];
    });
    try {
      final client = SupabaseService().client;
      // Get operation_stages first
      final os = await client
          .from('operation_stages')
          .select('stage_id, order_no')
          .eq('operation_id', operationId)
          .order('order_no', ascending: true);
      final osList = (os is List)
          ? os.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      // Map stage_id to names via manufacturing_stages
      final ids = osList.map((e) => e['stage_id']?.toString()).whereType<String>().toList();
      Map<String, String> nameById = {};
      if (ids.isNotEmpty) {
        final names = await client
            .from('manufacturing_stages')
            .select('id, stage_name')
            .inFilter('id', ids);
        if (names is List) {
          for (final r in names) {
            final m = Map<String, dynamic>.from(r);
            final sid = m['id']?.toString();
            final nm = m['stage_name']?.toString() ?? '';
            if (sid != null) nameById[sid] = nm;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _stages = osList
            .map((e) => {
                  'stage_id': e['stage_id']?.toString(),
                  'order_no': e['order_no'],
                  'stage_name': nameById[e['stage_id']?.toString()] ?? e['stage_id']?.toString() ?? '',
                })
            .toList();
        // Keep previously selected stage only if it belongs to this operation
        if (_selectedStageId != null && !_stages.any((s) => s['stage_id'] == _selectedStageId)) {
          _selectedStageId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل مراحل العملية: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStages = false;
        });
      }
    }
  }

  // Load commercial operations from the database
  Future<void> _loadOperations() async {
    if (_isLoadingOperations) return;
    if (mounted) {
      setState(() {
        _isLoadingOperations = true;
      });
    }

    try {
      final client = SupabaseService().client;
      final response = await client
          .from('operations')
          .select('id, operation_code, type')
          .order('created_at', ascending: false);

      final list = (response is List)
          ? response
              .map<Map<String, dynamic>>((e) {
                final m = Map<String, dynamic>.from(e);
                return {
                  'id': m['id']?.toString(),
                  'operation_code': m['operation_code']?.toString() ?? '',
                  'type': m['type']?.toString() ?? '',
                };
              })
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _operations = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل العمليات: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingOperations = false;
        });
      }
    }
  }

  

  // Add default units to the database if none exist
  Future<void> _seedDefaultUnits() async {
    debugPrint('=== Starting _seedDefaultUnits ===');
    try {
      final client = SupabaseService().client;
      debugPrint('Supabase client initialized');

      try {
        // Check if units table is empty
        debugPrint('Querying units table...');
        final response = await client.from('units').select('id').limit(1);

        debugPrint('Response from units table: ${response.toString()}');

        if (response is List && response.isEmpty) {
          debugPrint('Units table is empty, adding default units...');

          // Default units to add
          final defaultUnits = [
            {'name_ar': 'كيلوجرام', 'name_en': 'Kilogram', 'code': 'KG'},
            {'name_ar': 'جرام', 'name_en': 'Gram', 'code': 'G'},
            {'name_ar': 'لتر', 'name_en': 'Liter', 'code': 'L'},
            {'name_ar': 'متر', 'name_en': 'Meter', 'code': 'M'},
            {'name_ar': 'قطعة', 'name_en': 'Piece', 'code': 'PC'},
          ];

          // Insert default units
          for (var unit in defaultUnits) {
            try {
              debugPrint('Attempting to insert unit: ${unit['name_ar']}');
              final result = await client.from('units').insert(unit);
              debugPrint('Insert result: $result');
              debugPrint(
                'Successfully added unit: ${unit['name_ar']} (${unit['code']})',
              );
            } catch (insertError) {
              debugPrint(
                'Error inserting unit ${unit['name_ar']}: $insertError',
              );
              if (insertError is Map && insertError['message'] != null) {
                debugPrint('Database error: ${insertError['message']}');
                debugPrint('Details: ${insertError['details']}');
                debugPrint('Hint: ${insertError['hint']}');
              }
            }
          }

          debugPrint('Finished adding default units');
        } else {
          debugPrint('Units table is not empty, skipping seed');
          debugPrint('Response type: ${response.runtimeType}');
          debugPrint('Response content: $response');
        }
      } catch (queryError) {
        debugPrint('Error querying units table: $queryError');
        if (queryError is Map) {
          debugPrint('Error details: ${queryError.toString()}');
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error in _seedDefaultUnits: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة الوحدات الافتراضية: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      rethrow; // Re-throw to see the full error in the console
    } finally {
      debugPrint('=== Completed _seedDefaultUnits ===');
    }
  }

  // Show dialog to add new payment method
  Future<void> _showAddPaymentMethodDialog() async {
    final nameArController = TextEditingController();
    final nameEnController = TextEditingController();
    final descriptionArController = TextEditingController();
    final descriptionEnController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إضافة طريقة دفع جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                    border: OutlineInputBorder(),
                  ),
                  textDirection: ui.TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameEnController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالإنجليزية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionArController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف بالعربية (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textDirection: ui.TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionEnController,
                  decoration: const InputDecoration(
                    labelText: 'الوصف بالإنجليزية (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameArController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الرجاء إدخال الاسم بالعربية'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final client = SupabaseService().client;
                  await client.from('payment_methods').insert({
                    'name_ar': nameArController.text,
                    'name_en': nameEnController.text.isNotEmpty
                        ? nameEnController.text
                        : nameArController.text,
                    'description_ar': descriptionArController.text,
                    'description_en': descriptionEnController.text,
                    'is_active': true,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة طريقة الدفع بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.of(context).pop();
                    await _loadPaymentMethods(); // Refresh the list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  // تحميل طرق الدفع من قاعدة البيانات
  Future<void> _loadPaymentMethods() async {
    if (_isLoadingPaymentMethods) {
      debugPrint('_loadPaymentMethods: عملية تحميل سابقة قيد التنفيذ');
      return;
    }

    debugPrint('=== بدء تحميل طرق الدفع ===');

    if (mounted) {
      setState(() {
        _isLoadingPaymentMethods = true;
        _isInitialized = false;
      });
    }

    try {
      debugPrint('جاري الاتصال بقاعدة البيانات...');
      final client = SupabaseService().client;

      debugPrint('جاري جلب طرق الدفع...');
      final response = await client
          .from('payment_methods')
          .select('*')
          .eq('is_active', true)
          .order('name_ar');

      debugPrint('نوع الاستجابة: ${response.runtimeType}');
      debugPrint('بيانات طرق الدفع المستلمة: $response');

      // Process the received data
      final List<Map<String, dynamic>> paymentMethods = [];

      // Convert response to List if it's not already
      final data = response is List ? response : [];

      for (var item in data) {
        try {
          if (item is Map<String, dynamic>) {
            final method = Map<String, dynamic>.from(item);
            final id = method['id']?.toString();
            final nameAr = method['name_ar']?.toString();

            if (id != null && nameAr != null) {
              paymentMethods.add({
                'id': id,
                'name_ar': nameAr,
                'name_en': method['name_en']?.toString() ?? '',
              });
              debugPrint('تمت إضافة: $nameAr (ID: $id)');
            }
          }
        } catch (e) {
          debugPrint('خطأ في معالجة البيانات: $e');
        }
      }

      if (mounted) {
        setState(() {
          _paymentMethods = paymentMethods;

          if (_paymentMethods.isNotEmpty) {
            // Only set default payment method if not already set
            if (_selectedPaymentMethodId == null ||
                !_paymentMethods.any(
                  (m) => m['id'] == _selectedPaymentMethodId,
                )) {
              _selectedPaymentMethodId = _paymentMethods[0]['id'];
              debugPrint(
                'تم تعيين طريقة الدفع الافتراضية: $_selectedPaymentMethodId',
              );
            }
          } else {
            _selectedPaymentMethodId = null;
            debugPrint('لا توجد طرق دفع متاحة في قاعدة البيانات');
          }

          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل طرق الدفع: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPaymentMethods = false;
        });
      }
    }
  }

  // Get the last reference number from the database
  Future<void> _loadLastReferenceNumber() async {
    if (_isLoadingReference) return;

    if (mounted) {
      setState(() {
        _isLoadingReference = true;
      });
    }

    try {
      final client = SupabaseService().client;
      final response = await client
          .from('purchases')
          .select('reference_number, created_at')
          .order('created_at', ascending: false)
          .limit(1);

      if (response != null && response.isNotEmpty) {
        final lastRef = response[0]['reference_number'] as String?;
        if (lastRef != null && lastRef.startsWith('PUR')) {
          // Extract date and sequence from the last reference
          final datePart = lastRef.substring(3, 11); // YYYYMMDD
          final sequenceStr = lastRef.length > 11
              ? lastRef.substring(11)
              : '000';

          final now = _purchaseDate ?? DateTime.now();
          final currentDate =
              '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

          setState(() {
            if (datePart == currentDate) {
              // If it's the same day, increment the sequence
              _dailySequence = (int.tryParse(sequenceStr) ?? 0) + 1;
            } else {
              // If it's a new day, reset the sequence
              _dailySequence = 1;
            }
            // Update the reference number
            _referenceNumberCtrl.text = _generateReferenceNumber();
          });
        } else {
          // If no valid reference found, start with sequence 1
          setState(() {
            _dailySequence = 1;
            _referenceNumberCtrl.text = _generateReferenceNumber();
          });
        }
      } else {
        // If no purchases exist yet, start with sequence 1
        setState(() {
          _dailySequence = 1;
          _referenceNumberCtrl.text = _generateReferenceNumber();
        });
      }
    } catch (e) {
      debugPrint('Error loading last reference: $e');
      // In case of error, still generate a reference with sequence 1
      setState(() {
        _dailySequence = 1;
        _referenceNumberCtrl.text = _generateReferenceNumber();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReference = false;
        });
      }
    }
  }


  Widget _buildSupplierDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSupplierId,
      decoration: const InputDecoration(
        labelText: 'المورد',
        border: OutlineInputBorder(),
      ),
      items: _suppliers
          .map<DropdownMenuItem<String>>(
            (supplier) => DropdownMenuItem(
              value: supplier['id'].toString(),
              child: Text(supplier['name_ar'] ?? 'بدون اسم'),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedSupplierId = value;
        });
      },
      validator: (value) => value == null ? 'الرجاء اختيار المورد' : null,
    );
  }

  Widget _buildDatePicker(
    BuildContext context,
    String label,
    DateTime? selectedDate, {
    bool isPurchaseDate = false,
  }) {
    return InkWell(
      onTap: () => _selectDate(context, isPurchaseDate: isPurchaseDate),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 16,
          ),
        ),
        child: Text(
          selectedDate != null
              ? '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
              : 'اختر التاريخ',
        ),
      ),
    );
  }

  Widget _buildItemDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الصنف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _itemCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم الصنف',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'هذا الحقل مطلوب' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onTap: () => _selectAll(_quantityCtrl),
                    onChanged: (_) => _calculateAmounts(),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'هذا الحقل مطلوب' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _isLoadingUnits
                      ? const InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'وحدة القياس',
                            border: OutlineInputBorder(),
                          ),
                          child: SizedBox(
                            height: 24,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          value: _selectedUnitId,
                          decoration: const InputDecoration(
                            labelText: 'وحدة القياس',
                            border: OutlineInputBorder(),
                          ),
                          items: _units.map<DropdownMenuItem<String>>((unit) {
                            return DropdownMenuItem<String>(
                              value: unit['id']?.toString(),
                              child: Text(
                                unit['name_ar']?.toString() ?? 'بدون اسم',
                                style: const TextStyle(fontFamily: 'Cairo'),
                                textDirection: ui.TextDirection.rtl,
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedUnitId = newValue;
                              });
                            }
                          },
                          validator: (value) => value == null
                              ? 'الرجاء اختيار وحدة القياس'
                              : null,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المبالغ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _unitPriceCtrl,
              decoration: const InputDecoration(
                labelText: 'سعر الوحدة',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onTap: () => _selectAll(_unitPriceCtrl),
              onChanged: (_) => _calculateAmounts(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _taxPercentCtrl,
              decoration: const InputDecoration(
                labelText: 'نسبة الضريبة %',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onTap: () => _selectAll(_taxPercentCtrl),
              onChanged: (_) => _calculateAmounts(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _discountPercentCtrl,
              decoration: const InputDecoration(
                labelText: 'نسبة الخصم %',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onTap: () => _selectAll(_discountPercentCtrl),
              onChanged: (_) => _calculateAmounts(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountPaidCtrl,
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onTap: () => _selectAll(_amountPaidCtrl),
              onChanged: (_) {
                _amountPaidDebounce?.cancel();
                _amountPaidDebounce = Timer(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  _calculateAmounts();
                });
              },
              onEditingComplete: () {
                _amountPaidDebounce?.cancel();
                _calculateAmounts();
              },
              onFieldSubmitted: (_) {
                _amountPaidDebounce?.cancel();
                _calculateAmounts();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملاحظات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesArCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظات بالعربية',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesEnCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظات بالإنجليزية',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickers() {
    return Row(
      children: [
        Expanded(
          child: _buildDatePicker(
            context,
            'تاريخ الشراء',
            _purchaseDate,
            isPurchaseDate: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _buildDatePicker(context, 'تاريخ الاستحقاق', _dueDate)),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    bool isPurchaseDate = false,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchaseDate
          ? (_purchaseDate ?? DateTime.now())
          : (_dueDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isPurchaseDate) {
          _purchaseDate = picked;
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _generateReferenceNumber();
    _loadLastReferenceNumber();
    _loadStatuses();
    _loadSuppliers();
    _loadPaymentMethods();
    _loadUnits();
    _loadPurchaseData();
    _loadOperations();
    // Removed direct listeners to avoid double-trigger loops; rely on onChanged callbacks only

    // Load data after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedDefaultUnits().then((_) {
        _loadSuppliers();
        _loadUnits();
        _loadPaymentMethods();
        _loadStatuses();
      });
    });

    // Calculate initial amounts
    _calculateAmounts();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _referenceNumberCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    _quantityCtrl.dispose();
    _unitPriceCtrl.dispose();
    _subtotalCtrl.dispose();
    _discountAmountCtrl.dispose();
    _discountPercentCtrl.dispose();
    _taxAmountCtrl.dispose();
    _taxPercentCtrl.dispose();
    _taxDiscountAmountCtrl.dispose();
    _taxDiscountPercentCtrl.dispose();
    _totalAmountCtrl.dispose();
    _amountPaidCtrl.dispose();
    _amountDueCtrl.dispose();
    _notesArCtrl.dispose();
    _notesEnCtrl.dispose();
    _itemCtrl.dispose();
    _amountPaidDebounce?.cancel();
    super.dispose();
  }

  // Select all text in a controller (used to auto-select default values on tap)
  void _selectAll(TextEditingController c) {
    try {
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    } catch (_) {}
  }

  // Determine if an operation matches the selected type (supports synonyms and Arabic labels)
  bool _opMatchesType(Map<String, dynamic> op, String? selected) {
    if (selected == null || selected == 'all') return true;
    final t = (op['type']?.toString() ?? '').toLowerCase();
    final s = selected.toLowerCase();
    if (s == 'manufacturing') {
      return t == 'manufacturing' ||
          t == 'industrial' ||
          t == 'industry' ||
          t.contains('manufact') ||
          t.contains('صنا');
    }
    if (s == 'commercial') {
      return t == 'commercial' ||
          t.contains('commercial') ||
          t.contains('تجار');
    }
    return true;
  }

  // Show bottom sheet to select operation (type + operation)
  Future<void> _showOperationSelector() async {
  // Ensure operations are loaded
  if (_operations.isEmpty && !_isLoadingOperations) {
    await _loadOperations();
  }

  String? localType = _selectedOperationType ?? 'all';
  String? localOpId = _selectedOperationId;
  String? localStageId = _selectedStageId;

  if (!mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                final filtered = _operations.where((op) => _opMatchesType(op, localType)).toList();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ربط بعملية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: localType,
                      decoration: const InputDecoration(
                        labelText: 'نوع العملية',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'commercial', child: Text('عملية تجارية')),
                        DropdownMenuItem(value: 'manufacturing', child: Text('عملية صناعية')),
                        DropdownMenuItem(value: 'all', child: Text('كل العمليات')),
                      ],
                      onChanged: (v) {
                        setSheetState(() {
                          localType = v;
                          // reset selection if current op not in new filter
                          if (localOpId != null && !_operations.any((op) => op['id'] == localOpId && _opMatchesType(op, localType))) {
                            localOpId = null;
                            localStageId = null;
                            _stages = [];
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: localOpId,
                      decoration: const InputDecoration(
                        labelText: 'اختر العملية',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: '', child: Text('بدون ربط بعملية')),
                        ...filtered.map((op) => DropdownMenuItem<String>(
                              value: op['id'] as String?,
                              child: Text("${op['operation_code']} - ${op['type']}"),
                            )),
                      ],
                      onChanged: (v) async {
                        setSheetState(() {
                          localOpId = (v == null || v.isEmpty) ? null : v;
                          localStageId = null;
                          _stages = [];
                        });
                        if (localOpId != null) {
                          await _loadStagesForOperation(localOpId!);
                        }
                        if (mounted) {
                          setSheetState(() {});
                        }
                      },
                    ),

                    const SizedBox(height: 12),
                    IgnorePointer(
                      ignoring: localOpId == null,
                      child: Opacity(
                        opacity: localOpId == null ? 0.6 : 1,
                        child: _isLoadingStages
                            ? const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'مرحلة العملية',
                                  border: OutlineInputBorder(),
                                ),
                                child: SizedBox(
                                  height: 24,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: localStageId,
                                decoration: const InputDecoration(
                                  labelText: 'مرحلة العملية',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(value: '', child: Text('بدون ربط بمرحلة')),
                                  ..._stages.map((s) => DropdownMenuItem<String>(
                                        value: s['stage_id'] as String?,
                                        child: Text("${s['stage_name']}"),
                                      )),
                                ],
                                onChanged: (v) {
                                  setSheetState(() {
                                    localStageId = (v == null || v.isEmpty) ? null : v;
                                  });
                                },
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('إلغاء'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedOperationType = localType;
                              _selectedOperationId = localOpId;
                              _selectedStageId = localStageId;
                            });
                            Navigator.of(ctx).pop();
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('حفظ'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}


  Future<void> _pickDate({
    required bool isPurchaseDate,
  }) async {
    final initialDate = isPurchaseDate
        ? (_purchaseDate ?? DateTime.now())
        : (_dueDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (isPurchaseDate) {
        _purchaseDate = picked;
        // Reload reference number with the new date
        await _loadLastReferenceNumber();
      } else {
        _dueDate = picked;
      }

      if (mounted) {
        setState(() {});
      }
    }
  }

  // Show dialog to add new supplier
  Future<void> _showAddSupplierDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إضافة مورد جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المورد',
                    border: OutlineInputBorder(),
                  ),
                  textDirection: ui.TextDirection.rtl,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  textDirection: ui.TextDirection.ltr,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('حفظ'),
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  try {
                    final client = SupabaseService().client;
                    final response = await client.from('suppliers').insert({
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim().isNotEmpty
                          ? phoneController.text.trim()
                          : null,
                      'created_at': DateTime.now().toIso8601String(),
                    }).select();

                    if (mounted) {
                      // Reload suppliers and select the new one
                      await _loadSuppliers();
                      setState(() {
                        _selectedSupplierId = response[0]['id'].toString();
                      });

                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تمت إضافة المورد بنجاح')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء إدخال اسم المورد')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // تحميل وحدات القياس من قاعدة البيانات
  Future<void> _loadUnits() async {
    if (_isLoadingUnits) {
      debugPrint('_loadUnits: عملية تحميل سابقة قيد التنفيذ');
      return;
    }

    debugPrint('=== بدء تحميل وحدات القياس ===');

    if (mounted) {
      setState(() {
        _isLoadingUnits = true;
      });
    }

    try {
      debugPrint('جاري الاتصال بقاعدة البيانات...');
      final client = SupabaseService().client;

      try {
        debugPrint('جاري جلب وحدات القياس...');
        final response = await client
            .from('units')
            .select('id, name_ar, name_en, code')
            .order('name_ar');

        debugPrint('نوع الاستجابة: ${response.runtimeType}');
        debugPrint('البيانات المستلمة: $response');

        // معالجة البيانات المستلمة
        final List<Map<String, dynamic>> units = [];

        if (response != null && response is List) {
          final data = response;
          debugPrint('تم استلام ${data.length} وحدة قياس');

          for (var item in data) {
            try {
              final unit = Map<String, dynamic>.from(item);
              if (unit['id'] != null && unit['name_ar'] != null) {
                units.add(unit);
                debugPrint('تمت إضافة: ${unit['name_ar']} (ID: ${unit['id']})');
              }
            } catch (e) {
              debugPrint('خطأ في معالجة البيانات: $e');
            }
          }
        } else {
          debugPrint('لا توجد وحدات متاحة');
        }

        if (mounted) {
          setState(() {
            _units = units;

            if (_units.isNotEmpty) {
              // تحديد الوحدة الافتراضية إذا لم يتم تحديد واحدة
              if (_selectedUnitId == null || _selectedUnitId!.isEmpty) {
                _selectedUnitId = _units[0]['id'].toString();
                debugPrint('تم تعيين الوحدة الافتراضية: $_selectedUnitId');
              } else {
                // التحقق من وجود الوحدة المحددة في القائمة الجديدة
                if (!_units.any(
                  (unit) => unit['id'].toString() == _selectedUnitId,
                )) {
                  _selectedUnitId = _units[0]['id'].toString();
                  debugPrint(
                    'تم إعادة تعيين الوحدة المحددة إلى: $_selectedUnitId',
                  );
                }
              }
            } else {
              _selectedUnitId = null;
              debugPrint('لا توجد وحدات متاحة في قاعدة البيانات');

              // محاولة إضافة وحدات افتراضية إذا لم يتم العثور على أي وحدات
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _seedDefaultUnits().then((_) => _loadUnits());
              });
            }

            _isLoadingUnits = false;
          });
        }
      } catch (queryError) {
        debugPrint('خطأ في استعلام قاعدة البيانات: $queryError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'حدث خطأ في جلب وحدات القياس. يرجى المحاولة مرة أخرى.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('خطأ غير متوقع: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ غير متوقع. يرجى إعادة تحميل الصفحة.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUnits = false;
        });
      }
      debugPrint('=== Completed _loadUnits ===');
    }
  }

  // Show dialog to add new unit
  Future<void> _showAddUnitDialog() async {
    final nameArController = TextEditingController();
    final nameEnController = TextEditingController();
    final codeController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إضافة وحدة قياس جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                    border: OutlineInputBorder(),
                  ),
                  textDirection: ui.TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameEnController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالإنجليزية',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'الكود (اختياري)',
                    hintText: 'مثال: KG, L, PCS',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameArController.text.trim().isNotEmpty &&
                    nameEnController.text.trim().isNotEmpty) {
                  try {
                    final client = SupabaseService().client;
                    final response = await client.from('units').insert({
                      'name_ar': nameArController.text.trim(),
                      'name_en': nameEnController.text.trim(),
                      'code': codeController.text.trim().isNotEmpty
                          ? codeController.text.trim().toUpperCase()
                          : null,
                    }).select();

                    if (mounted) {
                      await _loadUnits();
                      setState(() {
                        _selectedUnitId = response[0]['id'].toString();
                      });

                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تمت إضافة الوحدة بنجاح')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('حدث خطأ: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'الرجاء إدخال الاسم بالعربية والإنجليزية',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  // Load suppliers from the database
  Future<void> _loadSuppliers() async {
    try {
      final client = SupabaseService().client;
      final response = await client
          .from('suppliers')
          .select('id, name')
          .order('name');

      if (mounted) {
        setState(() {
          _suppliers = List<Map<String, dynamic>>.from(response);
          // Add a default "بدون مورد" option
          _suppliers.insert(0, {'id': null, 'name': 'بدون مورد'});
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Postgrest Error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الموردين: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error loading suppliers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحميل قائمة الموردين')),
        );
      }
    }
  }

  // Calculate subtotal, total, and amount due
  void _calculateAmounts() {
    if (!mounted) return;
    if (_isProgrammaticUpdate) return; // Skip if we are applying programmatic text updates
    if (_isCalculatingAmounts) return;
    _isCalculatingAmounts = true;
    _isProgrammaticUpdate = true; // Suppress onChanged/listener loops while we update fields

    try {
      // Get base values
      final quantity = double.tryParse(_quantityCtrl.text) ?? 0;
      final unitPrice = double.tryParse(_unitPriceCtrl.text) ?? 0;
      final subtotal = quantity * unitPrice;

      // Update UI with setState to reflect changes
      setState(() {
        _subtotalCtrl.text = subtotal.toStringAsFixed(2);

        double taxAmount = 0;
        double taxDiscountAmount = 0;

        // Calculate tax only if taxable
        if (_isTaxable) {
          // Get tax percentage and calculate tax amount
          final taxPercent = double.tryParse(_taxPercentCtrl.text) ?? 0;
          taxAmount = (subtotal * taxPercent) / 100;

          // Get tax discount percentage and calculate discount amount
          final taxDiscountPercent =
              double.tryParse(_taxDiscountPercentCtrl.text) ?? 0;
          taxDiscountAmount = (taxAmount * taxDiscountPercent) / 100;

          // Update controllers with new values
          _taxAmountCtrl.text = (taxAmount - taxDiscountAmount).toStringAsFixed(
            2,
          );
          _taxDiscountAmountCtrl.text = taxDiscountAmount.toStringAsFixed(2);

          // Force update the text in the controllers to reflect changes
          _taxAmountCtrl.value = _taxAmountCtrl.value.copyWith(
            text: (taxAmount - taxDiscountAmount).toStringAsFixed(2),
            selection: TextSelection.collapsed(
              offset: _taxAmountCtrl.text.length,
            ),
          );

          _taxDiscountAmountCtrl.value = _taxDiscountAmountCtrl.value.copyWith(
            text: taxDiscountAmount.toStringAsFixed(2),
            selection: TextSelection.collapsed(
              offset: _taxDiscountAmountCtrl.text.length,
            ),
          );
        } else {
          // Reset tax-related fields if not taxable
          _taxAmountCtrl.text = '0.00';
          _taxDiscountAmountCtrl.text = '0.00';
          _taxDiscountPercentCtrl.text = '0';

          // Force update the text in the controllers
          _taxAmountCtrl.value = _taxAmountCtrl.value.copyWith(
            text: '0.00',
            selection: TextSelection.collapsed(
              offset: _taxAmountCtrl.text.length,
            ),
          );

          _taxDiscountAmountCtrl.value = _taxDiscountAmountCtrl.value.copyWith(
            text: '0.00',
            selection: TextSelection.collapsed(
              offset: _taxDiscountAmountCtrl.text.length,
            ),
          );

          _taxDiscountPercentCtrl.value = _taxDiscountPercentCtrl.value
              .copyWith(
                text: '0',
                selection: TextSelection.collapsed(
                  offset: _taxDiscountPercentCtrl.text.length,
                ),
              );
        }

        // Calculate regular discount (on subtotal)
        final discountPercent = double.tryParse(_discountPercentCtrl.text) ?? 0;
        final discountAmount = (subtotal * discountPercent) / 100;
        _discountAmountCtrl.text = discountAmount.toStringAsFixed(2);

        // Calculate total
        final total =
            subtotal + (taxAmount - taxDiscountAmount) - discountAmount;
        _totalAmountCtrl.text = total.toStringAsFixed(2);

        // Update amount due and auto-update payment status
        String _norm(String s) {
          final t = s.trim().replaceAll('٬', '').replaceAll('\u00A0', '');
          if (t.contains(',') && !t.contains('.')) {
            return t.replaceAll(',', '.');
          }
          return t.replaceAll(',', '');
        }
        final paid = double.tryParse(_norm(_amountPaidCtrl.text)) ?? 0;
        final amountDueRaw = total - paid;
        final amountDue = amountDueRaw < 0 ? 0.0 : amountDueRaw;
        _amountDueCtrl.text = amountDue.toStringAsFixed(2);

        // Auto update status unless user explicitly selected cancelled in this session
        const double epsilon = 0.01; // tolerance for floating point
        if (!_userChoseCancelled) {
          // Currency-safe comparison using cents
          final totalCents = (total * 100).round();
          final paidCents = (paid * 100).round();
          final amountDueCents = ((_amountDueCtrl.text.isEmpty
                      ? 0.0
                      : double.tryParse(_amountDueCtrl.text) ?? (total - paid))
                  * 100)
              .round();

          String nextStatusCode;
          if (totalCents <= 0) {
            // No total to pay; keep draft or pending based on paid
            nextStatusCode = (paidCents > 0) ? 'partially_paid' : 'pending';
          } else if (paidCents >= totalCents || amountDueCents == 0) {
            nextStatusCode = 'completed';
          } else if (paidCents == 0) {
            nextStatusCode = 'pending';
          } else {
            nextStatusCode = 'partially_paid';
          }

          final sig = '${total.toStringAsFixed(2)}|${paid.toStringAsFixed(2)}|${amountDue.toStringAsFixed(2)}|$nextStatusCode';
          if (_lastAutoStatusSignature != sig) {
            debugPrint('[AutoStatus] total=$total paid=$paid amountDue=$amountDue next=$nextStatusCode');
          }

          // Map legacy desired to DB code, preferring Arabic and avoiding 'ملغاة' unless chosen
          String safeCode;
          if (amountDueCents == 0 || paidCents >= totalCents) {
            // Force to Arabic 'مدفوع' if available
            final paidAr = _dbStatuses.firstWhere(
              (s) => (s['code']?.toString() ?? '') == 'مدفوع',
              orElse: () => {},
            )['code']?.toString();
            if (paidAr != null && paidAr.isNotEmpty) {
              safeCode = paidAr;
            } else {
              safeCode = _mapLegacyToDbCode('completed');
            }
          } else {
            safeCode = _mapLegacyToDbCode(nextStatusCode);
          }
          if ((safeCode == 'ملغاة' || safeCode.toLowerCase() == 'cancelled') && !_userChoseCancelled) {
            // avoid auto-cancelling
            safeCode = _mapLegacyToDbCode('pending');
          }
          _selectedStatusCode = safeCode;
          // Align legacy _status with selected code (Arabic/English)
          switch (safeCode) {
            case 'completed':
            case 'مدفوع':
              _status = 'completed';
              break;
            case 'partially_paid':
            case 'مدفوعة جزئياً':
              _status = 'partially_paid';
              break;
            case 'pending':
            case 'غير مدفوع':
              _status = 'pending';
              break;
            case 'cancelled':
            case 'ملغاة':
              _status = 'cancelled';
              break;
            default:
              _status = 'draft';
          }
          if (_selectedStatusCode != 'ملغاة' && _selectedStatusCode != 'cancelled') {
            _userChoseCancelled = false;
          }
        }
      });
    } catch (e) {
      debugPrint('Error calculating amounts: $e');
    } finally {
      _isCalculatingAmounts = false;
      _isProgrammaticUpdate = false; // Re-enable reactions after updates
    }
  }

  // Resolve status code to an available code from DB statuses (flexible matching)
  String _resolveStatusCode(String desired) {
    // 1) exact candidate matches
    List<String> candidates;
    switch (desired) {
      case 'completed':
        candidates = ['completed', 'paid', 'fully_paid', 'done'];
        break;
      case 'partially_paid':
        candidates = ['partially_paid', 'partial', 'part_paid'];
        break;
      case 'pending':
        candidates = ['pending', 'unpaid', 'due', 'draft'];
        break;
      case 'cancelled':
        candidates = ['cancelled', 'canceled'];
        break;
      default:
        candidates = [desired];
    }
    for (final c in candidates) {
      if (_dbStatuses.any((s) => s['code']?.toString().toLowerCase() == c)) {
        return c;
      }
    }

    // 2) fuzzy match on code
    String? fuzzy;
    for (final s in _dbStatuses) {
      final code = s['code']?.toString().toLowerCase() ?? '';
      if (desired == 'completed' && (code.contains('paid') || code.contains('complete') || code.contains('done'))) {
        fuzzy = code; break;
      }
      if (desired == 'partially_paid' && (code.contains('partial') || code.contains('part'))) {
        fuzzy = code; break;
      }
      if (desired == 'pending' && (code.contains('pending') || code.contains('unpaid') || code.contains('due') || code.contains('draft'))) {
        fuzzy = code; break;
      }
    }
    if (fuzzy != null) return fuzzy;

    // 3) fuzzy match on Arabic names
    for (final s in _dbStatuses) {
      final nameAr = (s['name_ar']?.toString() ?? '').replaceAll('ً', '').replaceAll('ٌ', '').replaceAll('ٍ', '');
      if (desired == 'completed' && nameAr.contains('مدفوع')) return s['code']?.toString() ?? desired;
      if (desired == 'partially_paid' && (nameAr.contains('جزئ') || nameAr.contains('جزئي'))) return s['code']?.toString() ?? desired;
      if (desired == 'pending' && (nameAr.contains('غير') || nameAr.contains('غير مدفوع') || nameAr.contains('معلق'))) return s['code']?.toString() ?? desired;
    }

    // 4) fallback: keep current selected if valid else first
    if (_selectedStatusCode != null && _dbStatuses.any((s) => s['code']?.toString() == _selectedStatusCode)) {
      return _selectedStatusCode!;
    }
    return _dbStatuses.isNotEmpty
        ? (_dbStatuses.first['code']?.toString() ?? desired)
        : desired;
  }

  // Map legacy status (completed/pending/partially_paid/cancelled) to a DB code, preferring Arabic codes
  String _mapLegacyToDbCode(String legacy) {
    // 1) direct Arabic preferences
    String? preferArabic;
    switch (legacy) {
      case 'completed':
        preferArabic = _dbStatuses.firstWhere(
          (s) => (s['code']?.toString() ?? '') == 'مدفوع' ||
                 (s['name_ar']?.toString() ?? '').contains('مدفوع'),
          orElse: () => {},
        )['code']?.toString();
        break;
      case 'partially_paid':
        preferArabic = _dbStatuses.firstWhere(
          (s) => (s['code']?.toString() ?? '') == 'مدفوعة جزئياً' ||
                 (s['name_ar']?.toString() ?? '').contains('جزئ'),
          orElse: () => {},
        )['code']?.toString();
        break;
      case 'pending':
        preferArabic = _dbStatuses.firstWhere(
          (s) => (s['code']?.toString() ?? '') == 'غير مدفوع' ||
                 (s['name_ar']?.toString() ?? '').contains('غير'),
          orElse: () => {},
        )['code']?.toString();
        break;
      case 'cancelled':
        preferArabic = _dbStatuses.firstWhere(
          (s) => (s['code']?.toString() ?? '') == 'ملغاة' ||
                 (s['name_ar']?.toString() ?? '').contains('لغاء'),
          orElse: () => {},
        )['code']?.toString();
        break;
    }
    if (preferArabic != null && preferArabic.isNotEmpty) return preferArabic;

    // 2) exact legacy code exists
    final exact = _dbStatuses.firstWhere(
      (s) => (s['code']?.toString().toLowerCase() ?? '') == legacy,
      orElse: () => {},
    )['code']?.toString();
    if (exact != null && exact.isNotEmpty) return exact;

    // 3) keep current if valid
    if (_selectedStatusCode != null &&
        _dbStatuses.any((s) => (s['code']?.toString() ?? '') == _selectedStatusCode)) {
      return _selectedStatusCode!;
    }

    // 4) safe fallback: prefer 'غير مدفوع' then any non-cancel Arabic
    final pendingAr = _dbStatuses.firstWhere(
      (s) => (s['code']?.toString() ?? '') == 'غير مدفوع',
      orElse: () => {},
    )['code']?.toString();
    if (pendingAr != null && pendingAr.isNotEmpty) return pendingAr;

    final nonCancelled = _dbStatuses
        .map((s) => s['code']?.toString() ?? '')
        .firstWhere((c) => c.isNotEmpty && c != 'ملغاة' && c.toLowerCase() != 'cancelled', orElse: () => 'غير مدفوع');
    return nonCancelled.isNotEmpty ? nonCancelled : legacy;
  }

  // Log activity for purchase operations
  Future<void> _logPurchaseActivity(
    String action,
    String purchaseId, {
    String? details,
  }) async {
    try {
      final supabase = SupabaseService().client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        final displayName =
            user.email ?? user.userMetadata?['full_name'] ?? 'User';

        await supabase.from('activity_logs').insert({
          'user_id': user.id,
          'user_name': displayName,
          'action': action,
          'entity_type': 'PURCHASE',
          'entity_id': purchaseId,
          'description': details ?? 'Purchase $action',
          'ip_address': '', // You can add IP tracking if needed
          'user_agent': '', // You can add user agent if needed
        });
      }
    } catch (e) {
      debugPrint('Error logging purchase activity: $e');
      // Don't fail the operation if logging fails
    }
  }

  // Load purchase statuses from DB (purchase_statuses)
  Future<void> _loadStatuses() async {
    if (_isLoadingStatuses) return;
    if (!mounted) return;
    setState(() => _isLoadingStatuses = true);
    try {
      final client = SupabaseService().client;
      final response = await client
          .from('purchase_statuses')
          .select('code, name_ar, name_en, color, is_active')
          .eq('is_active', true)
          .order('name_ar');

      final list = (response is List)
          ? response
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _dbStatuses = list;

        // Initialize or correct selected status code
        final hasSelected =
            _selectedStatusCode != null &&
            _dbStatuses.any(
              (s) => s['code']?.toString() == _selectedStatusCode,
            );

        if (!hasSelected) {
          final fromCode = widget.purchase?['status_code']?.toString();
          final fromLegacy = widget.purchase?['status']?.toString();
          String code = 'draft';

          if (fromCode != null && fromCode.isNotEmpty) {
            code = fromCode;
          } else if (fromLegacy != null && fromLegacy.isNotEmpty) {
            switch (fromLegacy.toLowerCase()) {
              case 'completed':
              case 'paid':
                code = 'completed';
                break;
              case 'partially_paid':
                code = 'partially_paid';
                break;
              case 'pending':
                code = 'pending';
                break;
              case 'cancelled':
                code = 'cancelled';
                break;
              default:
                code = 'draft';
            }
          }

          _selectedStatusCode =
              _dbStatuses.any((s) => s['code']?.toString() == code)
              ? code
              : (_dbStatuses.any((s) => (s['code']?.toString() ?? '') == 'pending')
                  ? 'pending'
                  : (_dbStatuses.any((s) => (s['code']?.toString() ?? '') == 'draft')
                      ? 'draft'
                      : (_dbStatuses.isNotEmpty
                          ? _dbStatuses.first['code']?.toString()
                          : 'draft')));
        }
      });
    } catch (e) {
      debugPrint('Error loading statuses: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحميل حالات الفواتير: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingStatuses = false);
    }
  }

  // Load purchase data when editing
  Future<void> _loadPurchaseData() async {
    if (widget.purchase == null) return;

    try {
      setState(() => _isSaving = true);

      final purchase = widget.purchase!;
      _referenceNumberCtrl.text = purchase['reference_number'] ?? '';
      _invoiceNumberCtrl.text = purchase['invoice_number'] ?? '';
      _selectedSupplierId = purchase['supplier_id']?.toString();
      // Load linked operation if present
      _selectedOperationId = purchase['operation_id']?.toString();
      // Load linked stage if present
      _selectedStageId = purchase['stage_id']?.toString();
      if (_selectedOperationId != null && _selectedOperationId!.isNotEmpty) {
        await _loadStagesForOperation(_selectedOperationId!);
      }

      // Load payment method first
      await _loadPaymentMethods();

      // Set payment method after loading all methods
      if (purchase['payment_method_id'] != null) {
        final paymentMethodId = purchase['payment_method_id']?.toString();
        if (_paymentMethods.any((m) => m['id'] == paymentMethodId)) {
          _selectedPaymentMethodId = paymentMethodId;
        } else if (_paymentMethods.isNotEmpty) {
          // If the saved payment method is not found, use the first available one
          _selectedPaymentMethodId = _paymentMethods[0]['id'];
        }
      } else if (_paymentMethods.isNotEmpty) {
        // If no payment method is set, use the first available one
        _selectedPaymentMethodId = _paymentMethods[0]['id'];
      }

      _purchaseDate = purchase['purchase_date'] != null
          ? DateTime.parse(purchase['purchase_date'])
          : null;
      _dueDate = purchase['due_date'] != null
          ? DateTime.parse(purchase['due_date'])
          : null;
      _itemCtrl.text = purchase['item'] ?? '';
      _quantityCtrl.text = (purchase['quantity'] ?? 0).toString();
      _unitPriceCtrl.text = (purchase['unit_price'] ?? 0).toString();
      _taxPercentCtrl.text = (purchase['tax_percent'] ?? 0).toString();
      _discountPercentCtrl.text = (purchase['discount_percent'] ?? 0)
          .toString();
      _amountPaidCtrl.text = (purchase['amount_paid'] ?? 0).toString();
      _notesArCtrl.text = purchase['notes_ar'] ?? '';
      _notesEnCtrl.text = purchase['notes_en'] ?? '';

      // Update status
      final loadedStatus = (purchase['status'] ?? 'draft')
          .toString()
          .toLowerCase();
      switch (loadedStatus) {
        case 'completed':
        case 'paid':
          _status = 'completed';
          break;
        case 'partially_paid':
          _status = 'partially_paid';
          break;
        case 'pending':
          _status = 'pending';
          break;
        case 'cancelled':
          _status = 'cancelled';
          break;
        default:
          _status = 'draft';
      }

      // Update status_code
      final loadedCode = (purchase['status_code'] ?? '')
          .toString()
          .toLowerCase();
      if (loadedCode.isNotEmpty) {
        _selectedStatusCode = loadedCode;
      } else {
        switch (loadedStatus) {
          case 'completed':
          case 'paid':
            _selectedStatusCode = 'completed';
            break;
          case 'partially_paid':
            _selectedStatusCode = 'partially_paid';
            break;
          case 'pending':
            _selectedStatusCode = 'pending';
            break;
          case 'cancelled':
            _selectedStatusCode = 'cancelled';
            break;
          default:
            _selectedStatusCode = 'draft';
        }
      }

      // Recalculate amounts
      _calculateAmounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل بيانات الفاتورة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate required fields
    if (_selectedUnitId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء اختيار وحدة القياس'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Validate payment method is selected
    if (_selectedPaymentMethodId == null || _selectedPaymentMethodId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الرجاء اختيار طريقة الدفع'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;

      // Get the selected unit details
      final selectedUnit = _units.firstWhere(
        (unit) => unit['id'].toString() == _selectedUnitId,
        orElse: () => {
          'id': 0,
          'name_ar': 'غير محدد',
          'name_en': 'Not specified',
        },
      );

      // Prepare purchase data
      final purchaseData = <String, dynamic>{
        'reference_number': _referenceNumberCtrl.text,
        'unit_id': int.tryParse(_selectedUnitId ?? '') ?? 0,
        'unit_of_measure_ar': selectedUnit['name_ar'] ?? 'غير محدد',
        'unit_of_measure_en': selectedUnit['name_en'] ?? 'Not specified',
        'invoice_number': _invoiceNumberCtrl.text,
        'supplier_id': _selectedSupplierId,
        'payment_method_id': _selectedPaymentMethodId, // Add payment method ID
        'purchase_date': _purchaseDate?.toIso8601String(),
        'due_date': _dueDate?.toIso8601String(),
        'operation_id': (_selectedOperationId == null || _selectedOperationId!.isEmpty)
            ? null
            : _selectedOperationId,
        'stage_id': (_selectedStageId == null || _selectedStageId!.isEmpty)
            ? null
            : _selectedStageId,
        'item': _itemCtrl.text,
        'quantity': double.tryParse(_quantityCtrl.text) ?? 0,
        'unit_price': double.tryParse(_unitPriceCtrl.text) ?? 0,
        'total_amount': _totalAmountCtrl.text.isEmpty
            ? 0.0
            : double.tryParse(_totalAmountCtrl.text) ?? 0.0,
        'tax_percent': double.tryParse(_taxPercentCtrl.text) ?? 0,
        'tax_amount': _taxAmountCtrl.text.isEmpty
            ? 0.0
            : double.tryParse(_taxAmountCtrl.text) ?? 0.0,
        'discount_percent': double.tryParse(_discountPercentCtrl.text) ?? 0,
        'discount_amount': _discountAmountCtrl.text.isEmpty
            ? 0.0
            : double.tryParse(_discountAmountCtrl.text) ?? 0.0,
        'amount_paid': double.tryParse(_amountPaidCtrl.text) ?? 0,
        'amount_due': _amountDueCtrl.text.isEmpty
            ? 0.0
            : double.tryParse(_amountDueCtrl.text) ?? 0.0,
        'notes_ar': _notesArCtrl.text,
        'notes_en': _notesEnCtrl.text,
        'status': (() {
          // map from code (Arabic/English) to legacy
          final code = (_selectedStatusCode ?? _status).toString();
          switch (code) {
            // English
            case 'completed':
              return 'completed';
            case 'partially_paid':
              return 'partially_paid';
            case 'pending':
              return 'pending';
            case 'cancelled':
              return 'cancelled';
            // Arabic
            case 'مدفوع':
              return 'completed';
            case 'مدفوعة جزئياً':
              return 'partially_paid';
            case 'غير مدفوع':
              return 'pending';
            case 'ملغاة':
              return 'cancelled';
            default:
              return 'draft';
          }
        })(),
        'status_code': _selectedStatusCode ?? 'draft',
        'notes_ar': _notesArCtrl.text,
        'notes_en': _notesEnCtrl.text,
        'is_taxable': _isTaxable,
        'subtotal': double.tryParse(_subtotalCtrl.text) ?? 0,
      };

      // Only add supplier_id if it's not null and not empty
      if (_selectedSupplierId != null && _selectedSupplierId!.isNotEmpty) {
        purchaseData['supplier_id'] = _selectedSupplierId;
      }

      // Add payment method ID if selected
      if (_selectedPaymentMethodId != null &&
          _selectedPaymentMethodId!.isNotEmpty) {
        purchaseData['payment_method_id'] = _selectedPaymentMethodId;
      }

      // Remove null values to avoid database errors
      purchaseData.removeWhere((key, value) => value == null);

      if (widget.purchase != null) {
        if (user != null) {
          purchaseData['updated_by'] = user.id;
        }
        // تحديث الفاتورة الموجودة
        await client
            .from('purchases')
            .update(purchaseData)
            .eq('id', widget.purchase!['id']);

        // Stage expense logging on update
        try {
          final prevOpId = widget.purchase!['operation_id']?.toString();
          final prevStageId = widget.purchase!['stage_id']?.toString();
          final newOpId = _selectedOperationId;
          final newStageId = _selectedStageId;
          // Parse old and new totals
          double oldTotal = 0.0;
          final prevTotalDyn = widget.purchase!['total_amount'];
          if (prevTotalDyn is num) oldTotal = prevTotalDyn.toDouble();
          else if (prevTotalDyn is String) oldTotal = double.tryParse(prevTotalDyn) ?? 0.0;
          final newTotal = (_totalAmountCtrl.text.isEmpty
              ? 0.0
              : double.tryParse(_totalAmountCtrl.text) ?? 0.0);
          if (newOpId != null && newOpId.isNotEmpty && newStageId != null && newStageId.isNotEmpty) {
            // If first time assigning a stage, add full amount
            if (prevStageId == null || prevStageId.toString().isEmpty || prevOpId != newOpId || prevStageId != newStageId) {
              if (newTotal > 0) {
                final orderNo = await _getStageOrderNo(newOpId, newStageId) ?? 1;
                await _addStageExpense(
                  operationId: newOpId,
                  stageId: newStageId,
                  orderNo: orderNo,
                  amount: newTotal,
                  note: 'مصروف فاتورة مشتريات رقم ${_referenceNumberCtrl.text}',
                );
              }
            } else {
              // Same stage/op: add only the delta if increased
              final delta = newTotal - oldTotal;
              if (delta > 0) {
                final orderNo = await _getStageOrderNo(newOpId, newStageId) ?? 1;
                await _addStageExpense(
                  operationId: newOpId,
                  stageId: newStageId,
                  orderNo: orderNo,
                  amount: delta,
                  note: 'فرق زيادة فاتورة مشتريات رقم ${_referenceNumberCtrl.text}',
                );
              }
            }
          }
        } catch (e) {
          debugPrint('Stage expense logging (update) failed: $e');
        }

        // سجل النشاط
        final updatedId = widget.purchase!['id'].toString();
        final oldMap = Map<String, dynamic>.from(widget.purchase!);
        final List<String> changes = [];
        purchaseData.forEach((k, v) {
          final prev = oldMap[k];
          final prevStr = prev?.toString() ?? '';
          final newStr = v?.toString() ?? '';
          if (prevStr != newStr) {
            changes.add('$k: ${prev ?? '-'} -> ${v ?? '-'}');
          }
        });
        final detailsMsg = changes.isNotEmpty
            ? 'Update purchase ${_referenceNumberCtrl.text} | ' + changes.join(', ')
            : 'Update purchase ${_referenceNumberCtrl.text}';
        await _logPurchaseActivity(
          'UPDATE',
          updatedId,
          details: detailsMsg,
        );

        // تسجيل دفعة المورد إذا تم اختيار مورد وإدخال مبلغ مدفوع
        final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
        double previousPaid = 0.0;
        final prev = widget.purchase!['amount_paid'];
        if (prev is num) {
          previousPaid = prev.toDouble();
        } else if (prev is String) {
          previousPaid = double.tryParse(prev) ?? 0.0;
        }
        final delta = amountPaid - previousPaid;
        if (delta > 0) {
          await _recordSupplierPayment(
            _referenceNumberCtrl.text,
            delta,
            _selectedSupplierId,
            _selectedPaymentMethodId,
          );
        }

        // تحديث جدول supplier_purchases إذا تم اختيار مورد
        if (_selectedSupplierId != null && _selectedSupplierId!.isNotEmpty) {
          // التأكد من وجود الجدول أولاً
          await _ensureSupplierPurchasesTable();

          // استخراج المبلغ القديم من بيانات الفاتورة الموجودة
          double? oldAmount;
          if (widget.purchase != null) {
            final purchaseTotalAmount = widget.purchase!['total_amount'];
            if (purchaseTotalAmount != null) {
              if (purchaseTotalAmount is num) {
                oldAmount = purchaseTotalAmount.toDouble();
              } else if (purchaseTotalAmount is String) {
                oldAmount = double.tryParse(purchaseTotalAmount);
              }
            }
          }

          debugPrint('=== استدعاء تحديث إحصائيات المورد ===');
          debugPrint('معرف المورد: $_selectedSupplierId');
          debugPrint(
            'المبلغ الجديد: ${_totalAmountCtrl.text.isEmpty ? 0.0 : double.tryParse(_totalAmountCtrl.text) ?? 0.0}',
          );
          debugPrint('المبلغ القديم: $oldAmount');
          debugPrint(
            'نوع العملية: ${widget.purchase != null ? 'تحديث' : 'إضافة جديدة'}',
          );

          await _updateSupplierPurchases(
            _selectedSupplierId!,
            _totalAmountCtrl.text.isEmpty
                ? 0.0
                : double.tryParse(_totalAmountCtrl.text) ?? 0.0,
            _referenceNumberCtrl.text,
            isUpdate: widget.purchase != null,
            oldAmount: oldAmount,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الفاتورة بنجاح')),
          );
        }
      } else {
        if (user != null) {
          purchaseData['created_by'] = user.id;
        }
        // إضافة فاتورة جديدة مع إرجاع المعرف
        final inserted = await client
            .from('purchases')
            .insert(purchaseData)
            .select('id')
            .single();

        // Stage expense logging on create: add full amount to selected stage
        try {
          if (_selectedOperationId != null && _selectedOperationId!.isNotEmpty &&
              _selectedStageId != null && _selectedStageId!.isNotEmpty) {
            final total = (_totalAmountCtrl.text.isEmpty
                ? 0.0
                : double.tryParse(_totalAmountCtrl.text) ?? 0.0);
            if (total > 0) {
              final orderNo = await _getStageOrderNo(_selectedOperationId!, _selectedStageId!) ?? 1;
              await _addStageExpense(
                operationId: _selectedOperationId!,
                stageId: _selectedStageId!,
                orderNo: orderNo,
                amount: total,
                note: 'مصروف فاتورة مشتريات رقم ${_referenceNumberCtrl.text}',
              );
            }
          }
        } catch (e) {
          debugPrint('Stage expense logging (create) failed: $e');
        }

        // سجل النشاط
        final newId = inserted['id'].toString();
        await _logPurchaseActivity(
          'CREATE',
          newId,
          details: 'Create purchase ${_referenceNumberCtrl.text}',
        );

        // تسجيل دفعة المورد إذا تم اختيار مورد وإدخال مبلغ مدفوع
        final amountPaid = double.tryParse(_amountPaidCtrl.text) ?? 0.0;
        if (amountPaid > 0) {
          await _recordSupplierPayment(
            _referenceNumberCtrl.text,
            amountPaid,
            _selectedSupplierId,
            _selectedPaymentMethodId,
          );
        }

        // تحديث جدول supplier_purchases إذا تم اختيار مورد
        if (_selectedSupplierId != null && _selectedSupplierId!.isNotEmpty) {
          // التأكد من وجود الجدول أولاً
          await _ensureSupplierPurchasesTable();
          await _updateSupplierPurchases(
            _selectedSupplierId!,
            _totalAmountCtrl.text.isEmpty
                ? 0.0
                : double.tryParse(_totalAmountCtrl.text) ?? 0.0,
            _referenceNumberCtrl.text,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إضافة الفاتورة بنجاح')),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        Navigator.of(context).pop(true);
      }
    } on PostgrestException catch (e) {
      debugPrint('Postgrest Error: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في قاعدة البيانات: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error saving purchase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ غير متوقع أثناء حفظ الفاتورة')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // التحقق من وجود جدول supplier_purchases وإنشاؤه إذا لم يكن موجود
  Future<void> _ensureSupplierPurchasesTable() async {
    try {
      final client = SupabaseService().client;

      // محاولة الاستعلام عن الجدول لمعرفة ما إذا كان موجود
      try {
        await client.from('supplier_purchases').select('id').limit(1);
        debugPrint('جدول supplier_purchases موجود بالفعل');
        return;
      } catch (e) {
        debugPrint(
          'جدول supplier_purchases غير موجود أو لا يحتوي على البيانات المطلوبة: $e',
        );

        // إنشاء الجدول مباشرة عبر SQL خام
        const createTableSQL = '''
          CREATE TABLE IF NOT EXISTS supplier_purchases (
              id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
              supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE CASCADE,
              total_purchase_amount DECIMAL(15,2) DEFAULT 0.00,
              purchase_count INTEGER DEFAULT 0,
              average_purchase_amount DECIMAL(15,2) DEFAULT 0.00,
              last_purchase_date TIMESTAMP WITH TIME ZONE,
              last_purchase_amount DECIMAL(15,2) DEFAULT 0.00,
              last_purchase_reference VARCHAR(50),
              is_active BOOLEAN DEFAULT true,
              created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
              updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );

          CREATE INDEX IF NOT EXISTS idx_supplier_purchases_supplier_id ON supplier_purchases(supplier_id);
          CREATE INDEX IF NOT EXISTS idx_supplier_purchases_last_purchase_date ON supplier_purchases(last_purchase_date);
          CREATE INDEX IF NOT EXISTS idx_supplier_purchases_active ON supplier_purchases(is_active);
        ''';

        await client.from('supplier_purchases').select(createTableSQL);
        debugPrint('تم إنشاء جدول supplier_purchases بنجاح');
      }
    } catch (e) {
      debugPrint('خطأ في إنشاء جدول supplier_purchases: $e');
    }
  }

  Future<void> _updateSupplierPurchases(
    String supplierId,
    double purchaseAmount,
    String referenceNumber, {
    bool isUpdate = false,
    double? oldAmount,
  }) async {
    try {
      final client = SupabaseService().client;

      // البحث عن سجل موجود للمورد
      final existingRecord = await client
          .from('supplier_purchases')
          .select('*')
          .eq('supplier_id', supplierId)
          .maybeSingle();

      if (existingRecord != null) {
        // تحديث السجل الموجود
        final currentTotal =
            (existingRecord['total_purchase_amount'] as num?)?.toDouble() ??
            0.0;
        final currentCount =
            (existingRecord['purchase_count'] as num?)?.toInt() ?? 0;

        debugPrint('=== تحديث إحصائيات المورد ===');
        debugPrint('المبلغ الحالي في قاعدة البيانات: $currentTotal');
        debugPrint('عدد المشتريات الحالي: $currentCount');
        debugPrint('المبلغ الجديد للفاتورة: $purchaseAmount');
        if (isUpdate && oldAmount != null) {
          debugPrint('المبلغ القديم للفاتورة: $oldAmount');
        }
        debugPrint(
          'نوع العملية: ${isUpdate ? 'تحديث' : 'إضافة جديدة'}',
        );

        double newTotal;
        int newCount;

        if (isUpdate && oldAmount != null && oldAmount > 0) {
          // للتحديث: اطرح المبلغ القديم وأضف المبلغ الجديد
          newTotal = currentTotal - oldAmount + purchaseAmount;
          // لا نغير العدد لأنه نفس الفاتورة
          newCount = currentCount;
          debugPrint(
            'حساب المبلغ الجديد: $currentTotal - $oldAmount + $purchaseAmount = $newTotal',
          );
        } else {
          // للفواتير الجديدة: أضف المبلغ الجديد
          newTotal = currentTotal + purchaseAmount;
          newCount = currentCount + 1;
          debugPrint(
            'حساب المبلغ الجديد (إضافة جديدة): $currentTotal + $purchaseAmount = $newTotal',
          );
        }

        // بناء بيانات التحديث بحسب الأعمدة المتاحة فقط
        final updateData = <String, dynamic>{
          'total_purchase_amount': newTotal,
          'purchase_count': newCount,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // إضافة الحقول الاختيارية فقط إذا كانت موجودة في السجل
        final recordKeys = existingRecord.keys.toSet();

        if (recordKeys.contains('average_purchase_amount')) {
          final newAverage = newCount > 0 ? newTotal / newCount : 0.0;
          updateData['average_purchase_amount'] = newAverage;
        }

        if (recordKeys.contains('last_purchase_date')) {
          updateData['last_purchase_date'] = DateTime.now().toIso8601String();
        }

        if (recordKeys.contains('last_purchase_amount')) {
          updateData['last_purchase_amount'] = purchaseAmount;
        }

        if (recordKeys.contains('last_purchase_reference')) {
          updateData['last_purchase_reference'] = referenceNumber;
        }

        debugPrint('البيانات المحدثة: $updateData');

        await client
            .from('supplier_purchases')
            .update(updateData)
            .eq('supplier_id', supplierId);

        debugPrint(
          'تم تحديث إحصائيات المورد $supplierId بنجاح - المبلغ الجديد: $newTotal',
        );
      } else {
        // إنشاء سجل جديد للمورد
        debugPrint('إنشاء سجل جديد للمورد $supplierId');
        debugPrint('المبلغ الجديد للفاتورة: $purchaseAmount');

        final insertData = <String, dynamic>{
          'supplier_id': supplierId,
          'total_purchase_amount': purchaseAmount,
          'purchase_count': 1,
          'is_active': true,
        };

        // إضافة الحقول الاختيارية فقط إذا كانت موجودة في الجدول
        try {
          // محاولة قراءة هيكل الجدول لمعرفة الأعمدة المتاحة
          await client.from('supplier_purchases').select('id').limit(0);
          // إذا نجحت العملية، نفترض أن الجدول له الهيكل الكامل
          insertData.addAll({
            'average_purchase_amount': purchaseAmount,
            'last_purchase_date': DateTime.now().toIso8601String(),
            'last_purchase_amount': purchaseAmount,
            'last_purchase_reference': referenceNumber,
          });
        } catch (e) {
          // إذا فشلت، نستخدم الحقول الأساسية فقط
          debugPrint('بعض الأعمدة غير موجودة في الجدول: $e');
        }

        await client.from('supplier_purchases').insert(insertData);

        debugPrint('تم إنشاء سجل جديد للمورد $supplierId بنجاح');
      }

      debugPrint('تم تحديث إحصائيات المورد $supplierId بنجاح');
    } catch (e) {
      debugPrint('خطأ في تحديث إحصائيات المورد: $e');
      // لا نحتاج لإظهار رسالة خطأ للمستخدم هنا لأن حفظ الفاتورة نجح
    }
  }

  Future<void> _recordSupplierPayment(
    String purchaseReference,
    double amountPaid,
    String? supplierId,
    String? paymentMethodId,
  ) async {
    if (supplierId == null || supplierId.isEmpty || amountPaid <= 0) {
      return; // No need to record payment if no supplier or no amount paid
    }

    try {
      final client = SupabaseService().client;
      final user = client.auth.currentUser;

      if (user == null) {
        debugPrint('No authenticated user for supplier payment recording');
        return;
      }

      // Get payment method name
      String? paymentMethodName = 'غير محدد';
      if (paymentMethodId != null && paymentMethodId.isNotEmpty) {
        try {
          final paymentMethod = _paymentMethods.firstWhere(
            (method) => method['id'] == paymentMethodId,
            orElse: () => {'name_ar': 'غير محدد'},
          );
          paymentMethodName =
              paymentMethod['name_ar']?.toString() ?? 'غير محدد';
        } catch (e) {
          debugPrint('Error getting payment method name: $e');
          paymentMethodName = 'غير محدد';
        }
      }

      // Prepare supplier payment data
      final paymentData = <String, dynamic>{
        'supplier_id': supplierId,
        'amount': amountPaid,
        'currency': 'EGP', // Default currency - can be made configurable later
        'paid_at': DateTime.now().toIso8601String(),
        'method': paymentMethodName,
        'reference': purchaseReference,
        'notes': _itemCtrl.text.isNotEmpty
            ? _itemCtrl.text
            : 'دفعة مقابل فاتورة مشتريات رقم $purchaseReference',
        'metadata': {
          'purchase_reference': purchaseReference,
          'payment_method_id': paymentMethodId,
          'item_description': _itemCtrl.text,
          'purchase_date': _purchaseDate?.toIso8601String(),
          'operation_id': (_selectedOperationId == null || _selectedOperationId!.isEmpty)
              ? null
              : _selectedOperationId,
          'stage_id': (_selectedStageId == null || _selectedStageId!.isEmpty)
              ? null
              : _selectedStageId,
        },
        'created_by': user.id,
      };

      debugPrint('Recording supplier payment: $paymentData');

      // Insert the supplier payment record
      final result = await client
          .from('supplier_payments')
          .insert(paymentData)
          .select('id')
          .single();

      debugPrint(
        'Supplier payment recorded successfully with ID: ${result['id']}',
      );
    } catch (e) {
      debugPrint('Error recording supplier payment: $e');
      // Don't show error to user as the purchase was saved successfully
      // The supplier payment recording is supplementary functionality
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: 1.2),
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'العودة',
              onPressed: () => AppRouter.goBack(context),
            ),
            title: Text(
              widget.purchase != null
                  ? 'تعديل الفاتورة'
                  : 'إضافة فاتورة مشتريات جديدة',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'خيارات',
                onPressed: _showOperationSelector,
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Basic Information Section
                    const Text(
                      'معلومات الفاتورة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reference Number (Auto-generated and non-editable)
                    AbsorbPointer(
                      child: TextFormField(
                        controller: _referenceNumberCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'الرقم المرجعي',
                          hintText: 'سيتم إنشاؤه تلقائياً',
                          prefixIcon: const Icon(Icons.numbers),
                          filled: true,
                          fillColor: Colors.grey[200],
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Supplier Invoice Number (Required) with embedded Tax Toggle
                    TextFormField(
                      controller: _invoiceNumberCtrl,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يجب إدخال رقم فاتورة المورد';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'رقم فاتورة المورد *',
                        hintText: 'أدخل رقم الفاتورة من المورد',
                        prefixIcon: const Icon(Icons.receipt),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _isTaxable = !_isTaxable;
                              _calculateAmounts();
                            });
                          },
                          tooltip: 'فاتورة ضريبية',
                          icon: Icon(
                            Icons.receipt_long,
                            size: 18,
                            color: _isTaxable ? Colors.green : Colors.grey[700],
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Supplier Selection with Add Button
                    Row(
                      children: [
                        Expanded(
                          child: (_suppliers.isEmpty)
                              ? const InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'المورد',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  child: SizedBox(
                                    height: 24,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'جاري التحميل...',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                )
                              : DropdownButtonFormField<String?>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'المورد',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  value:
                                      _suppliers.any(
                                        (s) =>
                                            s['id']?.toString() ==
                                            _selectedSupplierId,
                                      )
                                      ? _selectedSupplierId
                                      : null,
                                  items: _suppliers
                                      .map<DropdownMenuItem<String?>>((
                                        supplier,
                                      ) {
                                        return DropdownMenuItem<String?>(
                                          value: supplier['id']?.toString(),
                                          child: Text(
                                            supplier['name']?.toString() ??
                                                'بدون مورد',
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSupplierId = value;
                                    });
                                  },
                                ),
                        ),
                        const SizedBox(width: 4),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blue,
                              ),
                              tooltip: 'إضافة مورد جديد',
                              onPressed: _showAddSupplierDialog,
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              iconSize: 18,
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.blue,
                              ),
                              tooltip: 'تحديث قائمة الموردين',
                              onPressed: _loadSuppliers,
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              iconSize: 18,
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Dates Section
                    const SizedBox(height: 12),
                    const Text(
                      'التواريخ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Purchase Date
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isPurchaseDate: true),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _purchaseDate != null
                                  ? '${_purchaseDate!.month}/${_purchaseDate!.day}'
                                  : 'اختر تاريخ الشراء',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Due Date
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isPurchaseDate: false),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _dueDate != null
                                  ? '${_dueDate!.month}/${_dueDate!.day}'
                                  : 'تاريخ الاستحقاق',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 16),
                    // البيان (يوضع بعد التواريخ)
                    TextFormField(
                      controller: _itemCtrl,
                      decoration: const InputDecoration(
                        labelText: 'البيان',
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                      textDirection: ui.TextDirection.rtl,
                    ),
                    const SizedBox(height: 16),

                    // Payment Method with Add Button
                    Row(
                      children: [
                        Expanded(
                          child: _isLoadingPaymentMethods
                              ? const InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'طريقة الدفع',
                                    prefixIcon: Icon(Icons.payment),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'جاري تحميل طرق الدفع...',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _isInitialized && _paymentMethods.isNotEmpty
                              ? DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'payment-methods-${_paymentMethods.length}',
                                  ),
                                  value:
                                      _paymentMethods.any(
                                        (m) =>
                                            m['id'] == _selectedPaymentMethodId,
                                      )
                                      ? _selectedPaymentMethodId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'طريقة الدفع',
                                    prefixIcon: Icon(Icons.payment),
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _paymentMethods
                                      .map<DropdownMenuItem<String>>((method) {
                                        final methodId = method['id'];
                                        return DropdownMenuItem<String>(
                                          value: methodId,
                                          child: Text(
                                            method['name_ar']?.toString() ??
                                                'بدون اسم',
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                            ),
                                            textDirection: ui.TextDirection.rtl,
                                          ),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedPaymentMethodId = newValue;
                                      });
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'الرجاء اختيار طريقة دفع';
                                    }
                                    return null;
                                  },
                                )
                              : const InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'طريقة الدفع',
                                    prefixIcon: Icon(Icons.payment),
                                    border: OutlineInputBorder(),
                                  ),
                                  child: SizedBox(
                                    height: 24,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'جاري التحميل...',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 4),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blue,
                              ),
                              tooltip: 'إضافة طريقة دفع جديدة',
                              onPressed: _showAddPaymentMethodDialog,
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              iconSize: 18,
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.blue,
                              ),
                              tooltip: 'تحديث قائمة طرق الدفع',
                              onPressed: _loadPaymentMethods,
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              iconSize: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Product Details Section
                    const Text(
                      'تفاصيل المنتج',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Unit of Measure Dropdown with Add Button
                    Row(
                      children: [
                        Expanded(
                          child: (_isLoadingUnits || _units.isEmpty)
                              ? const InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'وحدة القياس',
                                    prefixIcon: Icon(Icons.square_foot),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'جاري التحميل...',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'وحدة القياس',
                                    prefixIcon: Icon(Icons.square_foot),
                                    errorStyle: TextStyle(color: Colors.red),
                                  ),
                                  value:
                                      _units.any(
                                        (u) =>
                                            u['id']?.toString() ==
                                            _selectedUnitId,
                                      )
                                      ? _selectedUnitId
                                      : null,
                                  items:
                                      _units.map<DropdownMenuItem<String>>((
                                        unit,
                                      ) {
                                        final unitId = unit['id']?.toString();
                                        return DropdownMenuItem<String>(
                                          value: unitId,
                                          child: Text(
                                            '${unit['name_ar']} (${unit['name_en']}${unit['code'] != null ? ' - ${unit['code']}' : ''})',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList()..add(
                                        const DropdownMenuItem<String>(
                                          value: null,
                                          enabled: false,
                                          child: Text(
                                            'اختر وحدة القياس',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                  onChanged: (String? value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedUnitId = value;
                                        debugPrint('Selected unit ID: $value');
                                      });
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء اختيار وحدة القياس';
                                    }
                                    return null;
                                  },
                                ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.blue,
                              ),
                              tooltip: 'إضافة وحدة قياس جديدة',
                              onPressed: () async {
                                await _showAddUnitDialog();
                                await _loadUnits(); // Refresh the units list after adding a new one
                              },
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              iconSize: 18,
                            ),
                            const SizedBox(height: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.blue,
                              ),
                              tooltip: 'تحديث قائمة الوحدات',
                              onPressed: _loadUnits,
                              visualDensity: const VisualDensity(
                                horizontal: -4,
                                vertical: -4,
                              ),
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 36,
                              ),
                              iconSize: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quantity and Unit Price
                    Row(
                      children: [
                        // Quantity
                        Expanded(
                          child: TextFormField(
                            controller: _quantityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الكمية',
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateAmounts(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Unit Price
                        Expanded(
                          child: TextFormField(
                            controller: _unitPriceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'سعر الوحدة',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateAmounts(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Subtotal
                    TextFormField(
                      controller: _subtotalCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'المجموع الفرعي',
                        prefixIcon: Icon(Icons.calculate),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tax Percentage and Amount (only visible if taxable)
                    Visibility(
                      visible: _isTaxable,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _taxPercentCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _calculateAmounts(),
                                  decoration: const InputDecoration(
                                    labelText: 'نسبة الضريبة %',
                                    prefixIcon: Icon(Icons.percent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _taxAmountCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'قيمة الضريبة',
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Tax Discount Section
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _taxDiscountPercentCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _calculateAmounts(),
                                  decoration: const InputDecoration(
                                    labelText: 'خصم الضريبة %',
                                    prefixIcon: Icon(Icons.percent),
                                    hintText: '0',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _taxDiscountAmountCtrl,
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    labelText: 'قيمة خصم الضريبة',
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),

                    // Discount Percentage and Amount
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _discountPercentCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateAmounts(),
                            decoration: const InputDecoration(
                              labelText: 'نسبة الخصم %',
                              prefixIcon: Icon(Icons.discount),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _discountAmountCtrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'قيمة الخصم',
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Total Amount
                    TextFormField(
                      controller: _totalAmountCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'المجموع الكلي',
                        prefixIcon: Icon(Icons.calculate),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount Paid and Due
                    Row(
                      children: [
                        // Amount Paid
                        Expanded(
                          child: TextFormField(
                            controller: _amountPaidCtrl,
                            decoration: const InputDecoration(
                              labelText: 'المبلغ المدفوع',
                              prefixIcon: Icon(Icons.payment),
                            ),
                            keyboardType: TextInputType.number,
                            onTap: () => _selectAll(_amountPaidCtrl),
                            onChanged: (_) {
                              _amountPaidDebounce?.cancel();
                              _amountPaidDebounce = Timer(const Duration(milliseconds: 300), () {
                                if (!mounted) return;
                                _calculateAmounts();
                              });
                            },
                            onEditingComplete: () {
                              _amountPaidDebounce?.cancel();
                              _calculateAmounts();
                            },
                            onFieldSubmitted: (_) {
                              _amountPaidDebounce?.cancel();
                              _calculateAmounts();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Amount Due
                        Expanded(
                          child: TextFormField(
                            controller: _amountDueCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'المبلغ المستحق',
                              prefixIcon: Icon(Icons.money_off),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Status (from purchase_statuses)
                    (_isLoadingStatuses || _dbStatuses.isEmpty)
                        ? const InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'حالة الدفع',
                              prefixIcon: Icon(Icons.info_outline),
                              border: OutlineInputBorder(),
                            ),
                            child: SizedBox(
                              height: 24,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'جاري التحميل...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value:
                                _dbStatuses.any(
                                  (s) => (s['code']?.toString().trim() ?? '') == (_selectedStatusCode?.toString().trim() ?? ''),
                                )
                                ? _selectedStatusCode
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'حالة الدفع',
                              prefixIcon: Icon(Icons.info_outline),
                              border: OutlineInputBorder(),
                            ),
                            items: _dbStatuses.map<DropdownMenuItem<String>>((
                              s,
                            ) {
                              return DropdownMenuItem<String>(
                                value: s['code']?.toString(),
                                child: Text(
                                  s['name_ar']?.toString() ??
                                      s['name_en']?.toString() ??
                                      s['code'].toString(),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatusCode = value;
                                  // Track manual cancel selection (Arabic/English)
                                  if (value == 'ملغاة' || value == 'cancelled') {
                                    _userChoseCancelled = true;
                                  } else {
                                    _userChoseCancelled = false;
                                  }
                                  // keep legacy _status aligned (Arabic/English)
                                  switch (value) {
                                    case 'completed':
                                    case 'مدفوع':
                                      _status = 'completed';
                                      break;
                                    case 'partially_paid':
                                    case 'مدفوعة جزئياً':
                                      _status = 'partially_paid';
                                      break;
                                    case 'pending':
                                    case 'غير مدفوع':
                                      _status = 'pending';
                                      break;
                                    case 'cancelled':
                                    case 'ملغاة':
                                      _status = 'cancelled';
                                      break;
                                    default:
                                      _status = 'draft';
                                  }
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'الرجاء اختيار حالة الفاتورة';
                              }
                              return null;
                            },
                          ),

                    const SizedBox(height: 20),

                    // Notes Section
                    const Text(
                      'ملاحظات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Arabic Notes
                    TextFormField(
                      controller: _notesArCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('حفظ الفاتورة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
