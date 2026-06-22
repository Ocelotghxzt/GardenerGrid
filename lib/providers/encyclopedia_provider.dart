import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/foraging_entry.dart';
import '../models/plant_entry.dart';
import '../services/local_storage_service.dart';
import '../services/online_plant_search_service.dart';

class EncyclopediaProvider extends ChangeNotifier {
	final LocalStorageService _localStorage;
	static const int _targetLargeDatasetSize = 10000;
	final OnlinePlantSearchService _onlineSearchService =
			OnlinePlantSearchService();
  List<PlantEntry> _plants = [];
  List<ForagingEntry> _foragingEntries = [];
	List<OnlinePlantSearchResult> _onlinePlantResults = [];
  bool _loading = false;
	bool _onlineLoading = false;
  String? _error;
	String? _onlineError;
	int _onlineSearchNonce = 0;

  EncyclopediaProvider(this._localStorage);

  List<PlantEntry> get plants => _plants;
  List<ForagingEntry> get foragingEntries => _foragingEntries;
	List<OnlinePlantSearchResult> get onlinePlantResults => _onlinePlantResults;
  bool get loading => _loading;
	bool get onlineLoading => _onlineLoading;
  String? get error => _error;
	String? get onlineError => _onlineError;

  Future<void> load({bool forceRefresh = false}) async {
	if (_plants.isNotEmpty || _foragingEntries.isNotEmpty) {
	  if (!forceRefresh) return;
	}

	_loading = true;
	_error = null;
	notifyListeners();

	try {
		final hasPlantCache = await _localStorage.hasPlantCache();
	  final hasForagingCache = await _localStorage.hasForagingCache();

	  final cacheCount = await _localStorage.plantCacheCount();
	  final shouldUpgradeToLargeDataset =
		  hasPlantCache && cacheCount > 0 && cacheCount < _targetLargeDatasetSize;

	  if ((hasPlantCache && hasForagingCache) &&
		  !forceRefresh &&
		  !shouldUpgradeToLargeDataset) {
		_plants = await _localStorage.searchPlants('');
		_foragingEntries = await _localStorage.searchForaging('');

		if (_plants.isEmpty || _foragingEntries.isEmpty) {
		  await _loadBundledDataAndCache();
		}
	  } else {
		if (forceRefresh || shouldUpgradeToLargeDataset) {
		  await _localStorage.clearEncyclopediaCache();
		}
		await _loadBundledDataAndCache();
	  }
	} catch (e) {
	  _error = 'Could not load offline encyclopedia.';
	}

	_loading = false;
	notifyListeners();
  }

  Future<void> _loadBundledDataAndCache() async {
	String plantsJson;
	try {
	  plantsJson = await rootBundle.loadString('assets/data/plants_10000.json');
	} catch (_) {
	  plantsJson = await rootBundle.loadString('assets/data/plants.json');
	}
	final foragingJson = await rootBundle.loadString('assets/data/foraging.json');

	final plantsData = jsonDecode(plantsJson) as List<dynamic>;
	final foragingData = jsonDecode(foragingJson) as List<dynamic>;

	_plants = plantsData
		.map((item) => PlantEntry.fromJson(item as Map<String, dynamic>))
		.toList();
	_foragingEntries = foragingData
		.map((item) => ForagingEntry.fromJson(item as Map<String, dynamic>))
		.toList();

	await _localStorage.cachePlants(_plants);
	await _localStorage.cacheForaging(_foragingEntries);
  }

  List<PlantEntry> searchPlants(String query) {
	final trimmed = query.trim();
	if (trimmed.isEmpty) return _plants;
	final q = trimmed.toLowerCase();
	final tokens = q
		.split(RegExp(r'[^a-z0-9]+'))
		.where((t) => t.isNotEmpty)
		.toList();
	final matches = _plants.where((plant) {
	  final bag = [
		plant.name,
		plant.scientificName,
		plant.category,
		plant.family,
		plant.description,
		plant.tags.join(' '),
	  ].join(' ').toLowerCase();

	  if (bag.contains(q)) return true;
	  return tokens.every(bag.contains) ||
		  plant.name.toLowerCase().contains(q) ||
		  plant.scientificName.toLowerCase().contains(q) ||
		  plant.category.toLowerCase().contains(q) ||
		  plant.tags.any((tag) => tag.toLowerCase().contains(q));
	}).toList();

	matches.sort((a, b) => _plantSearchScore(q, b).compareTo(_plantSearchScore(q, a)));
	return matches;
  }

	int _plantSearchScore(String q, PlantEntry plant) {
	  final name = plant.name.toLowerCase();
	  final scientific = plant.scientificName.toLowerCase();
	  final category = plant.category.toLowerCase();
	  final idText = plant.id.replaceAll('_', ' ').toLowerCase();
	  final bag = [
		name,
		scientific,
		category,
		plant.family.toLowerCase(),
		plant.tags.join(' ').toLowerCase(),
		plant.description.toLowerCase(),
	  ].join(' ');

	  var score = 0;
	  if (name == q) score += 500;
	  if (scientific == q) score += 480;
	  if (idText == q) score += 440;
	  if (name.startsWith(q)) score += 220;
	  if (scientific.startsWith(q)) score += 210;
	  if (name.contains(q)) score += 120;
	  if (scientific.contains(q)) score += 110;
	  if (category == q) score += 80;

	  final tokens = q
		  .split(RegExp(r'[^a-z0-9]+'))
		  .where((t) => t.isNotEmpty)
		  .toList();
	  for (final token in tokens) {
		if (name == token || scientific == token) {
		  score += 140;
		} else if (name.startsWith(token) || scientific.startsWith(token)) {
		  score += 60;
		} else if (bag.contains(token)) {
		  score += 15;
		}
	  }

	  return score;
	}

