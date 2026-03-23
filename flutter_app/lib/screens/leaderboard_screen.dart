import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/phase4_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  final _service = Phase4Service();
  final _frames = const {
    'all': 'global',
    'month': 'monthly',
    'week': 'weekly',
  };

  String _selected = 'all';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rankings = const [];
  int? _userRank;
  num? _userScore;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getLeaderboard(timeFrame: _frames[_selected]!, limit: 50);
      if (!mounted) return;
      setState(() {
        _rankings = List<Map<String, dynamic>>.from(data['rankings'] as List? ?? const []);
        _userRank = (data['userRank'] as num?)?.toInt();
        _userScore = data['userScore'] as num?;
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

  Widget _framePill(String key, String label) {
    final selected = _selected == key;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selected = key);
          _load();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)])
                : null,
            color: selected ? null : const Color(0xFF102330),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF08111F) : _textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _podiumCard({required Map<String, dynamic> row, required int rank}) {
    final name = row['name'] as String? ?? 'Player';
    final score = (row['score'] as num?)?.toInt() ?? 0;
    final level = (row['level'] as num?)?.toInt() ?? 1;
    final avatarUrl = _avatarUrl(row);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: rank == 1
                ? const [Color(0xFF193244), Color(0xFF0F1C2A)]
                : const [Color(0xFF142434), Color(0xFF0F1C2A)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: rank == 1 ? _accent : Colors.white12),
        ),
        child: Column(
          children: [
            Text('#$rank', style: TextStyle(color: rank == 1 ? _accent : _textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            CircleAvatar(
              radius: rank == 1 ? 24 : 20,
              backgroundColor: const Color(0xFF183246),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? const Icon(Icons.person, color: _accent) : null,
            ),
            const SizedBox(height: 8),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Lvl $level', style: const TextStyle(color: _textMuted, fontSize: 11)),
            const SizedBox(height: 4),
            Text('${score.toString()} pts', style: const TextStyle(color: _textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String? _avatarUrl(Map<String, dynamic> row) {
    final avatarConfig = row['avatar_config'];
    if (avatarConfig is Map && avatarConfig['avatar_url'] is String) {
      final url = (avatarConfig['avatar_url'] as String).trim();
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _rankings.take(3).toList();

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
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                                  'Global Leaderboard',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.search, color: _textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _framePill('all', 'All Time'),
                              const SizedBox(width: 8),
                              _framePill('month', 'This Month'),
                              const SizedBox(width: 8),
                              _framePill('week', 'This Week'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (top3.length == 3)
                            Row(
                              children: [
                                _podiumCard(row: top3[1], rank: 2),
                                const SizedBox(width: 8),
                                _podiumCard(row: top3[0], rank: 1),
                                const SizedBox(width: 8),
                                _podiumCard(row: top3[2], rank: 3),
                              ],
                            ),
                          const SizedBox(height: 12),
                          if (_userRank != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF11283B), Color(0xFF0F1C2A)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFF2DD9FA)),
                              ),
                              child: Text(
                                'You are #$_userRank with ${(_userScore ?? 0).toString()} status',
                                style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700),
                              ),
                            ),
                          const SizedBox(height: 12),
                          ..._rankings.map((row) {
                            final rank = (row['rank'] as num?)?.toInt() ?? 0;
                            final name = row['name'] as String? ?? 'Player';
                            final score = (row['score'] as num?)?.toInt() ?? 0;
                            final level = (row['level'] as num?)?.toInt() ?? 1;
                            final uid = row['uid'] as String?;
                            final avatarUrl = _avatarUrl(row);
                            final isYou = _userRank == rank;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: uid == null ? null : () => context.go('/profile', extra: {'uid': uid}),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isYou
                                        ? const Color(0xFF143349)
                                        : (rank <= 3 ? const Color(0xFF12283A) : const Color(0xFF0F1C2A)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isYou
                                          ? const Color(0xFF2DD9FA)
                                          : (rank <= 3 ? const Color(0x5530E6FF) : Colors.white12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 28, child: Text('$rank', style: const TextStyle(color: _textMuted))),
                                      const SizedBox(width: 6),
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFF163245),
                                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                        child: avatarUrl == null ? const Icon(Icons.person, color: _accent, size: 18) : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(isYou ? 'YOU (${name.toUpperCase()})' : name, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            const Text('STATUS', style: TextStyle(color: _textMuted, fontSize: 10, letterSpacing: 1.0)),
                                          ],
                                        ),
                                      ),
                                      Text('Lvl $level', style: const TextStyle(color: _textMuted)),
                                      const SizedBox(width: 10),
                                      Text(score.toString(), style: const TextStyle(color: _accent, fontWeight: FontWeight.w700)),
                                      if (isYou) ...[
                                        const SizedBox(width: 8),
                                        const Icon(Icons.keyboard_double_arrow_up, color: _accent, size: 18),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
