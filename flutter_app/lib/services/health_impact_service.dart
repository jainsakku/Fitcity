import 'dart:convert';

import 'package:flutter/services.dart';

class HealthImpactPreview {
  const HealthImpactPreview({
    required this.bodyAgeYears,
    required this.lifespanYears,
    required this.diseaseRiskPercent,
  });

  final double bodyAgeYears;
  final double lifespanYears;
  final double diseaseRiskPercent;

  String get bodyAgeLabel => 'Body Age ${bodyAgeYears >= 0 ? '+' : ''}${bodyAgeYears.toStringAsFixed(1)}yr';
  String get lifespanLabel => 'Lifespan ${lifespanYears >= 0 ? '+' : ''}${lifespanYears.toStringAsFixed(1)}yr';
  String get diseaseRiskLabel => 'Disease Risk ${diseaseRiskPercent >= 0 ? '+' : ''}${diseaseRiskPercent.toStringAsFixed(1)}%';
}

class HealthImpactService {
  HealthImpactService._();

  static final HealthImpactService instance = HealthImpactService._();

  static const String _assetPath = 'assets/data/health_impact_lookup.json';

  bool _loaded = false;
  late final double _bodyAgePerPoint;
  late final double _lifespanPerPoint;
  late final double _diseaseRiskPerPoint;
  final Map<String, Map<String, double>> _categoryMultiplier = {};

  Future<void> _ensureLoaded() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final base = decoded['base'] as Map<String, dynamic>? ?? const {};
    _bodyAgePerPoint = (base['body_age_per_point'] as num?)?.toDouble() ?? -0.02;
    _lifespanPerPoint = (base['lifespan_per_point'] as num?)?.toDouble() ?? 0.015;
    _diseaseRiskPerPoint = (base['disease_risk_per_point'] as num?)?.toDouble() ?? -0.16;

    final categories = decoded['category_multipliers'] as Map<String, dynamic>? ?? const {};
    for (final entry in categories.entries) {
      final values = entry.value as Map<String, dynamic>? ?? const {};
      _categoryMultiplier[entry.key] = {
        'body_age': (values['body_age'] as num?)?.toDouble() ?? 1,
        'lifespan': (values['lifespan'] as num?)?.toDouble() ?? 1,
        'disease_risk': (values['disease_risk'] as num?)?.toDouble() ?? 1,
      };
    }

    _loaded = true;
  }

  Future<HealthImpactPreview> calculate({
    required List<Map<String, dynamic>> catalog,
    required Map<String, int> selectedFrequencies,
  }) async {
    await _ensureLoaded();

    if (selectedFrequencies.isEmpty || catalog.isEmpty) {
      return const HealthImpactPreview(
        bodyAgeYears: 0,
        lifespanYears: 0,
        diseaseRiskPercent: 0,
      );
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final task in catalog) {
      final id = task['id'];
      if (id is String) {
        byId[id] = task;
      }
    }

    double bodyAge = 0;
    double lifespan = 0;
    double diseaseRisk = 0;

    for (final entry in selectedFrequencies.entries) {
      final task = byId[entry.key];
      if (task == null) continue;

      final frequency = entry.value.clamp(1, 7);
      final difficulty = (task['base_difficulty'] as num?)?.toDouble() ?? 3;
      final category = (task['category'] as String?) ?? 'wellness';
      final multiplier = _categoryMultiplier[category] ?? const {
        'body_age': 1.0,
        'lifespan': 1.0,
        'disease_risk': 1.0,
      };

      final points = frequency * difficulty;
      bodyAge += points * _bodyAgePerPoint * (multiplier['body_age'] ?? 1);
      lifespan += points * _lifespanPerPoint * (multiplier['lifespan'] ?? 1);
      diseaseRisk += points * _diseaseRiskPerPoint * (multiplier['disease_risk'] ?? 1);
    }

    return HealthImpactPreview(
      bodyAgeYears: bodyAge,
      lifespanYears: lifespan,
      diseaseRiskPercent: diseaseRisk,
    );
  }
}
