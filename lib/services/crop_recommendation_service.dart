import '../models/crop.dart';
import '../models/soil_sample.dart';

class CropRecommendationService {
  List<CropScore> recommend(SoilSample sample, List<Crop> allCrops) {
    final scored = allCrops
        .map((c) => CropScore(
              crop: c,
              score: c.compatibilityScore(
                sample.ph,
                sample.nitrogen,
                sample.phosphorus,
                sample.potassium,
              ),
            ))
        .where((cs) => cs.score >= 40)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }
}

class CropScore {
  final Crop crop;
  final double score;
  const CropScore({required this.crop, required this.score});
}
