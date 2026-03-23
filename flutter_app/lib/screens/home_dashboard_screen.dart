import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/supabase_task_repository.dart';
import '../services/supabase_service.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  final _taskRepo = SupabaseTaskRepository();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _tasks = const [];
  Timer? _registrationTicker;
  StreamSubscription<List<Map<String, dynamic>>>? _streakSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _registrationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_allTasksRegisteredToday()) return;
      setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _registrationTicker?.cancel();
    _streakSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _error = 'No Firebase user found';
        _loading = false;
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await SupabaseService.ensureInitialized();
      final userRows = await SupabaseService.client
          .from('users')
          .select('uid,name,title,level,status_total,coins,body_age,real_age,lifespan_added,avatar_config')
          .eq('uid', uid)
          .limit(1);

      final tasks = await _taskRepo.fetchDashboard(uid);

      if (!mounted) return;
      setState(() {
        _user = userRows.isNotEmpty ? Map<String, dynamic>.from(userRows.first) : null;
        _tasks = tasks;
        _loading = false;
      });

      _attachRealtime(uid);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _attachRealtime(String uid) {
    _streakSubscription?.cancel();
    _userSubscription?.cancel();

    _streakSubscription = SupabaseService.client
        .from('streaks')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .listen((_) {
          _load(silent: true);
        });

    _userSubscription = SupabaseService.client
        .from('users')
        .stream(primaryKey: ['uid'])
        .eq('uid', uid)
        .listen((_) {
          _load(silent: true);
        });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  int _activeStreak() {
    if (_tasks.isEmpty) return 0;
    return _tasks
        .map((t) => (t['streak_count'] as num?)?.toInt() ?? 0)
        .fold<int>(0, (max, v) => v > max ? v : max);
  }

  double _riskReductionScore() {
    if (_tasks.isEmpty) return 0;
    double total = 0;
    for (final t in _tasks) {
      final h = (t['disease_risk_heart'] as num?)?.toDouble() ?? 0;
      final d = (t['disease_risk_diabetes'] as num?)?.toDouble() ?? 0;
      final s = (t['disease_risk_stroke'] as num?)?.toDouble() ?? 0;
      total += (h.abs() + d.abs() + s.abs()) / 3;
    }
    return (total / _tasks.length * 100).clamp(0, 100);
  }

  String _statusLabel(int value) {
    final text = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final reverseIndex = text.length - i;
      out.write(text[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        out.write(',');
      }
    }
    return out.toString();
  }

  int _moneySavedPerYear() {
    if (_tasks.isEmpty) return 0;
    var totalDaily = 0.0;
    for (final t in _tasks) {
      totalDaily += (t['money_saved_daily'] as num?)?.toDouble() ?? 0;
    }
    return (totalDaily * 365).round();
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

  bool _isCompletedToday(Map<String, dynamic> task) {
    final raw = task['last_completed_date'];
    if (raw == null) return false;
    final text = raw.toString();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return text.startsWith(today);
  }

  int _completedTodayCount() {
    if (_tasks.isEmpty) return 0;
    return _tasks.where(_isCompletedToday).length;
  }

  bool _allTasksRegisteredToday() {
    if (_tasks.isEmpty) return false;
    return _completedTodayCount() >= _tasks.length;
  }

  String? _avatarUrl() {
    Map<String, dynamic>? configMap;
    final config = _user?['avatar_config'];

    if (config is Map) {
      configMap = Map<String, dynamic>.from(config);
    } else if (config is String && config.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(config);
        if (parsed is Map) {
          configMap = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {
        // Ignore malformed avatar config and fall back to deterministic URL below.
      }
    }

    final savedUrl = (configMap?['avatar_url'] as String?)?.trim();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }

    final uid = (_user?['uid'] as String?)?.trim();
    final name = (_user?['name'] as String?)?.trim();
    final fallbackSeed = (uid != null && uid.isNotEmpty)
        ? uid
        : ((name != null && name.isNotEmpty) ? name : 'fitcity-user');
    final encoded = Uri.encodeComponent(fallbackSeed);
    return 'https://api.dicebear.com/9.x/personas/png?seed=$encoded&backgroundType=gradientLinear';
  }

  Widget _metricCard({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1B2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 18),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = (user?['name'] as String?) ?? 'Athlete';
    final level = (user?['level'] as num?)?.toInt() ?? 1;
    final status = (user?['status_total'] as num?)?.toInt() ?? 0;
    final statusFormatted = _statusLabel(status);
    final coins = (user?['coins'] as num?)?.toInt() ?? 0;
    final bodyAgeValue = (user?['body_age'] as num?)?.toDouble() ?? (user?['real_age'] as num?)?.toDouble();
    final bodyAge = bodyAgeValue == null ? '--' : bodyAgeValue.toStringAsFixed(1);
    final realAge = (user?['real_age'] as num?)?.toInt();
    final lifespan = ((user?['lifespan_added'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
    final completedCount = _completedTodayCount();
    final totalTasks = _tasks.length;
    final progress = totalTasks == 0 ? 0.0 : (completedCount / totalTasks).clamp(0, 1).toDouble();
    final allDone = _allTasksRegisteredToday();
    final avatarUrl = _avatarUrl();

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
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _accent))
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, style: const TextStyle(color: _textPrimary), textAlign: TextAlign.center),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${_greeting()}, $name', style: const TextStyle(color: _textPrimary, fontSize: 27, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text('Level $level - Status: $statusFormatted', style: const TextStyle(color: _textMuted)),
                                  ],
                                ),
                              ),
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white.withValues(alpha: 0.10),
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? const Icon(Icons.person, color: _accent) : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF102330),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text('🔥 ${_activeStreak()} Day Streak', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF102330),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text('💰 $coins', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF102330),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Icon(allDone ? Icons.verified : Icons.timer_outlined, color: _accent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    allDone ? 'All tasks registered for today' : 'Time left to register completed tasks',
                                    style: const TextStyle(color: _textMuted, fontSize: 12),
                                  ),
                                ),
                                Text(
                                  allDone ? 'DONE' : _registrationTimeLeftLabel(),
                                  style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1C2A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Today's Progress  $completedCount/$totalTasks",
                                  style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(999),
                                  color: _accent,
                                  backgroundColor: Colors.white12,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  allDone ? 'All daily logs complete. Great consistency.' : '${math.max(0, totalTasks - completedCount)} tasks left to log today',
                                  style: const TextStyle(color: _textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF13263A), Color(0xFF0A1220)],
                              ),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('YOUR SKYLINE', style: TextStyle(color: _accent, letterSpacing: 1.4, fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      const Text('Tap to explore', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      TextButton.icon(
                                        onPressed: () => context.go('/task-detail', extra: _tasks.isNotEmpty ? _tasks.first : null),
                                        icon: const Icon(Icons.arrow_forward, color: _accent, size: 16),
                                        label: const Text('Open Task Focus', style: TextStyle(color: _accent)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(colors: [Color(0xFF22384C), Color(0xFF18273A)]),
                                  ),
                                  child: const Icon(Icons.domain, color: _accent, size: 34),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text("Today's Tasks", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                          const SizedBox(height: 10),
                          ..._tasks.take(4).map((task) {
                            final isBroken = task['is_broken'] == true;
                            final streak = (task['streak_count'] as num?)?.toInt() ?? 0;
                            final completedToday = _isCompletedToday(task);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                onTap: () => context.go('/task-detail', extra: task),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1C2A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isBroken ? const Color(0x66FF4D67) : Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: const BoxDecoration(color: Color(0xFF142C3B), shape: BoxShape.circle),
                                        child: Icon(
                                          isBroken
                                              ? Icons.warning_amber_rounded
                                              : (completedToday ? Icons.check_circle : Icons.radio_button_unchecked),
                                          color: isBroken ? const Color(0xFFFF6A76) : _accent,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(task['task_name'] as String? ?? 'Task', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                                      ),
                                      Text('🔥$streak', style: const TextStyle(color: _textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                          const Text('Health Impact', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                          const SizedBox(height: 10),
                          GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            shrinkWrap: true,
                            childAspectRatio: 1.35,
                            children: [
                              _metricCard(label: 'Body Age', value: bodyAge, icon: Icons.biotech),
                              _metricCard(label: 'Lifespan Added', value: '+$lifespan yrs', icon: Icons.favorite),
                              _metricCard(label: 'Risk Reduction', value: '${_riskReductionScore().toStringAsFixed(0)}%', icon: Icons.monitor_heart),
                              _metricCard(label: 'Money Saved / year', value: '₹${_moneySavedPerYear()}', icon: Icons.savings),
                            ],
                          ),
                          if (realAge != null) ...[
                            const SizedBox(height: 8),
                            Text('Real age: $realAge years', style: const TextStyle(color: _textMuted), textAlign: TextAlign.center),
                          ],
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
