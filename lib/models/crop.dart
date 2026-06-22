import 'package:cloud_firestore/cloud_firestore.dart';

class Crop {
  final String id;
  final String name;
  final String category;
  final double phMin;
  final double phMax;
  final double nitrogenNeed;
  final double phosphorusNeed;
  final double potassiumNeed;
  final double tempMinF;
  final double tempMaxF;
  final String wateringFrequency;
  final String? plantingWindow;
  final String? harvestWindow;
  final List<String> companionPlants;
  final List<String> pestRisks;
  final String? notes;
  final bool isCustom;
  final String? userId;

  const Crop({
    required this.id,
    required this.name,
    required this.category,
    required this.phMin,
    required this.phMax,
    required this.nitrogenNeed,
    required this.phosphorusNeed,
    required this.potassiumNeed,
    required this.tempMinF,
    required this.tempMaxF,
    required this.wateringFrequency,
    this.plantingWindow,
    this.harvestWindow,
    this.companionPlants = const [],
    this.pestRisks = const [],
    this.notes,
    this.isCustom = false,
    this.userId,
  });

  factory Crop.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Crop(
      id: doc.id,
      name: d['name'] ?? '',
      category: d['category'] ?? '',
      phMin: (d['phMin'] ?? 5.5).toDouble(),
      phMax: (d['phMax'] ?? 7.5).toDouble(),
      nitrogenNeed: (d['nitrogenNeed'] ?? 0.0).toDouble(),
      phosphorusNeed: (d['phosphorusNeed'] ?? 0.0).toDouble(),
      potassiumNeed: (d['potassiumNeed'] ?? 0.0).toDouble(),
      tempMinF: (d['tempMinF'] ?? 40.0).toDouble(),
      tempMaxF: (d['tempMaxF'] ?? 90.0).toDouble(),
      wateringFrequency: d['wateringFrequency'] ?? 'Weekly',
      plantingWindow: d['plantingWindow'],
      harvestWindow: d['harvestWindow'],
      companionPlants: List<String>.from(d['companionPlants'] ?? []),
      pestRisks: List<String>.from(d['pestRisks'] ?? []),
      notes: d['notes'],
      isCustom: d['isCustom'] ?? false,
      userId: d['userId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'category': category,
    'phMin': phMin,
    'phMax': phMax,
    'nitrogenNeed': nitrogenNeed,
    'phosphorusNeed': phosphorusNeed,
    'potassiumNeed': potassiumNeed,
    'tempMinF': tempMinF,
    'tempMaxF': tempMaxF,
    'wateringFrequency': wateringFrequency,
    'plantingWindow': plantingWindow,
    'harvestWindow': harvestWindow,
    'companionPlants': companionPlants,
    'pestRisks': pestRisks,
    'notes': notes,
    'isCustom': isCustom,
    'userId': userId,
  };

  double compatibilityScore(double ph, double n, double p, double k) {
    double score = 100;
    if (ph < phMin || ph > phMax) score -= 30;
    if (n < nitrogenNeed * 0.7) score -= 20;
    if (p < phosphorusNeed * 0.7) score -= 20;
    if (k < potassiumNeed * 0.7) score -= 20;
    return score.clamp(0, 100);
  }
}
