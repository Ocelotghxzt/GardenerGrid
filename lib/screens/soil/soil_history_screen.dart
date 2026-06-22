import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/soil_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../models/soil_sample.dart';

class SoilHistoryScreen extends StatelessWidget {
  const SoilHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final soil = context.watch<SoilProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Soil History')),
      body: soil.history.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'No Samples Yet',
              subtitle: 'Add your first soil sample to see history and trends.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PhTrendChart(samples: soil.history),
                const SizedBox(height: 20),
                _NpkTrendChart(samples: soil.history),
                const SizedBox(height: 20),
                const Text('Sample Log',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...soil.history.map((s) => _SampleTile(sample: s)),
              ],
            ),
    );
  }
}

class _PhTrendChart extends StatelessWidget {
  final List<SoilSample> samples;
  const _PhTrendChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    final reversed = samples.reversed.toList();
    final latest = reversed.last.ph;
    final min = reversed.map((s) => s.ph).reduce((a, b) => a < b ? a : b);
    final max = reversed.map((s) => s.ph).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('pH Trend',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _MetricTrendSummary(
              label: 'Current pH',
              value: latest,
              min: 0,
              max: 14,
              color: AppTheme.primary,
              unit: '',
            ),
            const SizedBox(height: 12),
            Text(
              'Range: ${min.toStringAsFixed(1)} to ${max.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...reversed.take(6).map(
              (sample) => _TrendRow(
                label: DateFormat('M/d').format(sample.timestamp),
                value: sample.ph,
                min: 0,
                max: 14,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NpkTrendChart extends StatelessWidget {
  final List<SoilSample> samples;
  const _NpkTrendChart({required this.samples});

  @override
  Widget build(BuildContext context) {
    final reversed = samples.reversed.toList();
    final maxValue = reversed
      .map((s) => [s.nitrogen, s.phosphorus, s.potassium].reduce((a, b) => a > b ? a : b))
      .reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('NPK Trend',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                _Legend(color: Colors.blue, label: 'N'),
                const SizedBox(width: 10),
                _Legend(color: Colors.orange, label: 'P'),
                const SizedBox(width: 10),
                _Legend(color: Colors.purple, label: 'K'),
              ],
            ),
            const SizedBox(height: 16),
            ...reversed.take(6).map(
              (sample) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('M/d').format(sample.timestamp),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    _TrendRow(
                      label: 'N',
                      value: sample.nitrogen,
                      min: 0,
                      max: maxValue <= 0 ? 1 : maxValue,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 4),
                    _TrendRow(
                      label: 'P',
                      value: sample.phosphorus,
                      min: 0,
                      max: maxValue <= 0 ? 1 : maxValue,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 4),
                    _TrendRow(
                      label: 'K',
                      value: sample.potassium,
                      min: 0,
                      max: maxValue <= 0 ? 1 : maxValue,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTrendSummary extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color color;
  final String unit;

  const _MetricTrendSummary({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = ((value - min) / ((max - min) <= 0 ? 1 : (max - min)))
        .clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(1)}$unit'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Color color;

  const _TrendRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = ((value - min) / ((max - min) <= 0 ? 1 : (max - min)))
        .clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(width: 12, height: 3, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _SampleTile extends StatelessWidget {
  final SoilSample sample;
  const _SampleTile({required this.sample});

  @override
  Widget build(BuildContext context) {
    final score = sample.healthScore;
    final scoreColor = score == null
        ? Colors.grey
        : score >= 75
            ? AppTheme.primaryLight
            : score >= 50
                ? AppTheme.accent
                : AppTheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: score != null
            ? CircleAvatar(
            backgroundColor: scoreColor.withValues(alpha: 0.15),
                child: Text('$score',
                    style: TextStyle(
                        color: scoreColor, fontWeight: FontWeight.w700)),
              )
            : const Icon(Icons.science),
        title: Text(DateFormat('MMM d, y – h:mm a').format(sample.timestamp)),
        subtitle: Text(
            'pH ${sample.ph} · N ${sample.nitrogen} · P ${sample.phosphorus} · K ${sample.potassium}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Moisture: ${sample.moisture}% · EC: ${sample.electricalConductivity} mS/cm'),
                Text('Organic Matter: ${sample.organicMatter}% · Texture: ${sample.texture ?? "N/A"}'),
                Text('Source: ${sample.source.name}'),
                if (sample.deficiencies.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('Deficiencies:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...sample.deficiencies.map((d) => Text('• $d')),
                ],
                if (sample.amendments.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('Amendments:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...sample.amendments.map((a) => Text('• $a')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
