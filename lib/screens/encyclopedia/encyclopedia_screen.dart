import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/foraging_entry.dart';
import '../../models/plant_entry.dart';
import '../../providers/encyclopedia_provider.dart';
import '../../services/online_plant_search_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class EncyclopediaScreen extends StatefulWidget {
  const EncyclopediaScreen({super.key});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen>
	with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchCtrl = TextEditingController();
	Timer? _searchDebounce;
	String? _countryCode;
  String _query = '';

  @override
  void initState() {
	super.initState();
	_tabController = TabController(length: 2, vsync: this);
	WidgetsBinding.instance.addPostFrameCallback((_) {
	  context.read<EncyclopediaProvider>().load();
	  _resolveCountryCode();
	});
  }

  Future<void> _resolveCountryCode() async {
	try {
	  var permission = await Geolocator.checkPermission();
	  if (permission == LocationPermission.denied) {
		permission = await Geolocator.requestPermission();
	  }
	  if (permission == LocationPermission.denied ||
		  permission == LocationPermission.deniedForever) {
		return;
	  }

	  final pos = await Geolocator.getCurrentPosition();
	  final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
	  if (!mounted) return;
	  setState(() => _countryCode = marks.isNotEmpty ? marks.first.isoCountryCode : null);
	} catch (_) {
	  // Region-aware ranking is optional; fallback works without this.
	}
  }

  @override
  void dispose() {
	_searchDebounce?.cancel();
	_tabController.dispose();
	_searchCtrl.dispose();
	super.dispose();
  }

  @override
  Widget build(BuildContext context) {
	final encyclopedia = context.watch<EncyclopediaProvider>();
	final plants = encyclopedia.searchPlants(_query);
	final forage = encyclopedia.searchForaging(_query);
    final online = encyclopedia.onlinePlantResults;

	return Scaffold(
	  appBar: AppBar(
		title: const Text('Encyclopedia'),
		actions: [
		  IconButton(
			icon: const Icon(Icons.local_library_outlined),
			onPressed: () => context.push('/encyclopedia/library'),
			tooltip: 'Library Mode',
		  ),
		  IconButton(
			icon: const Icon(Icons.refresh),
			onPressed: () => context
				.read<EncyclopediaProvider>()
				.load(forceRefresh: true),
			tooltip: 'Refresh data',
		  ),
		],
		bottom: TabBar(
		  controller: _tabController,
		  tabs: const [
			Tab(text: 'Plants & Botany'),
			Tab(text: 'Foraging'),
		  ],
		),
	  ),
	  body: Column(
		children: [
		  Padding(
			padding: const EdgeInsets.all(16),
			child: TextField(
			  controller: _searchCtrl,
			  decoration: InputDecoration(
				hintText: 'Search herbs, wildflowers, berries, mushrooms...',
				prefixIcon: const Icon(Icons.search),
				suffixIcon: _query.isEmpty
					? null
					: IconButton(
						icon: const Icon(Icons.clear),
						onPressed: () {
						  _searchCtrl.clear();
						  context.read<EncyclopediaProvider>().clearOnlineSearch();
						  setState(() => _query = '');
						},
					  ),
			  ),
			  onChanged: _onQueryChanged,
			),
		  ),
		  if (_query.trim().isNotEmpty)
			Padding(
			  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
			  child: _OnlineResultsCard(
				query: _query,
				results: online,
				loading: encyclopedia.onlineLoading,
				error: encyclopedia.onlineError,
			  ),
			),
		  Expanded(
			child: encyclopedia.loading
				? const Center(child: CircularProgressIndicator())
				: encyclopedia.error != null
					? EmptyState(
						icon: Icons.error_outline,
						title: 'Could not load encyclopedia',
						subtitle: encyclopedia.error!,
						actionLabel: 'Retry',
						onAction: () => context.read<EncyclopediaProvider>().load(),
					  )
					: TabBarView(
						controller: _tabController,
						children: [
						  _PlantTab(plants: plants),
						  _ForagingTab(entries: forage),
						],
					  ),
		  ),
		],
	  ),
	);
  }

  void _onQueryChanged(String value) {
	setState(() => _query = value);

	_searchDebounce?.cancel();
	_searchDebounce = Timer(const Duration(milliseconds: 450), () {
	  if (!mounted) return;
	  context.read<EncyclopediaProvider>().searchPlantsOnline(
		value,
		countryCode: _countryCode,
	  );
	});
  }
}

