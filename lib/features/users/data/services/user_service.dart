import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse, PostgrestException, AuthException;

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String username,
    String? phoneNumber,
    String role = 'operator',  // Using 'operator' as default role which exists in the database
    String status = 'active',
  }) async {
    print('Starting user creation for: $email');
    AuthResponse? authResponse;
    
    try {
      print('1. Creating auth user...');
      // 1. First create the auth user
      authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'username': username,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          'role': role,
          'status': status,
        },
      );
      print('Auth user created: ${authResponse.user?.id}');

      final userId = authResponse.user?.id;
      if (userId == null) {
        throw Exception('فشل في إنشاء حساب المستخدم: لا يوجد معرف مستخدم');
      }

      // 2. Create user profile in public.users table
      print('2. Creating user profile...');
      final userData = {
        'id': userId,
        'email': email,
        'full_name': fullName,
        'username': username,
        'phone_number': phoneNumber,
        'role': role,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      print('User data to insert: $userData');
      
      final response = await _supabase
          .from('users')
          .upsert(userData, onConflict: 'id');
      
      print('User profile created successfully');
      return userId;
      
    } on PostgrestException catch (e) {
      print('Database error: ${e.code} - ${e.message}');
      print('Details: ${e.details}');
      print('Hint: ${e.hint}');
      
      if (e.code == '23505') {
        throw Exception('اسم المستخدم أو البريد الإلكتروني مستخدم مسبقاً');
      }
      rethrow;
      
    } on AuthException catch (e) {
      print('Auth error: ${e.message}');
      throw Exception('خطأ في المصادقة: ${e.message}');
      
    } catch (e, stackTrace) {
      print('Unexpected error: $e');
      print('Stack trace: $stackTrace');
      
      // Clean up auth user if it was created
      if (authResponse?.user?.id != null) {
        print('Attempting to clean up auth user...');
        try {
          await _supabase.auth.admin.deleteUser(authResponse!.user!.id);
          print('Auth user cleaned up successfully');
        } catch (cleanupError) {
          print('Error during cleanup: $cleanupError');
        }
      }
      
      throw Exception('فشل في إنشاء المستخدم: ${e.toString()}');
    }
  }

  // طرق إضافية لإدارة المستخدمين
  Future<void> updateLastLogin({
    required String userId,
    String? ip,
    String? device,
    Map<String, dynamic>? location,
  }) async {
    try {
      await _supabase
          .from('users')
          .update({
            'last_login_at': DateTime.now().toIso8601String(),
            'last_login_ip': ip,
            'last_login_device': device,
            'last_login_location': location,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        // لا نكسر الواجهة بسبب صلاحيات RLS على users
        return;
      }
      rethrow;
    } catch (e) {
      print('خطأ في تحديث آخر تسجيل دخول: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
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
}
