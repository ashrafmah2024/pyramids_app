import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:postgrest/postgrest.dart';
import 'package:pyramids/core/constants/app_constants.dart';
import 'package:pyramids/features/users/domain/entities/user.dart' as app_user;
import 'package:pyramids/features/users/domain/entities/user_role.dart';
import 'package:pyramids/features/users/domain/entities/user_status.dart';

class UserRemoteDataSource {
  final SupabaseClient _supabaseClient;

  UserRemoteDataSource({required SupabaseClient supabaseClient})
    : _supabaseClient = supabaseClient;

  static const String _tableName = 'users';
  

  Future<List<app_user.User>> getUsers() async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);

      return (response as List).map((userData) => _mapToUser(userData)).toList();
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        // صلاحيات RLS: لا نكسر الواجهة، نعيد قائمة فارغة
        return <app_user.User>[];
      }
      rethrow;
    }
  }

  Future<app_user.User> getUser(String id) async {
    try {
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        throw Exception('لا تملك صلاحية لعرض بيانات هذا المستخدم أو أنه غير موجود.');
      }
      return _mapToUser(response);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw Exception('لا تملك صلاحية لعرض بيانات هذا المستخدم.');
      }
      rethrow;
    }
  }

  Future<app_user.User> createUser(app_user.User user) async {
    // إنشاء مستخدم إداري عبر Edge Function: يجب تمرير الحقول المطلوبة التي تتوقعها الوظيفة
    // الحقول المطلوبة: email, password, full_name, username
    if (user.email.isEmpty || user.fullName.isEmpty || user.username.isEmpty) {
      throw Exception(
        'بيانات ناقصة: البريد الإلكتروني والاسم الكامل واسم المستخدم مطلوبة',
      );
    }
    final password = user.passwordHash ?? '';
    if (password.isEmpty) {
      // في هذا المشروع نخزن كلمة المرور مؤقتًا في passwordHash من النموذج (ثم يجب تشفيرها في سيناريو حقيقي)
      throw Exception('بيانات ناقصة: كلمة المرور مطلوبة');
    }

    // ابنِ حمولة الوظيفة وفق صيغة الـ Edge Function
    final funcBody = <String, dynamic>{
      'email': user.email,
      'password': password, // الوظيفة تتوقع "password" وليس password_hash
      'full_name': user.fullName,
      'username': user.username,
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty)
        'phone_number': user.phoneNumber,
      'role': user.role.toString().split('.').last,
      'status': user.status.toString().split('.').last,
    };

    final resp = await _supabaseClient.functions.invoke(
      AppConstants.adminFunctionCreateUser,
      body: funcBody,
      headers: {
        if (AppConstants.adminSecret.isNotEmpty)
          'x-admin-secret': AppConstants.adminSecret,
      },
    );

    if (resp.data is Map<String, dynamic>) {
      final data = resp.data as Map<String, dynamic>;
      if (data['success'] == true) {
        // اجلب الصف من الجدول بعد الإنشاء للتأكد من القيم النهائية
        final created = await _supabaseClient
            .from(_tableName)
            .select()
            .eq('id', data['userId'])
            .maybeSingle();
        if (created != null) {
          final createdUser = _mapToUser(created);
          // تسجيل نشاط إنشاء المستخدم (غير معطل لمسار التنفيذ)
          try {
            final currentUser = _supabaseClient.auth.currentUser;
            if (currentUser != null) {
              final displayName = currentUser.email ?? currentUser.userMetadata?['full_name'] ?? 'User';
              await _supabaseClient.from('activity_logs').insert({
                'user_id': currentUser.id,
                'user_name': displayName,
                'action': 'CREATE_USER',
                'description': 'تم إنشاء مستخدم جديد: ${createdUser.fullName} بدور ${createdUser.role.toString().split('.').last}',
                'created_at': DateTime.now().toIso8601String(),
              });
            }
          } catch (_) {}
          return createdUser;
        }
        // في حال منعت RLS القراءة مباشرة بعد الإنشاء، نرجع كائنًا مبنيًا من البيانات المتاحة
        final fallback = <String, dynamic>{
          'id': data['userId'],
          'email': user.email,
          'full_name': user.fullName,
          'username': user.username,
          'phone_number': user.phoneNumber,
          'role': user.role.toString().split('.').last,
          'status': user.status.toString().split('.').last,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'last_login_at': null,
          'last_login_ip': null,
          'last_login_device': null,
          'last_login_location': null,
        };
        return _mapToUser(fallback);
      }
      throw Exception(data['error'] ?? 'فشل في إنشاء المستخدم عبر الوظيفة');
    }

    throw Exception('استجابة غير متوقعة من الوظيفة');
  }

  Future<app_user.User> updateUser(app_user.User user) async {
    try {
      // ابنِ حمولة تحديث صريحة لتجنّب تمرير أعمدة قد تُرفض بسياسات RLS (مثل id و created_at)
      final updates = <String, dynamic>{
        'full_name': user.fullName,
        'username': user.username,
        'email': user.email,
        'phone_number': user.phoneNumber,
        'role': user.role.toString().split('.').last,
        'status': user.status.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      }..removeWhere((k, v) => v == null);

      // 1) نفّذ التحديث بدون طلب تمثيل الصف
      await _supabaseClient
          .from(_tableName)
          .update(updates)
          .eq('id', user.id);

      // 2) تسجيل نشاط تعديل المستخدم (غير معطل لمسار التنفيذ)
      try {
        final currentUser = _supabaseClient.auth.currentUser;
        if (currentUser != null) {
          final displayName = currentUser.email ?? currentUser.userMetadata?['full_name'] ?? 'User';
          await _supabaseClient.from('activity_logs').insert({
            'user_id': currentUser.id,
            'user_name': displayName,
            'action': 'UPDATE_USER',
            'description': 'تم تعديل مستخدم: ${user.fullName}',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}

      // 3) اجلب الصف المحدّث باستعلام منفصل
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        throw Exception('فشل التحديث: لم يتم العثور على صف مطابق أو لا تملك صلاحية لقراءة النتيجة.');
      }
      final updated = _mapToUser(response);
      return updated;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw Exception('لا تملك صلاحية لتعديل هذا المستخدم.');
      }
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    // 1) حذف المستخدم من نظام المصادقة عبر Edge Function بصلاحيات إدارية
    final resp = await _supabaseClient.functions.invoke(
      AppConstants.adminFunctionDeleteUser,
      body: {'user_id': id},
      headers: {
        if (AppConstants.adminSecret.isNotEmpty)
          'x-admin-secret': AppConstants.adminSecret,
      },
    );

    if (resp.data is Map<String, dynamic>) {
      final data = resp.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'فشل حذف المستخدم من auth');
      }
      // تسجيل نشاط حذف المستخدم (غير معطل لمسار التنفيذ)
      try {
        final currentUser = _supabaseClient.auth.currentUser;
        if (currentUser != null) {
          final displayName = currentUser.email ?? currentUser.userMetadata?['full_name'] ?? 'User';
          await _supabaseClient.from('activity_logs').insert({
            'user_id': currentUser.id,
            'user_name': displayName,
            'action': 'DELETE_USER',
            'description': 'تم حذف مستخدم: $id',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {}
    }
  }

  Future<app_user.User> updateUserStatus({
    required String userId,
    required UserStatus status,
  }) async {
    try {
      // 1) تحديث بدون طلب التمثيل
      await _supabaseClient
          .from(_tableName)
          .update({'status': status.toString().split('.').last})
          .eq('id', userId);

      // 2) جلب الصف المحدّث باستعلام منفصل
      final response = await _supabaseClient
          .from(_tableName)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        throw Exception('فشل تغيير الحالة: لم يتم العثور على صف مطابق أو لا تملك صلاحية لقراءة النتيجة.');
      }
      final updated = _mapToUser(response);
      return updated;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw Exception('لا تملك صلاحية لتغيير حالة هذا المستخدم.');
      }
      rethrow;
    }
  }

  Future<void> changeUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    // استدعاء Edge Function بصلاحيات إدارية لتغيير كلمة المرور في نظام auth
    final resp = await _supabaseClient.functions.invoke(
      AppConstants.adminFunctionChangeUserPassword,
      body: {'user_id': userId, 'new_password': newPassword},
      headers: {
        if (AppConstants.adminSecret.isNotEmpty)
          'x-admin-secret': AppConstants.adminSecret,
      },
    );

    if (resp.data is Map<String, dynamic>) {
      final data = resp.data as Map<String, dynamic>;
      if (data['success'] == true) return;
      throw Exception(data['error'] ?? 'فشل تغيير كلمة المرور عبر الوظيفة');
    }
  }

  Map<String, dynamic> _mapToJson(app_user.User user, {String? overrideId}) {
    final data = <String, dynamic>{
      'full_name': user.fullName,
      'username': user.username,
      'password_hash': user.passwordHash,
      'email': user.email,
      'phone_number': user.phoneNumber,
      'role': user.role.toString().split('.').last,
      'status': user.status.toString().split('.').last,
      'created_at': user.createdAt.toIso8601String(),
      'updated_at': user.updatedAt.toIso8601String(),
      'last_login_at': user.lastLoginAt?.toIso8601String(),
      'last_login_ip': user.lastLoginIp,
      'last_login_device': user.lastLoginDevice,
      'last_login_location': user.lastLoginLocation,
    };

    // ضمن الحل 1: دائمًا مرّر id. إن وجد overrideId نستخدمه وإلا نستخدم user.id.
    final idToUse = overrideId ?? user.id;
    if (idToUse.isNotEmpty) {
      data['id'] = idToUse;
    }

    return data;
  }

  app_user.User _mapToUser(Map<String, dynamic> json) {
    return app_user.User(
      id: json['id'],
      fullName: json['full_name'],
      username: json['username'],
      passwordHash: json['password_hash'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.viewer,
      ),
      status: UserStatus.values.firstWhere(
        (e) => e.toString() == 'UserStatus.${json['status']}',
        orElse: () => UserStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at']).toLocal()
          : null,
      lastLoginIp: json['last_login_ip'],
      lastLoginDevice: json['last_login_device'],
      lastLoginLocation: json['last_login_location'] != null
          ? Map<String, dynamic>.from(json['last_login_location'])
          : null,
    );
  }
}
