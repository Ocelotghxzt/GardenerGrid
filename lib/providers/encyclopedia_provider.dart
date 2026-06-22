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
	  } else {
		if (forceRefresh || shouldUpgradeToLargeDataset) {
		  await _localStorage.clearEncyclopediaCache();
		}

		String plantsJson;
		try {
		  plantsJson = await rootBundle.loadString('assets/data/plants_10000.json');
		} catch (_) {
		  plantsJson = await rootBundle.loadString('assets/data/plants.json');
		}
		final foragingJson =
			await rootBundle.loadString('assets/data/foraging.json');

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
	} catch (e) {
	  _error = 'Could not load offline encyclopedia.';
	}

	_loading = false;
	notifyListeners();
  }

  List<PlantEntry> searchPlants(String query) {
	if (query.trim().isEmpty) return _plants;
	final q = query.toLowerCase();
	return _plants.where((plant) {
	  return plant.name.toLowerCase().contains(q) ||
		  plant.scientificName.toLowerCase().contains(q) ||
		  plant.category.toLowerCase().contains(q) ||
		  plant.tags.any((tag) => tag.toLowerCase().contains(q));
	}).toList();
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
	if (q.length < 2) {
	  _onlinePlantResults = [];
	  _onlineError = null;
	  _onlineLoading = false;
	  notifyListeners();
	  return;
	}

	_onlineLoading = true;
	_onlineError = null;
	notifyListeners();

	try {
	  _onlinePlantResults = await _onlineSearchService.search(
		q,
		countryCode: countryCode,
	  );
	} catch (_) {
	  _onlineError = 'Online search unavailable.';
	}

	_onlineLoading = false;
	notifyListeners();
  }

  void clearOnlineSearch() {
	_onlinePlantResults = [];
	_onlineError = null;
	_onlineLoading = false;
	notifyListeners();
  }
}
