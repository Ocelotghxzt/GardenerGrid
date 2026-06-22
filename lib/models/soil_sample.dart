import 'package:cloud_firestore/cloud_firestore.dart';

enum SampleSource { manual, upload, bluetoothSensor, wifiSensor }

class SoilSample {
  final String id;
  final String fieldId;
  final DateTime timestamp;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double moisture;
  final double electricalConductivity;
  final double organicMatter;
  final String? texture;
  final String? notes;
  final String? sensorName;
  final String? sensorId;
  final int? signalStrength;
  final SampleSource source;
  final int? healthScore;
  final List<String> deficiencies;
  final List<String> amendments;

  const SoilSample({
    required this.id,
    required this.fieldId,
    required this.timestamp,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.moisture,
    required this.electricalConductivity,
    required this.organicMatter,
    this.texture,
    this.notes,
    this.sensorName,
    this.sensorId,
    this.signalStrength,
    required this.source,
    this.healthScore,
    this.deficiencies = const [],
    this.amendments = const [],
  });

  factory SoilSample.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SoilSample(
      id: doc.id,
      fieldId: d['fieldId'] ?? '',
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      ph: (d['ph'] ?? 7.0).toDouble(),
      nitrogen: (d['nitrogen'] ?? 0.0).toDouble(),
      phosphorus: (d['phosphorus'] ?? 0.0).toDouble(),
      potassium: (d['potassium'] ?? 0.0).toDouble(),
      moisture: (d['moisture'] ?? 0.0).toDouble(),
      electricalConductivity: (d['electricalConductivity'] ?? 0.0).toDouble(),
      organicMatter: (d['organicMatter'] ?? 0.0).toDouble(),
      texture: d['texture'],
      notes: d['notes'],
      sensorName: d['sensorName'],
      sensorId: d['sensorId'],
      signalStrength: d['signalStrength'],
      source: SampleSource.values.firstWhere(
        (e) => e.name == (d['source'] ?? 'manual'),
        orElse: () => SampleSource.manual,
      ),
      healthScore: d['healthScore'],
      deficiencies: List<String>.from(d['deficiencies'] ?? []),
      amendments: List<String>.from(d['amendments'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fieldId': fieldId,
    'timestamp': Timestamp.fromDate(timestamp),
    'ph': ph,
    'nitrogen': nitrogen,
    'phosphorus': phosphorus,
    'potassium': potassium,
    'moisture': moisture,
    'electricalConductivity': electricalConductivity,
    'organicMatter': organicMatter,
    'texture': texture,
    'notes': notes,
    'sensorName': sensorName,
    'sensorId': sensorId,
    'signalStrength': signalStrength,
    'source': source.name,
    'healthScore': healthScore,
    'deficiencies': deficiencies,
    'amendments': amendments,
  };
}
