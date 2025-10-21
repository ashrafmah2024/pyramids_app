import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/business_field.dart';
import '../../domain/entities/client.dart';
import '../../domain/entities/client_field.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/supplier_field.dart';

class PartnersRemoteDataSource {
  final SupabaseClient _client;
  PartnersRemoteDataSource(this._client);

  Future<List<BusinessField>> getBusinessFields() async {
    final res = await _client
        .from('business_fields')
        .select()
        .order('name_ar');
    return (res as List)
        .map((e) => BusinessField.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<BusinessField> createClientBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  }) async {
    final data = {
      'name_ar': nameAr,
      'name_en': nameEn,
      'description': description,
      'is_active': true,
    }..removeWhere((k, v) => v == null);
    final res = await _client
        .from('business_fields')
        .insert(data)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('Insert succeeded but no row visible due to RLS.');
    }
    return BusinessField.fromJson(Map<String, dynamic>.from(res));
  }

  Future<List<BusinessField>> getSupplierFieldDefinitions() async {
    final res = await _client.from('supplier_business_fields').select();
    final list = (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
    // بناء BusinessField بمرونة لدعم اختلاف أسماء الأعمدة
    final fields = list.map((row) {
      final id = row['id'] as String;
      final nameAr = (row['name_ar'] ?? row['name'] ?? row['title'] ?? '').toString();
      final nameEn = row['name_en'] as String?;
      final description = row['description'] as String?;
      final isActive = (row['is_active'] as bool?) ?? true;
      final createdAtStr = (row['created_at'] as String?) ?? DateTime.now().toIso8601String();
      return BusinessField(
        id: id,
        nameAr: nameAr,
        nameEn: nameEn,
        description: description,
        isActive: isActive,
        createdAt: DateTime.parse(createdAtStr).toLocal(),
      );
    }).toList();
    fields.sort((a, b) => a.nameAr.compareTo(b.nameAr));
    return fields;
  }

  Future<BusinessField> createSupplierBusinessField({
    required String nameAr,
    String? nameEn,
    String? description,
  }) async {
    final data = {
      // نستخدم name_ar كعمود أساسي للاسم في supplier_business_fields
      'name_ar': nameAr,
      'name_en': nameEn,
      'description': description,
    }..removeWhere((k, v) => v == null);
    final res = await _client
        .from('supplier_business_fields')
        .insert(data)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('Insert succeeded but no row visible due to RLS.');
    }
    final row = Map<String, dynamic>.from(res);
    final id = row['id'] as String;
    final resNameAr = (row['name_ar'] ?? row['name'] ?? row['title'] ?? '').toString();
    final resNameEn = row['name_en'] as String?;
    final resDescription = row['description'] as String?;
    final resIsActive = (row['is_active'] as bool?) ?? true;
    final resCreatedAtStr = (row['created_at'] as String?) ?? DateTime.now().toIso8601String();
    return BusinessField(
      id: id,
      nameAr: resNameAr,
      nameEn: resNameEn,
      description: resDescription,
      isActive: resIsActive,
      createdAt: DateTime.parse(resCreatedAtStr).toLocal(),
    );
  }

  Future<List<Client>> getClients() async {
    final res = await _client
        .from('clients')
        .select()
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Client.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Supplier>> getSuppliers() async {
    final res = await _client
        .from('suppliers')
        .select()
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ClientField>> getClientFields(String clientId) async {
    final res = await _client
        .from('client_fields')
        .select()
        .eq('client_id', clientId);
    return (res as List)
        .map((e) => ClientField.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<SupplierField>> getSupplierFields(String supplierId) async {
    final res = await _client
        .from('supplier_field_assignments')
        .select('supplier_id, supplier_field_id, created_at, id:supplier_field_id, field_id:supplier_field_id')
        .eq('supplier_id', supplierId);
    return (res as List)
        .map((e) => SupplierField.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Client> createClient({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  }) async {
    // تسجيل النشاط قبل إنشاء العميل
    try {
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'INSERT',
          'description': 'تم إنشاء عميل جديد: $name ${phone ?? ''}',
        });
      }
    } catch (e) {
      // لا نوقف العملية إذا فشل تسجيل النشاط، فقط نسجل الخطأ
      print('Failed to log client creation activity: $e');
    }

    final data = {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'notes': notes,
      'is_active': isActive,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await _client.from('clients').insert(data).select().maybeSingle();
    if (res == null) {
      throw Exception('Insert succeeded but no row visible due to RLS.');
    }
    return Client.fromJson(Map<String, dynamic>.from(res));
  }

  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool isActive = true,
    num balance = 0,
  }) async {
    // تسجيل النشاط قبل إنشاء المورد
    try {
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'INSERT',
          'description': 'تم إنشاء مورد جديد: $name ${phone ?? ''}',
        });
      }
    } catch (e) {
      // لا نوقف العملية إذا فشل تسجيل النشاط، فقط نسجل الخطأ
      print('Failed to log supplier creation activity: $e');
    }

    final data = {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'notes': notes,
      'is_active': isActive,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await _client.from('suppliers').insert(data).select().maybeSingle();
    if (res == null) {
      throw Exception('Insert succeeded but no row visible due to RLS.');
    }
    return Supplier.fromJson(Map<String, dynamic>.from(res));
  }

  Future<bool> updateClientFields({
    required String clientId,
    required List<String> fieldIds,
  }) async {
    // احذف العلاقات القديمة
    await _client.from('client_fields').delete().eq('client_id', clientId);
    // أدخل العلاقات الجديدة إذا كانت هناك عناصر
    if (fieldIds.isNotEmpty) {
      final rows = fieldIds
          .map((fid) => {
                'client_id': clientId,
                'field_id': fid,
              })
          .toList();
      await _client.from('client_fields').insert(rows);
    }
    // تسجيل النشاط (غير معطل لمسار التنفيذ)
    try {
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'UPDATE',
          'description': 'تعديل مجالات عميل: ' + clientId,
        });
      }
    } catch (_) {}
    return true;
  }

  Future<Client> updateClient({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
  }) async {
    final data = {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'notes': notes,
      'is_active': isActive,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await _client
        .from('clients')
        .update(data)
        .eq('id', id)
        .select()
        .maybeSingle();

    if (res == null) {
      throw Exception('Update succeeded but no row visible due to RLS.');
    }
    final updated = Client.fromJson(Map<String, dynamic>.from(res));
    // تسجيل النشاط (غير معطل لمسار التنفيذ)
    try {
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'UPDATE',
          'description': 'تم تحديث عميل: ' + updated.name,
        });
      }
    } catch (_) {}
    return updated;
  }

  Future<bool> updateSupplierFields({
    required String supplierId,
    required List<String> fieldIds,
  }) async {
    // اجلب العلاقات القديمة قبل الحذف
    List<String> oldFieldIds = [];
    try {
      final prev = await _client
          .from('supplier_field_assignments')
          .select('supplier_field_id')
          .eq('supplier_id', supplierId);
      oldFieldIds = (prev as List)
          .map((e) => (e['supplier_field_id'] ?? e['field_id']).toString())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {}

    // احذف العلاقات القديمة
    await _client.from('supplier_field_assignments').delete().eq('supplier_id', supplierId);
    // أدخل العلاقات الجديدة إذا كانت هناك عناصر
    if (fieldIds.isNotEmpty) {
      final rows = fieldIds
          .map((fid) => {
                'supplier_id': supplierId,
                'supplier_field_id': fid,
              })
          .toList();
      await _client.from('supplier_field_assignments').insert(rows);
    }
    // حساب الفروقات وتسجيل النشاط (غير معطل لمسار التنفيذ)
    try {
      final added = fieldIds.where((id) => !oldFieldIds.contains(id)).toList();
      final removed = oldFieldIds.where((id) => !fieldIds.contains(id)).toList();
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        final diffs = <String>[];
        if (added.isNotEmpty) diffs.add('added: ${added.join("|")}');
        if (removed.isNotEmpty) diffs.add('removed: ${removed.join("|")}');
        final desc = diffs.isNotEmpty
            ? 'تعديل مجالات مورد: $supplierId | ' + diffs.join(', ')
            : 'تعديل مجالات مورد: $supplierId';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'UPDATE',
          'description': desc,
          'entity_type': 'SUPPLIER',
          'entity_id': supplierId,
        });
      }
    } catch (_) {}
    return true;
  }

  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    String? phone,
    String? email,
    String? address,
    String? taxNumber,
    String? notes,
    bool? isActive,
    num? balance,
  }) async {
    // اجلب بيانات المورد القديمة قبل التحديث لعمل مقارنة قبل/بعد
    Map<String, dynamic>? oldRow;
    try {
      final prev = await _client
          .from('suppliers')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (prev != null) {
        oldRow = Map<String, dynamic>.from(prev);
      }
    } catch (_) {}

    final data = {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'tax_number': taxNumber,
      'notes': notes,
      'is_active': isActive,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((k, v) => v == null);

    final res = await _client
        .from('suppliers')
        .update(data)
        .eq('id', id)
        .select()
        .maybeSingle();

    if (res == null) {
      throw Exception('Update succeeded but no row visible due to RLS.');
    }
    final updated = Supplier.fromJson(Map<String, dynamic>.from(res));
    // تسجيل النشاط مع تفاصيل قبل/بعد (غير معطل لمسار التنفيذ)
    try {
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        final diffs = <String>[];
        if (oldRow != null) {
          data.forEach((k, v) {
            final prev = oldRow![k];
            final prevStr = prev?.toString() ?? '';
            final newStr = v?.toString() ?? '';
            if (prevStr != newStr) {
              diffs.add('$k: ${prev ?? '-'} -> ${v ?? '-'}');
            }
          });
        }
        final desc = diffs.isNotEmpty
            ? 'تحديث مورد: ${updated.name} | ' + diffs.join(', ')
            : 'تحديث مورد: ${updated.name}';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'UPDATE',
          'description': desc,
          'entity_type': 'SUPPLIER',
          'entity_id': id,
        });
      }
    } catch (_) {}
    return updated;
  }

  Future<bool> deleteSupplier(String id) async {
    await _client.from('suppliers').delete().eq('id', id);
    // تسجيل النشاط (غير معطل لمسار التنفيذ)
    try {
      final authUser = _client.auth.currentUser;
      if (authUser != null) {
        final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
        await _client.from('activity_logs').insert({
          'user_id': authUser.id,
          'user_name': displayName,
          'action': 'DELETE',
          'description': 'تم حذف مورد: ' + id,
        });
      }
    } catch (_) {}
    return true;
  }
}