class _OnlineResultsCard extends StatelessWidget {
  final String query;
  final List<OnlinePlantSearchResult> results;
  final bool loading;
  final String? error;

  const _OnlineResultsCard({
	required this.query,
	required this.results,
	required this.loading,
	required this.error,
  });

  @override
  Widget build(BuildContext context) {
	if (loading) {
	  return const Card(
		child: Padding(
		  padding: EdgeInsets.all(12),
		  child: Row(
			children: [
			  SizedBox(
				width: 16,
				height: 16,
				child: CircularProgressIndicator(strokeWidth: 2),
			  ),
			  SizedBox(width: 10),
			  Text('Searching online sources...'),
			],
		  ),
		),
	  );
	}

	if (error != null) {
	  return Card(
		child: Padding(
		  padding: const EdgeInsets.all(12),
		  child: Text(error!),
		),
	  );
	}

	if (results.isEmpty) {
	  return const SizedBox.shrink();
	}

	return Card(
	  child: Padding(
		padding: const EdgeInsets.all(12),
		child: Column(
		  crossAxisAlignment: CrossAxisAlignment.start,
		  children: [
			Text(
			  'Online AI/Search Results',
			  style: Theme.of(context)
				  .textTheme
				  .titleMedium
				  ?.copyWith(fontWeight: FontWeight.w700),
			),
			const SizedBox(height: 4),
			Text('Live results for "$query" from free open sources (GBIF, iNaturalist, OpenFarm, Wikipedia, Openverse, Wikidata).'),
			const SizedBox(height: 4),
			Text('Showing ${results.length} open-library matches.'),
			const SizedBox(height: 8),
			...results.take(12).map((r) => _OnlineResultTile(result: r)),
		  ],
		),
	  ),
	);
  }
}

class _OnlineResultTile extends StatelessWidget {
  final OnlinePlantSearchResult result;

  const _OnlineResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
	final provider = context.read<EncyclopediaProvider>();
	final local = provider.findLocalPlantMatch(
	  scientificName: result.scientificName,
	  commonName: result.name,
	);

	return ListTile(
	  contentPadding: EdgeInsets.zero,
	  leading: result.imageUrl != null
		  ? CircleAvatar(backgroundImage: NetworkImage(result.imageUrl!))
		  : const CircleAvatar(child: Icon(Icons.travel_explore)),
	  title: Text(local?.name ?? result.name),
	  subtitle: Column(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  Text('${local?.scientificName ?? result.scientificName} • ${result.source}'),
		  const SizedBox(height: 4),
		  Wrap(
			spacing: 6,
			runSpacing: 4,
			children: [
			  Chip(
				label: Text(result.source),
				visualDensity: VisualDensity.compact,
			  ),
			  Chip(
				label: Text('Confidence ${(result.confidence * 100).toStringAsFixed(0)}%'),
				visualDensity: VisualDensity.compact,
			  ),
			],
		  ),
		],
	  ),
	  trailing: local != null
		  ? const Icon(Icons.chevron_right)
		  : const Icon(Icons.cloud_done, size: 18),
	  onTap: () {
		if (local != null) {
		  context.push('/encyclopedia/plant/${local.id}');
		} else {
		  showDialog<void>(
			context: context,
			builder: (_) => AlertDialog(
			  title: Text(result.name),
			  content: Text(
				result.snippet ??
					'Found in online sources but not in local encyclopedia cache yet.',
			  ),
			  actions: [
				TextButton(
				  onPressed: () => Navigator.of(context).pop(),
				  child: const Text('Close'),
				),
			  ],
			),
		  );
		}
	  },
	);
  }
}

