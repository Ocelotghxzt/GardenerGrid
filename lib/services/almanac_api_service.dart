import 'dart:convert';
import 'package:http/http.dart' as http;

class AlmanacAstronomy {
  final DateTime date;
  final DateTime? sunrise;
  final DateTime? sunset;
  final int? daylightSeconds;

  const AlmanacAstronomy({
    required this.date,
    this.sunrise,
    this.sunset,
    this.daylightSeconds,
  });
}

class AlmanacFrostWindow {
  final DateTime? lastSpringFrost;
  final DateTime? firstFallFrost;

  const AlmanacFrostWindow({
    this.lastSpringFrost,
    this.firstFallFrost,
  });
}

class ResolvedGardenLocation {
  final String displayName;
  final String? countryCode;
  final String? postalCode;
  final double latitude;
  final double longitude;

  const ResolvedGardenLocation({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.countryCode,
    this.postalCode,
  });
}

class HardinessZoneEstimate {
  final int zone;
  final double averageAnnualExtremeMinC;
  final String basis;

  const HardinessZoneEstimate({
    required this.zone,
    required this.averageAnnualExtremeMinC,
    required this.basis,
  });
}

/// Open-data astronomy feed (no API key required).
/// Source: Open-Meteo forecast endpoint.
class AlmanacApiService {
  Future<ResolvedGardenLocation?> resolveLocation(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;

  final uri = Uri.parse(
    'https://geocoding-api.open-meteo.com/v1/search'
    '?name=${Uri.encodeQueryComponent(trimmed)}'
    '&count=1&language=en&format=json',
  );

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ??
      const <Map<String, dynamic>>[];
    if (results.isEmpty) return null;
    final top = results.first;
    final name = (top['name'] ?? '').toString().trim();
    final admin1 = (top['admin1'] ?? '').toString().trim();
    final country = (top['country'] ?? '').toString().trim();
    final postcodes = (top['postcodes'] as List?)?.map((v) => v.toString()).toList() ?? const <String>[];
    final displayParts = [name, admin1, country].where((p) => p.isNotEmpty).toList();

    return ResolvedGardenLocation(
    displayName: displayParts.join(', '),
    countryCode: (top['country_code'] ?? '').toString().trim().isEmpty
      ? null
      : (top['country_code'] ?? '').toString().trim(),
    postalCode: postcodes.isEmpty ? null : postcodes.first,
    latitude: (top['latitude'] as num).toDouble(),
    longitude: (top['longitude'] as num).toDouble(),
    );
  } catch (_) {
    return null;
  }
  }

  Future<HardinessZoneEstimate?> estimateHardinessZone({
  required double latitude,
  required double longitude,
  int startYear = 2020,
  int endYear = 2024,
  }) async {
  final uri = Uri.parse(
    'https://climate-api.open-meteo.com/v1/climate'
    '?latitude=$latitude'
    '&longitude=$longitude'
    '&start_date=$startYear-01-01'
    '&end_date=$endYear-12-31'
    '&models=MRI_AGCM3_2_S'
    '&daily=temperature_2m_min',
  );

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>?;
    if (daily == null) return null;
    final times = (daily['time'] as List?)?.cast<String>() ?? const <String>[];
    final mins = (daily['temperature_2m_min'] as List?) ?? const [];
    if (times.isEmpty || mins.isEmpty) return null;

    final yearlyMins = <int, double>{};
    for (int i = 0; i < times.length && i < mins.length; i++) {
    final d = DateTime.tryParse(times[i]);
    final t = mins[i] is num ? (mins[i] as num).toDouble() : null;
    if (d == null || t == null) continue;
    final current = yearlyMins[d.year];
    if (current == null || t < current) {
      yearlyMins[d.year] = t;
    }
    }
    if (yearlyMins.isEmpty) return null;

    final averageMin = yearlyMins.values.reduce((a, b) => a + b) / yearlyMins.length;
    final zone = _zoneFromAverageMinC(averageMin);
    return HardinessZoneEstimate(
    zone: zone,
    averageAnnualExtremeMinC: averageMin,
    basis: 'Estimated from recent annual extreme minimum temperatures ($startYear-$endYear) using open climate data.',
    );
  } catch (_) {
    return null;
  }
  }

  int _zoneFromAverageMinC(double minC) {
  const bounds = <(double, int)>[
    (-45.6, 2),
    (-40.0, 3),
    (-34.4, 4),
    (-28.9, 5),
    (-23.3, 6),
    (-17.8, 7),
    (-12.2, 8),
    (-6.7, 9),
    (-1.1, 10),
    (4.4, 11),
  ];
  for (final entry in bounds) {
    if (minC < entry.$1) return entry.$2 - 1;
  }
  return 12;
  }

  Future<AlmanacAstronomy?> fetchAstronomy({
    required double latitude,
    required double longitude,
    DateTime? date,
  }) async {
    final target = date ?? DateTime.now();
    final day =
        '${target.year.toString().padLeft(4, '0')}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&daily=sunrise,sunset,daylight_duration'
      '&timezone=auto'
      '&start_date=$day'
      '&end_date=$day',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final sunriseRaw = (daily['sunrise'] as List?)?.firstOrNull?.toString();
      final sunsetRaw = (daily['sunset'] as List?)?.firstOrNull?.toString();
      final daylightRaw = (daily['daylight_duration'] as List?)?.firstOrNull;

      return AlmanacAstronomy(
        date: target,
        sunrise: sunriseRaw != null ? DateTime.tryParse(sunriseRaw) : null,
        sunset: sunsetRaw != null ? DateTime.tryParse(sunsetRaw) : null,
        daylightSeconds: daylightRaw is num ? daylightRaw.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<AlmanacFrostWindow?> fetchFrostWindow({
  required double latitude,
  required double longitude,
  int? year,
  }) async {
  final y = year ?? DateTime.now().year;
  final start = '$y-01-01';
  final end = '$y-12-31';

  final uri = Uri.parse(
    'https://archive-api.open-meteo.com/v1/archive'
    '?latitude=$latitude'
    '&longitude=$longitude'
    '&daily=temperature_2m_min'
    '&timezone=auto'
    '&start_date=$start'
    '&end_date=$end',
  );

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>?;
    if (daily == null) return null;

    final times = (daily['time'] as List?)?.cast<String>() ?? const [];
    final mins = (daily['temperature_2m_min'] as List?) ?? const [];
    if (times.isEmpty || mins.isEmpty) return null;

    DateTime? lastSpring;
    DateTime? firstFall;

    for (int i = 0; i < times.length && i < mins.length; i++) {
    final d = DateTime.tryParse(times[i]);
    final t = mins[i] is num ? (mins[i] as num).toDouble() : null;
    if (d == null || t == null) continue;

    final isFrost = t <= 0.0;
    if (!isFrost) continue;

    if (d.month <= 6) {
      if (lastSpring == null || d.isAfter(lastSpring)) {
      lastSpring = d;
      }
    } else {
      if (firstFall == null || d.isBefore(firstFall)) {
      firstFall = d;
      }
    }
    }

    return AlmanacFrostWindow(
    lastSpringFrost: lastSpring,
    firstFallFrost: firstFall,
    );
  } catch (_) {
    return null;
  }
  }
}
