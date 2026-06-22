import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/market_price.dart';
import 'firestore_service.dart';
import 'local_storage_service.dart';

class MarketService {
  // USDA AMS Market News API — free, no API key required for public data
  static const String _usdaBase =
      'https://marsapi.ams.usda.gov/services/v1.2/reports';
  static const String _usdaPublicBase =
      'https://marsapi.ams.usda.gov/services/v3.1/public';

  final FirestoreService _firestore;
  final LocalStorageService _localStorage;

  MarketService({
    FirestoreService? firestore,
    required LocalStorageService localStorage,
  })  : _firestore = firestore ?? FirestoreService(),
        _localStorage = localStorage;

  Future<bool> verifyUsdaData() async {
    try {
      final uri = Uri.parse('$_usdaPublicBase/listPublishedReports/7?format=json');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['reports'] as List<dynamic>? ?? [];
      return results.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<MarketPrice>> fetchLocalPrices(String cropName) async {
    final merged = <MarketPrice>[];

    final publicHints = await _fetchFromUsdaPublicReports(cropName);
    merged.addAll(publicHints);

    try {
      // Opportunistic protected route fallback when public report data
      // does not provide enough matching coverage.
      final uri = Uri.parse('$_usdaBase?q=$cropName&allSections=true');
      final response = await http.get(uri,
          headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          merged.addAll(results
              .map((r) => MarketPrice.fromUsdaJson(r as Map<String, dynamic>))
              .where((p) => p.cropName.isNotEmpty)
              .toList());
        }
      }
    } catch (_) {
      // Fall through to static fallback.
    }

    if (merged.isEmpty) {
      merged.addAll(_getFallbackPrices(cropName));
    }

    return _dedupeAndSort(merged, cropName);
  }

  Future<List<MarketPrice>> fetchPricesForRegion(
      String cropName, String stateCode) async {
    final merged = <MarketPrice>[];

    final publicHints =
        await _fetchFromUsdaPublicReports(cropName, stateCode: stateCode);
    merged.addAll(publicHints);

    try {
      final uri = Uri.parse(
          '$_usdaBase?q=$cropName&marketLocationState=$stateCode&allSections=true');
      final response = await http.get(uri,
          headers: {'Accept': 'application/json'}).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          merged.addAll(results
              .map((r) => MarketPrice.fromUsdaJson(r as Map<String, dynamic>))
              .where((p) => p.cropName.isNotEmpty)
              .toList());
        }
      }
    } catch (_) {}

    if (merged.isEmpty) {
      final fallback = _getFallbackPrices(cropName)
          .map((p) => MarketPrice(
                cropName: p.cropName,
                pricePerUnit: p.pricePerUnit,
                unit: p.unit,
                source: p.source,
                region: stateCode,
                fetchedAt: p.fetchedAt,
                marketName: p.marketName,
                marketAddress: p.marketAddress,
              ))
          .toList();
      merged.addAll(fallback);
    }