class _PlantTab extends StatelessWidget {
  final List<PlantEntry> plants;

  const _PlantTab({required this.plants});

  @override
  Widget build(BuildContext context) {
	if (plants.isEmpty) {
	  return const EmptyState(
		icon: Icons.local_florist_outlined,
		title: 'No plants found',
		subtitle: 'Try another search term for the offline plant encyclopedia.',
	  );
	}

	final medicinal = plants.where((p) => p.tags.contains('medicinal')).length;
	final pollinator = plants.where((p) => p.tags.contains('pollinator')).length;

	return ListView(
	  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
	  children: [
		const SectionHeader(title: 'Offline Plant Knowledge'),
		const SizedBox(height: 12),
		Row(
		  children: [
			Expanded(
			  child: _SummaryCard(
				color: AppTheme.primary,
				label: 'Plant entries',
				value: '${plants.length}',
				icon: Icons.eco,
			  ),
			),
			const SizedBox(width: 12),
			Expanded(
			  child: _SummaryCard(
				color: AppTheme.accent,
				label: 'Medicinal',
				value: '$medicinal',
				icon: Icons.healing,
			  ),
			),
			const SizedBox(width: 12),
			Expanded(
			  child: _SummaryCard(
				color: Colors.teal,
				label: 'Pollinator',
				value: '$pollinator',
				icon: Icons.hive_outlined,
			  ),
			),
		  ],
		),
		const SizedBox(height: 16),
		...plants.map(
		  (plant) => Card(
			child: ListTile(
			  leading: _PlantAvatar(imageAsset: plant.imageAsset),
			  title: Text(plant.name),
			  subtitle: Text(
				'${plant.category} • ${plant.scientificName}',
				maxLines: 2,
				overflow: TextOverflow.ellipsis,
			  ),
			  trailing: const Icon(Icons.chevron_right),
			  onTap: () => context.push('/encyclopedia/plant/${plant.id}'),
			),
		  ),
		),
	  ],
	);
  }
}

class _ForagingTab extends StatelessWidget {
  final List<ForagingEntry> entries;

  const _ForagingTab({required this.entries});

  @override
  Widget build(BuildContext context) {
	if (entries.isEmpty) {
	  return const EmptyState(
		icon: Icons.travel_explore,
		title: 'No foraging entries found',
		subtitle: 'Try another search term for the offline foraging guide.',
	  );
	}

	return ListView(
	  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
	  children: [
		Card(
		  color: AppTheme.soil.withValues(alpha: 0.08),
		  child: const Padding(
			padding: EdgeInsets.all(16),
			child: Text(
			  'Always verify foraged plants with multiple sources before eating. The offline guide is a field reference, not a substitute for expert confirmation.',
			),
		  ),
		),
		const SizedBox(height: 12),
		...entries.map(
		  (entry) => Card(
			child: ExpansionTile(
			  leading: CircleAvatar(
				backgroundColor: Colors.orange.withValues(alpha: 0.14),
				child: const Icon(Icons.travel_explore, color: Colors.orange),
			  ),
			  title: Text(entry.name),
			  subtitle: Text('${entry.category} • ${entry.edibility}'),
			  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
			  expandedCrossAxisAlignment: CrossAxisAlignment.start,
			  children: [
				Text(entry.description),
				const SizedBox(height: 12),
				_LabelText(label: 'Season', value: entry.season),
				_LabelText(label: 'Habitat', value: entry.habitat.join(', ')),
				_LabelText(
				  label: 'Lookalike danger',
				  value: entry.lookalikeDanger,
				  valueColor: AppTheme.error,
				),
				_LabelText(label: 'Harvest notes', value: entry.harvestNotes),
				_LabelText(
				  label: 'Preparation',
				  value: entry.preparationMethods.join(', '),
				),
				const SizedBox(height: 8),
				Text(
				  'Safety warnings: ${entry.safetyWarnings.join(' • ')}',
				  style: const TextStyle(
					color: AppTheme.error,
					fontWeight: FontWeight.w700,
				  ),
				),
			  ],
			),
		  ),
		),
	  ],
	);
  }
}

