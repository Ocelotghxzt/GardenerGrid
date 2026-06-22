import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/foraging_entry.dart';
import '../models/market_price.dart';
import '../models/plant_entry.dart';
import '../models/soil_sample.dart';

class LocalStorageService {
  static const _dbName = 'gardenergrid_local.db';
	static const _dbVersion = 3;

  Database? _db;

  Future<Database> get database async {
	if (_db != null) return _db!;
	final basePath = await getDatabasesPath();
	_db = await openDatabase(
	  p.join(basePath, _dbName),
	  version: _dbVersion,
	  onCreate: (db, version) async {
		await _createBaseTables(db);
		await _createMeshRetryQueueTable(db);
		await _createCommunityMarketCacheTable(db);
	  },
	  onUpgrade: (db, oldVersion, newVersion) async {
		if (oldVersion < 2) {
		  await _createMeshRetryQueueTable(db);
		}
		if (oldVersion < 3) {
		  await _createCommunityMarketCacheTable(db);
		}
	  },
	);
	return _db!;
  }

  Future<void> _createBaseTables(Database db) async {
	await db.execute('''
	  CREATE TABLE IF NOT EXISTS soil_samples (
		id TEXT PRIMARY KEY,
		owner_id TEXT NOT NULL,
		field_id TEXT NOT NULL,
		timestamp TEXT NOT NULL,
		ph REAL NOT NULL,
		nitrogen REAL NOT NULL,
		phosphorus REAL NOT NULL,
		potassium REAL NOT NULL,
		moisture REAL NOT NULL,
		electrical_conductivity REAL NOT NULL,
		organic_matter REAL NOT NULL,
		texture TEXT,
		notes TEXT,
		sensor_name TEXT,
		sensor_id TEXT,
		signal_strength INTEGER,
		source TEXT NOT NULL,
		health_score INTEGER,
		deficiencies_json TEXT NOT NULL,
		amendments_json TEXT NOT NULL
	  )
	''');

	await db.execute('''
	  CREATE TABLE IF NOT EXISTS encyclopedia_plants (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		scientific_name TEXT NOT NULL,
		category TEXT NOT NULL,
		search_blob TEXT NOT NULL,
		payload_json TEXT NOT NULL
	  )
	''');

	await db.execute('''
	  CREATE TABLE IF NOT EXISTS encyclopedia_foraging (
		id TEXT PRIMARY KEY,
		name TEXT NOT NULL,
		scientific_name TEXT NOT NULL,
		category TEXT NOT NULL,
		search_blob TEXT NOT NULL,
		payload_json TEXT NOT NULL
	  )
	''');
  }

  Future<void> _createMeshRetryQueueTable(Database db) async {
	await db.execute('''
	  CREATE TABLE IF NOT EXISTS mesh_retry_queue (
		id TEXT PRIMARY KEY,
		channel_id TEXT NOT NULL,
		payload_json TEXT NOT NULL,
		attempts INTEGER NOT NULL DEFAULT 0,
		next_retry_at INTEGER NOT NULL DEFAULT 0,
		created_at INTEGER NOT NULL,
		last_error TEXT
	  )
	''');
  }

  Future<void> _createCommunityMarketCacheTable(Database db) async {
	await db.execute('''
	  CREATE TABLE IF NOT EXISTS community_market_prices_cache (
		id TEXT PRIMARY KEY,
		crop_name TEXT NOT NULL,
		region TEXT NOT NULL,
		search_blob TEXT NOT NULL,
		payload_json TEXT NOT NULL,
		updated_at INTEGER NOT NULL
	  )
	''');
  }

  Future<void> saveSoilSample(SoilSample sample, String ownerId) async {
	final db = await database;
	await db.insert(
	  'soil_samples',
	  {
		'id': sample.id,
		'owner_id': ownerId,
		'field_id': sample.fieldId,
		'timestamp': sample.timestamp.toIso8601String(),
		'ph': sample.ph,
		'nitrogen': sample.nitrogen,
		'phosphorus': sample.phosphorus,
		'potassium': sample.potassium,
		'moisture': sample.moisture,
		'electrical_conductivity': sample.electricalConductivity,
		'organic_matter': sample.organicMatter,
		'texture': sample.texture,
		'notes': sample.notes,
		'sensor_name': sample.sensorName,
		'sensor_id': sample.sensorId,
		'signal_strength': sample.signalStrength,
		'source': sample.source.name,
		'health_score': sample.healthScore,
		'deficiencies_json': jsonEncode(sample.deficiencies),
		'amendments_json': jsonEncode(sample.amendments),
	  },
	  conflictAlgorithm: ConflictAlgorithm.replace,
	);
  }

