import 'package:flutter/material.dart';
import '../models/market_price.dart';
import '../services/market_service.dart';

class MarketProvider extends ChangeNotifier {
  final MarketService _service;

  final Map<String, List<MarketPrice>> _prices = {};
  final Map<String, List<MarketPrice>> _communityPrices = {};
  bool _loading = false;
  String? _error;
  bool _usdaVerified = false;
  DateTime? _usdaVerifiedAt;

  bool get loading => _loading;
  String? get error => _error;
  bool get usdaVerified => _usdaVerified;
  DateTime? get usdaVerifiedAt => _usdaVerifiedAt;

  MarketProvider(this._service) {
    verifyUsda();
  }

  List<MarketPrice> pricesFor(String cropName) =>
      _prices[cropName.toLowerCase()] ?? [];

  List<MarketPrice> communityPricesFor(String cropName) =>
      _communityPrices[cropName.toLowerCase()] ?? [];

  Future<void> fetchPrices(String cropName, {String stateCode = ''}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = stateCode.isNotEmpty
          ? await _service.fetchPricesForRegion(cropName, stateCode)
          : await _service.fetchLocalPrices(cropName);
      _prices[cropName.toLowerCase()] = results;
    } catch (e) {
      _error = 'Could not load market data. Check your connection.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> verifyUsda() async {
    _usdaVerified = await _service.verifyUsdaData();
    _usdaVerifiedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> fetchCommunityPrices(String cropName, {String region = ''}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await _service.fetchCommunityPrices(cropName, region: region);
      _communityPrices[cropName.toLowerCase()] = results;
    } catch (_) {
      _error = 'Could not load community market prices.';
    }
    _loading = false;
    notifyListeners();
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
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.submitCommunityPrice(
        userId: userId,
        sellerName: sellerName,
        cropName: cropName,
        pricePerUnit: pricePerUnit,
        unit: unit,
        region: region,
        marketName: marketName,
        marketAddress: marketAddress,
      );
      await fetchCommunityPrices(cropName, region: region);
    } catch (_) {
      _error = 'Could not submit community market price.';
      _loading = false;
      notifyListeners();
    }
  }
}
