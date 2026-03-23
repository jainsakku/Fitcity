import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/supabase_service.dart';

class StreakRecoveryScreen extends StatefulWidget {
  const StreakRecoveryScreen({super.key});

  @override
  State<StreakRecoveryScreen> createState() => _StreakRecoveryScreenState();
}

class _StreakRecoveryScreenState extends State<StreakRecoveryScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _danger = Color(0xFFFF6A76);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  bool _loading = true;
  bool _working = false;
  String? _error;
  int _coins = 0;
  Map<String, dynamic>? _broken;
  Timer? _countdownTicker;

  Map<String, dynamic>? _pickStreakRow(List<dynamic> rows) {
    if (rows.isEmpty) return null;

    final normalized = rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();

    final brokenRows = normalized.where((r) => r['is_broken'] == true).toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse((a['recovery_deadline'] ?? '').toString());
        final bd = DateTime.tryParse((b['recovery_deadline'] ?? '').toString());
        if (ad == null && bd == null) {
          final as = (a['streak_count'] as num?)?.toInt() ?? 0;
          final bs = (b['streak_count'] as num?)?.toInt() ?? 0;
          return bs.compareTo(as);
        }
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    if (brokenRows.isNotEmpty) return brokenRows.first;

    final shieldRows = normalized.where((r) => r['shield_active'] == true).toList()
      ..sort((a, b) {
        final as = (a['streak_count'] as num?)?.toInt() ?? 0;
        final bs = (b['streak_count'] as num?)?.toInt() ?? 0;
        return bs.compareTo(as);
      });
    if (shieldRows.isNotEmpty) return shieldRows.first;

    normalized.sort((a, b) {
      final as = (a['streak_count'] as num?)?.toInt() ?? 0;
      final bs = (b['streak_count'] as num?)?.toInt() ?? 0;
      return bs.compareTo(as);
    });
    return normalized.first;
  }

  @override
  void initState() {
    super.initState();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_broken == null) return;
      setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _error = 'No Firebase user found';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.ensureInitialized();

      final users = await SupabaseService.client
          .from('users')
          .select('coins')
          .eq('uid', uid)
          .limit(1);

      final rows = await SupabaseService.client
          .from('v_user_dashboard')
          .select('user_task_id,task_name,streak_count,recovery_cost,recovery_deadline,grace_days_remaining,shield_active,is_broken')
          .eq('user_id', uid)
          .order('streak_count', ascending: false)
          .limit(20);

      final picked = _pickStreakRow(rows);

      if (!mounted) return;
      setState(() {
        _coins = users.isNotEmpty ? (users.first['coins'] as num?)?.toInt() ?? 0 : 0;
        _broken = picked;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _recover() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userTaskId = _broken?['user_task_id'] as String?;
    if (uid == null || userTaskId == null) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final res = await SupabaseService.client.functions.invoke(
        'recover-streak',
        headers: {'x-fitcity-uid': uid},
        body: {'userTaskId': userTaskId},
      );
      if (res.status >= 400) {
        throw Exception('recover-streak failed: ${res.data}');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _buyShield() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      final res = await SupabaseService.client.functions.invoke(
        'buy-streak-shield',
        headers: {'x-fitcity-uid': uid},
        body: {},
      );
      if (res.status >= 400) {
        throw Exception('buy-streak-shield failed: ${res.data}');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _remainingLabel() {
    final deadlineRaw = _broken?['recovery_deadline'];
    if (deadlineRaw == null) return '--:--:--';
    final deadline = DateTime.tryParse(deadlineRaw.toString());
    if (deadline == null) return '--:--:--';
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return '00:00:00';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final broken = _broken;
    final isBroken = broken?['is_broken'] == true;
    final streak = (broken?['streak_count'] as num?)?.toInt() ?? 12;
    final cost = (broken?['recovery_cost'] as num?)?.toInt() ?? 150;
    final grace = (broken?['grace_days_remaining'] as num?)?.toInt() ?? 0;
    final shield = broken?['shield_active'] == true;

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
              : ListView(
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
                        const Expanded(
                          child: Text(
                            'FITCITY',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _accent, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isBroken ? 'Streak at Risk' : 'Streak Status',
                      style: TextStyle(color: isBroken ? _danger : _accent, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isBroken
                          ? 'Your $streak-Day Streak broke 💔'
                          : 'Your $streak-Day Streak is protected 🛡️',
                      style: const TextStyle(color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    if (isBroken) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer, color: _danger, size: 18),
                          const SizedBox(width: 6),
                          Text('${_remainingLabel()} Remaining', style: const TextStyle(color: _textMuted)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1C2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Grace Days: $grace remaining this quarter', style: const TextStyle(color: _textPrimary)),
                          const SizedBox(height: 6),
                          Text(shield ? 'Shield active' : 'No shield active', style: const TextStyle(color: _textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1C2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isBroken ? 'Streak Recovery' : 'Streak Shield', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(isBroken ? 'Recovery cost: $cost coins' : 'Shield cost: 150 coins', style: const TextStyle(color: _textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Shield applies to all active tasks and is consumed when it prevents the next break.', style: TextStyle(color: _textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Balance: $_coins coins', style: const TextStyle(color: _textMuted)),
                        ],
                      ),
                    ),
                    if (isBroken) ...[
                      const SizedBox(height: 12),
                      const Text('Recovery Tiers', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('1-7d: 50   8-30d: 150   31-90d: 300   91-365d: 500   365+: 1k', style: TextStyle(color: _textMuted)),
                    ],
                    const SizedBox(height: 16),
                    if (_working) const LinearProgressIndicator(color: _accent),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)]),
                      ),
                      child: ElevatedButton(
                        onPressed: broken == null || _working || !isBroken ? null : _recover,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(isBroken ? 'Recover Streak' : 'No Recovery Needed', style: const TextStyle(color: Color(0xFF08111F), fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: broken == null || _working || shield ? null : _buyShield,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: _accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.shield, color: _accent),
                      label: Text(
                        shield ? 'Global Shield Active' : 'Buy Global Shield (150 coins)',
                        style: const TextStyle(color: _accent, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: _danger)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
