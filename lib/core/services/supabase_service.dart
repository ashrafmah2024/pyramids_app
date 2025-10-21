import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;

  SupabaseClient get client => _client;
  
  Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
        debug: kDebugMode,
      );
      
      _client = Supabase.instance.client;
      
      // Set auth state change listener
      _client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        final Session? session = data.session;
        
        if (kDebugMode) {
          print('Auth state changed: $event');
          if (session != null) {
            print('User ID: ${session.user.id}');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Supabase: $e');
      }
      rethrow;
    }
  }
  
  // Auth methods
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        await _updateLastLogin(response.user!.id);
      }
      
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Sign in error: $e');
      }
      rethrow;
    }
  }
  
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required Map<String, dynamic> userMetadata,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Sign up error: $e');
      }
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }
  
  // User management
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        // إرجاع null بهدوء عند غياب صلاحية القراءة
        return null;
      }
      rethrow;
    } catch (e) {
      print('خطأ في جلب بيانات المستخدم: $e');
      return null;
    }
  }
  
  Future<void> _updateLastLogin(String userId) async {
    try {
      final response = await _client
          .from('users')
          .update({
            'last_login_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId)
          .maybeSingle();
      if (response == null) {
        throw Exception('Update succeeded but no row visible due to RLS.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating last login: $e');
      }
    }
  }
  
  // Database methods
  Future<List<Map<String, dynamic>>> fetchData({
    required String tableName,
    String? filterColumn,
    dynamic filterValue,
  }) async {
    final query = _client.from(tableName).select();
    
    if (filterColumn != null && filterValue != null) {
      query.eq(filterColumn, filterValue);
    }
    
    return await query;
  }
  
  Future<Map<String, dynamic>> insertData({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    // حماية: تجنّب إنشاء صفوف في جدول users عبر هذه الدالة العامة.
    // يجب إنشاء حساب المستخدم عبر auth.signUp ثم upsert للبروفايل باستخدام نفس الـ id.
    if (tableName == 'users') {
      throw Exception(
        'لا تستخدم insertData لإنشاء صف في جدول users. استخدم مسار التسجيل AuthRepositoryImpl.signUpWithEmailAndPassword أو UserService.createUser (والذي ينفذ signUp أولاً).',
      );
    }
    final res = await _client
        .from(tableName)
        .insert(data)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('Insert succeeded but no row visible due to RLS.');
    }
    return res as Map<String, dynamic>;
  }
  
  Future<Map<String, dynamic>> updateData({
    required String tableName,
    required String idColumn,
    required String idValue,
    required Map<String, dynamic> data,
  }) async {
    final res = await _client
        .from(tableName)
        .update(data)
        .eq(idColumn, idValue)
        .select()
        .maybeSingle();
    if (res == null) {
      throw Exception('Update succeeded but no row visible due to RLS.');
    }
    return res as Map<String, dynamic>;
  }
  
  Future<void> deleteData({
    required String tableName,
    required String idColumn,
    required String idValue,
  }) async {
    await _client
        .from(tableName)
        .delete()
        .eq(idColumn, idValue);
  }
  
  // Realtime subscriptions
  Stream<List<Map<String, dynamic>>> subscribeToTable({
    required String tableName,
    String? filterColumn,
    dynamic filterValue,
  }) {
    final query = _client.from(tableName).stream(primaryKey: ['id']);
    
    if (filterColumn != null && filterValue != null) {
      return query.eq(filterColumn, filterValue);
    }
    
    return query;
  }
}