  Future<List<SoilSample>> getSoilSamples(String ownerId, String fieldId) async {
	final db = await database;
	final rows = await db.query(
	  'soil_samples',
	  where: 'owner_id = ? AND field_id = ?',
	  whereArgs: [ownerId, fieldId],
	  orderBy: 'timestamp DESC',
	);

	return rows.map(_soilSampleFromRow).toList();
  }

  SoilSample _soilSampleFromRow(Map<String, Object?> row) {
	return SoilSample(
	  id: row['id']! as String,
	  fieldId: row['field_id']! as String,
	  timestamp: DateTime.parse(row['timestamp']! as String),
	  ph: (row['ph']! as num).toDouble(),
	  nitrogen: (row['nitrogen']! as num).toDouble(),
	  phosphorus: (row['phosphorus']! as num).toDouble(),
	  potassium: (row['potassium']! as num).toDouble(),
	  moisture: (row['moisture']! as num).toDouble(),
	  electricalConductivity:
		  (row['electrical_conductivity']! as num).toDouble(),
	  organicMatter: (row['organic_matter']! as num).toDouble(),
	  texture: row['texture'] as String?,
	  notes: row['notes'] as String?,
		sensorName: row['sensor_name'] as String?,
	  sensorId: row['sensor_id'] as String?,
	  signalStrength: row['signal_strength'] as int?,
	  source: SampleSource.values.firstWhere(
		(value) => value.name == row['source'],
		orElse: () => SampleSource.manual,
	  ),
	  healthScore: row['health_score'] as int?,
	  deficiencies:
		  List<String>.from(jsonDecode(row['deficiencies_json']! as String)),
	  amendments:
		  List<String>.from(jsonDecode(row['amendments_json']! as String)),
	);
  }

  Future<void> cachePlants(List<PlantEntry> plants) async {
	final db = await database;
	final batch = db.batch();
	for (final plant in plants) {
	  batch.insert(
		'encyclopedia_plants',
		{
		  'id': plant.id,
		  'name': plant.name,
		  'scientific_name': plant.scientificName,
		  'category': plant.category,
		  'search_blob': _plantSearchBlob(plant),
		  'payload_json': jsonEncode(_plantToJson(plant)),
		},
		conflictAlgorithm: ConflictAlgorithm.replace,
	  );
	}
	await batch.commit(noResult: true);
  }

  Future<void> cacheForaging(List<ForagingEntry> entries) async {
	final db = await database;
	final batch = db.batch();
	for (final entry in entries) {
	  batch.insert(
		'encyclopedia_foraging',
		{
		  'id': entry.id,
		  'name': entry.name,
		  'scientific_name': entry.scientificName,
		  'category': entry.category,
		  'search_blob': _foragingSearchBlob(entry),
		  'payload_json': jsonEncode(_foragingToJson(entry)),
		},
		conflictAlgorithm: ConflictAlgorithm.replace,
	  );
	}
	await batch.commit(noResult: true);
  }

  Future<List<PlantEntry>> searchPlants(String query) async {
	final db = await database;
	final trimmed = query.trim().toLowerCase();
	final rows = await db.query(
	  'encyclopedia_plants',
	  where: trimmed.isEmpty ? null : 'search_blob LIKE ?',
	  whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
	  orderBy: 'name COLLATE NOCASE ASC',
	);
	return rows
		.map((row) => PlantEntry.fromJson(
			jsonDecode(row['payload_json']! as String) as Map<String, dynamic>))
		.toList();
  }

  Future<List<ForagingEntry>> searchForaging(String query) async {
	final db = await database;
	final trimmed = query.trim().toLowerCase();
	final rows = await db.query(
	  'encyclopedia_foraging',
	  where: trimmed.isEmpty ? null : 'search_blob LIKE ?',
	  whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
	  orderBy: 'name COLLATE NOCASE ASC',
	);
	return rows
		.map((row) => ForagingEntry.fromJson(
			jsonDecode(row['payload_json']! as String) as Map<String, dynamic>))
		.toList();
  }

