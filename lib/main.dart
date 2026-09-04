import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docavail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D2B9E)),
        scaffoldBackgroundColor: const Color(0xFFF3F5FB),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Splash screen shown on app launch.
///
/// Fades in the Docavail icon, holds it on screen for ~2 seconds total,
/// then transitions (with a fade) into [LoginScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;

  static const _fadeInDuration = Duration(milliseconds: 700);
  static const _totalSplashDuration = Duration(seconds: 2);

  late final Future<bool> _sessionCheck;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: _fadeInDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
    _sessionCheck = AuthService.instance.hasValidSession();

    Timer(_totalSplashDuration, _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    _sessionCheck.then((valid) {
      if (!mounted) return;
      final destination = valid ? const AppShell() : const LoginScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'assets/icon/docavail.png',
            width: 140,
            height: 140,
          ),
        ),
      ),
    );
  }
}