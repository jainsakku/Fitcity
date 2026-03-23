import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/health_connect_service.dart';
import '../services/supabase_service.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, this.task});

  final Map<String, dynamic>? task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);
  final _healthConnectService = HealthConnectService();

  bool _submitting = false;
  String? _message;
  Timer? _deadlineTicker;

  Map<String, dynamic> get _task => widget.task ?? const {};

  int _stars() {
    final diff = (_task['base_difficulty'] as num?)?.toDouble() ?? 3;
    return diff.round().clamp(1, 5);
  }

  @override
  void initState() {
    super.initState();
    _deadlineTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _deadlineTicker?.cancel();
    super.dispose();
  }

  String _registrationTimeLeftLabel() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final diff = tomorrow.difference(now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _markCompleted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userTaskId = _task['user_task_id'] as String?;
    final duration = (_task['duration_min'] as num?)?.toInt() ?? 30;
    if (uid == null || userTaskId == null) {
      setState(() => _message = 'Missing user/task context');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      await SupabaseService.ensureInitialized();
      final evidence = await _healthConnectService.collectVerificationEvidence(
        durationMinutes: duration,
      );
      final res = await SupabaseService.client.functions.invoke(
        'complete-task',
        headers: {'x-fitcity-uid': uid},
        body: {
          'userTaskId': userTaskId,
          'verificationType': evidence?['verificationType'] ?? 'honor',
          if (evidence?['healthConnectData'] != null) 'healthConnectData': evidence!['healthConnectData'],
        },
      );

      if (res.status >= 400) {
        throw Exception('complete-task failed: ${res.data}');
      }

      final data = Map<String, dynamic>.from(res.data as Map);

      if (!mounted) return;
      context.go('/celebration', extra: {
        'task_name': data['taskName'] ?? _task['task_name'] ?? 'Workout',
        'status_earned': data['statusEarned'] ?? 0,
        'coins_earned': data['coinsEarned'] ?? 0,
        'streak': data['streakCount'] ?? ((_task['streak_count'] as num?)?.toInt() ?? 0),
        'impact': data['healthMessage'] ?? 'Great session completed.',
        'body_age_impact': data['bodyAgeImpact'] ?? 0,
        'lifespan_impact': data['lifespanImpact'] ?? 0,
        'new_coins': data['newCoins'] ?? 0,
        'user_task_id': data['userTaskId'] ?? userTaskId,
        'completion_date': data['completionDate'],
      });
    } catch (e) {
      setState(() => _message = '$e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_submitting) return;
    final finished = await context.push<bool>('/workout-session', extra: _task);
    if (!mounted) return;
    if (finished == true) {
      await _markCompleted();
    }
  }

  Widget _impactTile({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: _textMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskName = _task['task_name'] as String? ?? 'Gym Workout';
    final duration = (_task['duration_min'] as num?)?.toInt() ?? 60;
    final streak = (_task['streak_count'] as num?)?.toInt() ?? 12;
    final frequency = (_task['frequency'] as num?)?.toInt() ?? 5;
    final baseDifficulty = (_task['base_difficulty'] as num?)?.toDouble() ?? 3;
    final difficultyStars = _stars();
    final freqMultiplier = switch (frequency) {
      7 => 1.5,
      6 => 1.4,
      5 => 1.3,
      4 => 1.1,
      3 => 1.0,
      2 => 0.85,
      _ => 0.7,
    };
    final streakMultiplier = streak >= 30
        ? 2.0
        : streak >= 14
            ? 1.7
            : streak >= 7
                ? 1.4
                : streak >= 3
                    ? 1.2
                    : 1.0;
    final statusEarned = (10 * baseDifficulty * freqMultiplier * streakMultiplier * 0.8).round();
    final coinsEarned = (statusEarned / 10).round().clamp(1, 999);
    final moneySavedDaily = (_task['money_saved_daily'] as num?)?.toDouble() ?? 45;

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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                    icon: const Icon(Icons.arrow_back, color: _textPrimary),
                  ),
                  const Spacer(),
                  const Text('FITCITY', style: TextStyle(color: _accent, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF13263A), Color(0xFF0A1220)],
                  ),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$taskName - ${duration}min', style: const TextStyle(color: _textPrimary, fontSize: 27, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ...List.generate(5, (i) => Icon(Icons.star, size: 18, color: i < difficultyStars ? _accent : Colors.white24)),
                        const Spacer(),
                        Text('🔥 $streak Day Streak', style: const TextStyle(color: _textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('calendar_today ${frequency}x/week    shield 2 Grace Days', style: const TextStyle(color: _textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1C2A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Time left to register this task today',
                        style: TextStyle(color: _textMuted, fontSize: 12),
                      ),
                    ),
                    Text(
                      _registrationTimeLeftLabel(),
                      style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('HEALTH IMPACT PREVIEW', style: TextStyle(color: _accent, letterSpacing: 1.6, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _impactTile(label: 'Body Age', value: '${(_task['body_age_impact'] as num?)?.toStringAsFixed(2) ?? '-0.05'} years', icon: Icons.biotech),
              const SizedBox(height: 8),
              _impactTile(label: 'Lifespan', value: '+${(_task['lifespan_impact'] as num?)?.toStringAsFixed(2) ?? '0.01'} years', icon: Icons.hourglass_empty),
              const SizedBox(height: 8),
              _impactTile(label: 'Heart Disease Risk', value: '${(_task['disease_risk_heart'] as num?)?.toStringAsFixed(1) ?? '-0.3'}%', icon: Icons.favorite),
              const SizedBox(height: 8),
              _impactTile(label: 'Saved Today', value: '₹${moneySavedDaily.toStringAsFixed(0)}', icon: Icons.currency_rupee),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101D2B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Earnings Potential', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Status earned: +$statusEarned • Coins: +$coinsEarned', style: const TextStyle(color: _textPrimary)),
                    const SizedBox(height: 4),
                    Text('Base ${baseDifficulty.toStringAsFixed(1)}★ × Freq ${freqMultiplier.toStringAsFixed(1)} × Streak ${streakMultiplier.toStringAsFixed(1)}', style: const TextStyle(color: _textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_submitting) const LinearProgressIndicator(color: _accent),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)]),
                ),
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _startWorkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: const Icon(Icons.play_arrow, color: Color(0xFF08111F)),
                  label: const Text('Start Workout', style: TextStyle(color: Color(0xFF08111F), fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _submitting ? null : _markCompleted,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Log as Completed', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
              ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                Text(_message!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
