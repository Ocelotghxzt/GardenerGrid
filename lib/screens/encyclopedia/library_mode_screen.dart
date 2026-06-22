import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/plant_entry.dart';
import '../../providers/encyclopedia_provider.dart';
import '../../providers/soil_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class LibraryModeScreen extends StatefulWidget {
  const LibraryModeScreen({super.key});

  @override
  State<LibraryModeScreen> createState() => _LibraryModeScreenState();
}

class _LibraryModeScreenState extends State<LibraryModeScreen> {
  final _searchCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  bool _medicinalOnly = false;
  int? _zone;
  String? _countryCode;
  final Set<String> _sources = <String>{
    'GBIF',
    'iNaturalist',
    'OpenFarm',
    'Wikipedia Search',
    'Openverse Search',
    'Wikidata Search',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EncyclopediaProvider>().load();
      _useDeviceLocation(silent: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final encyclopedia = context.watch<EncyclopediaProvider>();
    final soil = context.watch<SoilProvider>().latestSample;

    final offline = _filterOffline(encyclopedia.searchPlants(_query));
    final online = encyclopedia.onlinePlantResults
        .where((item) => _sources.contains(item.source))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Reset filters',
            onPressed: _resetFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search the largest gardening library...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location or ZIP',
                      hintText: 'Atlanta, GA or 30301',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _triggerOnlineSearch();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _zone,
                    decoration: const InputDecoration(
                      labelText: 'USDA zone',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Unknown'),
                      ),
                      for (int zone = 3; zone <= 11; zone++)
                        DropdownMenuItem<int>(
                          value: zone,
                          child: Text('Zone $zone'),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _zone = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _useDeviceLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use my location'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _medicinalOnly,
                    title: const Text('Medicinal only'),
                    onChanged: (value) {
                      setState(() => _medicinalOnly = value);
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                for (final source in const [
                  'GBIF',
                  'iNaturalist',
                  'OpenFarm',
                  'Wikipedia Search',
                  'Openverse Search',
                  'Wikidata Search',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      selected: _sources.contains(source),
                      label: Text(source),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _sources.add(source);
                          } else {
                            _sources.remove(source);
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                _StatPill(
                  label: 'Offline entries',
                  value: '${offline.length}',
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: 'Open-source live',
                  value: '${online.length}',
                  color: Colors.teal,
                ),
              ],
            ),
          ),
          Expanded(
            child: (offline.isEmpty && online.isEmpty)
                ? const EmptyState(
                    icon: Icons.menu_book,
                    title: 'No matching library entries',
                    subtitle: 'Try a broader search or enable more sources.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      if (offline.isNotEmpty) ...[
                        const Text(
                          'Offline Encyclopedia',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...offline.take(20).map(
                              (plant) => Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.eco),
                                  ),
                                  title: Text(plant.name),
                                  subtitle: Text(plant.scientificName),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _showPlantDetailSheet(
                                    title: plant.name,
                                    subtitle: plant.scientificName,
                                    source: 'Offline Encyclopedia',
                                    imageUrl: null,
                                    description: plant.description,
                                    localPlant: plant,
                                    similarPlants: const <PlantEntry>[],
                                    soil: soil,
                                    confidence: null,
                                    sourceSnippet: null,
                                    fullEntryAction: () => context.push('/encyclopedia/plant/${plant.id}'),
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: 16),
                      ],
                      if (online.isNotEmpty) ...[
                        const Text(
                          'Open-Source Live Repository',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...online.take(40).map(
                              (item) => Card(
                                child: ListTile(
                                  leading: item.imageUrl == null
                                      ? const CircleAvatar(
                                          child: Icon(Icons.travel_explore),
                                        )
                                      : CircleAvatar(
                                          backgroundImage: NetworkImage(item.imageUrl!),
                                        ),
                                  title: Text(item.name),
                                  subtitle: Text(
                                    '${item.scientificName}\n${item.source} • ${(item.confidence * 100).toStringAsFixed(0)}%',
                                  ),
                                  isThreeLine: true,
                                  onTap: () {
                                    final local = encyclopedia.findLocalPlantMatch(
                                      scientificName: item.scientificName,
                                      commonName: item.name,
                                    );
                                    final similarPlants = local == null
                                        ? encyclopedia.findSimilarLocalPlants(
                                            commonName: item.name,
                                            scientificName: item.scientificName,
                                            family: item.family,
                                            snippet: item.snippet,
                                          )
                                        : const <PlantEntry>[];
                                    _showPlantDetailSheet(
                                      title: item.name,
                                      subtitle: item.scientificName,
                                      source: item.source,
                                      imageUrl: item.imageUrl,
                                      description: item.snippet?.trim().isNotEmpty == true
                                          ? item.snippet!
                                          : 'Open-source reference entry from ${item.source}.',
                                      localPlant: local,
                                      similarPlants: similarPlants,
                                      soil: soil,
                                      confidence: item.confidence,
                                      sourceSnippet: item.snippet,
                                      fullEntryAction: local == null
                                          ? null
                                          : () => context.push('/encyclopedia/plant/${local.id}'),
                                    );
                                  },
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<PlantEntry> _filterOffline(List<PlantEntry> plants) {
    if (!_medicinalOnly) return plants;
    return plants.where((p) {
      final tags = p.tags.map((t) => t.toLowerCase()).toList();
      return tags.contains('medicinal') ||
          p.medicinalUses.trim().isNotEmpty;
    }).toList();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _triggerOnlineSearch();
  }

  void _triggerOnlineSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      context.read<EncyclopediaProvider>().searchPlantsOnline(
            _query,
            countryCode: _effectiveCountryCode,
          );
    });
  }

  String? get _effectiveCountryCode {
  final raw = _locationCtrl.text.trim().toUpperCase();
  if (_countryCode != null && _countryCode!.isNotEmpty) return _countryCode;
  return raw.length == 2 ? raw : null;
  }

  Future<void> _useDeviceLocation({bool silent = false}) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location permission denied. You can still type a ZIP or area manually.')),
      );
    }
    return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (!mounted) return;
    final place = marks.isNotEmpty ? marks.first : null;
    final labelParts = [
    place?.locality,
    place?.administrativeArea,
    place?.postalCode,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    setState(() {
    _countryCode = place?.isoCountryCode;
    if (labelParts.isNotEmpty) {
      _locationCtrl.text = labelParts.join(', ');
    }
    });
    _triggerOnlineSearch();
  } catch (_) {
    if (!silent && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not resolve your location right now. Enter a ZIP or area manually.')),
    );
    }
  }
  }

  void _showPlantDetailSheet({
  required String title,
  required String subtitle,
  required String source,
  required String description,
  required PlantEntry? localPlant,
  required List<PlantEntry> similarPlants,
  required dynamic soil,
  String? imageUrl,
  double? confidence,
  String? sourceSnippet,
  VoidCallback? fullEntryAction,
  }) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) {
    final locationLabel = _locationCtrl.text.trim();
    final survival = _buildSurvivalAssessment(localPlant, similarPlants, soil, locationLabel);
    return SafeArea(
      child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
        Center(
          child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(999),
          ),
          ),
        ),
        const SizedBox(height: 16),
        if (imageUrl != null) ...[
          ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            imageUrl,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          ),
          const SizedBox(height: 16),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
          Chip(label: Text(source)),
          if (confidence != null)
            Chip(label: Text('${(confidence * 100).toStringAsFixed(0)}% match')),
          if (_zone != null)
            Chip(label: Text('Zone $_zone')),
          if (locationLabel.isNotEmpty)
            Chip(label: Text(locationLabel)),
          ],
        ),
        const SizedBox(height: 16),
        Text(description),
        const SizedBox(height: 16),
        Text('Will it survive for me?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(survival),
        if (localPlant == null && similarPlants.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Closest local analogs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final analog in similarPlants)
            _DetailRow(
              label: analog.name,
              value: '${analog.family} • Zone ${analog.hardinessZone} • pH ${analog.phMin.toStringAsFixed(1)}-${analog.phMax.toStringAsFixed(1)}',
            ),
        ],
        if (localPlant != null) ...[
          const SizedBox(height: 16),
          Text('Growing profile', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _DetailRow(label: 'Soil', value: localPlant.soilPreference),
          _DetailRow(label: 'pH range', value: '${localPlant.phMin.toStringAsFixed(1)} - ${localPlant.phMax.toStringAsFixed(1)}'),
          _DetailRow(label: 'Sunlight', value: localPlant.sunlight),
          _DetailRow(label: 'Water', value: localPlant.water),
          _DetailRow(label: 'Hardiness', value: localPlant.hardinessZone),
          _DetailRow(label: 'Propagation', value: localPlant.propagation),
          const SizedBox(height: 8),
          Text(localPlant.gardeningTips),
        ],
        if (sourceSnippet != null && sourceSnippet.trim().isNotEmpty && sourceSnippet.trim() != description.trim()) ...[
          const SizedBox(height: 16),
          Text('Source note', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(sourceSnippet),
        ],
        if (fullEntryAction != null) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            fullEntryAction();
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open full profile'),
          ),
        ],
        ],
      ),
      ),
    );
    },
  );
  }

  String _buildSurvivalAssessment(PlantEntry? plant, List<PlantEntry> similarPlants, dynamic soil, String locationLabel) {
  final pieces = <String>[];
  if (locationLabel.isNotEmpty) {
    pieces.add('Area: $locationLabel.');
  }

  if (plant == null) {
    if (similarPlants.isEmpty) {
      pieces.add('This live result does not have a full local growing profile yet, so soil-fit and hardiness cannot be scored precisely.');
      if (_zone == null) {
        pieces.add('Add your USDA zone to compare winter survival more accurately.');
      }
      return pieces.join(' ');
    }

    final analog = similarPlants.first;
    pieces.add('No exact local profile was found, so this estimate is inferred from similar plants in your library, especially ${analog.name}.');
    pieces.add(_buildZoneAssessment(analog));

    if (soil == null) {
      pieces.add('No saved soil sample is loaded, so I cannot compare your current pH to the closest analog yet.');
    } else {
      final ph = soil.ph as double;
      if (ph >= analog.phMin && ph <= analog.phMax) {
        pieces.add('Your latest soil pH ${ph.toStringAsFixed(1)} fits the closest analog range of ${analog.phMin.toStringAsFixed(1)}-${analog.phMax.toStringAsFixed(1)}, which is a positive sign.');
      } else {
        pieces.add('Your latest soil pH ${ph.toStringAsFixed(1)} sits outside the closest analog range of ${analog.phMin.toStringAsFixed(1)}-${analog.phMax.toStringAsFixed(1)}, so soil amendment may be needed.');
      }
    }

    pieces.add('Treat this as a best-fit estimate until a precise profile is available.');
    return pieces.join(' ');
  }

  final zoneNote = _buildZoneAssessment(plant);
  if (zoneNote.isNotEmpty) {
    pieces.add(zoneNote);
  }

  if (soil == null) {
    pieces.add('No saved soil sample is loaded, so I cannot compare your current pH and nutrients yet.');
  } else {
    final ph = soil.ph as double;
    if (ph >= plant.phMin && ph <= plant.phMax) {
    pieces.add('Your latest soil pH ${ph.toStringAsFixed(1)} is inside this plant\'s preferred ${plant.phMin.toStringAsFixed(1)}-${plant.phMax.toStringAsFixed(1)} range.');
    } else {
    pieces.add('Your latest soil pH ${ph.toStringAsFixed(1)} is outside this plant\'s preferred ${plant.phMin.toStringAsFixed(1)}-${plant.phMax.toStringAsFixed(1)} range, so amendment would likely help.');
    }
    pieces.add('Water need: ${plant.water}. Sun need: ${plant.sunlight}.');
  }

  return pieces.join(' ');
  }

  String _buildZoneAssessment(PlantEntry plant) {
  if (_zone == null) {
    return 'Select your USDA zone to check outdoor survival against ${plant.hardinessZone}.';
  }
  final matches = RegExp(r'\d+').allMatches(plant.hardinessZone).map((m) => int.tryParse(m.group(0)!)).whereType<int>().toList();
  if (matches.isEmpty) {
    return 'This plant lists hardiness ${plant.hardinessZone}. Compare that against your Zone $_zone.';
  }
  final minZone = matches.reduce((a, b) => a < b ? a : b);
  final maxZone = matches.reduce((a, b) => a > b ? a : b);
  if (_zone! < minZone) {
    return 'Your Zone $_zone is colder than the listed ${plant.hardinessZone} range, so outdoor survival is unlikely without protection or container overwintering.';
  }
  if (_zone! > maxZone) {
    return 'Your Zone $_zone is warmer than the listed ${plant.hardinessZone} range, so heat or chill-hour stress may reduce performance.';
  }
  return 'Your Zone $_zone falls inside the listed ${plant.hardinessZone} range, so this plant should be climatically viable in your area if other conditions are met.';
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _medicinalOnly = false;
      _zone = null;
      _countryCode = null;
      _sources
        ..clear()
        ..addAll(const {
          'GBIF',
          'iNaturalist',
          'OpenFarm',
          'Wikipedia Search',
          'Openverse Search',
          'Wikidata Search',
        });
      _searchCtrl.clear();
      _locationCtrl.clear();
    });
    context.read<EncyclopediaProvider>().clearOnlineSearch();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
	return Padding(
	  padding: const EdgeInsets.only(bottom: 6),
	  child: Text('$label: $value'),
	);
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
