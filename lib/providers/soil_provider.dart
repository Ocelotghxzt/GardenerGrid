import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/soil_sample.dart';
import '../services/firestore_service.dart';
import '../services/local_storage_service.dart';
import '../services/soil_analysis_service.dart';

class SoilProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final LocalStorageService _localStorage;
  final SoilAnalysisService _analyzer = SoilAnalysisService();

  SoilSample? _latestSample;
  List<SoilSample> _history = [];
  bool _loading = false;
  String? _error;
  String _currentFieldId = 'default';

  SoilSample? get latestSample => _latestSample;
  List<SoilSample> get history => _history;
  bool get loading => _loading;
  String? get error => _error;

  SoilProvider(this._firestore, this._localStorage);

  Future<void> loadField(String userId, String fieldId) async {
    _currentFieldId = fieldId;
    _firestore.soilSamplesStream(userId, fieldId).listen((samples) {
      _history = samples;
      _latestSample = samples.isNotEmpty ? samples.first : null;
      notifyListeners();
    });
  }

  Future<void> submitSample({
    required String userId,
    required Map<String, double> values,
    required SampleSource source,
    String? notes,
    String? texture,
    String? sensorName,
    String? sensorId,
    int? signalStrength,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = SoilSample(
        id: const Uuid().v4(),
        fieldId: _currentFieldId,
        timestamp: DateTime.now(),
        ph: values['ph'] ?? 7.0,
        nitrogen: values['nitrogen'] ?? 0,
        phosphorus: values['phosphorus'] ?? 0,
        potassium: values['potassium'] ?? 0,
        moisture: values['moisture'] ?? 0,
        electricalConductivity: values['ec'] ?? 0,
        organicMatter: values['organicMatter'] ?? 0,
        texture: texture,
        notes: notes,
        sensorName: sensorName,
        sensorId: sensorId,
        signalStrength: signalStrength,
        source: source,
      );
      final analyzed = _analyzer.analyze(raw);
      await _firestore.saveSoilSample(analyzed, userId);
      await _localStorage.saveSoilSample(analyzed, userId);
      _latestSample = analyzed;
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }
}
