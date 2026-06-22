import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/soil_sample.dart';
import '../models/mesh_node.dart';
import '../models/mesh_models.dart';
import 'mesh_settings_service.dart';

class MeshInboundPacket {
  final String nodeId;
  final DateTime receivedAt;
  final MeshFrame frame;

  const MeshInboundPacket({
    required this.nodeId,
    required this.receivedAt,
    required this.frame,
  });
}

class BluetoothService {
  final StreamController<SoilSample?> _sensorDataController =
      StreamController.broadcast();
  final StreamController<MeshInboundPacket> _meshInboundController =
      StreamController.broadcast();

  final Map<String, BluetoothDevice> _meshDevicesById = {};
  final Map<String, BluetoothCharacteristic> _meshWriteByNodeId = {};
  final Map<String, BluetoothCharacteristic> _meshNotifyByNodeId = {};
  final Set<String> _connectedMeshNodeIds = {};
  final Map<String, Completer<void>> _ackWaiters = {};
  final Set<String> _seenFrameIds = {};
  final MeshSettingsService _meshSettingsService;
  MeshRuntimeSettings _meshSettings = MeshRuntimeSettings.defaults;
  Future<void>? _initFuture;

  Stream<SoilSample?> get sensorDataStream => _sensorDataController.stream;
  Stream<MeshInboundPacket> get meshInboundStream => _meshInboundController.stream;

  static const int _defaultTtl = 5;
  static const int _maxRetries = 3;
  static const Duration _ackTimeout = Duration(milliseconds: 900);

  BluetoothService({MeshSettingsService? meshSettingsService})
      : _meshSettingsService = meshSettingsService ?? MeshSettingsService() {
    _initFuture = _loadSettings();
  }

  Future<void> _loadSettings() async {
    _meshSettings = await _meshSettingsService.load();
  }

  Future<void> _ensureInitialized() async {
    await (_initFuture ?? Future<void>.value());
  }

  MeshRuntimeSettings currentMeshSettings() => _meshSettings;

  Future<MeshRuntimeSettings> getMeshSettings() async {
    await _ensureInitialized();
    return _meshSettings;
  }

  Future<void> updateMeshSettings(MeshRuntimeSettings settings) async {
    _meshSettings = settings;
    await _meshSettingsService.save(settings);
  }

