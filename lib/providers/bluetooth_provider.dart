import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/mesh_node.dart';
import '../models/soil_sample.dart';
import '../models/mesh_models.dart';
import '../services/bluetooth_service.dart' as ble;
import '../services/mesh_settings_service.dart';

class BluetoothProvider extends ChangeNotifier {
  final ble.BluetoothService _bleService;
  final bool _ownsService;

  List<ScanResult> _scanResults = [];
  bool _scanning = false;
  SoilSample? _lastSensorReading;
  String? _lastSensorName;
  String? _lastSensorId;
  String? _error;
  List<MeshNode> _meshNodes = [];
  Set<String> _connectedMeshNodeIds = {};
  List<ble.MeshInboundPacket> _meshInboundPackets = [];
  MeshRuntimeSettings _meshSettings = MeshRuntimeSettings.defaults;

  List<ScanResult> get scanResults => _scanResults;
  bool get scanning => _scanning;
  SoilSample? get lastSensorReading => _lastSensorReading;
  String? get lastSensorName => _lastSensorName;
  String? get lastSensorId => _lastSensorId;
  String? get error => _error;
  List<MeshNode> get meshNodes => _meshNodes;
  Set<String> get connectedMeshNodeIds => _connectedMeshNodeIds;
  List<ble.MeshInboundPacket> get meshInboundPackets => _meshInboundPackets;
  MeshRuntimeSettings get meshSettings => _meshSettings;

  BluetoothProvider({ble.BluetoothService? bluetoothService})
    : _bleService = bluetoothService ?? ble.BluetoothService(),
      _ownsService = bluetoothService == null {
    _bleService.sensorDataStream.listen((sample) {
      _lastSensorReading = sample;
      _lastSensorName = sample?.sensorName;
      _lastSensorId = sample?.sensorId;
      notifyListeners();
    });

    _bleService.meshInboundStream.listen((packet) {
      _meshInboundPackets = [..._meshInboundPackets, packet].takeLast(100).toList();
      notifyListeners();
    });

    _meshSettings = _bleService.currentMeshSettings();
    _initMeshSettings();
  }

  Future<void> _initMeshSettings() async {
    _meshSettings = await _bleService.getMeshSettings();
    notifyListeners();
  }

  Future<void> startScan() async {
    _scanning = true;
    _error = null;
    _scanResults = [];
    notifyListeners();
    try {
      await _bleService.startScan();
      _bleService.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });
    } catch (e) {
      _error = 'Bluetooth scan failed. Check permissions.';
    }
    _scanning = false;
    notifyListeners();
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
    _scanning = false;
    notifyListeners();
  }

  Future<SoilSample?> connectAndRead(
      BluetoothDevice device, String fieldId) async {
    _error = null;
    notifyListeners();
    final sample = await _bleService.readSensorData(device, fieldId);
    if (sample == null) {
      _error = 'Could not read sensor data from device.';
      notifyListeners();
    }
    return sample;
  }

  // Reserved for mesh node implementation
  Future<void> discoverMeshNodes() async {
    _meshNodes = await _bleService.discoverMeshNodes();
    _connectedMeshNodeIds = _bleService.connectedMeshNodeIds();
    notifyListeners();
  }

  Future<bool> connectMeshNode(String nodeId) async {
    _error = null;
    notifyListeners();

    final ok = await _bleService.connectMeshNode(nodeId);
    if (!ok) {
      _error = 'Could not connect to mesh node.';
    }

    _connectedMeshNodeIds = _bleService.connectedMeshNodeIds();
    _meshNodes = _meshNodes
        .map((n) => n.id == nodeId
            ? MeshNode(
                id: n.id,
                name: n.name,
                bleUuid: n.bleUuid,
                fieldId: n.fieldId,
                batteryLevel: n.batteryLevel,
                signalStrength: n.signalStrength,
                lastSync: DateTime.now(),
                status: ok ? NodeStatus.online : NodeStatus.error,
                extendedData: n.extendedData,
              )
            : n)
        .toList();
    notifyListeners();
    return ok;
  }

  Future<void> disconnectMeshNode(String nodeId) async {
    await _bleService.disconnectMeshNode(nodeId);
    _connectedMeshNodeIds = _bleService.connectedMeshNodeIds();
    _meshNodes = _meshNodes
        .map((n) => n.id == nodeId
            ? MeshNode(
                id: n.id,
                name: n.name,
                bleUuid: n.bleUuid,
                fieldId: n.fieldId,
                batteryLevel: n.batteryLevel,
                signalStrength: n.signalStrength,
                lastSync: n.lastSync,
                status: NodeStatus.offline,
                extendedData: n.extendedData,
              )
            : n)
        .toList();
    notifyListeners();
  }

  Future<bool> sendMeshPacket(String nodeId, String payload) async {
    final ok = await _bleService.sendMeshPacket(nodeId, payload);
    if (!ok) {
      _error = 'Could not send packet to selected mesh node.';
      notifyListeners();
    }
    return ok;
  }

  Future<bool> broadcastMeshPacket(String payload) async {
    final ok = await _bleService.broadcastMeshPacket(payload);
    if (!ok) {
      _error = 'No connected mesh nodes available for broadcast.';
      notifyListeners();
    }
    return ok;
  }

  Future<bool> broadcastMeshFrame(MeshFrame frame) async {
    if (_connectedMeshNodeIds.isEmpty) {
      _error = 'No connected mesh nodes available for broadcast.';
      notifyListeners();
      return false;
    }

    var sentAny = false;
    for (final id in _connectedMeshNodeIds) {
      final ok = await _bleService.sendMeshFrame(id, frame);
      sentAny = sentAny || ok;
    }
    if (!sentAny) {
      _error = 'Could not relay frame to connected mesh nodes.';
      notifyListeners();
    }
    return sentAny;
  }

  Future<void> saveMeshSettings(MeshRuntimeSettings settings) async {
    await _bleService.updateMeshSettings(settings);
    _meshSettings = settings;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_ownsService) {
      _bleService.dispose();
    }
    super.dispose();
  }
}

extension _TakeLastExt<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}
