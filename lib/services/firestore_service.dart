import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/soil_sample.dart';
import '../models/crop.dart';
import '../models/maintenance_task.dart';
import '../models/market_price.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
    CollectionReference<Map<String, dynamic>> get _communityPricesCol =>
            _db.collection('community_market_prices');

  // Soil samples
  Future<void> saveSoilSample(SoilSample sample, String userId) =>
      _db.collection('users').doc(userId)
         .collection('soil_samples').doc(sample.id)
         .set(sample.toFirestore());

  Stream<List<SoilSample>> soilSamplesStream(String userId, String fieldId) =>
      _db.collection('users').doc(userId)
         .collection('soil_samples')
         .where('fieldId', isEqualTo: fieldId)
         .orderBy('timestamp', descending: true)
         .snapshots()
         .map((s) => s.docs.map(SoilSample.fromFirestore).toList());

  // Crops
  Future<void> saveCustomCrop(Crop crop, String userId) =>
      _db.collection('users').doc(userId)
         .collection('custom_crops').doc(crop.id)
         .set(crop.toFirestore());

  Stream<List<Crop>> customCropsStream(String userId) =>
      _db.collection('users').doc(userId)
         .collection('custom_crops')
         .snapshots()
         .map((s) => s.docs.map(Crop.fromFirestore).toList());

  Future<List<Crop>> getDefaultCrops() async {
    final snap = await _db.collection('crops').get();
    return snap.docs.map(Crop.fromFirestore).toList();
  }

  Future<void> deleteCustomCrop(String userId, String cropId) =>
      _db.collection('users').doc(userId)
         .collection('custom_crops').doc(cropId).delete();

  // Maintenance tasks
  Future<void> saveTask(MaintenanceTask task, String userId) =>
      _db.collection('users').doc(userId)
         .collection('tasks').doc(task.id)
         .set(task.toFirestore());

  Stream<List<MaintenanceTask>> tasksStream(String userId) =>
      _db.collection('users').doc(userId)
         .collection('tasks')
         .orderBy('dueDate')
         .snapshots()
         .map((s) => s.docs.map(MaintenanceTask.fromFirestore).toList());

  Future<void> updateTaskStatus(
      String userId, String taskId, TaskStatus status) =>
      _db.collection('users').doc(userId)
         .collection('tasks').doc(taskId)
         .update({'status': status.name});

    Future<void> submitCommunityMarketPrice({
        required String userId,
        required String sellerName,
        required String cropName,
        required double pricePerUnit,
        required String unit,
        required String region,
        required String marketName,
        String? marketAddress,
    }) {
        final docId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
        return _communityPricesCol.doc(docId).set({
            'userId': userId,
            'sellerName': sellerName,
            'cropName': cropName,
            'pricePerUnit': pricePerUnit,
            'unit': unit,
            'region': region,
            'marketName': marketName,
            'marketAddress': marketAddress,
            'source': 'Community Farmer',
            'createdAt': FieldValue.serverTimestamp(),
            'searchBlob': '$cropName $marketName $region'.toLowerCase(),
        });
    }

    Future<List<MarketPrice>> fetchCommunityMarketPrices(
        String cropName, {
        String region = '',
    }) async {
        Query<Map<String, dynamic>> query = _communityPricesCol
                .where('searchBlob', isGreaterThanOrEqualTo: cropName.toLowerCase())
                .where('searchBlob', isLessThanOrEqualTo: '${cropName.toLowerCase()}\uf8ff')
                .orderBy('searchBlob')
                .orderBy('createdAt', descending: true)
                .limit(50);

        if (region.isNotEmpty) {
            query = query.where('region', isEqualTo: region);
        }

        final snap = await query.get();
        return snap.docs
                .map((doc) {
                    final d = doc.data();
                    return MarketPrice(
                        cropName: (d['cropName'] ?? '').toString(),
                        pricePerUnit: (d['pricePerUnit'] as num?)?.toDouble() ?? 0,
                        unit: (d['unit'] ?? 'unit').toString(),
                        source: (d['source'] ?? 'Community Farmer').toString(),
                        region: (d['region'] ?? '').toString(),
                        fetchedAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        marketName: d['marketName']?.toString(),
                        marketAddress: d['marketAddress']?.toString(),
                    );
                })
                .where((p) => p.cropName.isNotEmpty)
                .toList();
    }
}
