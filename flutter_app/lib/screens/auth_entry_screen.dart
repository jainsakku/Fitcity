import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthEntryScreen extends StatefulWidget {
  const AuthEntryScreen({super.key});

  @override
  State<AuthEntryScreen> createState() => _AuthEntryScreenState();
}

class _AuthEntryScreenState extends State<AuthEntryScreen> {
  static const _bgBottom = Color(0xFF041722);
  static const _cyan = Color(0xFF29D8FA);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF7F95A8);

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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/splash');
                        }
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: _textPrimary),
                      ),
                    ),
                    const Spacer(),
                    const Text('PREMIUM', style: TextStyle(color: _textMuted, letterSpacing: 2.2, fontSize: 30 / 2, fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                    ),
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF09313A), Color(0xFF04131B)],
                          ),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
                        ),
                        child: const Icon(Icons.location_city, color: _cyan, size: 110),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 56 / 2, fontWeight: FontWeight.w700),
                        children: [
                          TextSpan(text: 'Fit', style: TextStyle(color: _textPrimary)),
                          TextSpan(text: 'City', style: TextStyle(color: _cyan)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Your Workouts.\nYour Skyline. Your City.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textPrimary, fontSize: 56 / 2, fontWeight: FontWeight.w700, height: 1.18),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Build your legacy, one rep at a time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _textMuted, fontSize: 33 / 2, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(colors: [Color(0xFF224F56), _cyan]),
                    boxShadow: [
                      BoxShadow(color: _cyan.withValues(alpha: 0.25), blurRadius: 20),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => context.go('/signup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size.fromHeight(78),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Get Started  →', style: TextStyle(color: Color(0xFF031014), fontWeight: FontWeight.w800, fontSize: 21)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(74),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                  ),
                  child: const Text('I Already Have An Account', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