  // Start scanning for any BLE device advertising soil sensor characteristics.
  // Generic approach — works with any BLE sensor until specific UUIDs are known.
  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  // Connect to a device and attempt to read soil data characteristics.
  // Maps generic BLE GATT values to SoilSample fields.
  // Specific UUIDs will be added when mesh node hardware specs are provided.
  Future<SoilSample?> readSensorData(
      BluetoothDevice device, String fieldId) async {
    try {
      final sensorName =
          device.platformName.isNotEmpty ? device.platformName : 'BLE Sensor';
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );
      final services = await device.discoverServices();

      double ph = 7.0;
      double moisture = 0;
      double nitrogen = 0;
      double phosphorus = 0;
      double potassium = 0;
      double ec = 0;

      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.read) {
            final value = await char.read();
            if (value.isEmpty) continue;
            // Parse based on characteristic UUID suffix — extend per device spec
            final uuidSuffix = char.uuid.toString().split('-').last;
            switch (uuidSuffix) {
              case '0001': ph = _decodeFloat(value); break;
              case '0002': moisture = _decodeFloat(value); break;
              case '0003': nitrogen = _decodeFloat(value); break;
              case '0004': phosphorus = _decodeFloat(value); break;
              case '0005': potassium = _decodeFloat(value); break;
              case '0006': ec = _decodeFloat(value); break;
            }
          }
        }
      }

      final sample = SoilSample(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fieldId: fieldId,
        timestamp: DateTime.now(),
        ph: ph,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        moisture: moisture,
        electricalConductivity: ec,
        organicMatter: 0,
        notes: 'Captured from $sensorName over Bluetooth.',
        sensorName: sensorName,
        sensorId: device.remoteId.str,
        source: SampleSource.bluetoothSensor,
      );

      _sensorDataController.add(sample);
      await device.disconnect();
      return sample;
    } catch (_) {
      await device.disconnect();
      return null;
    }
  }

  double _decodeFloat(List<int> bytes) {
    if (bytes.length < 2) return 0;
    return ((bytes[0] << 8) | bytes[1]) / 100.0;
  }

  // Reserved: mesh node discovery — to be expanded with mesh node specs
  Future<List<MeshNode>> discoverMeshNodes() async {
    await _ensureInitialized();
    List<ScanResult> latest = [];
    final sub = scanResults.listen((results) {
      latest = results;
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();
    await sub.cancel();

    final nodes = <MeshNode>[];

    for (final result in latest) {
      final device = result.device;
      final advServices = result.advertisementData.serviceUuids
          .map((u) => u.toString().toLowerCase())
          .toList();

      if (!advServices.contains(_meshSettings.serviceUuid.toLowerCase())) {
        continue;
      }

      final id = device.remoteId.str;
      _meshDevicesById[id] = device;

      nodes.add(
        MeshNode(
          id: id,
          name: device.platformName.isNotEmpty ? device.platformName : 'Mesh Node',
          bleUuid: _meshSettings.serviceUuid,
          fieldId: 'default',
          batteryLevel: 0,
          signalStrength: result.rssi,
          lastSync: null,
          status: _connectedMeshNodeIds.contains(id)
              ? NodeStatus.online
              : NodeStatus.offline,
          extendedData: {
            'advertisedServices': advServices,
          },
        ),
      );
    }

    return nodes;
  }

  Future<bool> connectMeshNode(String nodeId) async {
    await _ensureInitialized();
    final device = _meshDevicesById[nodeId];
    if (device == null) return false;

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
      );

      final services = await device.discoverServices();
      BluetoothCharacteristic? writeChar;
      BluetoothCharacteristic? notifyChar;

      for (final service in services) {
        if (!_uuidEq(service.uuid.str, _meshSettings.serviceUuid)) {
          continue;
        }

        for (final c in service.characteristics) {
          if (writeChar == null &&
              _uuidEq(c.uuid.str, _meshSettings.txCharUuid) &&
              (c.properties.write || c.properties.writeWithoutResponse)) {
            writeChar = c;
          }
          if (notifyChar == null &&
              _uuidEq(c.uuid.str, _meshSettings.rxCharUuid) &&
              (c.properties.notify || c.properties.indicate)) {
            notifyChar = c;
          }
        }
      }

      if (writeChar == null) {
        return false;
      }

      if (notifyChar == null) {
        return false;
      }

      _meshWriteByNodeId[nodeId] = writeChar;
      _meshNotifyByNodeId[nodeId] = notifyChar;
      await _attachNotifyListener(nodeId, notifyChar);

      _connectedMeshNodeIds.add(nodeId);
      return true;
    } catch (_) {
      try {
        await device.disconnect();
      } catch (_) {}
      return false;
    }
  }

  Future<void> disconnectMeshNode(String nodeId) async {
    final device = _meshDevicesById[nodeId];
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectedMeshNodeIds.remove(nodeId);
    _meshWriteByNodeId.remove(nodeId);
    _meshNotifyByNodeId.remove(nodeId);
  }

  Future<bool> sendMeshPacket(String nodeId, String text) async {
    final unsigned = MeshFrame(
      id: const Uuid().v4(),
      type: MeshFrameType.message,
      originNodeId: nodeId,
      channelId: 'general',
      hop: 0,
      ttl: _defaultTtl,
      requiresAck: true,
      signature: '',
      timestamp: DateTime.now(),
      payload: {
        'text': text,
      },
    );
    final frame = _signFrame(unsigned);
    return sendMeshFrame(nodeId, frame, retries: _maxRetries);
  }

  Future<bool> sendMeshFrame(
    String nodeId,
    MeshFrame frame, {
    int retries = _maxRetries,
  }) async {
    await _ensureInitialized();
    final signedFrame = frame.signature.isNotEmpty ? frame : _signFrame(frame);

    final write = _meshWriteByNodeId[nodeId];
    if (write == null) {
      final connected = await connectMeshNode(nodeId);
      if (!connected) return false;
    }

    final char = _meshWriteByNodeId[nodeId];
    if (char == null) return false;

    var attempt = 0;
    while (attempt <= retries) {
      attempt += 1;
      try {
        Completer<void>? waiter;
        if (signedFrame.requiresAck) {
          waiter = Completer<void>();
          _ackWaiters[signedFrame.id] = waiter;
        }

        final bytes = utf8.encode(jsonEncode(signedFrame.toMap()));
        if (char.properties.write) {
          await char.write(bytes, withoutResponse: false);
        } else {
          await char.write(bytes, withoutResponse: true);
        }

        if (!signedFrame.requiresAck) {
          return true;
        }

        try {
          await waiter!.future.timeout(_ackTimeout);
          return true;
        } catch (_) {
          _ackWaiters.remove(signedFrame.id);
          if (attempt > retries) {
            return false;
          }
        }
      } catch (_) {
        if (attempt > retries) {
          return false;
        }
      }
    }

    return false;
  }

  Future<void> _attachNotifyListener(
      String nodeId, BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      characteristic.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        final payload = utf8.decode(data, allowMalformed: true);
        final parsed = _tryParseFrame(payload);
        if (parsed == null) return;
        if (!_verifyFrameSignature(parsed)) return;

        if (_seenFrameIds.contains(parsed.id)) {
          return;
        }
        _seenFrameIds.add(parsed.id);
        if (_seenFrameIds.length > 500) {
          _seenFrameIds.remove(_seenFrameIds.first);
        }

        if (parsed.type == MeshFrameType.ack && parsed.ackFor != null) {
          final waiter = _ackWaiters.remove(parsed.ackFor!);
          waiter?.complete();
          return;
        }

        if (parsed.requiresAck) {
          final unsignedAck = MeshFrame(
            id: const Uuid().v4(),
            type: MeshFrameType.ack,
            originNodeId: nodeId,
            channelId: parsed.channelId,
            hop: 0,
            ttl: _defaultTtl,
            requiresAck: false,
            ackFor: parsed.id,
            signature: '',
            timestamp: DateTime.now(),
            payload: const {'status': 'ok'},
          );
          final ack = _signFrame(unsignedAck);
          unawaited(sendMeshFrame(nodeId, ack, retries: 0));
        }

        if (parsed.ttlExpired) {
          return;
        }

        _meshInboundController.add(
          MeshInboundPacket(
            nodeId: nodeId,
            receivedAt: DateTime.now(),
            frame: parsed,
          ),
        );
      });
    } catch (_) {
      // Notification path is optional; writes can still work.
    }
  }

  bool isMeshNodeConnected(String nodeId) => _connectedMeshNodeIds.contains(nodeId);

  Set<String> connectedMeshNodeIds() => Set.unmodifiable(_connectedMeshNodeIds);

  Future<bool> broadcastMeshPacket(String text) async {
    if (_connectedMeshNodeIds.isEmpty) return false;

    final unsigned = MeshFrame(
      id: const Uuid().v4(),
      type: MeshFrameType.message,
      originNodeId: 'local',
      channelId: 'general',
      hop: 0,
      ttl: _defaultTtl,
      requiresAck: true,
      signature: '',
      timestamp: DateTime.now(),
      payload: {
        'text': text,
      },
    );
    final frame = _signFrame(unsigned);

    var sentAny = false;
    for (final id in _connectedMeshNodeIds) {
      final ok = await sendMeshFrame(id, frame, retries: _maxRetries);
      sentAny = sentAny || ok;
    }
    return sentAny;
  }

  bool _uuidEq(String a, String b) => a.toLowerCase() == b.toLowerCase();

  MeshFrame _signFrame(MeshFrame frame) {
    final canonical = _canonicalForSignature(frame);
    final digest = Hmac(
      sha256,
      utf8.encode(_meshSettings.hmacSecret),
    ).convert(utf8.encode(canonical));

    return MeshFrame(
      id: frame.id,
      type: frame.type,
      originNodeId: frame.originNodeId,
      channelId: frame.channelId,
      hop: frame.hop,
      ttl: frame.ttl,
      requiresAck: frame.requiresAck,
      ackFor: frame.ackFor,
      signature: digest.toString(),
      timestamp: frame.timestamp,
      payload: frame.payload,
    );
  }

  bool _verifyFrameSignature(MeshFrame frame) {
    if (frame.signature.isEmpty) {
      return false;
    }

    final unsigned = MeshFrame(
      id: frame.id,
      type: frame.type,
      originNodeId: frame.originNodeId,
      channelId: frame.channelId,
      hop: frame.hop,
      ttl: frame.ttl,
      requiresAck: frame.requiresAck,
      ackFor: frame.ackFor,
      signature: '',
      timestamp: frame.timestamp,
      payload: frame.payload,
    );

    return _signFrame(unsigned).signature == frame.signature;
  }

  String _canonicalForSignature(MeshFrame frame) {
    final payloadJson = jsonEncode(_sortMap(frame.payload));
    return [
      frame.id,
      frame.type.name,
      frame.originNodeId,
      frame.channelId,
      frame.hop.toString(),
      frame.ttl.toString(),
      frame.requiresAck.toString(),
      frame.ackFor ?? '',
      frame.timestamp.toIso8601String(),
      payloadJson,
    ].join('|');
  }

  Map<String, dynamic> _sortMap(Map<String, dynamic> input) {
    final keys = input.keys.toList()..sort();
    final out = <String, dynamic>{};
    for (final key in keys) {
      final value = input[key];
      if (value is Map<String, dynamic>) {
        out[key] = _sortMap(value);
      } else {
        out[key] = value;
      }
    }
    return out;
  }

  MeshFrame? _tryParseFrame(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      return MeshFrame.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _sensorDataController.close();
    _meshInboundController.close();
  }
}
