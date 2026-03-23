import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({super.key, this.task});

  final Map<String, dynamic>? task;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  static const _bgTop = Color(0xFF04181C);
  static const _bgBottom = Color(0xFF040814);
  static const _accent = Color(0xFF1DF7D4);
  static const _textPrimary = Color(0xFFEAF2FF);
  static const _textMuted = Color(0xFF8A9AAC);

  Timer? _ticker;
  late int _remainingSeconds;
  bool _running = true;

  int get _totalSeconds {
    final durationMin = (widget.task?['duration_min'] as num?)?.toInt() ?? 30;
    return (durationMin * 60).clamp(60, 7200);
  }

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _totalSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
          _running = false;
        });
        _ticker?.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _clockLabel() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final taskName = widget.task?['task_name'] as String? ?? 'Workout Session';
    final progress = 1 - (_remainingSeconds / _totalSeconds);

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
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(false),
                    icon: const Icon(Icons.arrow_back, color: _textPrimary),
                  ),
                  const Spacer(),
                  const Text('LIVE SESSION', style: TextStyle(color: _accent, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 18),
              Text(taskName, textAlign: TextAlign.center, style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w700, fontSize: 26)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1C2A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text('TIME LEFT', style: TextStyle(color: _textMuted, letterSpacing: 1.2)),
                    const SizedBox(height: 10),
                    Text(_clockLabel(), style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.w800, fontSize: 46)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      color: _accent,
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _running ? 'Session in progress. Keep moving.' : 'Timer complete. You can log this workout now.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(colors: [Color(0xFF1BE5C8), Color(0xFF16D4F4)]),
                ),
                child: ElevatedButton.icon(
                  onPressed: _running
                      ? () => setState(() => _running = false)
                      : () => setState(() => _running = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow, color: const Color(0xFF08111F)),
                  label: Text(
                    _running ? 'Pause Timer' : 'Resume Timer',
                    style: const TextStyle(color: Color(0xFF08111F), fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.pop(true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: _accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Complete Workout Now', style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