  Future<List<PlantEntry>> searchPlantsLocal(String query) =>
	  _localStorage.searchPlants(query);

  List<ForagingEntry> searchForaging(String query) {
	if (query.trim().isEmpty) return _foragingEntries;
	final q = query.toLowerCase();
	return _foragingEntries.where((entry) {
	  return entry.name.toLowerCase().contains(q) ||
		  entry.scientificName.toLowerCase().contains(q) ||
		  entry.category.toLowerCase().contains(q) ||
		  entry.tags.any((tag) => tag.toLowerCase().contains(q));
	}).toList();
  }

  Future<List<ForagingEntry>> searchForagingLocal(String query) =>
	  _localStorage.searchForaging(query);

  PlantEntry? plantById(String id) {
	try {
	  return _plants.firstWhere((plant) => plant.id == id);
	} catch (_) {
	  return null;
	}
  }

  PlantEntry? findLocalPlantMatch({
	required String scientificName,
	required String commonName,
  }) {
	final sci = scientificName.toLowerCase().trim();
	final common = commonName.toLowerCase().trim();

	for (final p in _plants) {
	  final pSci = p.scientificName.toLowerCase();
	  final pName = p.name.toLowerCase();
	  if (sci.isNotEmpty && (pSci == sci || pSci.contains(sci) || sci.contains(pSci))) {
		return p;
	  }
	  if (common.isNotEmpty &&
		  (pName == common || pName.contains(common) || common.contains(pName))) {
		return p;
	  }
	}

	return null;
  }

	Future<void> searchPlantsOnline(String query, {String? countryCode}) async {
	final q = query.trim();
	final requestId = ++_onlineSearchNonce;
	if (q.length < 2) {
	  _onlinePlantResults = [];
	  _onlineError = null;
	  _onlineLoading = false;
	  notifyListeners();
	  return;
	}

	_onlineLoading = true;
	_onlineError = null;

	try {
	  final cached = await _localStorage.searchOnlineEncyclopediaCache(q);
	  if (requestId != _onlineSearchNonce) return;
	  if (cached.isNotEmpty) {
		_onlinePlantResults = cached;
	  }
	} catch (_) {
	  // Cache read failure should never block network fetch.
	}
	notifyListeners();

	try {
	  final remote = await _onlineSearchService
		  .search(
		q,
		countryCode: countryCode,
	  )
		  .timeout(const Duration(seconds: 20));

	  if (requestId != _onlineSearchNonce) return;

	  if (remote.isNotEmpty) {
		final merged = <String, OnlinePlantSearchResult>{};
		for (final item in _onlinePlantResults) {
		  merged['${item.source}|${item.id}'] = item;
		}
		for (final item in remote) {
		  final local = findLocalPlantMatch(
			scientificName: item.scientificName,
			commonName: item.name,
		  );
		  final normalized = local == null
			  ? item
			  : item.copyWith(
				  name: local.name,
				  scientificName: local.scientificName,
				  family: local.family,
				  snippet: item.snippet ?? local.description,
			  );
		  merged['${normalized.source}|${normalized.id}'] = normalized;
		}
		_onlinePlantResults = merged.values.toList()
		  ..sort((a, b) => _onlineSearchScore(q, b).compareTo(_onlineSearchScore(q, a)));

		await _localStorage.cacheOnlineEncyclopediaResults(
		  q,
		  _onlinePlantResults,
		);
	  } else if (_onlinePlantResults.isEmpty) {
		_onlineError = 'No matching entries found in open encyclopedia sources.';
	  }
	} catch (_) {
	  if (requestId != _onlineSearchNonce) return;
	  if (_onlinePlantResults.isEmpty) {
		_onlineError = 'Online search unavailable.';
	  }
	}

	_onlineLoading = false;
	notifyListeners();
  }

	int _onlineSearchScore(String query, OnlinePlantSearchResult result) {
	  final q = query.toLowerCase();
	  final name = result.name.toLowerCase();
	  final scientific = result.scientificName.toLowerCase();
	  final family = result.family.toLowerCase();
	  final snippet = (result.snippet ?? '').toLowerCase();
	  final bag = '$name $scientific $family $snippet';
	  var score = (result.confidence * 100).round();

	  if (name == q) score += 500;
	  if (scientific == q) score += 480;
	  if (name.startsWith(q)) score += 220;
	  if (scientific.startsWith(q)) score += 210;
	  if (name.contains(q)) score += 120;
	  if (scientific.contains(q)) score += 110;

	  final tokens = q
		  .split(RegExp(r'[^a-z0-9]+'))
		  .where((t) => t.isNotEmpty)
		  .toList();
	  for (final token in tokens) {
		if (name == token || scientific == token) {
		  score += 120;
		} else if (name.startsWith(token) || scientific.startsWith(token)) {
		  score += 50;
		} else if (bag.contains(token)) {
		  score += 12;
		}
	  }

	  return score;
	}

  void clearOnlineSearch() {
	_onlinePlantResults = [];
	_onlineError = null;
	_onlineLoading = false;
	notifyListeners();
  }
}
