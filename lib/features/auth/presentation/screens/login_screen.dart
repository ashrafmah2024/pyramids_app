import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/l10n/gen/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/theme/app_theme.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late final AnimationController _shakeController;
  Animation<double> _shakeAnimation = const AlwaysStoppedAnimation<double>(0);
  Timer? _lockTimer;
  bool _hasInternet = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<InternetConnectionStatus>? _internetStatusSub;
  Timer? _webPollTimer;
  String? _appVersion;
  String? _buildNumber;
  bool _updateAvailable = false;
  String? _updateMessage;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -16), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -16, end: 16), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 16, end: -16), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -16, end: 16), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 16, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );

    // Periodically tick to update lock countdown and clear lock when expired
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<AuthProvider>();
      final wasLocked = provider.isLocked;
      provider.checkAndUpdateLock();
      if (mounted && (wasLocked || provider.isLocked)) {
        setState(() {});
      }
    });

    // Platform-specific connectivity initialization
    if (kIsWeb) {
      _initWebConnectivity();
    } else {
      _initNativeConnectivity();
    }

    // No periodic HTTP probes needed now; stream handles changes on native.
    _loadVersionAndCheckUpdate();

    // Auto-redirect if already authenticated (e.g., app reopened with saved session)
    // Wait for first frame to ensure providers are available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();

      // Ensure provider state is up-to-date (hydrate from stored Supabase session)
      try {
        await auth.checkAuthStatus();
      } catch (_) {}

      if (!mounted) return;

      if (auth.isAuthenticated) {
        final role = auth.currentUser?.role.toLowerCase();
        final target = (role == 'manager')
            ? AppRouter.manager
            : (role == 'accountant')
                ? AppRouter.accountant
                : AppRouter.manager;
        GoRouter.of(context).go(target);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shakeController.dispose();
    _lockTimer?.cancel();
    _connectivitySub?.cancel();
    _internetStatusSub?.cancel();
    _webPollTimer?.cancel();
    super.dispose();
  }

  void _triggerShake() {
    if (_shakeController.isAnimating) return;
    _shakeController.forward(from: 0);
  }

  Future<void> _login() async {
    print('بدء عملية تسجيل الدخول...');

    if (!_formKey.currentState!.validate()) {
      print('❗ فشل التحقق من صحة النموذج');
      return;
    }

    print('البريد الإلكتروني: ${_emailController.text.trim()}');
    print('جاري محاولة تسجيل الدخول...');

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      print('✅ تم تهيئة AuthProvider');

      final success = await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      print('🔑 نتيجة محاولة تسجيل الدخول: $success');

      if (success && mounted) {
        final user = authProvider.currentUser;
        print(
          '👤 بيانات المستخدم: ${user?.toJson().toString() ?? 'لا توجد بيانات'}',
        );

        final role = user?.role.toLowerCase() ?? 'unknown';
        print('🎭 دور المستخدم: $role');

        if (mounted) {
          String targetRoute;

          if (role == 'manager') {
            targetRoute = AppRouter.manager;
          } else if (role == 'accountant') {
            targetRoute = AppRouter.accountant;
          } else {
            targetRoute = AppRouter.manager;
          }

          print('🔄 سيتم التوجيه إلى: $targetRoute');

          // Use GoRouter to navigate
          final router = GoRouter.of(context);
          router.go(targetRoute);
          print('✅ تم تسجيل الدخول بنجاح والتوجيه إلى $targetRoute');
        }
      } else if (mounted) {
        print('❌ فشل تسجيل الدخول');
        _triggerShake();
      }
    } catch (e, stackTrace) {
      print('❌ حدث خطأ أثناء تسجيل الدخول: $e');
      print('📜 تفاصيل الخطأ: $stackTrace');
      if (mounted) {
        _triggerShake();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    _loadVersionAndCheckUpdate();
  }

  // Compare semantic versions like 1.2.3
  int _compareVersions(String a, String b) {
    List<int> pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (pa.length < 3) pa.add(0);
    while (pb.length < 3) pb.add(0);
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  Future<void> _loadVersionAndCheckUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      // ignore if package info fails
    }

    try {
      final client = Supabase.instance.client;
      // Expecting a table app_config with rows { key: 'latest_version' | 'update_message', value: '...' }
      final rows = await client.from('app_config').select('key,value').inFilter(
        'key',
        ['latest_version', 'update_message'],
      );

      String? latest;
      String? message;
      for (final r in rows) {
        if (r['key'] == 'latest_version') latest = r['value']?.toString();
        if (r['key'] == 'update_message') message = r['value']?.toString();
      }

      if (latest != null && _appVersion != null) {
        final cmp = _compareVersions(latest!, _appVersion!);
        if (cmp > 0) {
          if (!mounted) return;
          setState(() {
            _updateAvailable = true;
            _latestVersion = latest;
            _updateMessage = message ?? 'يتوفر تحديث جديد للإصدار $latest.';
          });
        }
      }
    } catch (_) {
      // If table doesn't exist or network error, silently ignore
    }
  }

  // Web-only connectivity probing using same-origin fetch to avoid CORS pitfalls
  Future<void> _webProbeOnce() async {
    try {
      final resp = await http
          .get(Uri.parse('/'))
          .timeout(const Duration(seconds: 2));
      if (mounted)
        setState(
          () => _hasInternet = resp.statusCode >= 200 && resp.statusCode < 500,
        );
    } catch (_) {
      if (mounted) setState(() => _hasInternet = false);
    }
  }

  void _initWebConnectivity() {
    // initial probe
    _webProbeOnce();
    // periodic probe
    _webPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _webProbeOnce();
    });
    // react on transport changes by probing once
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      await _webProbeOnce();
    });
  }

  void _initNativeConnectivity() {
    // Initial reachability check
    InternetConnectionChecker.createInstance().hasConnection.then((reachable) {
      if (mounted) setState(() => _hasInternet = reachable);
    });
    // Subscribe to reachability changes
    _internetStatusSub = InternetConnectionChecker.createInstance()
        .onStatusChange
        .listen((status) {
          if (!mounted) return;
          setState(
            () => _hasInternet = status == InternetConnectionStatus.connected,
          );
        });
    // Transport change: if none, mark offline for immediate UX
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final transportsAvailable =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      if (!transportsAvailable && mounted) setState(() => _hasInternet = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final authProvider = context.watch<AuthProvider>();
    final isLocked = authProvider.isLocked;
    String _formatDuration(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a237e),
            Color(0xFF4a148c),
          ], // تدرج من الأزرق إلى البنفسجي
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and App Name
                  SizedBox(height: bottomInset > 0 ? 16 : size.height * 0.05),
                  // عرض الشعار بدون خلفية
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 200,
                      width: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Pyramids',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3.0,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ' Management System',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_updateAvailable) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.system_update,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _updateMessage ??
                                  'يتوفر تحديث جديد ${_latestVersion != null ? '(v$_latestVersion)' : ''}.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Inline error banner on failed attempts or lockout
                  if (authProvider.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authProvider.error!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isLocked) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_clock),
                          const SizedBox(width: 8),
                          Text(
                            'محظور لمدة ${_formatDuration(authProvider.lockRemaining)}',
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Email Field with shake
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                        ),
                        errorStyle: TextStyle(color: Colors.red.shade200),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      onChanged: (_) => Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).clearError(),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) {
                          return 'Please enter your email';
                        }
                        // Development-friendly check: minimal validation to avoid blocking login
                        // Accept any string that contains '@' (skip strict TLD checks)
                        if (!v.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field with shake
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                        ),
                        errorStyle: TextStyle(color: Colors.red.shade200),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      onChanged: (_) => Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      ).clearError(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  const SizedBox.shrink(),

                  // Login Button with shake
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: FilledButton(
                      onPressed: (_isLoading || isLocked) ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_appVersion != null) ...[
                    Text(
                      'الإصدار: v${_appVersion!}${_buildNumber != null ? "+${_buildNumber!}" : ''}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Internet status indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasInternet ? Icons.wifi : Icons.wifi_off,
                        color: _hasInternet
                            ? Colors.green
                            : theme.colorScheme.error,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hasInternet
                            ? AppLocalizations.of(
                                context,
                              )!.internetStatusConnected
                            : AppLocalizations.of(
                                context,
                              )!.internetStatusDisconnected,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _hasInternet
                              ? Colors.green
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: bottomInset > 0 ? 12 : size.height * 0.08),
                  // Remaining attempts and reset hint
                  if (authProvider.failedAttempts > 0) ...[
                    Text(
                      'المحاولات الفاشلة: ${authProvider.failedAttempts} / 3',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox.shrink(),
                  ],

                  const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
