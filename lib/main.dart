import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pyramids/l10n/gen/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:pyramids/core/constants/app_constants.dart';
import 'package:pyramids/core/navigation/app_router.dart';
import 'package:pyramids/core/services/supabase_service.dart';
import 'package:pyramids/core/theme/app_theme.dart';
import 'package:pyramids/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:pyramids/features/auth/domain/repositories/auth_repository.dart';
import 'package:pyramids/features/auth/presentation/providers/auth_provider.dart';
import 'package:pyramids/features/users/data/datasources/user_remote_data_source.dart';
import 'package:pyramids/features/users/data/repositories/user_repository_impl.dart';
import 'package:pyramids/features/users/domain/repositories/user_repository.dart';
import 'package:pyramids/features/users/presentation/providers/user_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pyramids/features/partners/data/datasources/partners_remote_data_source.dart';
import 'package:pyramids/features/partners/data/repositories/partners_repository_impl.dart';
import 'package:pyramids/features/partners/domain/repositories/partners_repository.dart';
import 'package:pyramids/features/partners/presentation/providers/partners_provider.dart';
import 'package:pyramids/features/manufacturing/presentation/providers/manufacturing_provider.dart';
import 'package:pyramids/features/partners/presentation/providers/supplier_account_statement_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Android will use google-services.json). For iOS, ensure GoogleService-Info.plist exists.
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyCwZy-3p6sqv5alRkqLFgYX57tFWDIJALo',
          authDomain: 'pyramids-89577.firebaseapp.com',
          projectId: 'pyramids-89577',
          storageBucket: 'pyramids-89577.firebasestorage.app',
          messagingSenderId: '32764700037',
          appId: '1:32764700037:web:YOUR_WEB_APP_ID_HERE', // Replace with your actual web app ID from Firebase console
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  
  // Initialize Supabase
  SupabaseService? supabaseService;
  try {
    supabaseService = SupabaseService();
    await supabaseService.initialize();
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    MultiProvider(
      providers: [
        // Core Services
        Provider<SupabaseService>(
          create: (_) => supabaseService!,
        ),
        
        // Repositories
        Provider<AuthRepository>(
          create: (context) => AuthRepositoryImpl(supabaseService!),
        ),
        Provider<UserRepository>(
          create: (context) => UserRepositoryImpl(
            remoteDataSource: UserRemoteDataSource(supabaseClient: supabaseService!.client),
          ),
        ),
        // Partners Repository
        Provider<PartnersRepository>(
          create: (context) => PartnersRepositoryImpl(
            PartnersRemoteDataSource(supabaseService!.client),
          ),
        ),
        
        // Providers
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            context.read<AuthRepository>(),
          )..checkAuthStatus(),
        ),
        // User Provider
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(
            userRepository: context.read<UserRepository>(),
          ),
        ),
        // Partners Provider
        ChangeNotifierProvider<PartnersProvider>(
          create: (context) => PartnersProvider(
            context.read<PartnersRepository>(),
          ),
        ),
        ChangeNotifierProvider<ManufacturingProvider>(
          create: (context) => ManufacturingProvider()..resetWorkingStages(),
        ),
        ChangeNotifierProvider<SupplierAccountStatementProvider>(
          create: (context) => SupplierAccountStatementProvider(),
        ),

        // App Theme
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
        ),
      ],
      child: const PyramidsApp(),
    ),
  );
}

class PyramidsApp extends StatelessWidget {
  const PyramidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppTheme>(
      builder: (context, theme, _) {
        return MaterialApp.router(
          title: 'Pyramids',
          debugShowCheckedModeBanner: false,
          theme: theme.currentTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', ''),
            Locale('en', ''),
          ],
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // انتظر إطار ما بعد البناء ثم تحقّق من حالة المصادقة عبر AuthProvider
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    // إذا كان ما زال يتحقق من الحالة، انتظر حتى يكتمل (بحد أقصى 3 ثوان)
    final start = DateTime.now();
    while (authProvider.isLoading && DateTime.now().difference(start) < const Duration(seconds: 3)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    if (!mounted) return;

    // إذا المستخدم مصادق بالفعل، وجّه حسب الدور
    if (authProvider.isAuthenticated) {
      final user = authProvider.currentUser;
      final role = user?.role.toLowerCase();
      final targetRoute = (role == 'manager')
          ? AppRouter.manager
          : (role == 'accountant')
              ? AppRouter.accountant
              : AppRouter.dashboard;
      Navigator.of(context).pushReplacementNamed(targetRoute);
      return;
    }

    // فحص ثانوي: إن لم يكن مصادقاً عبر المزود، افحص جلسة Supabase مباشرة
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // قد لا تتوفر بيانات الدور هنا، وجّه للوحة التحكم كافتراضي
        Navigator.of(context).pushReplacementNamed(AppRouter.dashboard);
        return;
      }
    } catch (_) {}

    // إن لم تكن هناك جلسة، وجّه لشاشة تسجيل الدخول
    Navigator.of(context).pushReplacementNamed(AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add your app logo here
            const FlutterLogo(size: 100),
            const SizedBox(height: 20),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Placeholder screen for navigation
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
      ),
      body: const Center(
        child: Text('Welcome to Pyramids App'),
      ),
    );
  }
}