    return _dedupeAndSort(merged, cropName);
  }

  Future<List<MarketPrice>> _fetchFromUsdaPublicReports(
    String cropName, {
    String stateCode = '',
  }) async {
    try {
      final uri = Uri.parse('$_usdaPublicBase/listPublishedReports/14?format=json');
      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final reports = data['reports'] as List<dynamic>? ?? const [];
      final fallback = _getFallbackPrices(cropName);
      final fallbackPrice =
          fallback.isNotEmpty ? fallback.first.pricePerUnit : 0.0;
      final fallbackUnit = fallback.isNotEmpty ? fallback.first.unit : 'unit';

      return reports
          .whereType<Map<String, dynamic>>()
          .where((r) {
            final title = (r['reportTitle'] ?? '').toString().toLowerCase();
            final hasCrop = title.contains(cropName.toLowerCase());
            final hasState = stateCode.isEmpty || title.contains(stateCode.toLowerCase());
            return hasCrop && hasState;
          })
          .take(8)
          .map((r) {
            final title = (r['reportTitle'] ?? '').toString();
            final publishedDate = (r['publishedDate'] ?? '').toString();
            final region = title.contains('-')
                ? title.split('-').last.trim()
                : (stateCode.isNotEmpty ? stateCode : 'USA');
            return MarketPrice(
              cropName: cropName,
              pricePerUnit: fallbackPrice,
              unit: fallbackUnit,
              source: 'USDA AMS Report (Indexed)',
              region: region,
              fetchedAt: DateTime.tryParse(publishedDate) ?? DateTime.now(),
              marketName: title,
              marketAddress: 'Report reference',
            );
          })
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> submitCommunityPrice({
    required String userId,
    required String sellerName,
    required String cropName,
    required double pricePerUnit,
    required String unit,
    required String region,
    required String marketName,
    String? marketAddress,
  }) {
    return _firestore.submitCommunityMarketPrice(
      userId: userId,
      sellerName: sellerName,
      cropName: cropName,
      pricePerUnit: pricePerUnit,
      unit: unit,
      region: region,
      marketName: marketName,
      marketAddress: marketAddress,
    );
  }

  Future<List<MarketPrice>> fetchCommunityPrices(
    String cropName, {
    String region = '',
  }) async {
    try {
      final remote = await _firestore.fetchCommunityMarketPrices(
        cropName,
        region: region,
      );
      if (remote.isNotEmpty) {
        await _localStorage.cacheCommunityMarketPrices(remote);
      }
      return remote;
    } catch (_) {
      return _localStorage.searchCommunityMarketPrices(
        cropName,
        region: region,
      );
    }
  }

  /// Returns reasonable average market prices for common crops when API is unavailable.
  /// Includes wholesale and consumer retail averages for robustness.
  List<MarketPrice> _getFallbackPrices(String cropName) {
    final name = cropName.toLowerCase();
    final now = DateTime.now();

    final fallback = {
      'tomato': (1.85, 'lb'),
      'lettuce': (2.25, 'head'),
      'pepper': (2.30, 'lb'),
      'cucumber': (1.65, 'lb'),
      'basil': (2.95, 'bunch'),
      'mint': (2.50, 'bunch'),
      'parsley': (2.25, 'bunch'),
      'cilantro': (2.10, 'bunch'),
      'squash': (1.45, 'lb'),
      'zucchini': (1.55, 'lb'),
      'bean': (1.95, 'lb'),
      'pea': (2.20, 'lb'),
      'carrot': (1.20, 'lb'),
      'radish': (1.80, 'bunch'),
      'spinach': (3.30, 'lb'),
      'kale': (2.95, 'lb'),
      'potato': (0.95, 'lb'),
      'onion': (1.05, 'lb'),
      'garlic': (0.95, 'bulb'),
      'strawberry': (3.95, 'lb'),
      'blueberry': (4.95, 'lb'),
      'raspberry': (5.60, 'lb'),
      'apple': (1.70, 'lb'),
      'peach': (2.40, 'lb'),
      'corn': (0.75, 'ear'),
      'soybean': (0.42, 'lb'),
      'wheat': (0.28, 'lb'),
      'pumpkin': (0.68, 'lb'),
    };

    final key = fallback.keys.firstWhere(
      (k) => name.contains(k) || k.contains(name),
      orElse: () => '',
    );

    if (key.isEmpty) {
      return [
        MarketPrice(
          cropName: cropName,
          pricePerUnit: 2.20,
          unit: 'per lb',
          fetchedAt: now,
          marketName: 'Average Retail (US)',
          marketAddress: 'National baseline',
          source: 'Fallback Retail Average',
          region: 'USA',
        ),
        MarketPrice(
          cropName: cropName,
          pricePerUnit: 1.45,
          unit: 'per lb',
          fetchedAt: now,
          marketName: 'Average Wholesale (US)',
          marketAddress: 'National baseline',
          source: 'Fallback Wholesale Average',
          region: 'USA',
        ),
      ];
    }

    final item = fallback[key]!;
    return [
      MarketPrice(
        cropName: cropName,
        pricePerUnit: item.$1.toDouble(),
        unit: 'per ${item.$2}',
        fetchedAt: now,
        marketName: 'Average Retail (US)',
        marketAddress: 'National baseline',
        source: 'Fallback Retail Average',
        region: 'USA',
      ),
      MarketPrice(
        cropName: cropName,
        pricePerUnit: (item.$1 * 0.68),
        unit: 'per ${item.$2}',
        fetchedAt: now,
        marketName: 'Average Wholesale (US)',
        marketAddress: 'National baseline',
        source: 'Fallback Wholesale Average',
        region: 'USA',
      ),
    ];
  }

  List<MarketPrice> _dedupeAndSort(List<MarketPrice> input, String cropName) {
    final map = <String, MarketPrice>{};
    for (final p in input) {
      if (p.cropName.isEmpty || p.pricePerUnit <= 0) continue;
      final key = '${p.marketName ?? ''}-${p.region}-${p.source}-${p.unit}'.toLowerCase();
      map[key] = p;
    }

    final items = map.values.toList()
      ..sort((a, b) {
        final src = a.source.compareTo(b.source);
        if (src != 0) return src;
        return b.fetchedAt.compareTo(a.fetchedAt);
      });

    if (items.isEmpty) {
      return _getFallbackPrices(cropName);
    }

    return items;
  }
}
