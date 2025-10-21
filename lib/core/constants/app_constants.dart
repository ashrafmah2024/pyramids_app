class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://hwruivpabecrenwhrgtc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3cnVpdnBhYmVjcmVud2hyZ3RjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTkzMDg3NzUsImV4cCI6MjA3NDg4NDc3NX0.1cIACowXQyZRaaC4CVbT3O-CsF9ZZnj7OtpkQBoeYgk';
  
  // Edge Functions (Admin) - يجب ضبطها من بيئة آمنة
  // ملاحظة: لا تضع أسرارًا حقيقية في تطبيق العميل الإنتاجي.
  static const String adminFunctionCreateUser = 'create_user';
  static const String adminFunctionDeleteUser = 'delete_user';
  static const String adminFunctionChangeUserPassword = 'change_user_password';
  // تنبيه أمني: هذه القيمة للاختبار المحلي فقط. لا تُرفع إلى المستودع العام.
  static const String adminSecret = '9834e5e093d7415a2d593924cb210fe6';
  
  // App Info
  static const String appName = 'Pyramids';
  static const String appVersion = '1.0.0';
  
  // Local Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String themeModeKey = 'theme_mode';
  static const String localeKey = 'locale';
  
  // API Endpoints
  static const String baseApiUrl = '$supabaseUrl/rest/v1';
  // Public IP endpoint
  static const String publicIpUrl = 'https://api.ipify.org?format=json';
  
  // Tables
  static const String loginAuditTable = 'login_audit';
  
  // Default Settings
  static const String defaultLocale = 'ar';
  static const bool defaultThemeDark = false;
}