class PlantDetailScreen extends StatelessWidget {
  final String plantId;

  const PlantDetailScreen({super.key, required this.plantId});

  @override
  Widget build(BuildContext context) {
	final plant = context.watch<EncyclopediaProvider>().plantById(plantId);
	if (plant == null) {
	  return Scaffold(
		appBar: AppBar(title: const Text('Plant Detail')),
		body: const EmptyState(
		  icon: Icons.local_florist_outlined,
		  title: 'Plant not found',
		  subtitle: 'This encyclopedia entry is missing or still loading.',
		),
	  );
	}

	return Scaffold(
	  appBar: AppBar(title: Text(plant.name)),
	  body: ListView(
		padding: const EdgeInsets.all(16),
		children: [
		  if (plant.imageAsset != null && plant.imageAsset!.isNotEmpty)
			ClipRRect(
			  borderRadius: BorderRadius.circular(20),
			  child: _PlantImage(
				imageAsset: plant.imageAsset!,
				height: 220,
			  ),
			),
		  if (plant.imageAsset != null && plant.imageAsset!.isNotEmpty)
			const SizedBox(height: 16),
		  Container(
			padding: const EdgeInsets.all(20),
			decoration: BoxDecoration(
			  gradient: const LinearGradient(
				colors: [AppTheme.primary, Color(0xFF66BB6A)],
				begin: Alignment.topLeft,
				end: Alignment.bottomRight,
			  ),
			  borderRadius: BorderRadius.circular(24),
			),
			child: Column(
			  crossAxisAlignment: CrossAxisAlignment.start,
			  children: [
				Text(
				  plant.name,
				  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
						color: Colors.white,
						fontWeight: FontWeight.w800,
					  ),
				),
				const SizedBox(height: 4),
				Text(
				  plant.scientificName,
				  style: Theme.of(context).textTheme.titleMedium?.copyWith(
						color: Colors.white.withValues(alpha: 0.88),
						fontStyle: FontStyle.italic,
					  ),
				),
				const SizedBox(height: 12),
				Wrap(
				  spacing: 8,
				  runSpacing: 8,
				  children: plant.tags
					  .map(
						(tag) => Chip(
						  label: Text(tag),
						  backgroundColor: Colors.white.withValues(alpha: 0.14),
						  labelStyle: const TextStyle(color: Colors.white),
						),
					  )
					  .toList(),
				),
			  ],
			),
		  ),
		  const SizedBox(height: 16),
		  Card(
			child: Padding(
			  padding: const EdgeInsets.all(16),
			  child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  const SectionHeader(title: 'Overview'),
				  const SizedBox(height: 8),
				  Text(plant.description),
				  const SizedBox(height: 16),
				  _LabelText(label: 'Family', value: plant.family),
				  _LabelText(label: 'Category', value: plant.category),
				  _LabelText(label: 'Hardiness zone', value: plant.hardinessZone),
				  _LabelText(label: 'Bloom season', value: plant.bloomSeason),
				  _LabelText(
					label: 'Size',
					value: '${plant.heightCm.toStringAsFixed(0)} cm tall × ${plant.spreadCm.toStringAsFixed(0)} cm wide',
				  ),
				],
			  ),
			),
		  ),
		  const SizedBox(height: 16),
		  Card(
			child: Padding(
			  padding: const EdgeInsets.all(16),
			  child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  const SectionHeader(title: 'Growing Conditions'),
				  const SizedBox(height: 8),
				  _LabelText(label: 'Soil', value: plant.soilPreference),
				  _LabelText(label: 'Sunlight', value: plant.sunlight),
				  _LabelText(label: 'Water', value: plant.water),
				  _LabelText(
					label: 'pH range',
					value: '${plant.phMin.toStringAsFixed(1)} – ${plant.phMax.toStringAsFixed(1)}',
				  ),
				  _LabelText(label: 'Propagation', value: plant.propagation),
				],
			  ),
			),
		  ),
		  const SizedBox(height: 16),
		  Card(
			child: Padding(
			  padding: const EdgeInsets.all(16),
			  child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  const SectionHeader(title: 'Uses & Companions'),
				  const SizedBox(height: 8),
				  _LabelText(label: 'Culinary uses', value: plant.culinaryUses),
				  _LabelText(label: 'Medicinal uses', value: plant.medicinalUses),
				  _LabelText(
					label: 'Companion plants',
					value: plant.companionPlants.join(', '),
				  ),
				  if (plant.pestRepellent.isNotEmpty)
					_LabelText(
					  label: 'Repels',
					  value: plant.pestRepellent.join(', '),
					),
				],
			  ),
			),
		  ),
		  const SizedBox(height: 16),
		  Card(
			color: AppTheme.background,
			child: Padding(
			  padding: const EdgeInsets.all(16),
			  child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
				  const SectionHeader(title: 'Gardening Tips'),
				  const SizedBox(height: 8),
				  Text(plant.gardeningTips),
				],
			  ),
			),
		  ),
		],
	  ),
	);
  }
}

