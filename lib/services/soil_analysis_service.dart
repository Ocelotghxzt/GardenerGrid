import '../models/soil_sample.dart';

class SoilAnalysisService {
  // Analyzes a soil sample locally using USDA-aligned thresholds.
  // When a backend ML service is added later, call it here instead.
  SoilSample analyze(SoilSample sample) {
    final deficiencies = <String>[];
    final amendments = <String>[];
    int score = 100;

    // pH
    if (sample.ph < 5.5) {
      deficiencies.add('Low pH (acidic)');
      amendments.add('Apply agricultural lime to raise pH');
      score -= 20;
    } else if (sample.ph > 7.5) {
      deficiencies.add('High pH (alkaline)');
      amendments.add('Apply elemental sulfur to lower pH');
      score -= 15;
    }

    // Nitrogen (ppm thresholds)
    if (sample.nitrogen < 20) {
      deficiencies.add('Low Nitrogen');
      amendments.add('Apply nitrogen-rich fertilizer (urea or blood meal)');
      score -= 20;
    }

    // Phosphorus
    if (sample.phosphorus < 15) {
      deficiencies.add('Low Phosphorus');
      amendments.add('Apply superphosphate or bone meal');
      score -= 15;
    }

    // Potassium
    if (sample.potassium < 100) {
      deficiencies.add('Low Potassium');
      amendments.add('Apply potash (muriate of potash)');
      score -= 15;
    }

    // Organic matter
    if (sample.organicMatter < 2.0) {
      deficiencies.add('Low Organic Matter');
      amendments.add('Add compost or aged manure');
      score -= 10;
    }

    // Moisture
    if (sample.moisture < 20) {
      deficiencies.add('Low Soil Moisture');
      amendments.add('Increase irrigation frequency');
      score -= 10;
    } else if (sample.moisture > 80) {
      deficiencies.add('Excess Moisture');
      amendments.add('Improve drainage or reduce irrigation');
      score -= 10;
    }

    return SoilSample(
      id: sample.id,
      fieldId: sample.fieldId,
      timestamp: sample.timestamp,
      ph: sample.ph,
      nitrogen: sample.nitrogen,
      phosphorus: sample.phosphorus,
      potassium: sample.potassium,
      moisture: sample.moisture,
      electricalConductivity: sample.electricalConductivity,
      organicMatter: sample.organicMatter,
      texture: sample.texture,
      notes: sample.notes,
      source: sample.source,
      healthScore: score.clamp(0, 100),
      deficiencies: deficiencies,
      amendments: amendments,
    );
  }
}
