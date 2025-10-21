import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/features/auth/domain/models/user_model.dart';
import 'package:pyramids/features/auth/domain/repositories/auth_repository.dart';
import 'dart:developer' as developer;

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  
  AuthProvider(this._authRepository);
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const Duration _lockDuration = Duration(minutes: 1);
  DateTime? _lockedUntil;
  
  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get failedAttempts => _failedAttempts;
  int get remainingAttempts => isLocked ? 0 : (_maxAttempts - _failedAttempts).clamp(0, _maxAttempts);
  bool get showResetHint => _failedAttempts >= 2 && !isAuthenticated;
  bool get isLocked => _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
  Duration get lockRemaining => isLocked ? _lockedUntil!.difference(DateTime.now()) : Duration.zero;
  
  // Check if user is authenticated on app start
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final isSignedIn = await _authRepository.isSignedIn();
      if (isSignedIn) {
        _currentUser = await _authRepository.getCurrentUser();
      }
    } catch (e) {
      _error = 'Failed to check authentication status: $e';
      if (kDebugMode) {
        print(_error);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    print('🔐 بدء عملية تسجيل الدخول في AuthProvider');
    print('📧 البريد الإلكتروني: $email');
    
    // If currently locked, prevent attempts and show time remaining
    if (isLocked) {
      final message = _lockedMessage();
      _error = message;
      print('🔒 الحساب مغلق مؤقتًا: $message');
      notifyListeners();
      return false;
    }

    // If lock time passed but state not reset yet, clean up
    _checkAndUpdateLock();

    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('🔍 جاري التواصل مع خادم المصادقة...');
      _currentUser = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (_currentUser != null) {
        print('✅ تم تسجيل الدخول بنجاح للمستخدم: ${_currentUser!.email}');
        print('👤 تفاصيل المستخدم: ${_currentUser!.toJson()}');
        // success: reset failed attempts
        _failedAttempts = 0;
        _lockedUntil = null;
        return true;
      } else {
        print('❌ فشل تسجيل الدخول: لم يتم العثور على بيانات المستخدم');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ حدث خطأ أثناء تسجيل الدخول: $e');
      print('📜 تفاصيل الخطأ: $stackTrace');
      
      // increment failed attempts and show Arabic-friendly message
      _failedAttempts += 1;
      print('🔄 عدد محاولات الفاشلة: $_failedAttempts من $_maxAttempts');
      
      final baseMessage = _mapArabicError(e);
      if (_failedAttempts >= _maxAttempts) {
        _startLock();
        _error = _lockedMessage(prefix: baseMessage);
        print('🔒 تم قفل الحساب مؤقتًا: $_error');
      } else {
        final remaining = remainingAttempts;
        final attemptsMessage = remaining > 0
            ? ' تبقّى $remaining محاولات.'
            : '';
        _error = baseMessage + attemptsMessage;
        print('⚠️ خطأ في تسجيل الدخول: $_error');
      }
      
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
      print('🏁 انتهت عملية تسجيل الدخول');
    }
  }
  
  // Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentUser = await _authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );
      return true;
    } catch (e) {
      _error = 'Failed to sign up: $e';
      if (kDebugMode) {
        print(_error);
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authRepository.signOut();
      _currentUser = null;
    } catch (e) {
      _error = 'Failed to sign out: $e';
      if (kDebugMode) {
        print(_error);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authRepository.resetPassword(email);
    } catch (e) {
      _error = 'Failed to reset password: $e';
      if (kDebugMode) {
        print(_error);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update profile
  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    if (_currentUser == null) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentUser = await _authRepository.updateProfile(
        userId: _currentUser!.id,
        fullName: fullName,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
      );
      // تسجيل نشاط تحديث الملف الشخصي لضمان التسجيل من الطبقة العلوية
      try {
        final supabase = Supabase.instance.client;
        final u = supabase.auth.currentUser;
        if (u != null) {
          final displayName = u.email ?? u.userMetadata?['full_name'] ?? 'User';
          await supabase.from('activity_logs').insert({
            'user_id': u.id,
            'user_name': displayName,
            'action': 'UPDATE_PROFILE',
            'description': (fullName != null ? 'تم تحديث الاسم' : 'تم تحديث الملف الشخصي'),
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (e, st) {
        developer.log('Failed to insert UPDATE_PROFILE activity from provider: $e', stackTrace: st);
      }
    } catch (e) {
      _error = 'Failed to update profile: $e';
      if (kDebugMode) {
        print(_error);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      _error = 'Failed to change password: $e';
      if (kDebugMode) {
        print(_error);
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Map repository/Supabase errors to Arabic-friendly messages
  String _mapArabicError(Object e) {
    final message = e.toString();
    // Common Supabase/Auth errors mapping
    if (message.contains('Invalid login credentials') ||
        message.contains('Email not confirmed') ||
        message.contains('Invalid login') ||
        message.contains('invalid_grant')) {
      return 'بيانات الدخول غير صحيحة.';
    }
    if (message.contains('Email not confirmed')) {
      return 'البريد الإلكتروني غير مُفعل. يرجى تفعيل البريد أو إعادة الإرسال.';
    }
    if (message.contains('Network') || message.contains('timeout')) {
      return 'خطأ في الاتصال بالشبكة. يرجى التحقق من الإنترنت والمحاولة مرة أخرى.';
    }
    return 'فشل تسجيل الدخول: $message';
  }

  void _startLock() {
    _lockedUntil = DateTime.now().add(_lockDuration);
    notifyListeners();
  }

  String _lockedMessage({String? prefix}) {
    final remaining = lockRemaining;
    final secs = remaining.inSeconds;
    final msg = 'لقد استنفدت جميع المحاولات. الرجاء الانتظار ${secs}s قبل المحاولة مرة أخرى.';
    return prefix != null ? '$prefix $msg' : msg;
  }

  void _checkAndUpdateLock() {
    if (_lockedUntil != null && DateTime.now().isAfter(_lockedUntil!)) {
      _lockedUntil = null;
      _failedAttempts = 0;
      _error = null;
      notifyListeners();
    }
  }

  // Expose a public method for UI to tick and clear lock when time passes
  void checkAndUpdateLock() => _checkAndUpdateLock();
}
