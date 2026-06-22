import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mesh_models.dart';

/// Firestore-backed service for the mesh community network.
/// Abstracts the underlying transport so BLE/LoRa mesh nodes can be
/// plugged in later without changing the provider or UI layers.
class MeshService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesCol(String channelId) =>
	  _db.collection('mesh_channels').doc(channelId).collection('messages');

  CollectionReference<Map<String, dynamic>> get _listingsCol =>
	  _db.collection('mesh_marketplace');

  static const List<String> defaultChannels = [
	'general',
	'soil-talk',
	'seeds-trade',
	'weather',
	'local-news',
  ];

  Stream<List<MeshMessage>> messagesStream(String channelId) {
	return _messagesCol(channelId)
		.orderBy('timestamp', descending: false)
		.limitToLast(100)
		.snapshots()
		.map((snap) => snap.docs.map(MeshMessage.fromFirestore).toList());
  }

  Future<void> sendMessage(MeshMessage message) async {
	await _messagesCol(message.channelId).add(message.toFirestore());
  }

  Stream<List<MeshListing>> activeListingsStream() {
	return _listingsCol
		.where('isActive', isEqualTo: true)
		.orderBy('createdAt', descending: true)
		.limit(100)
		.snapshots()
		.map((snap) => snap.docs.map(MeshListing.fromFirestore).toList());
  }

  Stream<List<MeshListing>> myListingsStream(String userId) {
	return _listingsCol
		.where('sellerId', isEqualTo: userId)
		.orderBy('createdAt', descending: true)
		.snapshots()
		.map((snap) => snap.docs.map(MeshListing.fromFirestore).toList());
  }

  Future<String> createListing(MeshListing listing) async {
	final ref = await _listingsCol.add(listing.toFirestore());
	return ref.id;
  }

  Future<void> updateListing(String id, Map<String, dynamic> updates) async {
	await _listingsCol.doc(id).update(updates);
  }

  Future<void> deactivateListing(String id) async {
	await _listingsCol.doc(id).update({'isActive': false});
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
	return {
	  'transport': 'firestore-fallback',
	  'meshHardwareConnected': false,
	  'pendingOutbound': 0,
	  'pendingInbound': 0,
	  'lastSync': DateTime.now().toIso8601String(),
	};
  }

  Future<void> queueOutboundPacket({
	required String channelId,
	required Map<String, dynamic> payload,
  }) async {
	await _db.collection('mesh_sync_queue').add({
	  'channelId': channelId,
	  'payload': payload,
	  'direction': 'outbound',
	  'transport': 'mesh-node-placeholder',
	  'createdAt': FieldValue.serverTimestamp(),
	  'status': 'queued',
	});
  }

  Future<void> queueInboundPacket({
	required String channelId,
	required Map<String, dynamic> payload,
  }) async {
	await _db.collection('mesh_sync_queue').add({
	  'channelId': channelId,
	  'payload': payload,
	  'direction': 'inbound',
	  'transport': 'mesh-node-placeholder',
	  'createdAt': FieldValue.serverTimestamp(),
	  'status': 'queued',
	});
  }
}
