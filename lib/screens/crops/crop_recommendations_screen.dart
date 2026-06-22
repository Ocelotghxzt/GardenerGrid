import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/crop_provider.dart';
import '../../providers/soil_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class CropRecommendationsScreen extends StatelessWidget {
  const CropRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final crops = context.watch<CropProvider>();
    final soil = context.watch<SoilProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crops'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Custom Crop',
            onPressed: () => context.push('/crops/add'),
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Recommended'),
                Tab(text: 'My Crops'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Recommended
                  crops.recommendations.isEmpty
                      ? EmptyState(
                          icon: Icons.eco,
                          title: 'No Recommendations Yet',
                          subtitle: 'Add a soil sample to get personalized crop recommendations.',
                          actionLabel: 'Add Soil Sample',
                          onAction: () => context.push('/soil/input'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: crops.recommendations.length,
                          itemBuilder: (ctx, i) {
                            final cs = crops.recommendations[i];
                            return _CropCard(
                              name: cs.crop.name,
                              category: cs.crop.category,
                              score: cs.score,
                              phRange: '${cs.crop.phMin} – ${cs.crop.phMax}',
                              wateringFrequency: cs.crop.wateringFrequency,
                              onTap: () =>
                                  context.push('/crops/detail/${cs.crop.id}'),
                            );
                          },
                        ),

                  // My custom crops
                  crops.customCrops.isEmpty
                      ? EmptyState(
                          icon: Icons.add_circle_outline,
                          title: 'No Custom Crops',
                          subtitle: 'Add crops that aren\'t in the default list.',
                          actionLabel: 'Add Crop',
                          onAction: () => context.push('/crops/add'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: crops.customCrops.length,
                          itemBuilder: (ctx, i) {
                            final c = crops.customCrops[i];
                            return _CropCard(
                              name: c.name,
                              category: c.category,
                              score: soil.latestSample != null
                                  ? c.compatibilityScore(
                                      soil.latestSample!.ph,
                                      soil.latestSample!.nitrogen,
                                      soil.latestSample!.phosphorus,
                                      soil.latestSample!.potassium,
                                    )
                                  : null,
                              phRange: '${c.phMin} – ${c.phMax}',
                              wateringFrequency: c.wateringFrequency,
                              isCustom: true,
                              onTap: () =>
                                  context.push('/crops/detail/${c.id}'),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final String name;
  final String category;
  final double? score;
  final String phRange;
  final String wateringFrequency;
  final bool isCustom;
  final VoidCallback onTap;

  const _CropCard({
    required this.name,
    required this.category,
    this.score,
    required this.phRange,
    required this.wateringFrequency,
    this.isCustom = false,
    required this.onTap,
  });

  Color get _scoreColor {
    if (score == null) return Colors.grey;
    if (score! >= 75) return AppTheme.primaryLight;
    if (score! >= 50) return AppTheme.accent;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.eco, color: AppTheme.primary),
        ),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (isCustom) ...[
              const SizedBox(width: 6),
              const Chip(
                label: Text('Custom', style: TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
        subtitle: Text('$category · pH $phRange · $wateringFrequency watering'),
        trailing: score != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${score!.toInt()}%',
                      style: TextStyle(
                          color: _scoreColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  const Text('match', style: TextStyle(fontSize: 10)),
                ],
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
