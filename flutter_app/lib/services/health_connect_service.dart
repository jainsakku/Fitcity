import 'dart:io';

import 'package:health/health.dart';

class HealthConnectService {
  Future<Map<String, dynamic>?> collectVerificationEvidence({
    required int durationMinutes,
  }) async {
    try {
      final health = Health();
      await health.configure();

      if (Platform.isAndroid) {
        final available = await health.isHealthConnectAvailable();
        if (!available) {
          return null;
        }
      }

      final types = <HealthDataType>[
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.WORKOUT,
      ];

      final hasPermissions = await health.hasPermissions(types) ?? false;
      final authorized = hasPermissions || await health.requestAuthorization(types);
      if (!authorized) {
        return null;
      }

      final end = DateTime.now();
      final start = end.subtract(Duration(minutes: durationMinutes + 20));
      final points = await health.getHealthDataFromTypes(
        types: types,
        startTime: start,
        endTime: end,
      );

      num steps = 0;
      num calories = 0;
      num distanceKm = 0;
      int workoutEvents = 0;

      for (final point in points) {
        final value = point.value;
        if (value is! NumericHealthValue) {
          if (point.type == HealthDataType.WORKOUT) {
            workoutEvents += 1;
          }
          continue;
        }

        switch (point.type) {
          case HealthDataType.STEPS:
            steps += value.numericValue;
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            calories += value.numericValue;
            break;
          case HealthDataType.DISTANCE_WALKING_RUNNING:
            distanceKm += value.numericValue / 1000;
            break;
          case HealthDataType.WORKOUT:
            workoutEvents += 1;
            break;
          default:
            break;
        }
      }

      if (steps <= 0 && calories <= 0 && distanceKm <= 0 && workoutEvents <= 0) {
        return null;
      }

      return {
        'verificationType': 'auto',
        'healthConnectData': {
          'windowStart': start.toIso8601String(),
          'windowEnd': end.toIso8601String(),
          'steps': steps.round(),
          'activeCalories': calories.toDouble(),
          'distanceKm': double.parse(distanceKm.toStringAsFixed(3)),
          'workoutEvents': workoutEvents,
        },
      };
    } catch (_) {
      return null;
    }
  }
}
