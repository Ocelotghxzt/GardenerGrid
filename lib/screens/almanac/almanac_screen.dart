import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/almanac_provider.dart';
import '../../theme/app_theme.dart';

class AlmanacScreen extends StatefulWidget {
  const AlmanacScreen({super.key});

  @override
  State<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends State<AlmanacScreen> {
  int _zone = 5;
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _timeFormat = DateFormat('h:mm a');
  String? _locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAstronomy();
    });
  }

  Future<void> _loadAstronomy() async {
    final provider = context.read<AlmanacProvider>();
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission granted = permission;
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }

      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationError = 'Location denied. Showing local almanac only.';
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      await provider.loadAstronomy(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (mounted) {
        setState(() {
          _locationError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationError = 'Could not load live astronomy. Using offline data.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final almanac = context.watch<AlmanacProvider>();
    final now = DateTime.now();
    final phase = almanac.getMoonPhase(now);
    final seasonTips = almanac.getSeasonalTips(now.month, _zone);
    final plants = almanac.getPlantsForMonth(now.month, _zone);
    final firstFrost = almanac.firstFrost(_zone);
    final lastFrost = almanac.lastFrost(_zone);
    final hasLiveFrost = almanac.frostWindow?.firstFallFrost != null ||
      almanac.frostWindow?.lastSpringFrost != null;
    final astronomy = almanac.astronomy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gardening Almanac'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune),
            itemBuilder: (context) => [
              for (int z = 3; z <= 10; z++)
                PopupMenuItem(
                  value: z,
                  child: Text('Zone $z'),
                ),
            ],
            onSelected: (v) => setState(() => _zone = v),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAstronomy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_locationError != null)
              Card(
                color: Colors.amber.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_locationError!),
                ),
              ),
            if (almanac.loadingAstronomy)
              const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          almanac.getMoonPhaseIcon(phase),
                          size: 48,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                almanac.getMoonPhaseName(phase),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Current Moon Phase',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _moonPhaseCalendar(almanac, now),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (astronomy != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Astronomy (Open-Meteo)',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      if (astronomy.sunrise != null)
                        _iconLine(
                          Icons.wb_sunny_outlined,
                          'Sunrise: ${_timeFormat.format(astronomy.sunrise!)}',
                        ),
                      if (astronomy.sunset != null)
                        _iconLine(
                          Icons.nightlight_round,
                          'Sunset: ${_timeFormat.format(astronomy.sunset!)}',
                        ),
                      if (astronomy.daylightSeconds != null)
                        _iconLine(
                          Icons.timelapse,
                          'Daylight: ${_formatDuration(astronomy.daylightSeconds!)}',
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frost Dates (Zone $_zone)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLiveFrost
                          ? 'Based on local historical minimum temperatures (open climate data).'
                          : 'Estimated by hardiness zone.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _iconLine(Icons.ac_unit, 'Last Frost: ${_dateFormat.format(lastFrost)}'),
                    _iconLine(Icons.snowing, 'First Frost: ${_dateFormat.format(firstFrost)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What to Plant This Month',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...plants.map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _iconLine(Icons.eco, p),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seasonal Tips',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    ...seasonTips.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _iconLine(Icons.lightbulb_outline, tip),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _moonPhaseCalendar(AlmanacProvider almanac, DateTime now) {
    final days = List.generate(14, (i) => DateTime(now.year, now.month, now.day + i));
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final phase = almanac.getMoonPhase(day);
          final isToday = index == 0;
          return Container(
            width: 52,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isToday ? AppTheme.primary.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(12),
              border: isToday ? Border.all(color: AppTheme.primary, width: 2) : null,
            ),
            child: Column(
              children: [
                Icon(
                  almanac.getMoonPhaseIcon(phase),
                  size: 20,
                  color: isToday ? AppTheme.primary : Colors.grey[600],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEE').format(day),
                  style: TextStyle(
                    fontSize: 10,
                    color: isToday ? AppTheme.primary : Colors.grey[600],
                  ),
                ),
                Text(
                  day.day.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isToday ? AppTheme.primary : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _iconLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    return '${hours}h ${mins}m';
  }
}
