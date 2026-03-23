import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../repositories/supabase_auth_repository.dart';
import '../services/phase4_service.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.uid});

  final String? uid;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  final _service = Phase4Service();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _achievements = const [];
  List<Map<String, dynamic>> _neighborhoods = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _userSub;
  String? _subscribedUid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.getUserProfile(uid: widget.uid);
      final achievements = await _service.getAchievements(uid: widget.uid);
      final neighborhoods = await _service.getNeighborhoods();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _achievements = achievements;
        _neighborhoods = neighborhoods.take(2).toList();
        _loading = false;
      });

      final liveUid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (liveUid != null) {
        _attachUserRealtime(liveUid);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _attachUserRealtime(String uid) {
    if (_subscribedUid == uid && _userSub != null) return;

    _userSub?.cancel();
    _subscribedUid = uid;
    _userSub = SupabaseService.client
        .from('users')
        .stream(primaryKey: ['uid'])
        .eq('uid', uid)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
          setState(() {
            _profile = {
              ...?_profile,
              ...Map<String, dynamic>.from(rows.first),
            };
          });
        });
  }

  Widget _statTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1C2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  String _avatarUrl() {
    final p = _profile;
    Map<String, dynamic>? configMap;
    final config = p?['avatar_config'];

    if (config is Map) {
      configMap = Map<String, dynamic>.from(config);
    } else if (config is String && config.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(config);
        if (parsed is Map) {
          configMap = Map<String, dynamic>.from(parsed);
        }
      } catch (_) {
        // Ignore malformed config and use fallback URL.
      }
    }

    final savedUrl = (configMap?['avatar_url'] as String?)?.trim();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }

    final uid = (p?['uid'] as String?)?.trim();
    final name = (p?['name'] as String?)?.trim();
    final fallbackSeed = (uid != null && uid.isNotEmpty)
        ? uid
        : ((name != null && name.isNotEmpty) ? name : 'fitcity-profile');
    final encoded = Uri.encodeComponent(fallbackSeed);
    return 'https://api.dicebear.com/9.x/personas/png?seed=$encoded&backgroundType=gradientLinear';
  }

  Widget _profileAvatar(String avatarUrl) {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF113042),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: _accent),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            return const Center(
              child: Icon(Icons.person, color: _accent, size: 40),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final name = p?['name'] as String? ?? 'Alex';
    final title = p?['title'] as String? ?? 'Fitness Explorer';
    final level = (p?['level'] as num?)?.toInt() ?? 1;
    final status = (p?['status_total'] as num?)?.toInt() ?? 0;
    final coins = (p?['coins'] as num?)?.toInt() ?? 0;
    final bodyAge = (p?['body_age'] as num?)?.toDouble();
    final realAge = (p?['real_age'] as num?)?.toInt();
    final lifespan = (p?['lifespan_added'] as num?)?.toDouble() ?? 0;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final viewingOwnProfile = widget.uid == null || widget.uid == currentUid;
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
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: IconButton(
                                  onPressed: () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/home');
                                    }
                                  },
                                  icon: const Icon(Icons.arrow_back, color: _textPrimary),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'FITCITY',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _accent, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Share.share('Profile: $name • Level $level • Status $status in FitCity'),
                                icon: const Icon(Icons.share, color: _textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(child: _profileAvatar(avatarUrl)),
                          const SizedBox(height: 12),
                          Text(name, textAlign: TextAlign.center, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w800, fontSize: 30)),
                          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _textMuted)),
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF11283B),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('LEVEL $level', style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.5,
                            children: [
                              _statTile('Status', status.toString()),
                              _statTile('Coins', coins.toString()),
                              _statTile('Body Age', bodyAge?.toStringAsFixed(1) ?? '--'),
                              _statTile('Lifespan Added', '+${lifespan.toStringAsFixed(2)}y'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (realAge != null)
                            Text('Real age: $realAge years', style: const TextStyle(color: _textMuted), textAlign: TextAlign.center),
                          const SizedBox(height: 18),
                          const Text('Achievements', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _achievements.map((a) {
                              final unlocked = a['unlocked'] == true;
                              return Container(
                                width: MediaQuery.of(context).size.width / 2 - 26,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: unlocked ? const Color(0xFF143345) : const Color(0xFF101A25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: unlocked ? _accent : Colors.white12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['name'] as String? ?? 'Achievement', style: TextStyle(color: unlocked ? _accent : _textPrimary, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(a['description'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textMuted, fontSize: 12)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          const Text('Neighborhoods', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                          const SizedBox(height: 10),
                          ..._neighborhoods.map((n) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F1C2A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.groups, color: _accent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n['name'] as String? ?? 'Neighborhood', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                                          Text('${(n['active_members'] as num?)?.toInt() ?? 0} active members', style: const TextStyle(color: _textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.go('/neighborhood'),
                                      child: const Text('ENTER', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.go('/neighborhood'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _accent),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: const Text('Neighborhood Hub', style: TextStyle(color: _accent)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.go('/shop'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: _accent),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: const Text('Coin Shop', style: TextStyle(color: _accent)),
                                ),
                              ),
                            ],
                          ),
                          if (viewingOwnProfile) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await SupabaseAuthRepository().signOut();
                                if (!context.mounted) return;
                                context.go('/auth');
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0x55FF6A76)),
                                minimumSize: const Size.fromHeight(48),
                              ),
                              icon: const Icon(Icons.logout, color: Color(0xFFFF6A76)),
                              label: const Text('Log Out', style: TextStyle(color: Color(0xFFFF6A76), fontWeight: FontWeight.w700)),
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
