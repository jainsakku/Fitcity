import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../repositories/supabase_task_repository.dart';
import '../services/health_impact_service.dart';

class TaskPickerScreen extends StatefulWidget {
  const TaskPickerScreen({super.key});

  @override
  State<TaskPickerScreen> createState() => _TaskPickerScreenState();
}

class _TaskPickerScreenState extends State<TaskPickerScreen> {
  final _repo = SupabaseTaskRepository();
  final Map<String, int> _selected = {};
  static const _categoryOrder = ['cardio', 'strength', 'wellness', 'sports'];

  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _cardBg = Color(0xFF101828);
  static const _cardBorder = Color(0xFF1F2F3E);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  bool _loading = true;
  bool _saving = false;
  String? _message;
  List<Map<String, dynamic>> _catalog = const [];
  HealthImpactPreview _impact = const HealthImpactPreview(
    bodyAgeYears: 0,
    lifespanYears: 0,
    diseaseRiskPercent: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final catalog = await _repo.fetchCatalog();
      setState(() => _catalog = catalog);
      await _refreshImpact();
    } catch (e) {
      setState(() => _message = 'Failed to load tasks: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshImpact() async {
    final preview = await HealthImpactService.instance.calculate(
      catalog: _catalog,
      selectedFrequencies: _selected,
    );
    if (!mounted) return;
    setState(() => _impact = preview);
  }

  Future<void> _submit() async {
    if (_selected.length < 3 || _selected.length > 6) {
      setState(() {
        _message = 'Pick between 3 and 6 tasks.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final payload = _selected.entries
          .map((entry) => {
                'task_catalog_id': entry.key,
                'frequency': entry.value,
              })
          .toList();

      await _repo.createUserTasks(payload);

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _message = 'Failed to save selected tasks: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<Map<String, dynamic>> _tasksForCategory(String category) {
    return _catalog.where((t) => t['category'] == category).toList();
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'cardio':
        return 'Cardio';
      case 'strength':
        return 'Strength';
      case 'wellness':
        return 'Wellness';
      case 'sports':
        return 'Sports';
      default:
        return category;
    }
  }

  IconData _taskIcon(String category) {
    switch (category) {
      case 'cardio':
        return Icons.directions_run;
      case 'strength':
        return Icons.fitness_center;
      case 'wellness':
        return Icons.self_improvement;
      case 'sports':
        return Icons.sports_tennis;
      default:
        return Icons.task_alt;
    }
  }

  String _frequencyLabel(int frequency) {
    if (frequency == 7) return '7x/WEEK';
    return '${frequency}x/WEEK';
  }

  Widget _stars(double difficulty, bool selected) {
    final filled = difficulty.round().clamp(1, 5);
    return Row(
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            Icons.star,
            size: 14,
            color: i < filled
                ? (selected ? _accent : _textMuted.withValues(alpha: 0.6))
                : Colors.white24,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Stack(
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator(color: _accent))
              else
                ListView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 230),
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/character');
                            }
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: const Icon(Icons.arrow_back, color: _textPrimary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'FITCITY',
                                style: TextStyle(color: _accent, fontWeight: FontWeight.w700, letterSpacing: 1.3),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(4, (i) {
                                  final active = i == 2;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: i == 2 ? 46 : 28,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active ? _accent : const Color(0xFF3B4A5D),
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: active
                                          ? [BoxShadow(color: _accent.withValues(alpha: 0.6), blurRadius: 8)]
                                          : null,
                                    ),
                                  );
                                }),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text('Pick Your Tasks', style: TextStyle(color: _textPrimary, fontSize: 47 / 2, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose 3-6 tasks to start building your skyline',
                      style: TextStyle(color: _textMuted, fontSize: 18 / 2),
                    ),
                    const SizedBox(height: 22),
                    if (_catalog.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x22FF4D67),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x55FF4D67)),
                        ),
                        child: Text(
                          _message ??
                              'No tasks available. Check task_catalog seed data and read access, then tap refresh.',
                          style: const TextStyle(color: _textPrimary),
                        ),
                      ),
                    if (_catalog.isEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loadCatalog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent.withValues(alpha: 0.16),
                            foregroundColor: _accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Refresh Task Catalog'),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    ..._categoryOrder.map((category) {
                      final tasks = _tasksForCategory(category);
                      if (tasks.isEmpty) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _categoryTitle(category).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF17D8FF),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.4,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: tasks.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.74,
                              ),
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                final id = task['id'] as String;
                                final selected = _selected.containsKey(id);
                                final frequency = _selected[id] ?? 3;
                                final difficulty = (task['base_difficulty'] as num?)?.toDouble() ?? 3;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        _selected.remove(id);
                                      } else {
                                        _selected[id] = frequency;
                                      }
                                    });
                                    _refreshImpact();
                                  },
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: _cardBg,
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: selected ? _accent : _cardBorder,
                                        width: selected ? 2.2 : 1,
                                      ),
                                      boxShadow: selected
                                          ? [BoxShadow(color: _accent.withValues(alpha: 0.14), blurRadius: 16)]
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Icon(_taskIcon(category), size: 31, color: selected ? _accent : _textMuted),
                                            if (selected)
                                              Container(
                                                width: 34,
                                                height: 34,
                                                decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                                                child: const Icon(Icons.check, color: Color(0xFF00151B), size: 22),
                                              ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          task['name'] as String,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: _textPrimary, fontSize: 36 / 2, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 6),
                                        _stars(difficulty, selected),
                                        const SizedBox(height: 10),
                                        if (selected) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Text(
                                                'Frequency',
                                                style: TextStyle(color: _textMuted, fontSize: 11),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _accent.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  _frequencyLabel(frequency),
                                                  style: const TextStyle(
                                                    color: _accent,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              activeTrackColor: _accent,
                                              inactiveTrackColor: const Color(0xFF273445),
                                              thumbColor: _accent,
                                              overlayColor: _accent.withValues(alpha: 0.18),
                                              trackHeight: 4,
                                            ),
                                            child: Slider(
                                              value: frequency.toDouble(),
                                              min: 1,
                                              max: 7,
                                              divisions: 6,
                                              label: _frequencyLabel(frequency),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selected[id] = value.round();
                                                });
                                                _refreshImpact();
                                              },
                                            ),
                                          ),
                                        ] else
                                          const SizedBox(height: 26),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_message != null && _catalog.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x22FF4D67),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x55FF4D67)),
                          ),
                          child: Text(_message!, style: const TextStyle(color: _textPrimary)),
                        ),
                      ),
                  ],
                ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xCC1A2734),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 20)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(color: Color(0xFF10393C), shape: BoxShape.circle),
                            child: const Icon(Icons.query_stats, color: _accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('HEALTH COMBO IMPACT', style: TextStyle(color: _textMuted, letterSpacing: 1.5, fontWeight: FontWeight.w700, fontSize: 11)),
                                SizedBox(height: 4),
                                Text(
                                  '${_impact.bodyAgeLabel} | ${_impact.lifespanLabel}\n${_impact.diseaseRiskLabel}',
                                  style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 42, color: Colors.white12),
                          const SizedBox(width: 12),
                          Text('${_selected.length}\nselected', textAlign: TextAlign.right, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_saving) const LinearProgressIndicator(color: _accent),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)]),
                        ),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(62),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  color: Color(0xFF08111F),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward, color: Color(0xFF08111F)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
