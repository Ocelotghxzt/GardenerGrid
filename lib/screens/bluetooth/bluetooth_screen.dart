import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/soil_provider.dart';
import '../../providers/crop_provider.dart';
import '../../models/soil_sample.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});
  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BluetoothProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Sensors')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status card
          Card(
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bluetooth,
                          color: ble.scanning
                              ? AppTheme.primary
                              : Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        ble.scanning ? 'Scanning for sensors...' : 'Bluetooth Ready',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Works with any generic BLE soil sensor.\n'
                    'Dedicated mesh node support coming soon.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scan button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: ble.scanning
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.bluetooth_searching),
              label: Text(ble.scanning ? 'Scanning...' : 'Scan for Devices'),
              onPressed: ble.scanning
                  ? () => context.read<BluetoothProvider>().stopScan()
                  : () => context.read<BluetoothProvider>().startScan(),
            ),
          ),
          if (ble.error != null) ...[
            const SizedBox(height: 8),
            Text(ble.error!,
                style: const TextStyle(color: AppTheme.error),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),

          // Last sensor reading
          if (ble.lastSensorReading != null) ...[
            const Text('Last Sensor Reading',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            _SensorReadingCard(sample: ble.lastSensorReading!),
            const SizedBox(height: 20),
          ],

          // Scan results
          const Text('Nearby Devices',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),

          if (ble.scanResults.isEmpty && !ble.scanning)
            const EmptyState(
              icon: Icons.bluetooth_disabled,
              title: 'No Devices Found',
              subtitle: 'Make sure your sensor is powered on and in range, then scan again.',
            )
          else
            ...ble.scanResults.map((r) => _DeviceTile(scanResult: r)),

          const SizedBox(height: 32),

          _MeshSection(ble: ble),
        ],
      ),
    );
  }
}

class _MeshSection extends StatelessWidget {
  final BluetoothProvider ble;

  const _MeshSection({required this.ble});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Mesh Node Network',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Mesh settings',
                  onPressed: () => context.push('/bluetooth/mesh-settings'),
                  icon: const Icon(Icons.settings),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.read<BluetoothProvider>().discoverMeshNodes(),
                  icon: const Icon(Icons.search),
                  label: const Text('Discover'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Discover nearby BLE mesh relays, connect, and send packets.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (ble.meshNodes.isEmpty)
              const Text(
                'No mesh nodes discovered yet.',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...ble.meshNodes.map((node) {
                final connected = ble.connectedMeshNodeIds.contains(node.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      connected ? Icons.hub : Icons.hub_outlined,
                      color: connected ? AppTheme.primary : Colors.grey,
                    ),
                    title: Text(node.name),
                    subtitle: Text('RSSI ${node.signalStrength} dBm • ${node.id}'),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        TextButton(
                          onPressed: connected
                              ? () => context
                                  .read<BluetoothProvider>()
                                  .disconnectMeshNode(node.id)
                              : () => context
                                  .read<BluetoothProvider>()
                                  .connectMeshNode(node.id),
                          child: Text(connected ? 'Disconnect' : 'Connect'),
                        ),
                        if (connected)
                          IconButton(
                            tooltip: 'Send ping packet',
                            onPressed: () => context
                                .read<BluetoothProvider>()
                                .sendMeshPacket(node.id, 'PING:${DateTime.now().toIso8601String()}'),
                            icon: const Icon(Icons.send),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            if (ble.meshInboundPackets.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Inbound Mesh Packets',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...ble.meshInboundPackets.reversed.take(5).map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${p.receivedAt.hour.toString().padLeft(2, '0')}:${p.receivedAt.minute.toString().padLeft(2, '0')} ${p.nodeId} [${p.frame.type.name}] h${p.frame.hop}/ttl${p.frame.ttl} -> ${p.frame.payload}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final ScanResult scanResult;

  const _DeviceTile({required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final device = scanResult.device;
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : 'Unknown Device';
    final rssi = scanResult.rssi;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.sensors, color: AppTheme.primary),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('RSSI: $rssi dBm · ${device.remoteId}'),
        trailing: ElevatedButton(
          onPressed: () => _connect(context, device, rssi),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Connect'),
        ),
      ),
    );
  }

  Future<void> _connect(
      BuildContext context, BluetoothDevice device, int rssi) async {
    final ble = context.read<BluetoothProvider>();
    final auth = context.read<AuthProvider>();
    final soil = context.read<SoilProvider>();
    final crops = context.read<CropProvider>();
    final sample = await ble.connectAndRead(device, 'default');
    if (sample != null && context.mounted) {
      final uid = auth.userId;
      if (uid != null) {
        await soil.submitSample(
          userId: uid,
          values: {
            'ph': sample.ph,
            'nitrogen': sample.nitrogen,
            'phosphorus': sample.phosphorus,
            'potassium': sample.potassium,
            'moisture': sample.moisture,
            'ec': sample.electricalConductivity,
            'organicMatter': sample.organicMatter,
          },
          notes: sample.notes,
          sensorName: sample.sensorName,
          sensorId: sample.sensorId,
          signalStrength: sample.signalStrength ?? rssi,
          source: SampleSource.bluetoothSensor,
        );
        final latest = soil.latestSample;
        if (latest != null) {
          crops.updateRecommendations(latest);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sensor data read and saved!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }
}

class _SensorReadingCard extends StatelessWidget {
  final SoilSample sample;
  const _SensorReadingCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Live Reading',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${sample.timestamp.hour}:${sample.timestamp.minute.toString().padLeft(2, "0")}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sample.sensorName != null && sample.sensorName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Sensor: ${sample.sensorName}${sample.sensorId != null ? ' • ${sample.sensorId}' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Chip('pH', sample.ph.toStringAsFixed(1)),
                _Chip('N', '${sample.nitrogen.toInt()} ppm'),
                _Chip('P', '${sample.phosphorus.toInt()} ppm'),
                _Chip('K', '${sample.potassium.toInt()} ppm'),
                _Chip('Moisture', '${sample.moisture.toInt()}%'),
                _Chip('EC', '${sample.electricalConductivity} mS/cm'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label: $value',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
      );
}
