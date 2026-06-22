import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/market_provider.dart';
import '../../providers/crop_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../models/market_price.dart';

class MarketDashboardScreen extends StatefulWidget {
  const MarketDashboardScreen({super.key});
  @override
  State<MarketDashboardScreen> createState() => _MarketDashboardScreenState();
}

class _MarketDashboardScreenState extends State<MarketDashboardScreen> {
  final _searchCtrl = TextEditingController();
  final Set<String> _requestedCrops = <String>{};
  String _searchQuery = '';

  // Default popular crops to show market data for
  final List<String> _popularCrops = [
    'Corn', 'Soybeans', 'Wheat', 'Tomatoes', 'Lettuce',
    'Potatoes', 'Apples', 'Strawberries', 'Onions', 'Pumpkins',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final market = context.read<MarketProvider>();
      for (final crop in _popularCrops) {
        _requestedCrops.add(crop.toLowerCase());
        market.fetchPrices(crop);
        market.fetchCommunityPrices(crop);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final myCrops = context.watch<CropProvider>().allCrops
        .map((c) => c.name).toList();

    final displayCrops = [..._popularCrops, ...myCrops.where(
      (c) => !_popularCrops.contains(c))];

    final queryCrop = _searchQuery.trim();
    if (queryCrop.isNotEmpty &&
        !displayCrops.any((c) => c.toLowerCase() == queryCrop.toLowerCase())) {
      displayCrops.insert(0, _normalizeCropLabel(queryCrop));
    }

    final filtered = _searchQuery.isEmpty
        ? displayCrops
        : displayCrops
            .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Market Prices')),
      body: SafeArea(
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search crop...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        })
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // USDA data source badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  market.usdaVerified ? Icons.verified : Icons.warning_amber_rounded,
                  size: 14,
                  color: market.usdaVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  market.usdaVerified
                      ? 'USDA AMS verified live this session'
                      : 'USDA AMS currently unreachable, using fallback where needed',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.read<MarketProvider>().verifyUsda(),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Verify'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Crop market tiles
          Expanded(
          child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.trending_up,
                    title: 'No Results',
                    subtitle: 'Try a different crop name.',
                  )
                : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                24 + MediaQuery.of(context).padding.bottom,
              ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final crop = filtered[i];
                      _ensureCropLoaded(crop, market);
                      final prices = market.pricesFor(crop);
                      final communityPrices = market.communityPricesFor(crop);
                      return _MarketCropTile(
                        cropName: crop,
                        prices: prices,
                        communityPrices: communityPrices,
                        loading: market.loading && prices.isEmpty,
                        onRefresh: () {
                          market.fetchPrices(crop);
                          market.fetchCommunityPrices(crop);
                        },
                        onSharePrice: () => _showSharePriceSheet(context, crop),
                      );
                    },
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _MarketCropTile extends StatelessWidget {
  final String cropName;
  final List<MarketPrice> prices;
  final List<MarketPrice> communityPrices;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onSharePrice;

  const _MarketCropTile({
    required this.cropName,
    required this.prices,
    required this.communityPrices,
    required this.loading,
    required this.onRefresh,
    required this.onSharePrice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.trending_up, color: AppTheme.primary, size: 20),
        ),
        title: Text(cropName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: prices.isNotEmpty
            ? Text(
                '\$${prices.first.pricePerUnit.toStringAsFixed(2)} / ${prices.first.unit}',
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.w600))
            : loading
                ? const Text('Loading...',
                    style: TextStyle(color: Colors.grey))
                : const Text('No data — tap to refresh',
                    style: TextStyle(color: Colors.grey)),
        trailing: loading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Text('USDA + Community prices',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onSharePrice,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Share Local Price'),
                ),
              ],
            ),
          ),
          if (prices.isEmpty && !loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: onRefresh,
              ),
            )
          else
            ...prices.take(5).map(
                  (p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.store, size: 16),
                    title: Text(
                        '\$${p.pricePerUnit.toStringAsFixed(2)} / ${p.unit}'),
                    subtitle: Text(
                        '${p.marketName ?? "Unknown Market"} — ${p.region}'),
                    trailing: Text(p.source,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.grey)),
                  ),
                ),
          if (communityPrices.isNotEmpty)
            ...communityPrices.take(5).map(
                  (p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.group, size: 16),
                    title: Text(
                        '\$${p.pricePerUnit.toStringAsFixed(2)} / ${p.unit}'),
                    subtitle: Text(
                        '${p.marketName ?? "Community Market"} — ${p.region}'),
                    trailing: Text('Local',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w700)),
                  ),
                ),
          const _PriceAlertRow(),
        ],
      ),
    );
  }
}

extension on _MarketDashboardScreenState {
  void _ensureCropLoaded(String crop, MarketProvider market) {
    final key = crop.toLowerCase();
    if (_requestedCrops.contains(key)) return;
    _requestedCrops.add(key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      market.fetchPrices(crop);
      market.fetchCommunityPrices(crop);
    });
  }

  String _normalizeCropLabel(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) =>
            word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  void _showSharePriceSheet(BuildContext context, String cropName) {
    final auth = context.read<AuthProvider>();
    final marketNameCtrl = TextEditingController();
    final marketAddressCtrl = TextEditingController();
    final regionCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'lb');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Share local $cropName price',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: marketNameCtrl,
                  decoration: const InputDecoration(labelText: 'Market Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: marketAddressCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Market Address (optional)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: regionCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Region/State (for local search)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Price'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (auth.userId == null ||
                          marketNameCtrl.text.trim().isEmpty ||
                          regionCtrl.text.trim().isEmpty) {
                        return;
                      }
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                      await context.read<MarketProvider>().submitCommunityPrice(
                            userId: auth.userId!,
                            sellerName: auth.displayName,
                            cropName: cropName,
                            pricePerUnit: price,
                            unit: unitCtrl.text.trim().isEmpty
                                ? 'unit'
                                : unitCtrl.text.trim(),
                            region: regionCtrl.text.trim(),
                            marketName: marketNameCtrl.text.trim(),
                            marketAddress: marketAddressCtrl.text.trim().isEmpty
                                ? null
                                : marketAddressCtrl.text.trim(),
                          );
                      if (context.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    child: const Text('Publish Local Price'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PriceAlertRow extends StatefulWidget {
  const _PriceAlertRow();
  @override
  State<_PriceAlertRow> createState() => _PriceAlertRowState();
}

class _PriceAlertRowState extends State<_PriceAlertRow> {
  final _ctrl = TextEditingController();
  bool _set = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.notifications_none, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          const Text('Alert at \$', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _set = true),
            child: Text(_set ? 'Alert Set!' : 'Set Alert',
                style: TextStyle(
                    fontSize: 12,
                    color: _set ? AppTheme.primary : Colors.grey)),
          ),
        ],
      ),
    );
  }
}
