import 'package:flutter/material.dart';
import '../services/almanac_api_service.dart';

class AlmanacProvider with ChangeNotifier {
  final AlmanacApiService _api = AlmanacApiService();

  AlmanacAstronomy? _astronomy;
  AlmanacFrostWindow? _frostWindow;
  bool _loadingAstronomy = false;

  AlmanacAstronomy? get astronomy => _astronomy;
  AlmanacFrostWindow? get frostWindow => _frostWindow;
  bool get loadingAstronomy => _loadingAstronomy;

  Future<void> loadAstronomy({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) async {
    _loadingAstronomy = true;
    notifyListeners();

    _astronomy = await _api.fetchAstronomy(
      latitude: latitude,
      longitude: longitude,
      date: date,
    );

    _frostWindow = await _api.fetchFrostWindow(
      latitude: latitude,
      longitude: longitude,
      year: (date ?? DateTime.now()).year,
    );

    _loadingAstronomy = false;
    notifyListeners();
  }

  /// Returns a canonical moon phase date marker based on cycle position.
  /// The UI uses this marker only to derive icon/name bins.
  DateTime getMoonPhase(DateTime date) {
    const synodicMonth = 29.53058867;
    final referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final diffDays =
        date.toUtc().difference(referenceNewMoon).inMinutes / 1440.0;
    final age = diffDays % synodicMonth;
    final normalizedAge = age < 0 ? age + synodicMonth : age;
    return referenceNewMoon.add(Duration(minutes: (normalizedAge * 1440).round()));
  }

  String getMoonPhaseName(DateTime phaseMarker) {
    final age = _phaseAgeDays(phaseMarker);
    if (age < 1.84566) return 'New Moon';
    if (age < 5.53699) return 'Waxing Crescent';
    if (age < 9.22831) return 'First Quarter';
    if (age < 12.91963) return 'Waxing Gibbous';
    if (age < 16.61096) return 'Full Moon';
    if (age < 20.30228) return 'Waning Gibbous';
    if (age < 23.99361) return 'Last Quarter';
    if (age < 27.68493) return 'Waning Crescent';
    return 'New Moon';
  }

  IconData getMoonPhaseIcon(DateTime phaseMarker) {
    final age = _phaseAgeDays(phaseMarker);
    if (age < 1.84566) return Icons.brightness_2;
    if (age < 5.53699) return Icons.brightness_3;
    if (age < 9.22831) return Icons.brightness_4;
    if (age < 12.91963) return Icons.brightness_5;
    if (age < 16.61096) return Icons.brightness_7;
    if (age < 20.30228) return Icons.brightness_6;
    if (age < 23.99361) return Icons.brightness_4;
    if (age < 27.68493) return Icons.brightness_3;
    return Icons.brightness_2;
  }

  List<String> getSeasonalTips(int month, int zone) {
    final season = getSeasonName(month);
    switch (season) {
      case 'Spring':
        return [
          'Start cool-season crops indoors or direct sow based on soil temperature.',
          'Test soil and top-dress with compost before heavy planting.',
          'Watch frost alerts for Zone $zone and protect tender seedlings.',
        ];
      case 'Summer':
        return [
          'Mulch deeply to retain moisture and reduce heat stress.',
          'Water early morning and prioritize deep, infrequent irrigation.',
          'Succession plant fast crops every 2-3 weeks for continuous harvest.',
        ];
      case 'Fall':
        return [
          'Plant cover crops after final harvest to protect and enrich soil.',
          'Sow garlic and cold-tolerant greens in late fall windows.',
          'Track first frost in Zone $zone for final harvest timing.',
        ];
      default:
        return [
          'Plan rotations and order seeds based on last season notes.',
          'Maintain tools, sharpen blades, and sanitize propagation trays.',
          'Use winter for pruning and soil amendment planning.',
        ];
    }
  }

  List<String> getPlantsForMonth(int month, int zone) {
    final spring = [
      'Peas',
      'Spinach',
      'Lettuce',
      'Radish',
      'Onion sets',
      'Kale',
    ];
    final summer = [
      'Tomato',
      'Pepper',
      'Basil',
      'Cucumber',
      'Bean',
      'Squash',
    ];
    final fall = [
      'Garlic',
      'Carrot',
      'Beet',
      'Turnip',
      'Arugula',
      'Cilantro',
    ];
    final winter = [
      'Microgreens',
      'Indoor herbs',
      'Sprouts',
      'Greenhouse lettuce',
    ];

    if (month >= 3 && month <= 5) return spring;
    if (month >= 6 && month <= 8) return summer;
    if (month >= 9 && month <= 11) return fall;

    if (zone <= 6) return winter;
    return [...winter, 'Fava beans (mild winter)', 'Calendula (mild winter)'];
  }

  DateTime firstFrost(int zone, {int? year}) {
    if (_frostWindow?.firstFallFrost != null) {
      return _frostWindow!.firstFallFrost!;
    }

    final y = year ?? DateTime.now().year;
    final dayByZone = <int, DateTime>{
      3: DateTime(y, 9, 20),
      4: DateTime(y, 9, 28),
      5: DateTime(y, 10, 10),
      6: DateTime(y, 10, 22),
      7: DateTime(y, 11, 5),
      8: DateTime(y, 11, 20),
      9: DateTime(y, 12, 10),
      10: DateTime(y, 12, 31),
    };
    return dayByZone[zone] ?? DateTime(y, 10, 15);
  }

  DateTime lastFrost(int zone, {int? year}) {
    if (_frostWindow?.lastSpringFrost != null) {
      return _frostWindow!.lastSpringFrost!;
    }

    final y = year ?? DateTime.now().year;
    final dayByZone = <int, DateTime>{
      3: DateTime(y, 5, 25),
      4: DateTime(y, 5, 15),
      5: DateTime(y, 5, 5),
      6: DateTime(y, 4, 20),
      7: DateTime(y, 4, 5),
      8: DateTime(y, 3, 15),
      9: DateTime(y, 2, 15),
      10: DateTime(y, 1, 20),
    };
    return dayByZone[zone] ?? DateTime(y, 4, 25);
  }

  String getSeasonName(int month) {
    if (month >= 3 && month <= 5) return 'Spring';
    if (month >= 6 && month <= 8) return 'Summer';
    if (month >= 9 && month <= 11) return 'Fall';
    return 'Winter';
  }

  int _phaseAgeDays(DateTime phaseMarker) {
    final cycle = phaseMarker.difference(DateTime.utc(2000, 1, 6, 18, 14));
    final days = cycle.inMinutes / 1440.0;
    final age = days % 29.53058867;
    final normalized = age < 0 ? age + 29.53058867 : age;
    return normalized.round();
  }
}
