import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/core/constants/app_constants.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:pyramids/features/auth/domain/models/user_model.dart';
import 'package:pyramids/features/auth/domain/repositories/auth_repository.dart';
import 'package:pyramids/core/services/device_context_service.dart';
import 'package:pyramids/features/auth/data/datasources/login_audit_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseService _supabaseService;
  final _supabase = Supabase.instance.client;
  final LoginAuditRemoteDataSource _loginAuditDs = LoginAuditRemoteDataSource();

  AuthRepositoryImpl(this._supabaseService);

  @override
  Future<bool> isSignedIn() async {
    try {
      final session = _supabase.auth.currentSession;
      return session != null;
    } catch (e) {
      developer.log('Error checking if signed in: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Try to fetch profile; if missing, create it to avoid PGRST116 (.single on 0 rows)
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        return UserModel.fromJson(data as Map<String, dynamic>);
      }

      // Auto-provision a user profile row if none exists
      final newProfile = {
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User',
        'username': (user.email ?? '').split('@').first,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final inserted = await _supabase
          .from('users')
          .upsert(newProfile, onConflict: 'id')
          .select()
          .maybeSingle();

      return inserted != null
          ? UserModel.fromJson(inserted as Map<String, dynamic>)
          : UserModel.fromJson(newProfile);
    } on PostgrestException catch (e) {
      // في حال صلاحيات RLS تمنع الوصول، لا نُسقط الواجهة برسالة خطأ حمراء
      developer.log('PostgrestException in getCurrentUser: ${e.code} - ${e.message}');
      final au = _supabase.auth.currentUser;
      if (au == null) return null;
      // نُعيد أقل قدر من البيانات المتاحة من auth
      final DateTime? emailConfirmedAt =
          au.emailConfirmedAt == null ? null : DateTime.tryParse(au.emailConfirmedAt!);
      final DateTime? lastSignInAt =
          au.lastSignInAt == null ? null : DateTime.tryParse(au.lastSignInAt!);

      return UserModel(
        id: au.id,
        email: au.email ?? '',
        fullName: au.userMetadata?['full_name'] ?? (au.email?.split('@').first ?? 'User'),
        phoneNumber: au.userMetadata?['phone_number'],
        role: (au.userMetadata?['role'] as String?)?.toLowerCase() ?? 'user',
        emailConfirmedAt: emailConfirmedAt,
        lastSignInAt: lastSignInAt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      developer.log('Error getting current user: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('No user returned after sign in');
      }

      final user = await getCurrentUser();
      if (user == null) {
        throw Exception('Failed to fetch user data after sign in');
      }
      // Insert login audit (non-blocking critical path; errors logged only)
      try {
        final audit = await DeviceContextService.buildAudit(user.id);
        await _loginAuditDs.insert(audit);
      } catch (e) {
        developer.log('Failed to insert login audit: $e');
      }

      // سجل النشاط: إضافة حدث تسجيل الدخول (غير معطل لمسار التنفيذ)
      try {
        final authUser = _supabase.auth.currentUser;
        // نُفضّل البريد الإلكتروني كاسم معروض في السجلات
        if (authUser == null) {
        } else {
          final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
          await _supabase.from('activity_logs').insert({
            'user_id': authUser.id,
            'user_name': displayName,
            'action': 'LOGIN',
            'description': 'تم تسجيل الدخول بنجاح',
          });
        }
      } catch (e) {
        developer.log('Failed to insert activity log: $e');
      }
      return user;
    } catch (e) {
      developer.log('Error signing in: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      // Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          if (phoneNumber != null) 'phone_number': phoneNumber,
        },
      );

      if (authResponse.user == null) {
        throw Exception('No user returned after sign up');
      }

      // Create user profile in the database
      final userData = {
        'id': authResponse.user!.id,
        'email': email,
        'full_name': fullName,
        'username': email.split('@').first,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('users').upsert(userData, onConflict: 'id');
      try {
        final authUser = _supabase.auth.currentUser;
        if (authUser != null) {
          final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
          await _supabase.from('activity_logs').insert({
            'user_id': authUser.id,
            'user_name': displayName,
            'action': 'SIGNUP',
            'description': 'تم إنشاء حساب جديد',
          });
        }
      } catch (e) {
        developer.log('Failed to insert signup activity log: $e');
      }
      return UserModel.fromJson(userData);
    } catch (e) {
      developer.log('Error signing up: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      // إدراج سجل الخروج قبل إنهاء الجلسة لضمان صلاحية التوكن
      try {
        final authUser = _supabase.auth.currentUser;
        if (authUser != null) {
          final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
          await _supabase.from('activity_logs').insert({
            'user_id': authUser.id,
            'user_name': displayName,
            'action': 'LOGOUT',
            'description': 'تم تسجيل الخروج',
          });
        }
      } catch (e) {
        developer.log('Failed to insert logout activity log: $e');
      }

      await _supabase.auth.signOut();
    } catch (e) {
      developer.log('Error signing out: $e');
      rethrow;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      developer.log('Error resetting password: $e');
      rethrow;
    }
  }

  @override
  Future<UserModel> updateProfile({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;

      // مزامنة بيانات المستخدم في Auth metadata إذا توفرت قيم
      try {
        final meta = <String, dynamic>{};
        if (fullName != null) meta['full_name'] = fullName;
        if (phoneNumber != null) meta['phone_number'] = phoneNumber;
        if (profileImageUrl != null) meta['profile_image_url'] = profileImageUrl;
        if (meta.isNotEmpty) {
          await _supabase.auth.updateUser(UserAttributes(data: meta));
        }
      } catch (e) {
        developer.log('Failed to sync auth metadata: $e');
      }

      final response = await _supabase
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select()
          .maybeSingle();

      if (response != null) {
        // سجل النشاط - تحديث الملف الشخصي (غير معطل لمسار التنفيذ)
        try {
          final authUser = _supabase.auth.currentUser;
          if (authUser != null) {
            final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
            await _supabase.from('activity_logs').insert({
              'user_id': authUser.id,
              'user_name': displayName,
              'action': 'UPDATE_PROFILE',
              'description': 'تم تحديث الملف الشخصي',
            });
          }
        } catch (e) {
          developer.log('Failed to insert update profile activity log: $e');
        }
        return UserModel.fromJson(response as Map<String, dynamic>);
      }

      // إذا لم تُرجع RLS الصف بعد التحديث، نحاول جلبه باستعلام منفصل
      final maybe = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (maybe != null) {
        // سجل النشاط - تحديث الملف الشخصي (غير معطل لمسار التنفيذ)
        try {
          final authUser = _supabase.auth.currentUser;
          if (authUser != null) {
            final displayName = authUser.email ?? authUser.userMetadata?['full_name'] ?? 'User';
            await _supabase.from('activity_logs').insert({
              'user_id': authUser.id,
              'user_name': displayName,
              'action': 'UPDATE_PROFILE',
              'description': 'تم تحديث الملف الشخصي',
            });
          }
        } catch (e) {
          developer.log('Failed to insert update profile activity log: $e');
        }
        return UserModel.fromJson(maybe as Map<String, dynamic>);
      }

      // حل احتياطي أخير: بناء نموذج من بيانات auth المتاحة
      final au = _supabase.auth.currentUser;
      if (au != null) {
        // سجل النشاط حتى في مسار العودة الاحتياطي
        try {
          final displayName = au.email ?? au.userMetadata?['full_name'] ?? 'User';
          await _supabase.from('activity_logs').insert({
            'user_id': au.id,
            'user_name': displayName,
            'action': 'UPDATE_PROFILE',
            'description': 'تم تحديث الملف الشخصي',
          });
        } catch (e) {
          developer.log('Failed to insert update profile activity log (fallback): $e');
        }
        return UserModel(
          id: au.id,
          email: au.email ?? '',
          fullName: fullName ?? (au.userMetadata?['full_name'] ?? (au.email?.split('@').first ?? 'User')),
          phoneNumber: phoneNumber ?? (au.userMetadata?['phone_number'] ?? ''),
          role: (au.userMetadata?['role'] as String?)?.toLowerCase() ?? 'user',
          emailConfirmedAt: null,
          lastSignInAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      throw Exception('Update succeeded but no row visible due to RLS.');
    } catch (e) {
      developer.log('Error updating profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // First, reauthenticate the user
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );

      // Then update the password
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      developer.log('Error changing password: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isEmailVerified() async {
    try {
      final user = _supabase.auth.currentUser;
      return user?.emailConfirmedAt != null;
    } catch (e) {
      developer.log('Error checking email verification: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email!,
      );
    } catch (e) {
      developer.log('Error sending email verification: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // First, reauthenticate the user
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      // سجل النشاط قبل حذف الحساب (غير معطل لمسار التنفيذ)
      try {
        final displayName = user.email ?? user.userMetadata?['full_name'] ?? 'User';
        await _supabase.from('activity_logs').insert({
          'user_id': user.id,
          'user_name': displayName,
          'action': 'DELETE_ACCOUNT',
          'description': 'تم حذف الحساب',
        });
      } catch (e) {
        developer.log('Failed to insert delete account activity log: $e');
      }

      // Delete user data from the users table
      await _supabase.from('users').delete().eq('id', user.id);

      // Delete the auth user
      await _supabase.auth.admin.deleteUser(user.id);
    } catch (e) {
      developer.log('Error deleting account: $e');
      rethrow;
    }
  }
}
