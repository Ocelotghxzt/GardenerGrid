import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/crop.dart';
import '../models/soil_sample.dart';
import '../services/firestore_service.dart';
import '../services/crop_recommendation_service.dart';

class CropProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final CropRecommendationService _recommender = CropRecommendationService();

  List<Crop> _defaultCrops = [];
  List<Crop> _customCrops = [];
  List<CropScore> _recommendations = [];
  bool _loading = false;

  List<Crop> get defaultCrops => _defaultCrops;
  List<Crop> get customCrops => _customCrops;
  List<Crop> get allCrops => [..._defaultCrops, ..._customCrops];
  List<CropScore> get recommendations => _recommendations;
  bool get loading => _loading;

  CropProvider(this._firestore);

  Future<void> loadCrops(String userId) async {
    _loading = true;
    notifyListeners();
    _defaultCrops = await _firestore.getDefaultCrops();
    _firestore.customCropsStream(userId).listen((crops) {
      _customCrops = crops;
      notifyListeners();
    });
    _loading = false;
    notifyListeners();
  }

  void updateRecommendations(SoilSample sample) {
    _recommendations = _recommender
        .recommend(sample, allCrops)
        .map((cs) => CropScore(crop: cs.crop, score: cs.score))
        .toList();
    notifyListeners();
  }

  Future<void> addCustomCrop(Crop crop, String userId) async {
    final withId = Crop(
      id: const Uuid().v4(),
      name: crop.name,
      category: crop.category,
      phMin: crop.phMin,
      phMax: crop.phMax,
      nitrogenNeed: crop.nitrogenNeed,
      phosphorusNeed: crop.phosphorusNeed,
      potassiumNeed: crop.potassiumNeed,
      tempMinF: crop.tempMinF,
      tempMaxF: crop.tempMaxF,
      wateringFrequency: crop.wateringFrequency,
      plantingWindow: crop.plantingWindow,
      harvestWindow: crop.harvestWindow,
      companionPlants: crop.companionPlants,
      pestRisks: crop.pestRisks,
      notes: crop.notes,
      isCustom: true,
      userId: userId,
    );
    await _firestore.saveCustomCrop(withId, userId);
  }

  Future<void> deleteCustomCrop(String userId, String cropId) =>
      _firestore.deleteCustomCrop(userId, cropId);
}
