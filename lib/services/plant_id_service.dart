import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/plant_entry.dart';

class PlantIdMatch {
  final String id;
  final String name;
  final String scientificName;
  final double confidence;
  final String reason;
  final List<String> sources;

  const PlantIdMatch({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.confidence,
    required this.reason,
    this.sources = const <String>[],
  });

  bool get hasOnline => sources.any((s) => s.startsWith('online:'));
  bool get hasLocal => sources.contains('local:descriptor');
}

enum LeafShape { oval, lanceolate, heart, needle, palmate, lobed, feathery, other }
enum FlowerColor { white, yellow, pink, purple, red, blue, orange, none }
enum PlantHabit { herb, shrub, tree, vine, grass, succulent }
enum HabitatType { garden, forest, meadow, wetland, desert, urban }

class PlantDescriptors {
  final LeafShape? leafShape;
  final FlowerColor? flowerColor;
  final PlantHabit? plantHabit;
  final HabitatType? habitat;
  final double? heightCm;
  final String? notes;

  PlantDescriptors({
    this.leafShape,
    this.flowerColor,
    this.plantHabit,
    this.habitat,
    this.heightCm,
    this.notes,
  });
}

class PlantIdService {
  static final _picker = ImagePicker();

  Future<XFile?> pickImageFromGallery() async {
    return _picker.pickImage(source: ImageSource.gallery);
  }

  Future<XFile?> takePhoto() async {
    return _picker.pickImage(source: ImageSource.camera);
  }

  /// Online-first: combines two computer-vision providers and local descriptor matching.
  Future<List<PlantIdMatch>> identifyWithOpenData({
    XFile? image,
    required List<PlantEntry> plants,
    required PlantDescriptors descriptors,
    String? countryCode,
  }) async {
    final localRanked = identifyPlants(plants, descriptors);

    if (image == null) {
      return localRanked;
    }

    final remoteA = await _identifyWithInaturalistCv(image, plants, countryCode: countryCode);
    final remoteB = await _identifyWithInaturalistLegacy(image, plants, countryCode: countryCode);

    final remoteEnsemble = _ensembleRemote(remoteA, remoteB);
    if (remoteEnsemble.isEmpty) {
      return localRanked;
    }

    return _mergeAndRank(remoteEnsemble, localRanked);
  }

  // Provider A: iNaturalist computer-vision scoring endpoint.
  Future<List<PlantIdMatch>> _identifyWithInaturalistCv(
    XFile image,
    List<PlantEntry> plants, {
    String? countryCode,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.inaturalist.org/v1/computervision/score_image'),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      final streamed = await request.send().timeout(const Duration(seconds: 25));
      if (streamed.statusCode != 200) return [];

      final payload = jsonDecode(await streamed.stream.bytesToString());
      final candidates = _extractCandidates(payload);
      return _toMatches(
        plants: plants,
        candidates: candidates,
        sourceTag: 'online:inaturalist_cv',
        countryCode: countryCode,
      );
    } catch (_) {
      return [];
    }
  }

  // Provider B: iNaturalist identify endpoint (separate model pipeline).
  Future<List<PlantIdMatch>> _identifyWithInaturalistLegacy(
    XFile image,
    List<PlantEntry> plants, {
    String? countryCode,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://www.inaturalist.org/observations/identify'),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      final streamed = await request.send().timeout(const Duration(seconds: 25));
      if (streamed.statusCode != 200) return [];

      final payload = jsonDecode(await streamed.stream.bytesToString());
      final candidates = _extractCandidates(payload);
      return _toMatches(
        plants: plants,
        candidates: candidates,
        sourceTag: 'online:inaturalist_identify',
        countryCode: countryCode,
      );
    } catch (_) {
      return [];
    }
  }

