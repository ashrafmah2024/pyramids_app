import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pyramids/core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // انتظر لثانيتين ثم انتقل إلى الشاشة التالية
    Future.delayed(const Duration(seconds: 2), () {
      // TODO: استبدل '/home' بالمسار الصحيح للشاشة التالية
      if (mounted) {
        context.go('/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // يمكنك استبدال هذا بصورة الشعار الخاص بك
              Image.asset(
                'assets/images/logo.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 24),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
