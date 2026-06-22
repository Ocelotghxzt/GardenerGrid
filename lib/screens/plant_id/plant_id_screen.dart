import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/encyclopedia_provider.dart';
import '../../services/plant_id_service.dart';
import '../../theme/app_theme.dart';

class PlantIdScreen extends StatefulWidget {
  const PlantIdScreen({super.key});

  @override
  State<PlantIdScreen> createState() => _PlantIdScreenState();
}

class _PlantIdScreenState extends State<PlantIdScreen> {
  final _service = PlantIdService();
  XFile? _selectedImage;
  List<PlantIdMatch>? _results;
  bool _identifying = false;
  String? _countryCode;

  // Form state
  PlantHabit? _habit;
  HabitatType? _habitat;
  FlowerColor? _flowerColor;
  LeafShape? _leafShape;
  final _heightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCountryCode();
  }

  Future<void> _loadCountryCode() async {
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
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      final iso = placemarks.isNotEmpty ? placemarks.first.isoCountryCode : null;
      if (mounted) {
        setState(() => _countryCode = iso);
      }
    } catch (_) {
      // No-op: region boost is optional.
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final img = await (source == ImageSource.camera
        ? _service.takePhoto()
        : _service.pickImageFromGallery());
    if (img != null && mounted) {
      setState(() => _selectedImage = img);
    }
  }

  Future<void> _identify() async {
    final encyclopedia = context.read<EncyclopediaProvider>();
    if (encyclopedia.plants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Encyclopedia is empty. Check app data.')),
      );
      return;
    }

    setState(() => _identifying = true);

    final descriptors = PlantDescriptors(
      plantHabit: _habit,
      habitat: _habitat,
      flowerColor: _flowerColor,
      leafShape: _leafShape,
      heightCm: double.tryParse(_heightCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    // Brief delay for UX
    await Future.delayed(const Duration(milliseconds: 300));

    final results = await _service.identifyWithOpenData(
      image: _selectedImage,
      plants: encyclopedia.plants,
      descriptors: descriptors,
      countryCode: _countryCode,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _identifying = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _results = null;
      _habit = null;
      _habitat = null;
      _flowerColor = null;
      _leafShape = null;
      _heightCtrl.clear();
      _notesCtrl.clear();
    });
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plant Identification'),
        actions: [
          if (_results != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Start over',
            ),
        ],
      ),
      body: _results != null ? _buildResults() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Image capture section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '1. Take or select a photo (optional)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImage!.path),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Descriptor form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Describe the plant',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text('Plant type:', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButtonFormField<PlantHabit>(
                  value: _habit,
                  decoration: const InputDecoration(hintText: 'Select plant type'),
                  items: const [
                    DropdownMenuItem(value: PlantHabit.herb, child: Text('Herb/Flower')),
                    DropdownMenuItem(value: PlantHabit.shrub, child: Text('Shrub')),
                    DropdownMenuItem(value: PlantHabit.tree, child: Text('Tree')),
                    DropdownMenuItem(value: PlantHabit.vine, child: Text('Vine/Climber')),
                    DropdownMenuItem(value: PlantHabit.grass, child: Text('Grass')),
                    DropdownMenuItem(value: PlantHabit.succulent, child: Text('Succulent')),
                  ],
                  onChanged: (v) => setState(() => _habit = v),
                ),
                const SizedBox(height: 12),
                const Text('Where was it found?', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButtonFormField<HabitatType>(
                  value: _habitat,
                  decoration: const InputDecoration(hintText: 'Select habitat'),
                  items: const [
                    DropdownMenuItem(value: HabitatType.garden, child: Text('Garden/Farm')),
                    DropdownMenuItem(value: HabitatType.forest, child: Text('Forest/Woodland')),
                    DropdownMenuItem(value: HabitatType.meadow, child: Text('Meadow/Field')),
                    DropdownMenuItem(value: HabitatType.wetland, child: Text('Wetland')),
                    DropdownMenuItem(value: HabitatType.desert, child: Text('Dry/Arid')),
                    DropdownMenuItem(value: HabitatType.urban, child: Text('Urban/Park')),
                  ],
                  onChanged: (v) => setState(() => _habitat = v),
                ),
                const SizedBox(height: 12),
                const Text('Flower color:', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButtonFormField<FlowerColor>(
                  value: _flowerColor,
                  decoration: const InputDecoration(hintText: 'Select color'),
                  items: const [
                    DropdownMenuItem(value: FlowerColor.white, child: Text('White')),
                    DropdownMenuItem(value: FlowerColor.yellow, child: Text('Yellow')),
                    DropdownMenuItem(value: FlowerColor.pink, child: Text('Pink')),
                    DropdownMenuItem(value: FlowerColor.purple, child: Text('Purple/Blue')),
                    DropdownMenuItem(value: FlowerColor.red, child: Text('Red')),
                    DropdownMenuItem(value: FlowerColor.orange, child: Text('Orange')),
                    DropdownMenuItem(value: FlowerColor.none, child: Text('No flowers')),
                  ],
                  onChanged: (v) => setState(() => _flowerColor = v),
                ),
                const SizedBox(height: 12),
                const Text('Approximate height (cm, optional):', style: TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: _heightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'e.g., 60'),
                ),
                const SizedBox(height: 12),
                const Text('Additional notes (optional):', style: TextStyle(fontWeight: FontWeight.w600)),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Leaf shape, smell, texture, etc.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _identifying
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(_identifying ? 'Identifying...' : 'Identify Plant'),
            onPressed: _identifying ? null : _identify,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResults() {
    final results = _results!;
    return Column(
      children: [
        if (_selectedImage != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Image.file(
              File(_selectedImage!.path),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.search, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                '${results.length} potential match${results.length == 1 ? '' : 'es'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final match = results[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _service.getConfidenceColor(match.confidence),
                    child: Text(
                      '${(match.confidence * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(
                    match.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.scientificName,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (match.hasOnline)
                            _badge('ONLINE AI', Colors.teal),
                          if (match.hasLocal)
                            _badge('LOCAL DATA', Colors.indigo),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_service.getConfidenceLabel(match.confidence)} • ${match.reason}',
                        style: TextStyle(
                          color: _service.getConfidenceColor(match.confidence),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/encyclopedia/plant/${match.id}'),
                ),
              );
            },
          ),
        ),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No matches found. Try adding more descriptors.',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Search Again'),
              onPressed: _reset,
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}