class _SummaryCard extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
	required this.color,
	required this.label,
	required this.value,
	required this.icon,
  });

  @override
  Widget build(BuildContext context) {
	return Container(
	  padding: const EdgeInsets.all(14),
	  decoration: BoxDecoration(
		color: color.withValues(alpha: 0.12),
		borderRadius: BorderRadius.circular(18),
	  ),
	  child: Column(
		crossAxisAlignment: CrossAxisAlignment.start,
		children: [
		  Icon(icon, color: color),
		  const SizedBox(height: 10),
		  Text(
			value,
			style: Theme.of(context).textTheme.titleLarge?.copyWith(
				  fontWeight: FontWeight.w800,
				),
		  ),
		  const SizedBox(height: 4),
		  Text(label),
		],
	  ),
	);
  }
}

class _LabelText extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _LabelText({
	required this.label,
	required this.value,
	this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
	return Padding(
	  padding: const EdgeInsets.only(bottom: 10),
	  child: RichText(
		text: TextSpan(
		  style: Theme.of(context).textTheme.bodyMedium,
		  children: [
			TextSpan(
			  text: '$label: ',
			  style: const TextStyle(fontWeight: FontWeight.w700),
			),
			TextSpan(
			  text: value,
			  style: TextStyle(color: valueColor),
			),
		  ],
		),
	  ),
	);
  }
}

class _PlantAvatar extends StatelessWidget {
  final String? imageAsset;

  const _PlantAvatar({this.imageAsset});

  @override
  Widget build(BuildContext context) {
	if (imageAsset == null || imageAsset!.isEmpty) {
	  return CircleAvatar(
		backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
		child: const Icon(Icons.local_florist, color: AppTheme.primary),
	  );
	}

	if (imageAsset!.startsWith('http://') || imageAsset!.startsWith('https://')) {
	  return CircleAvatar(
		backgroundImage: NetworkImage(imageAsset!),
	  );
	}

	return CircleAvatar(
	  backgroundImage: AssetImage(imageAsset!),
	);
  }
}

class _PlantImage extends StatelessWidget {
  final String imageAsset;
  final double height;

  const _PlantImage({required this.imageAsset, required this.height});

  @override
  Widget build(BuildContext context) {
	if (imageAsset.startsWith('http://') || imageAsset.startsWith('https://')) {
	  return Image.network(
		imageAsset,
		height: height,
		width: double.infinity,
		fit: BoxFit.cover,
		errorBuilder: (_, __, ___) => _imageFallback(height),
	  );
	}

	return Image.asset(
	  imageAsset,
	  height: height,
	  width: double.infinity,
	  fit: BoxFit.cover,
	  errorBuilder: (_, __, ___) => _imageFallback(height),
	);
  }

  Widget _imageFallback(double h) {
	return Container(
	  height: h,
	  color: Colors.grey.withValues(alpha: 0.12),
	  child: const Center(
		child: Icon(Icons.local_florist, size: 42, color: Colors.grey),
	  ),
	);
  }
}
