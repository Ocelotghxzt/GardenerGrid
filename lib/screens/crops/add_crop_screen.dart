import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/crop_provider.dart';
import '../../models/crop.dart';
import '../../theme/app_theme.dart';

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});
  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phMin = TextEditingController(text: '5.5');
  final _phMax = TextEditingController(text: '7.5');
  final _nitrogen = TextEditingController(text: '0');
  final _phosphorus = TextEditingController(text: '0');
  final _potassium = TextEditingController(text: '0');
  final _tempMin = TextEditingController(text: '40');
  final _tempMax = TextEditingController(text: '90');
  final _plantingWindow = TextEditingController();
  final _harvestWindow = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Vegetable';
  String _watering = 'Weekly';
  bool _saving = false;

  final _categories = ['Vegetable', 'Fruit', 'Grain', 'Herb', 'Legume', 'Root', 'Other'];
  final _wateringOptions = ['Daily', 'Twice a week', 'Weekly', 'Bi-weekly', 'Monthly'];

  Widget _field(String label, TextEditingController ctrl,
      {String? suffix, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: optional
            ? null
            : (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Enter a number';
                return null;
              },
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final uid = context.read<AuthProvider>().userId!;
    final crop = Crop(
      id: '',
      name: _name.text.trim(),
      category: _category,
      phMin: double.parse(_phMin.text),
      phMax: double.parse(_phMax.text),
      nitrogenNeed: double.parse(_nitrogen.text),
      phosphorusNeed: double.parse(_phosphorus.text),
      potassiumNeed: double.parse(_potassium.text),
      tempMinF: double.parse(_tempMin.text),
      tempMaxF: double.parse(_tempMax.text),
      wateringFrequency: _watering,
      plantingWindow: _plantingWindow.text.trim().isEmpty
          ? null : _plantingWindow.text.trim(),
      harvestWindow: _harvestWindow.text.trim().isEmpty
          ? null : _harvestWindow.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      isCustom: true,
    );
    await context.read<CropProvider>().addCustomCrop(crop, uid);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom crop saved!'),
            backgroundColor: AppTheme.primary),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Custom Crop')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Crop Name'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field('pH Min', _phMin, suffix: 'pH')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('pH Max', _phMax, suffix: 'pH')),
                ],
              ),
              _field('Nitrogen Need', _nitrogen, suffix: 'ppm'),
              _field('Phosphorus Need', _phosphorus, suffix: 'ppm'),
              _field('Potassium Need', _potassium, suffix: 'ppm'),
              Row(
                children: [
                  Expanded(child: _field('Min Temp', _tempMin, suffix: '°F')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Max Temp', _tempMax, suffix: '°F')),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _watering,
                decoration: const InputDecoration(labelText: 'Watering Frequency'),
                items: _wateringOptions
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: (v) => setState(() => _watering = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _plantingWindow,
                decoration: const InputDecoration(
                    labelText: 'Planting Window (optional)',
                    hintText: 'e.g. March – May'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _harvestWindow,
                decoration: const InputDecoration(
                    labelText: 'Harvest Window (optional)',
                    hintText: 'e.g. July – September'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save Crop'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
