import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/phase4_service.dart';
import '../services/supabase_service.dart';

class NeighborhoodHubScreen extends StatefulWidget {
  const NeighborhoodHubScreen({super.key});

  @override
  State<NeighborhoodHubScreen> createState() => _NeighborhoodHubScreenState();
}

class _NeighborhoodHubScreenState extends State<NeighborhoodHubScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _danger = Color(0xFFFF6A76);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  final _service = Phase4Service();
  final _nameController = TextEditingController();
  final _mottoController = TextEditingController();

  bool _loading = true;
  bool _working = false;
  String? _error;

  Map<String, dynamic>? _neighborhood;
  List<Map<String, dynamic>> _raids = const [];
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _catalog = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _raidSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mottoController.dispose();
    _raidSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final primary = await _service.getPrimaryNeighborhood();
      final catalog = await _service.getNeighborhoods();

      List<Map<String, dynamic>> raids = const [];
      List<Map<String, dynamic>> members = const [];
      if (primary != null) {
        raids = await _service.getRaidBosses(primary['id'] as String);
        members = await _service.getNeighborhoodMembers(primary['id'] as String);
        _attachRaidRealtime(primary['id'] as String);
      }

      if (!mounted) return;
      setState(() {
        _neighborhood = primary;
        _catalog = catalog;
        _raids = raids;
        _members = members;
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

  void _attachRaidRealtime(String neighborhoodId) {
    _raidSub?.cancel();
    _raidSub = SupabaseService.client
        .from('raid_bosses')
        .stream(primaryKey: ['id'])
        .eq('neighborhood_id', neighborhoodId)
        .listen((rows) {
          if (!mounted) return;
          final raids = rows
              .where((r) => r['is_active'] == true)
              .map((r) => Map<String, dynamic>.from(r))
              .toList()
            ..sort((a, b) {
              final ad = DateTime.tryParse((a['deadline'] ?? '').toString());
              final bd = DateTime.tryParse((b['deadline'] ?? '').toString());
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1;
              if (bd == null) return -1;
              return ad.compareTo(bd);
            });
          setState(() => _raids = raids);
        });
  }

  Future<void> _join(String neighborhoodId) async {
    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await _service.joinNeighborhood(neighborhoodId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _found() async {
    final name = _nameController.text.trim();
    final motto = _mottoController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await _service.foundNeighborhood(
        name: name,
        motto: motto,
        type: 'interest',
      );
      _nameController.clear();
      _mottoController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _deadlineLabel(String? raw) {
    if (raw == null || raw.isEmpty) return 'No deadline';
    final deadline = DateTime.tryParse(raw);
    if (deadline == null) return 'No deadline';
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '${hours}h ${mins}m left';
  }

  @override
  Widget build(BuildContext context) {
    final n = _neighborhood;
    final hasNeighborhood = n != null;

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
                                context.go('/profile');
                              }
                            },
                            icon: const Icon(Icons.arrow_back, color: _textPrimary),
                          ),
                          const Expanded(
                            child: Text(
                              'Neighborhood Hub',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasNeighborhood)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF13263A), Color(0xFF0F1C2A)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🏘️ ${n['name']}', style: const TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text((n['motto'] as String?)?.isNotEmpty == true ? n['motto'] as String : 'Grind Together, Rise Together', style: const TextStyle(color: _textMuted)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: Text('Active Members: ${(n['active_members'] as num?)?.toInt() ?? 0}', style: const TextStyle(color: _textPrimary))),
                                  Text('Hours: ${((n['collective_hours'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}h', style: const TextStyle(color: _accent)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('Live raid sync enabled', style: TextStyle(color: _textMuted, fontSize: 12)),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1C2A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: const Text('You have not joined a neighborhood yet.', style: TextStyle(color: _textPrimary)),
                        ),
                      const SizedBox(height: 12),
                      if (hasNeighborhood) ...[
                        const Text('Raid Boss', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                        const SizedBox(height: 8),
                        ..._raids.map((r) {
                          final current = (r['current_progress'] as num?)?.toDouble() ?? 0;
                          final target = (r['target_value'] as num?)?.toDouble() ?? 1;
                          final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1C2A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['title'] as String? ?? 'Raid', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text('${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} ${(r['unit'] as String?) ?? ''}', style: const TextStyle(color: _textMuted)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(_deadlineLabel(r['deadline']?.toString()), style: const TextStyle(color: _textMuted, fontSize: 12)),
                                      const Spacer(),
                                      Text('Reward ${(r['reward_status'] as num?)?.toInt() ?? 0}⭐ / ${(r['reward_coins'] as num?)?.toInt() ?? 0}💰', style: const TextStyle(color: _accent, fontSize: 12)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(999),
                                    color: _accent,
                                    backgroundColor: Colors.white12,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        const Text('Top Members', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                        const SizedBox(height: 8),
                        ..._members.map((m) {
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
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF123143),
                                    child: Text((m['name'] as String).substring(0, 1), style: const TextStyle(color: _accent)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(m['name'] as String, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                                  ),
                                  Text('Lvl ${(m['level'] as num?)?.toInt() ?? 1}', style: const TextStyle(color: _textMuted)),
                                  const SizedBox(width: 8),
                                  Text((m['status_in_neighborhood'] as num?)?.toString() ?? '0', style: const TextStyle(color: _accent)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ] else ...[
                        const Text('Join a Neighborhood', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 20)),
                        const SizedBox(height: 8),
                        ..._catalog.take(4).map((row) {
                          final id = row['id'] as String;
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row['name'] as String? ?? 'Neighborhood', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                                        Text('${(row['active_members'] as num?)?.toInt() ?? 0} active members', style: const TextStyle(color: _textMuted, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: _working ? null : () => _join(id),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: _accent)),
                                    child: const Text('Join', style: TextStyle(color: _accent)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 10),
                        const Text('Found New Neighborhood', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: _textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Neighborhood name',
                            hintStyle: TextStyle(color: _textMuted),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accent)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mottoController,
                          style: const TextStyle(color: _textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Motto (optional)',
                            hintStyle: TextStyle(color: _textMuted),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accent)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _working ? null : _found,
                          style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: const Color(0xFF08111F)),
                          child: const Text('Create Neighborhood'),
                        ),
                      ],
                      if (_working) const LinearProgressIndicator(color: _accent),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: _danger)),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
