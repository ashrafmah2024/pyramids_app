import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/core/constants/app_constants.dart';
import 'package:pyramids/features/auth/domain/models/login_audit_model.dart';

class LoginAuditRemoteDataSource {
  final SupabaseClient _supabase;
  LoginAuditRemoteDataSource({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  Future<void> insert(LoginAuditModel audit) async {
    await _supabase.from(AppConstants.loginAuditTable).insert(audit.toJson());
  }
}
