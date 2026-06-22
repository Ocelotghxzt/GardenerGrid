import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/soil_provider.dart';
import '../../providers/crop_provider.dart';
import '../../models/soil_sample.dart';
import '../../theme/app_theme.dart';

class SoilInputScreen extends StatefulWidget {
  const SoilInputScreen({super.key});
  @override
  State<SoilInputScreen> createState() => _SoilInputScreenState();
}

class _SoilInputScreenState extends State<SoilInputScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _form = GlobalKey<FormState>();
  final _ph = TextEditingController(text: '7.0');
  final _nitrogen = TextEditingController(text: '0');
  final _phosphorus = TextEditingController(text: '0');
  final _potassium = TextEditingController(text: '0');
  final _moisture = TextEditingController();
  final _ec = TextEditingController();
  final _organicMatter = TextEditingController();
  final _notes = TextEditingController();
  String? _texture;
  bool _submitting = false;

  final List<String> _textures = ['Sandy', 'Loam', 'Clay', 'Silt', 'Sandy Loam', 'Clay Loam'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _submitManual() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    final soilProvider = context.read<SoilProvider>();
    final cropProvider = context.read<CropProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final uid = auth.userId!;
    await soilProvider.submitSample(
      userId: uid,
      values: {
        'ph': double.parse(_ph.text),
        'nitrogen': double.parse(_nitrogen.text),
        'phosphorus': double.parse(_phosphorus.text),
        'potassium': double.parse(_potassium.text),
        'moisture': _moisture.text.isEmpty ? 0.0 : double.tryParse(_moisture.text) ?? 0.0,
        'ec': _ec.text.isEmpty ? 0.0 : double.tryParse(_ec.text) ?? 0.0,
        'organicMatter': _organicMatter.text.isEmpty ? 0.0 : double.tryParse(_organicMatter.text) ?? 0.0,
      },
      source: SampleSource.manual,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      texture: _texture,
    );
    if (!mounted) return;
    final sample = soilProvider.latestSample;
    if (sample != null) {
      cropProvider.updateRecommendations(sample);
    }
    setState(() => _submitting = false);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Soil sample saved and analyzed!'),
        backgroundColor: AppTheme.primary,
      ),
    );
    router.go('/home');
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'csv']);
    if (result == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File "${result.files.first.name}" uploaded. CSV parsing coming soon.'),
          backgroundColor: AppTheme.accent,
        ),
      );
    }
  }

  Widget _buildField(String label, TextEditingController ctrl,
      {String? suffix, String? hint, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: optional ? '$label (optional)' : '$label*',
          suffixText: suffix,
          hintText: hint,
        ),
        validator: (v) {
          if (optional) {
            if (v == null || v.isEmpty) return null;
            if (double.tryParse(v) == null) return 'Enter a number';
            return null;
          }
          if (v == null || v.isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Enter a number';
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Soil Sample'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Manual Entry'),
            Tab(icon: Icon(Icons.upload_file), text: 'Upload Report'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // Manual entry tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('A basic soil test gives you pH, Nitrogen, Phosphorus, and Potassium — that\'s all we require. Fields marked * are required; everything else is optional.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  _buildField('pH Level', _ph,
                      hint: '5.5 – 7.5 ideal', suffix: 'pH'),
                  _buildField('Nitrogen (N)', _nitrogen, suffix: 'ppm'),
                  _buildField('Phosphorus (P)', _phosphorus, suffix: 'ppm'),
                  _buildField('Potassium (K)', _potassium, suffix: 'ppm'),
                  _buildField('Moisture', _moisture, suffix: '%', optional: true),
                  _buildField('Electrical Conductivity', _ec, suffix: 'mS/cm', optional: true),
                  _buildField('Organic Matter', _organicMatter, suffix: '%', optional: true),
                  DropdownButtonFormField<String>(
                    value: _texture,
                    decoration: const InputDecoration(
                      labelText: 'Soil Texture (optional)',
                      hintText: 'Leave empty if unknown',
                    ),
                    items: _textures
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _texture = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        hintText: 'Field location, conditions, etc.'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.analytics),
                      label:
                          Text(_submitting ? 'Analyzing...' : 'Analyze Sample'),
                      onPressed: _submitting ? null : _submitManual,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Upload tab
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Upload a PDF or CSV lab report',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(
                      'The app will read your soil values automatically.\nCSV auto-parsing and PDF OCR will be added in Phase 2.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose File'),
                    onPressed: _uploadFile,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
