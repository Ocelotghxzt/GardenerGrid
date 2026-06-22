import 'dart:convert';
import 'package:http/http.dart' as http;

class OnlinePlantSearchResult {
  final String id;
  final String name;
  final String scientificName;
  final String family;
  final String source;
  final String? snippet;
  final String? imageUrl;
  final double confidence;

  const OnlinePlantSearchResult({
    required this.id,
    required this.name,
    required this.scientificName,
    required this.family,
    required this.source,
    this.snippet,
    this.imageUrl,
    this.confidence = 0.6,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'scientificName': scientificName,
        'family': family,
        'source': source,
        'snippet': snippet,
        'imageUrl': imageUrl,
        'confidence': confidence,
      };

  factory OnlinePlantSearchResult.fromJson(Map<String, dynamic> json) {
    return OnlinePlantSearchResult(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      scientificName: (json['scientificName'] ?? '').toString(),
      family: (json['family'] ?? 'Unknown').toString(),
      source: (json['source'] ?? 'Unknown').toString(),
      snippet: json['snippet']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }

  OnlinePlantSearchResult copyWith({double? confidence}) {
    return OnlinePlantSearchResult(
      id: id,
      name: name,
      scientificName: scientificName,
      family: family,
      source: source,
      snippet: snippet,
      imageUrl: imageUrl,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Live online search using open data sources and literal open search engines.
class OnlinePlantSearchService {
  static const Map<String, double> _sourceWeight = {
    'GBIF': 0.86,
    'iNaturalist': 0.84,
    'OpenFarm': 0.78,
    'Wikipedia Search': 0.64,
    'Wikidata Search': 0.66,
    'Openverse Search': 0.50,
  };

  Future<List<OnlinePlantSearchResult>> search(
    String query, {
    String? countryCode,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final variants = _buildQueryVariants(q).take(3).toList();
    final allBatches = <List<OnlinePlantSearchResult>>[];

    for (final variant in variants) {
      final batches = await Future.wait<List<OnlinePlantSearchResult>>([
        _withRetry(() => _searchGbif(variant)),
        _withRetry(() => _searchINaturalist(variant)),
        _withRetry(() => _searchOpenFarm(variant)),
        _withRetry(() => _searchWikipedia(variant)),
        _withRetry(() => _searchOpenverse(variant)),
        _withRetry(() => _searchWikidata(variant)),
      ]);
      allBatches.addAll(batches);
    }

    final results = <OnlinePlantSearchResult>[];
    for (final batch in allBatches) {
      results.addAll(batch);
    }

    final deduped = <String, OnlinePlantSearchResult>{};
    for (final r in results) {
      final normalizedSci = r.scientificName.toLowerCase().trim();
      final normalizedName = r.name.toLowerCase().trim();
      final key = normalizedSci.isNotEmpty ? normalizedSci : normalizedName;
      final existing = deduped[key];
      if (existing == null || r.confidence > existing.confidence) {
        deduped[key] = r;
      }
    }

    var merged = deduped.values.toList();

    if (countryCode != null && countryCode.trim().isNotEmpty) {
      merged = await _applyRegionBias(merged, countryCode.toUpperCase());
    }

    merged = merged
        .map((item) => item.copyWith(
            confidence: ((item.confidence * 0.78) +
                    ((_sourceWeight[item.source] ?? 0.55) * 0.22))
                .clamp(0.0, 1.0)))
        .toList();

    merged.sort((a, b) {
      final rb = _relevanceScore(q, b);
      final ra = _relevanceScore(q, a);
      return rb.compareTo(ra);
    });
    return merged.take(80).toList();
  }

  List<String> _buildQueryVariants(String query) {
    final q = query.toLowerCase().trim();
    final variants = <String>{q};

    if (!q.contains('plant')) {
      variants.add('$q plant');
    }

    if (q.endsWith('ies') && q.length > 4) {
      variants.add('${q.substring(0, q.length - 3)}y');
    } else if (q.endsWith('s') && q.length > 3) {
      variants.add(q.substring(0, q.length - 1));
    } else {
      variants.add('${q}s');
    }

    return variants.toList();
  }

  Future<List<OnlinePlantSearchResult>> _withRetry(
    Future<List<OnlinePlantSearchResult>> Function() fn,
  ) async {
    try {
      final first = await fn();
      if (first.isNotEmpty) return first;
      return await fn();
    } catch (_) {
      return const [];
    }
  }

  double _relevanceScore(String query, OnlinePlantSearchResult result) {
    final qTokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length > 1)
        .toSet();
    final text = '${result.name} ${result.scientificName} ${result.family} ${result.snippet ?? ''}'
        .toLowerCase();
    var hits = 0;
    for (final t in qTokens) {
      if (text.contains(t)) hits += 1;
    }
    final lexical = qTokens.isEmpty ? 0.0 : hits / qTokens.length;
    return (result.confidence * 0.75) + (lexical * 0.25);
  }

  Future<List<OnlinePlantSearchResult>> _searchGbif(String query) async {
    final uri = Uri.parse(
      'https://api.gbif.org/v1/species/search'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&kingdomKey=6'
      '&rank=SPECIES'
      '&limit=20',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['results'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      return rows.map((row) {
        final sci =
            (row['scientificName'] ?? row['canonicalName'] ?? 'Unknown').toString();
        final common = (row['vernacularName'] ?? sci).toString();
        final family = (row['family'] ?? 'Unknown').toString();
        final taxonId = (row['key'] ?? '').toString();

        return OnlinePlantSearchResult(
          id: 'gbif_$taxonId',
          name: common,
          scientificName: sci,
          family: family,
          source: 'GBIF',
          snippet: 'Open biodiversity taxonomy record',
          confidence: 0.72,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlinePlantSearchResult>> _searchINaturalist(String query) async {
    final uri = Uri.parse(
      'https://api.inaturalist.org/v1/taxa/autocomplete'
      '?q=${Uri.encodeQueryComponent(query)}'
      '&taxon_id=47126'
      '&per_page=20',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['results'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      return rows.map((row) {
        final sci = (row['name'] ?? 'Unknown').toString();
        final common = (row['preferred_common_name'] ?? sci).toString();
        final taxonId = (row['id'] ?? '').toString();
        final iconic = (row['iconic_taxon_name'] ?? '').toString();
        final photo = row['default_photo'] is Map<String, dynamic>
            ? (row['default_photo']['medium_url'] ?? row['default_photo']['url'])
            : null;

        return OnlinePlantSearchResult(
          id: 'inat_$taxonId',
          name: common,
          scientificName: sci,
          family: iconic,
          source: 'iNaturalist',
          imageUrl: photo?.toString(),
          snippet: 'Community-verified observation taxonomy',
          confidence: 0.68,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  // Literal web-search engine integration: Wikipedia search API.
  Future<List<OnlinePlantSearchResult>> _searchWikipedia(String query) async {
    final uri = Uri.parse(
      'https://en.wikipedia.org/w/api.php'
      '?action=query'
      '&list=search'
      '&format=json'
      '&utf8=1'
      '&srlimit=10'
      '&srsearch=${Uri.encodeQueryComponent('$query plant')}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final queryNode = data['query'] as Map<String, dynamic>?;
      final rows = (queryNode?['search'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      return rows.map((row) {
        final title = (row['title'] ?? 'Unknown').toString();
        final pageId = (row['pageid'] ?? '').toString();
        final snippet = (row['snippet'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '');

        return OnlinePlantSearchResult(
          id: 'wiki_$pageId',
          name: title,
          scientificName: title,
          family: 'Wikipedia',
          source: 'Wikipedia Search',
          snippet: snippet,
          confidence: 0.58,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  // Literal open search engine media index (Openverse).
  Future<List<OnlinePlantSearchResult>> _searchOpenverse(String query) async {
    final uri = Uri.parse(
      'https://api.openverse.org/v1/images/'
      '?q=${Uri.encodeQueryComponent('$query plant')}'
      '&page_size=10',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['results'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      return rows.map((row) {
        final title = (row['title'] ?? 'Untitled').toString();
        final id = (row['id'] ?? '').toString();
        final creator = (row['creator'] ?? 'Openverse').toString();
        final thumb = (row['thumbnail'] ?? row['url'])?.toString();

        return OnlinePlantSearchResult(
          id: 'openverse_$id',
          name: title,
          scientificName: title,
          family: creator,
          source: 'Openverse Search',
          imageUrl: thumb,
          snippet: 'Open web media search result',
          confidence: 0.52,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlinePlantSearchResult>> _searchOpenFarm(String query) async {
    final uri = Uri.parse(
      'https://openfarm.cc/api/v1/crops/?filter=${Uri.encodeQueryComponent(query)}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['data'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      return rows.map((row) {
        final id = (row['id'] ?? '').toString();
        final attrs = row['attributes'] is Map<String, dynamic>
            ? row['attributes'] as Map<String, dynamic>
            : const <String, dynamic>{};
        final name = (attrs['name'] ?? 'Unknown crop').toString();
        final desc = (attrs['description'] ?? '').toString();
        final sun = (attrs['sun_requirements'] ?? '').toString();
        final main = (attrs['main_image_path'] ?? '').toString();

        return OnlinePlantSearchResult(
          id: 'openfarm_$id',
          name: name,
          scientificName: name,
          family: 'OpenFarm',
          source: 'OpenFarm',
          snippet: [desc, if (sun.isNotEmpty) 'Sun: $sun']
              .where((v) => v.trim().isNotEmpty)
              .join(' • '),
          imageUrl: main.isEmpty ? null : main,
          confidence: 0.74,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlinePlantSearchResult>> _searchWikidata(String query) async {
    final uri = Uri.parse(
      'https://www.wikidata.org/w/api.php'
      '?action=wbsearchentities'
      '&format=json'
      '&language=en'
      '&limit=10'
      '&type=item'
      '&search=${Uri.encodeQueryComponent('$query plant')}',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (data['search'] as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];

      return rows.map((row) {
        final id = (row['id'] ?? '').toString();
        final title = (row['label'] ?? 'Unknown').toString();
        final description = (row['description'] ?? 'Wikidata entity').toString();

        return OnlinePlantSearchResult(
          id: 'wikidata_$id',
          name: title,
          scientificName: title,
          family: 'Wikidata',
          source: 'Wikidata Search',
          snippet: description,
          confidence: 0.55,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<OnlinePlantSearchResult>> _applyRegionBias(
    List<OnlinePlantSearchResult> input,
    String countryCode,
  ) async {
    final out = <OnlinePlantSearchResult>[];

    for (final item in input) {
      if (item.scientificName.trim().isEmpty ||
          item.source == 'Wikipedia Search' ||
          item.source == 'Openverse Search') {
        out.add(item);
        continue;
      }

      final occurs = await _occursInCountry(item.scientificName, countryCode);
      out.add(item.copyWith(
        confidence: occurs
            ? (item.confidence + 0.08).clamp(0.0, 1.0)
            : item.confidence,
      ));
    }

    return out;
  }

  Future<bool> _occursInCountry(String scientificName, String countryCode) async {
    try {
      final uri = Uri.parse(
        'https://api.gbif.org/v1/occurrence/search'
        '?scientificName=${Uri.encodeQueryComponent(scientificName)}'
        '&country=${Uri.encodeQueryComponent(countryCode)}'
        '&limit=1',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final count = (data['count'] as num?)?.toInt() ?? 0;
      return count > 0;
    } catch (_) {
      return false;
    }
  }
}
