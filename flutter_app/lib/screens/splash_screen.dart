import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/supabase_auth_repository.dart';
import '../services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _bgBottom = Color(0xFF041722);
  static const _cyan = Color(0xFF29D8FA);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF7F95A8);

  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await SupabaseService.ensureInitialized();
      final authRepo = SupabaseAuthRepository();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        context.go('/auth');
        return;
      }

      await authRepo.syncCurrentUserToSupabase();
      final targetRoute = await authRepo.resolvePostAuthRouteForCurrentUser();

      if (!mounted) return;
      context.go(targetRoute);
    } catch (e, st) {
      developer.log(
        'Splash bootstrap failed',
        name: 'FitCity.Splash',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [Color(0xFF0B2C34), _bgBottom],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (_, value, child) => Transform.scale(scale: value, child: child),
                    child: const Icon(Icons.location_city, size: 120, color: _cyan),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(text: 'Fit', style: TextStyle(color: _textPrimary)),
                        TextSpan(text: 'City', style: TextStyle(color: _cyan)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(color: _cyan, strokeWidth: 2.8),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Bootstrapping FitCity...',
                  style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Startup error: $_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