  Future<bool> hasPlantCache() async {
	final db = await database;
	final result = await db.rawQuery('SELECT COUNT(*) AS count FROM encyclopedia_plants');
	return (result.first['count'] as int) > 0;
  }

  Future<int> plantCacheCount() async {
	final db = await database;
	final result = await db.rawQuery('SELECT COUNT(*) AS count FROM encyclopedia_plants');
	return (result.first['count'] as int?) ?? 0;
  }

  Future<bool> hasForagingCache() async {
	final db = await database;
	final result = await db.rawQuery('SELECT COUNT(*) AS count FROM encyclopedia_foraging');
	return (result.first['count'] as int) > 0;
  }

  Future<void> clearEncyclopediaCache() async {
	final db = await database;
	await db.delete('encyclopedia_plants');
	await db.delete('encyclopedia_foraging');
  }

  Future<void> enqueueMeshRetryPacket({
	required String id,
	required String channelId,
	required Map<String, dynamic> payload,
  }) async {
	final db = await database;
	await db.insert(
	  'mesh_retry_queue',
	  {
		'id': id,
		'channel_id': channelId,
		'payload_json': jsonEncode(payload),
		'attempts': 0,
		'next_retry_at': 0,
		'created_at': DateTime.now().millisecondsSinceEpoch,
	  },
	  conflictAlgorithm: ConflictAlgorithm.ignore,
	);
  }

  Future<List<Map<String, dynamic>>> getPendingMeshRetryPackets() async {
	final db = await database;
	final nowMs = DateTime.now().millisecondsSinceEpoch;
	final rows = await db.query(
	  'mesh_retry_queue',
	  where: 'next_retry_at <= ?',
	  whereArgs: [nowMs],
	  orderBy: 'created_at ASC',
	  limit: 200,
	);

	return rows
		.map(
		  (row) => {
			'id': row['id'] as String,
			'channelId': row['channel_id'] as String,
			'attempts': (row['attempts'] as int?) ?? 0,
			'payload': jsonDecode(row['payload_json'] as String)
				as Map<String, dynamic>,
		  },
		)
		.toList();
  }

