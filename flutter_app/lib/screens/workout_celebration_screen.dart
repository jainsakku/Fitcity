import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../services/supabase_service.dart';

class WorkoutCelebrationScreen extends StatefulWidget {
  const WorkoutCelebrationScreen({super.key, this.payload});

  final Map<String, dynamic>? payload;

  @override
  State<WorkoutCelebrationScreen> createState() => _WorkoutCelebrationScreenState();
}

class _WorkoutCelebrationScreenState extends State<WorkoutCelebrationScreen> {
  bool _loadingProfile = true;
  int? _level;
  int? _statusTotal;
  int? _coinsBalance;
  double? _bodyAge;
  double? _lifespanAdded;
  late final ConfettiController _confettiController;

  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
    _loadProfile();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      await SupabaseService.ensureInitialized();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() => _loadingProfile = false);
        return;
      }

      final rows = await SupabaseService.client
          .from('users')
          .select('level,status_total,coins,body_age,lifespan_added')
          .eq('uid', uid)
          .limit(1);

      if (!mounted) return;

      if (rows.isNotEmpty) {
        final row = rows.first;
        setState(() {
          _level = (row['level'] as num?)?.toInt();
          _statusTotal = (row['status_total'] as num?)?.toInt();
          _coinsBalance = (row['coins'] as num?)?.toInt();
          _bodyAge = (row['body_age'] as num?)?.toDouble();
          _lifespanAdded = (row['lifespan_added'] as num?)?.toDouble();
          _loadingProfile = false;
        });
      } else {
        setState(() => _loadingProfile = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final taskName = payload?['task_name'] as String? ?? 'Gym Workout';
    final status = (payload?['status_earned'] as num?)?.toInt() ?? 73;
    final coins = (payload?['coins_earned'] as num?)?.toInt() ?? 7;
    final streak = (payload?['streak'] as num?)?.toInt() ?? 13;
    final impact = payload?['impact'] as String? ?? 'You just reduced diabetes risk by 0.3%!';
    final bodyAgeImpact = (payload?['body_age_impact'] as num?)?.toDouble() ?? 0.05;
    final lifespanImpact = (payload?['lifespan_impact'] as num?)?.toDouble() ?? 0.01;
    final newCoins = (payload?['new_coins'] as num?)?.toInt() ?? _coinsBalance;
    final profileBodyAge = _bodyAge;
    final profileLifespan = _lifespanAdded;

    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.close, color: _textPrimary),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 24,
                  emissionFrequency: 0.05,
                ),
              ),
              SizedBox(
                height: 140,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (_, value, child) => Transform.scale(scale: value, child: child),
                  child: const Icon(Icons.emoji_events, color: _accent, size: 96),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Workout Complete! 🎉',
                  style: TextStyle(color: _textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(taskName, style: const TextStyle(color: _textMuted))),
              const SizedBox(height: 8),
              Center(child: Text('🔥 $streak Day Streak!', style: const TextStyle(color: _accent, fontWeight: FontWeight.w700))),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1C2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What You Just Earned', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: status),
                      duration: const Duration(milliseconds: 900),
                      builder: (_, value, __) => Text('⭐ +$value Status', style: const TextStyle(color: _textPrimary)),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: coins),
                      duration: const Duration(milliseconds: 1100),
                      builder: (_, value, __) => Text('💰 +$value Coins', style: const TextStyle(color: _textPrimary)),
                    ),
                    const SizedBox(height: 4),
                    if (_loadingProfile)
                      const Text('Syncing profile...', style: TextStyle(color: _textMuted))
                    else
                      Text(
                        _level != null && _statusTotal != null
                            ? 'Level $_level • Status ${_statusTotal!.toString()} • Wallet ${newCoins ?? 0}'
                            : (newCoins != null ? 'Wallet Balance: $newCoins coins' : 'Progress updated'),
                        style: const TextStyle(color: _textMuted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1C2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Health Impact', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(impact, style: const TextStyle(color: _accent, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      profileBodyAge != null
                          ? 'Body Age ${profileBodyAge.toStringAsFixed(2)} (${bodyAgeImpact >= 0 ? '-' : '+'}${bodyAgeImpact.abs().toStringAsFixed(2)}yr)'
                          : 'Body Age Impact -${bodyAgeImpact.toStringAsFixed(2)}yr',
                      style: const TextStyle(color: _textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profileLifespan != null
                          ? 'Lifespan Total +${profileLifespan.toStringAsFixed(2)} years'
                          : 'Lifespan Added +${lifespanImpact.toStringAsFixed(2)} years',
                      style: const TextStyle(color: _textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text('Future Medical Savings ₹${(coins * 6).toString()}', style: const TextStyle(color: _textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1C2A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Building Grew!', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Before  ↔  Now  (+3 floors)', style: TextStyle(color: _textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)]),
                ),
                child: ElevatedButton(
                  onPressed: () => Share.share(
                    'I completed $taskName in FitCity and earned +$status status and +$coins coins! 🔥',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Share Achievement', style: TextStyle(color: Color(0xFF08111F), fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Home', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