  Future<List<PlantIdMatch>> _toMatches({
    required List<PlantEntry> plants,
    required List<Map<String, dynamic>> candidates,
    required String sourceTag,
    String? countryCode,
  }) async {
    final out = <PlantIdMatch>[];

    for (final candidate in candidates.take(16)) {
      final sci = (candidate['scientific'] ?? '').toString();
      final common = (candidate['common'] ?? '').toString();
      var score = ((candidate['score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);

      final match = _matchCandidateToLocal(
        plants: plants,
        scientificName: sci,
        commonName: common,
      );
      if (match == null) continue;

      if (countryCode != null && countryCode.trim().isNotEmpty) {
        score = await _applyRegionBoost(score, sci.isNotEmpty ? sci : match.scientificName, countryCode);
      }

      out.add(
        PlantIdMatch(
          id: match.id,
          name: match.name,
          scientificName: match.scientificName,
          confidence: score,
          reason: 'AI photo-ID match',
          sources: [sourceTag],
        ),
      );
    }

    out.sort((a, b) => b.confidence.compareTo(a.confidence));
    return _dedupe(out).take(10).toList();
  }

  Future<double> _applyRegionBoost(double base, String scientificName, String countryCode) async {
    try {
      final uri = Uri.parse(
        'https://api.gbif.org/v1/occurrence/search'
        '?scientificName=${Uri.encodeQueryComponent(scientificName)}'
        '&country=${Uri.encodeQueryComponent(countryCode.toUpperCase())}'
        '&limit=1',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return base;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final count = (data['count'] as num?)?.toInt() ?? 0;
      if (count > 0) return (base + 0.12).clamp(0.0, 1.0);
      return base;
    } catch (_) {
      return base;
    }
  }

  List<PlantIdMatch> _ensembleRemote(
    List<PlantIdMatch> providerA,
    List<PlantIdMatch> providerB,
  ) {
    final map = <String, PlantIdMatch>{};

    for (final m in providerA) {
      map[m.id] = m;
    }

    for (final m in providerB) {
      final existing = map[m.id];
      if (existing == null) {
        map[m.id] = m;
      } else {
        final score = (existing.confidence * 0.55) + (m.confidence * 0.45);
        map[m.id] = PlantIdMatch(
          id: existing.id,
          name: existing.name,
          scientificName: existing.scientificName,
          confidence: score.clamp(0.0, 1.0),
          reason: 'AI ensemble vote (2 providers)',
          sources: {...existing.sources, ...m.sources}.toList(),
        );
      }
    }

    final merged = map.values.toList()..sort((a, b) => b.confidence.compareTo(a.confidence));
    return merged;
  }

  List<Map<String, dynamic>> _extractCandidates(dynamic payload) {
    final list = <Map<String, dynamic>>[];

    if (payload is List) {
      for (final item in payload) {
        final candidate = _parseCandidate(item);
        if (candidate != null) list.add(candidate);
      }
    } else if (payload is Map<String, dynamic>) {
      final keys = ['results', 'common_ancestor', 'taxa'];
      for (final key in keys) {
        final maybe = payload[key];
        if (maybe is List) {
          for (final item in maybe) {
            final candidate = _parseCandidate(item);
            if (candidate != null) list.add(candidate);
          }
        }
      }
    }

    return list;
  }

  Map<String, dynamic>? _parseCandidate(dynamic item) {
    if (item is! Map<String, dynamic>) return null;
    final taxon = item['taxon'] is Map<String, dynamic>
        ? item['taxon'] as Map<String, dynamic>
        : <String, dynamic>{};

    final scientific = (taxon['name'] ?? item['name'] ?? '').toString();
    final common = (taxon['preferred_common_name'] ?? item['preferred_common_name'] ?? '').toString();
    final score = ((item['combined_score'] ?? item['score'] ?? item['vision_score'] ?? 0.0) as num).toDouble();

    if (scientific.isEmpty && common.isEmpty) return null;

    return {
      'scientific': scientific,
      'common': common,
      'score': score,
    };
  }

  PlantEntry? _matchCandidateToLocal({
    required List<PlantEntry> plants,
    required String scientificName,
    required String commonName,
  }) {
    final sci = _norm(scientificName);
    final common = _norm(commonName);

    PlantEntry? best;
    double bestScore = 0;

    for (final plant in plants) {
      final pSci = _norm(plant.scientificName);
      final pName = _norm(plant.name);

      double score = 0;
      if (sci.isNotEmpty) {
        score = score > _nameSimilarity(sci, pSci) ? score : _nameSimilarity(sci, pSci);

        final sciGenus = sci.split(' ').first;
        final pGenus = pSci.split(' ').first;
        if (sciGenus.isNotEmpty && sciGenus == pGenus) {
          score = score > 0.75 ? score : 0.75;
        }
      }

      if (common.isNotEmpty) {
        score = score > _nameSimilarity(common, pName) ? score : _nameSimilarity(common, pName);
      }

      if (score > bestScore) {
        best = plant;
        bestScore = score;
      }
    }

    if (bestScore < 0.55) return null;
    return best;
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  double _nameSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) return 0.9;

    final at = a.split(' ').where((t) => t.isNotEmpty).toSet();
    final bt = b.split(' ').where((t) => t.isNotEmpty).toSet();
    if (at.isEmpty || bt.isEmpty) return 0;

    final overlap = at.intersection(bt).length;
    final union = at.union(bt).length;
    return union == 0 ? 0 : overlap / union;
  }

  List<PlantIdMatch> _mergeAndRank(
    List<PlantIdMatch> remote,
    List<PlantIdMatch> local,
  ) {
    final byId = <String, PlantIdMatch>{};

    for (final r in remote) {
      byId[r.id] = r;
    }

    for (final l in local) {
      final existing = byId[l.id];
      if (existing == null) {
        byId[l.id] = l;
      } else {
        final merged = (existing.confidence * 0.7) + (l.confidence * 0.3);
        byId[l.id] = PlantIdMatch(
          id: existing.id,
          name: existing.name,
          scientificName: existing.scientificName,
          confidence: merged.clamp(0.0, 1.0),
          reason: 'AI ensemble + local descriptor match',
          sources: {...existing.sources, ...l.sources}.toList(),
        );
      }
    }

    final merged = byId.values.toList()..sort((a, b) => b.confidence.compareTo(a.confidence));
    return merged.take(12).toList();
  }

  List<PlantIdMatch> _dedupe(List<PlantIdMatch> input) {
    final seen = <String>{};
    final out = <PlantIdMatch>[];
    for (final m in input) {
      if (seen.add(m.id)) out.add(m);
    }
    return out;
  }

  double _scorePlant(PlantEntry plant, PlantDescriptors desc) {
    double score = 0;
    double total = 0;

    final tags = plant.tags;
    final category = plant.category;
    final description = plant.description.toLowerCase();

    if (desc.plantHabit != null) {
      total += 1;
      final habitMap = {
        PlantHabit.herb: ['Herb', 'Wildflower'],
        PlantHabit.shrub: ['Shrub'],
        PlantHabit.tree: ['Tree'],
        PlantHabit.vine: ['Vine', 'Climber'],
        PlantHabit.grass: ['Grass'],
        PlantHabit.succulent: ['Succulent'],
      };
      final matches = habitMap[desc.plantHabit!] ?? [];
      if (matches.any((m) => category.contains(m))) score += 1;
    }

    if (desc.habitat != null) {
      total += 1;
      final habitatMap = {
        HabitatType.garden: ['companion', 'culinary', 'edible'],
        HabitatType.forest: ['native', 'shade'],
        HabitatType.meadow: ['native', 'perennial', 'wildflower'],
        HabitatType.wetland: ['wetland', 'moist'],
        HabitatType.desert: ['drought-tolerant'],
        HabitatType.urban: ['ornamental', 'urban'],
      };
      final habitatTags = habitatMap[desc.habitat!] ?? [];
      if (habitatTags.any((t) => tags.contains(t))) score += 1;
    }

    if (desc.flowerColor != null && desc.flowerColor != FlowerColor.none) {
      total += 1;
      final colorMap = {
        FlowerColor.white: ['white', 'cream', 'ivory'],
        FlowerColor.yellow: ['yellow', 'gold'],
        FlowerColor.pink: ['pink', 'rose'],
        FlowerColor.purple: ['purple', 'violet', 'lavender', 'blue'],
        FlowerColor.red: ['red', 'scarlet', 'crimson'],
        FlowerColor.blue: ['blue', 'azure'],
        FlowerColor.orange: ['orange'],
      };
      final colors = colorMap[desc.flowerColor!] ?? [];
      if (colors.any((c) => description.contains(c))) score += 1;
    } else if (desc.flowerColor == FlowerColor.none) {
      total += 1;
      if (!description.contains('flower') && !description.contains('bloom')) {
        score += 1;
      }
    }

    if (desc.heightCm != null) {
      total += 1;
      final diff = (desc.heightCm! - plant.heightCm).abs();
      if (diff < 50) {
        score += 1;
      } else if (diff < 150) {
        score += 0.5;
      }
    }

    if (desc.notes != null && desc.notes!.isNotEmpty) {
      total += 1;
      final note = desc.notes!.toLowerCase();
      if (plant.name.toLowerCase().contains(note) ||
          plant.scientificName.toLowerCase().contains(note) ||
          plant.description.toLowerCase().contains(note) ||
          plant.tags.any((t) => note.contains(t.toLowerCase()))) {
        score += 1;
      }
    }

    return total > 0 ? (score / total).clamp(0.0, 1.0) : 0.0;
  }

  List<PlantIdMatch> identifyPlants(
    List<PlantEntry> plants,
    PlantDescriptors descriptors,
  ) {
    final matches = <PlantIdMatch>[];

    for (final plant in plants) {
      final confidence = _scorePlant(plant, descriptors);
      if (confidence > 0.2) {
        final reasons = <String>[];

        if (descriptors.plantHabit != null) reasons.add('Plant type');
        if (descriptors.habitat != null) reasons.add('Habitat');
        if (descriptors.flowerColor != null) reasons.add('Flower color');
        if (descriptors.heightCm != null) reasons.add('Height');
        if (descriptors.notes != null && descriptors.notes!.isNotEmpty) {
          reasons.add('Notes');
        }

        matches.add(
          PlantIdMatch(
            id: plant.id,
            name: plant.name,
            scientificName: plant.scientificName,
            confidence: confidence,
            reason: reasons.isEmpty ? 'Partial heuristic match' : '${reasons.join(', ')} match',
            sources: const ['local:descriptor'],
          ),
        );
      }
    }

    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches.take(12).toList();
  }

  String getConfidenceLabel(double confidence) {
    if (confidence >= 0.8) return 'High Match';
    if (confidence >= 0.6) return 'Good Match';
    if (confidence >= 0.4) return 'Possible Match';
    return 'Unlikely Match';
  }

  Color getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return const Color(0xFF2E7D32);
    if (confidence >= 0.6) return const Color(0xFF43A047);
    if (confidence >= 0.4) return const Color(0xFFFFA000);
    return const Color(0xFFE65100);
  }
}