  Future<void> markMeshRetrySuccess(String id) async {
	final db = await database;
	await db.delete('mesh_retry_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markMeshRetryFailure(String id, String error, int attempts) async {
	final db = await database;
	final delaySeconds = (1 << attempts).clamp(2, 300);
	await db.update(
	  'mesh_retry_queue',
	  {
		'attempts': attempts,
		'last_error': error,
		'next_retry_at': DateTime.now()
			.add(Duration(seconds: delaySeconds))
			.millisecondsSinceEpoch,
	  },
	  where: 'id = ?',
	  whereArgs: [id],
	);
  }

  Future<void> cacheCommunityMarketPrices(List<MarketPrice> prices) async {
	final db = await database;
	final batch = db.batch();
	for (final price in prices) {
	  final id = '${price.source}-${price.cropName}-${price.marketName ?? ''}-${price.region}'
		  .toLowerCase()
		  .replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
	  batch.insert(
		'community_market_prices_cache',
		{
		  'id': id,
		  'crop_name': price.cropName,
		  'region': price.region,
		  'search_blob': '${price.cropName} ${price.marketName ?? ''} ${price.region}'.toLowerCase(),
		  'payload_json': jsonEncode(_marketPriceToJson(price)),
		  'updated_at': DateTime.now().millisecondsSinceEpoch,
		},
		conflictAlgorithm: ConflictAlgorithm.replace,
	  );
	}
	await batch.commit(noResult: true);
  }

  Future<List<MarketPrice>> searchCommunityMarketPrices(
	String query, {
	String region = '',
  }) async {
	final db = await database;
	final trimmed = query.trim().toLowerCase();
	String? where;
	List<Object?>? args;

	if (trimmed.isNotEmpty && region.isNotEmpty) {
	  where = 'search_blob LIKE ? AND region = ?';
	  args = ['%$trimmed%', region];
	} else if (trimmed.isNotEmpty) {
	  where = 'search_blob LIKE ?';
	  args = ['%$trimmed%'];
	} else if (region.isNotEmpty) {
	  where = 'region = ?';
	  args = [region];
	}

	final rows = await db.query(
	  'community_market_prices_cache',
	  where: where,
	  whereArgs: args,
	  orderBy: 'updated_at DESC',
	  limit: 200,
	);

	return rows
		.map((row) => _marketPriceFromJson(
			jsonDecode(row['payload_json']! as String) as Map<String, dynamic>))
		.toList();
  }

  Map<String, dynamic> _marketPriceToJson(MarketPrice price) => {
		'cropName': price.cropName,
		'pricePerUnit': price.pricePerUnit,
		'unit': price.unit,
		'source': price.source,
		'region': price.region,
		'fetchedAt': price.fetchedAt.toIso8601String(),
		'marketName': price.marketName,
		'marketAddress': price.marketAddress,
	  };

  MarketPrice _marketPriceFromJson(Map<String, dynamic> json) => MarketPrice(
		cropName: (json['cropName'] ?? '').toString(),
		pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble() ?? 0,
		unit: (json['unit'] ?? 'unit').toString(),
		source: (json['source'] ?? 'Local Cache').toString(),
		region: (json['region'] ?? '').toString(),
		fetchedAt: DateTime.tryParse((json['fetchedAt'] ?? '').toString()) ??
			DateTime.now(),
		marketName: json['marketName']?.toString(),
		marketAddress: json['marketAddress']?.toString(),
	  );

  Map<String, dynamic> _plantToJson(PlantEntry plant) => {
		'id': plant.id,
		'name': plant.name,
		'scientificName': plant.scientificName,
		'family': plant.family,
		'category': plant.category,
		'tags': plant.tags,
		'description': plant.description,
		'soilPreference': plant.soilPreference,
		'sunlight': plant.sunlight,
		'water': plant.water,
		'phMin': plant.phMin,
		'phMax': plant.phMax,
		'hardinessZone': plant.hardinessZone,
		'heightCm': plant.heightCm,
		'spreadCm': plant.spreadCm,
		'bloomSeason': plant.bloomSeason,
		'companionPlants': plant.companionPlants,
		'pestRepellent': plant.pestRepellent,
		'culinaryUses': plant.culinaryUses,
		'medicinalUses': plant.medicinalUses,
		'gardeningTips': plant.gardeningTips,
		'propagation': plant.propagation,
		'imageAsset': plant.imageAsset,
	  };

  Map<String, dynamic> _foragingToJson(ForagingEntry entry) => {
		'id': entry.id,
		'name': entry.name,
		'scientificName': entry.scientificName,
		'category': entry.category,
		'tags': entry.tags,
		'edibility': entry.edibility,
		'season': entry.season,
		'habitat': entry.habitat,
		'description': entry.description,
		'identification': {
		  'leaves': entry.identification.leaves,
		  'stem': entry.identification.stem,
		  'flower': entry.identification.flower,
		  'fruit': entry.identification.fruit,
		  'lookalikes': entry.identification.lookalikes,
		},
		'lookalikeDanger': entry.lookalikeDanger,
		'harvestNotes': entry.harvestNotes,
		'nutritionHighlights': entry.nutritionHighlights,
		'preparationMethods': entry.preparationMethods,
		'medicinalUses': entry.medicinalUses,
		'ecologicalRole': entry.ecologicalRole,
		'safetyWarnings': entry.safetyWarnings,
		'imageAsset': entry.imageAsset,
	  };

  String _plantSearchBlob(PlantEntry plant) => [
		plant.name,
		plant.scientificName,
		plant.family,
		plant.category,
		plant.description,
		plant.tags.join(' '),
		plant.companionPlants.join(' '),
		plant.medicinalUses,
		plant.culinaryUses,
	  ].join(' ').toLowerCase();

  String _foragingSearchBlob(ForagingEntry entry) => [
		entry.name,
		entry.scientificName,
		entry.category,
		entry.description,
		entry.tags.join(' '),
		entry.habitat.join(' '),
		entry.identification.lookalikes,
		entry.lookalikeDanger,
	  ].join(' ').toLowerCase();
}
