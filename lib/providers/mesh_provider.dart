import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/mesh_models.dart';
import '../services/bluetooth_service.dart';
import '../services/local_storage_service.dart';
import '../services/mesh_service.dart';

class MeshProvider extends ChangeNotifier {
  final MeshService _service;
  final LocalStorageService _localStorage;
  final BluetoothService? _bleService;
  StreamSubscription<MeshInboundPacket>? _meshInboundSub;
  Timer? _retryReplayTimer;

  List<MeshMessage> _messages = [];
  List<MeshListing> _listings = [];
  List<MeshMessage> _cloudMessages = [];
  List<MeshListing> _cloudListings = [];
  final Map<String, MeshMessage> _inboundMessageOverlay = {};
  final Map<String, MeshListing> _inboundListingOverlay = {};

  String _activeChannel = MeshService.defaultChannels.first;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _syncStatus = const {};

  List<MeshMessage> get messages => _messages;
  List<MeshListing> get listings => _listings;
  String get activeChannel => _activeChannel;
  bool get loading => _loading;
  String? get error => _error;
  List<String> get channels => MeshService.defaultChannels;
  Map<String, dynamic> get syncStatus => _syncStatus;

  MeshProvider(
    this._service,
    this._localStorage, {
    BluetoothService? bluetoothService,
  }) : _bleService = bluetoothService {
    _meshInboundSub =
        _bleService?.meshInboundStream.listen(_handleInboundPacket);
    unawaited(_replayPendingRetryQueue());
    _retryReplayTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => unawaited(_replayPendingRetryQueue()),
    );
  }

  void listenToChannel(String channelId) {
    _activeChannel = channelId;
    _service.messagesStream(channelId).listen((items) {
      _cloudMessages = items;
      _rebuildMessages();
      notifyListeners();
    });
  }

  void listenToMarketplace() {
    _service.activeListingsStream().listen((items) {
      _cloudListings = items;
      _rebuildListings();
      notifyListeners();
    });
  }

  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    required String text,
    bool isOffline = false,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final message = MeshMessage(
        id: const Uuid().v4(),
        senderId: senderId,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
        channelId: _activeChannel,
        isOffline: isOffline,
      );

      await _service.sendMessage(message);

      final frame = MeshFrame(
        id: const Uuid().v4(),
        type: MeshFrameType.message,
        originNodeId: senderId,
        channelId: _activeChannel,
        hop: 0,
        ttl: 5,
        requiresAck: true,
        signature: '',
        timestamp: DateTime.now(),
        payload: {
          'messageId': message.id,
          'senderId': senderId,
          'senderName': senderName,
          'text': text,
        },
      );

      await _service.queueOutboundPacket(
        channelId: _activeChannel,
        payload: frame.toMap(),
      );
      await _localStorage.enqueueMeshRetryPacket(
        id: frame.id,
        channelId: frame.channelId,
        payload: frame.toMap(),
      );
      await _tryRelayQueueItem(frame.id, frame.toMap(), existingAttempts: 0);
    } catch (e) {
      _error = 'Could not send message.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> createListing({
    required String sellerId,
    required String sellerName,
    required String title,
    required String description,
    required double price,
    required String unit,
    required ListingCategory category,
    String? location,
    List<String> tags = const [],
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final listing = MeshListing(
        id: const Uuid().v4(),
        sellerId: sellerId,
        sellerName: sellerName,
        title: title,
        description: description,
        price: price,
        unit: unit,
        category: category,
        location: location,
        createdAt: DateTime.now(),
        tags: tags,
      );

      await _service.createListing(listing);

      final frame = MeshFrame(
        id: const Uuid().v4(),
        type: MeshFrameType.listing,
        originNodeId: sellerId,
        channelId: _activeChannel,
        hop: 0,
        ttl: 5,
        requiresAck: true,
        signature: '',
        timestamp: DateTime.now(),
        payload: {
          'listingId': listing.id,
          'sellerId': sellerId,
          'sellerName': sellerName,
          'title': title,
          'description': description,
          'price': price,
          'unit': unit,
          'category': category.name,
          'location': location,
          'tags': tags,
        },
      );

      await _service.queueOutboundPacket(
        channelId: _activeChannel,
        payload: frame.toMap(),
      );
      await _localStorage.enqueueMeshRetryPacket(
        id: frame.id,
        channelId: frame.channelId,
        payload: frame.toMap(),
      );
      await _tryRelayQueueItem(frame.id, frame.toMap(), existingAttempts: 0);
    } catch (e) {
      _error = 'Could not create marketplace listing.';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> deactivateListing(String id) => _service.deactivateListing(id);

  Future<void> refreshSyncStatus() async {
    _syncStatus = await _service.getSyncStatus();
    notifyListeners();
  }

  Future<void> queueMeshStubMessage(String text) async {
    await _service.queueOutboundPacket(
      channelId: _activeChannel,
      payload: {
        'type': 'message',
        'text': text,
      },
    );
    await refreshSyncStatus();
  }

  Future<void> _replayPendingRetryQueue() async {
    final pending = await _localStorage.getPendingMeshRetryPackets();
    for (final item in pending) {
      await _tryRelayQueueItem(
        item['id'] as String,
        item['payload'] as Map<String, dynamic>,
        existingAttempts: (item['attempts'] as int?) ?? 0,
      );
    }
  }

  Future<void> _tryRelayQueueItem(
    String id,
    Map<String, dynamic> payload, {
    required int existingAttempts,
  }) async {
    if (_bleService == null) {
      await _localStorage.markMeshRetryFailure(
        id,
        'No Bluetooth mesh transport available.',
        existingAttempts + 1,
      );
      return;
    }

    final frame = MeshFrame.fromMap(payload);
    final nodeIds = _bleService.connectedMeshNodeIds();
    if (nodeIds.isEmpty) {
      await _localStorage.markMeshRetryFailure(
        id,
        'No connected mesh nodes.',
        existingAttempts + 1,
      );
      return;
    }

    var sentAny = false;
    for (final nodeId in nodeIds) {
      final ok = await _bleService.sendMeshFrame(nodeId, frame);
      sentAny = sentAny || ok;
    }

    if (sentAny) {
      await _localStorage.markMeshRetrySuccess(id);
    } else {
      await _localStorage.markMeshRetryFailure(
        id,
        'Send failed for all connected nodes.',
        existingAttempts + 1,
      );
    }
  }

  void _handleInboundPacket(MeshInboundPacket packet) {
    final frame = packet.frame;

    if (frame.type == MeshFrameType.message) {
      final msg = MeshMessage(
        id: (frame.payload['messageId'] ?? frame.id).toString(),
        senderId: (frame.payload['senderId'] ?? frame.originNodeId).toString(),
        senderName: (frame.payload['senderName'] ?? 'Mesh Peer').toString(),
        text: (frame.payload['text'] ?? '').toString(),
        timestamp: frame.timestamp,
        channelId: frame.channelId,
        isOffline: true,
      );
      _inboundMessageOverlay[msg.id] = msg;
      _rebuildMessages();
    }

    if (frame.type == MeshFrameType.listing) {
      final listing = MeshListing(
        id: (frame.payload['listingId'] ?? frame.id).toString(),
        sellerId: (frame.payload['sellerId'] ?? frame.originNodeId).toString(),
        sellerName: (frame.payload['sellerName'] ?? 'Mesh Peer').toString(),
        title: (frame.payload['title'] ?? '').toString(),
        description: (frame.payload['description'] ?? '').toString(),
        price: (frame.payload['price'] as num?)?.toDouble() ?? 0,
        unit: (frame.payload['unit'] ?? 'item').toString(),
        category: ListingCategory.values.firstWhere(
          (c) => c.name == (frame.payload['category'] ?? 'other').toString(),
          orElse: () => ListingCategory.other,
        ),
        location: frame.payload['location']?.toString(),
        createdAt: frame.timestamp,
        tags: List<String>.from(frame.payload['tags'] ?? const []),
      );
      _inboundListingOverlay[listing.id] = listing;
      _rebuildListings();
    }

    unawaited(
      _service.queueInboundPacket(
        channelId: frame.channelId,
        payload: frame.toMap(),
      ),
    );
    notifyListeners();
  }

  void _rebuildMessages() {
    final byId = <String, MeshMessage>{
      for (final item in _cloudMessages) item.id: item,
    };

    for (final overlay in _inboundMessageOverlay.values) {
      if (overlay.channelId == _activeChannel) {
        byId[overlay.id] = overlay;
      }
    }

    _messages = byId.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _rebuildListings() {
    final byId = <String, MeshListing>{
      for (final item in _cloudListings) item.id: item,
    };

    for (final overlay in _inboundListingOverlay.values) {
      byId[overlay.id] = overlay;
    }

    _listings = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  void dispose() {
    _meshInboundSub?.cancel();
    _retryReplayTimer?.cancel();
    super.dispose();
  }
}
