class MarketPrice {
  final String cropName;
  final double pricePerUnit;
  final String unit;
  final String source;
  final String region;
  final DateTime fetchedAt;
  final String? marketName;
  final String? marketAddress;
  final List<PricePoint> history;

  const MarketPrice({
    required this.cropName,
    required this.pricePerUnit,
    required this.unit,
    required this.source,
    required this.region,
    required this.fetchedAt,
    this.marketName,
    this.marketAddress,
    this.history = const [],
  });

  factory MarketPrice.fromUsdaJson(Map<String, dynamic> json) {
    return MarketPrice(
      cropName: json['commodity'] ?? '',
      pricePerUnit: double.tryParse(json['avg_price']?.toString() ?? '0') ?? 0,
      unit: json['unit'] ?? 'lb',
      source: 'USDA AMS',
      region: json['market_location_state'] ?? 'USA',
      fetchedAt: DateTime.now(),
      marketName: json['market_name'],
      marketAddress: json['market_location_city'],
      history: [],
    );
  }
}

class PricePoint {
  final DateTime date;
  final double price;
  const PricePoint({required this.date, required this.price});
}
