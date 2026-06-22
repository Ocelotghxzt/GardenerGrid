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
  Future<List<OnlinePlantSearchResult>> search(
    String query, {
    String? countryCode,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final results = <OnlinePlantSearchResult>[];

    results.addAll(await _searchGbif(q));
    results.addAll(await _searchINaturalist(q));
    results.addAll(await _searchWikipedia(q));
    results.addAll(await _searchOpenverse(q));

    final deduped = <String, OnlinePlantSearchResult>{};
    for (final r in results) {
      final key = '${r.scientificName.toLowerCase()}|${r.source.toLowerCase()}';
      final existing = deduped[key];
      if (existing == null || r.confidence > existing.confidence) {
        deduped[key] = r;
      }
    }

    var merged = deduped.values.toList();

    if (countryCode != null && countryCode.trim().isNotEmpty) {
      merged = await _applyRegionBias(merged, countryCode.toUpperCase());
    }

    merged.sort((a, b) => b.confidence.compareTo(a.confidence));
    return merged.take(30).toList();
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
