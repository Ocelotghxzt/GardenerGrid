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

/// Open-data astronomy feed (no API key required).
/// Source: Open-Meteo forecast endpoint.
class AlmanacApiService {
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
