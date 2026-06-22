import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crop_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/soil_provider.dart';
import '../../models/crop.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class CropDetailScreen extends StatefulWidget {
  final String cropId;
  const CropDetailScreen({super.key, required this.cropId});
  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final crop = _findCrop();
      if (crop != null) {
        context.read<MarketProvider>().fetchPrices(crop.name);
      }
    });
  }

  Crop? _findCrop() {
    final crops = context.read<CropProvider>();
    try {
      return crops.allCrops.firstWhere((c) => c.id == widget.cropId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final crop = _findCrop();
    if (crop == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crop Detail')),
        body: const Center(child: Text('Crop not found')),
      );
    }

    final soil = context.watch<SoilProvider>().latestSample;
    final market = context.watch<MarketProvider>();
    final score = soil != null
        ? crop.compatibilityScore(
            soil.ph, soil.nitrogen, soil.phosphorus, soil.potassium)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(crop.name),
        actions: crop.isCustom
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final auth = context.read<AuthProvider>();
                    final cropsProvider = context.read<CropProvider>();
                    final nav = GoRouter.of(context);
                    final uid = auth.userId!;
                    await cropsProvider.deleteCustomCrop(uid, crop.id);
                    if (!mounted) return;
                    nav.pop();
                  },
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: AppTheme.primary,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.eco, color: Colors.white, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(crop.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        Text(crop.category,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                        if (score != null)
                          Text('${score.toInt()}% soil match',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Soil requirements
          const Text('Soil Requirements',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              StatCard(label: 'pH Range', value: '${crop.phMin}–${crop.phMax}',
                  icon: Icons.science),
              StatCard(label: 'Nitrogen Need', value: '${crop.nitrogenNeed.toInt()}',
                  unit: 'ppm', icon: Icons.bubble_chart, color: Colors.blue),
              StatCard(label: 'Phosphorus Need', value: '${crop.phosphorusNeed.toInt()}',
                  unit: 'ppm', icon: Icons.bubble_chart, color: Colors.orange),
              StatCard(label: 'Potassium Need', value: '${crop.potassiumNeed.toInt()}',
                  unit: 'ppm', icon: Icons.bubble_chart, color: Colors.purple),
            ],
          ),
          const SizedBox(height: 16),

          // Growing conditions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Growing Conditions',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _InfoRow(Icons.thermostat,
                      'Temperature: ${crop.tempMinF.toInt()}°F – ${crop.tempMaxF.toInt()}°F'),
                  _InfoRow(Icons.water_drop, 'Watering: ${crop.wateringFrequency}'),
                  if (crop.plantingWindow != null)
                    _InfoRow(Icons.calendar_month, 'Plant: ${crop.plantingWindow}'),
                  if (crop.harvestWindow != null)
                    _InfoRow(Icons.agriculture, 'Harvest: ${crop.harvestWindow}'),
                  if (crop.companionPlants.isNotEmpty)
                    _InfoRow(Icons.eco,
                        'Companions: ${crop.companionPlants.join(", ")}'),
                  if (crop.pestRisks.isNotEmpty)
                    _InfoRow(Icons.bug_report,
                        'Pest risks: ${crop.pestRisks.join(", ")}',
                        color: AppTheme.error),
                  if (crop.notes != null && crop.notes!.isNotEmpty)
                    _InfoRow(Icons.notes, crop.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Market prices
          const Text('Market Prices',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          if (market.loading)
            const Center(child: CircularProgressIndicator())
          else if (market.pricesFor(crop.name).isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No market data available for ${crop.name} right now.',
                    style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ...market.pricesFor(crop.name).take(3).map(
                  (p) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.trending_up,
                          color: AppTheme.primary),
                      title: Text('\$${p.pricePerUnit.toStringAsFixed(2)} / ${p.unit}'),
                      subtitle: Text(
                          '${p.marketName ?? p.source} · ${p.region}'),
                      trailing: Text(p.source,
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoRow(this.icon, this.text, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color ?? Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(child: Text(text,
                style: TextStyle(color: color))),
          ],
        ),
      );
}
