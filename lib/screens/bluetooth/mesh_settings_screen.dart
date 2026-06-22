import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/bluetooth_provider.dart';
import '../../services/mesh_settings_service.dart';

class MeshSettingsScreen extends StatefulWidget {
  const MeshSettingsScreen({super.key});

  @override
  State<MeshSettingsScreen> createState() => _MeshSettingsScreenState();
}

class _MeshSettingsScreenState extends State<MeshSettingsScreen> {
  final _serviceCtrl = TextEditingController();
  final _txCtrl = TextEditingController();
  final _rxCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<BluetoothProvider>().meshSettings;
    if (_serviceCtrl.text.isEmpty) {
      _serviceCtrl.text = settings.serviceUuid;
      _txCtrl.text = settings.txCharUuid;
      _rxCtrl.text = settings.rxCharUuid;
      _secretCtrl.text = settings.hmacSecret;
    }
  }

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _txCtrl.dispose();
    _rxCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesh Runtime Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'These values are applied at runtime and persisted locally. Use the exact UUIDs/secret from your mesh hardware firmware.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _serviceCtrl,
            decoration: const InputDecoration(
              labelText: 'Mesh Service UUID',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _txCtrl,
            decoration: const InputDecoration(
              labelText: 'TX Characteristic UUID',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rxCtrl,
            decoration: const InputDecoration(
              labelText: 'RX Characteristic UUID',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secretCtrl,
            decoration: const InputDecoration(
              labelText: 'HMAC Secret',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          _serviceCtrl.text = MeshRuntimeSettings.defaults.serviceUuid;
                          _txCtrl.text = MeshRuntimeSettings.defaults.txCharUuid;
                          _rxCtrl.text = MeshRuntimeSettings.defaults.rxCharUuid;
                          _secretCtrl.text = MeshRuntimeSettings.defaults.hmacSecret;
                        },
                  child: const Text('Reset Defaults'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final settings = MeshRuntimeSettings(
      serviceUuid: _serviceCtrl.text.trim().toLowerCase(),
      txCharUuid: _txCtrl.text.trim().toLowerCase(),
      rxCharUuid: _rxCtrl.text.trim().toLowerCase(),
      hmacSecret: _secretCtrl.text.trim(),
    );

    await context.read<BluetoothProvider>().saveMeshSettings(settings);

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mesh settings saved.')),
    );
  }
}
