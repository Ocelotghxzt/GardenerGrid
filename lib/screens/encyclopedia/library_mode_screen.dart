import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/plant_entry.dart';
import '../../providers/encyclopedia_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class LibraryModeScreen extends StatefulWidget {
  const LibraryModeScreen({super.key});

  @override
  State<LibraryModeScreen> createState() => _LibraryModeScreenState();
}

class _LibraryModeScreenState extends State<LibraryModeScreen> {
  final _searchCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  bool _medicinalOnly = false;
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
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final encyclopedia = context.watch<EncyclopediaProvider>();

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
                    controller: _countryCtrl,
                    maxLength: 2,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Country code (optional)',
                      hintText: 'US',
                      counterText: '',
                    ),
                    onChanged: (_) => _triggerOnlineSearch(),
                  ),
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
                                  onTap: () => context.push('/encyclopedia/plant/${plant.id}'),
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
                                    showDialog<void>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(item.name),
                                        content: Text(
                                          item.snippet?.trim().isNotEmpty == true
                                              ? item.snippet!
                                              : 'Open-source reference entry from ${item.source}.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
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
      final cc = _countryCtrl.text.trim().toUpperCase();
      context.read<EncyclopediaProvider>().searchPlantsOnline(
            _query,
            countryCode: cc.length == 2 ? cc : null,
          );
    });
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _medicinalOnly = false;
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
      _countryCtrl.clear();
    });
    context.read<EncyclopediaProvider>().clearOnlineSearch();
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
