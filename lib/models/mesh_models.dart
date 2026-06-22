import 'package:cloud_firestore/cloud_firestore.dart';

enum MeshFrameType { message, listing, ack, control }

class MeshFrame {
	final String id;
	final MeshFrameType type;
	final String originNodeId;
	final String channelId;
	final int hop;
	final int ttl;
	final bool requiresAck;
	final String? ackFor;
	final String signature;
	final DateTime timestamp;
	final Map<String, dynamic> payload;

	const MeshFrame({
		required this.id,
		required this.type,
		required this.originNodeId,
		required this.channelId,
		required this.hop,
		required this.ttl,
		required this.requiresAck,
		required this.signature,
		required this.timestamp,
		required this.payload,
		this.ackFor,
	});

	MeshFrame nextHop({String? newOriginNodeId}) {
		return MeshFrame(
			id: id,
			type: type,
			originNodeId: newOriginNodeId ?? originNodeId,
			channelId: channelId,
			hop: hop + 1,
			ttl: ttl,
			requiresAck: requiresAck,
			signature: signature,
			timestamp: timestamp,
			payload: payload,
			ackFor: ackFor,
		);
	}

	bool get ttlExpired => hop >= ttl;

	Map<String, dynamic> toMap() => {
				'id': id,
				'type': type.name,
				'originNodeId': originNodeId,
				'channelId': channelId,
				'hop': hop,
				'ttl': ttl,
				'requiresAck': requiresAck,
				'ackFor': ackFor,
				'signature': signature,
				'timestamp': timestamp.toIso8601String(),
				'payload': payload,
			};

	factory MeshFrame.fromMap(Map<String, dynamic> m) {
		final rawType = (m['type'] ?? 'control').toString();
		return MeshFrame(
			id: (m['id'] ?? '').toString(),
			type: MeshFrameType.values.firstWhere(
				(t) => t.name == rawType,
				orElse: () => MeshFrameType.control,
			),
			originNodeId: (m['originNodeId'] ?? '').toString(),
			channelId: (m['channelId'] ?? 'general').toString(),
			hop: (m['hop'] as num?)?.toInt() ?? 0,
			ttl: (m['ttl'] as num?)?.toInt() ?? 5,
			requiresAck: m['requiresAck'] == true,
			ackFor: m['ackFor']?.toString(),
			signature: (m['signature'] ?? '').toString(),
			timestamp: DateTime.tryParse((m['timestamp'] ?? '').toString()) ?? DateTime.now(),
			payload: Map<String, dynamic>.from(m['payload'] ?? const {}),
		);
	}
}

class MeshMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String channelId;
  final bool isOffline;

  const MeshMessage({
	required this.id,
	required this.senderId,
	required this.senderName,
	required this.text,
	required this.timestamp,
	required this.channelId,
	this.isOffline = false,
  });

  factory MeshMessage.fromFirestore(DocumentSnapshot doc) {
	final d = doc.data() as Map<String, dynamic>;
	return MeshMessage(
	  id: doc.id,
	  senderId: d['senderId'] ?? '',
	  senderName: d['senderName'] ?? 'Farmer',
	  text: d['text'] ?? '',
	  timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
	  channelId: d['channelId'] ?? 'general',
	  isOffline: d['isOffline'] ?? false,
	);
  }

  Map<String, dynamic> toFirestore() => {
		'senderId': senderId,
		'senderName': senderName,
		'text': text,
		'timestamp': FieldValue.serverTimestamp(),
		'channelId': channelId,
		'isOffline': isOffline,
	  };
}

enum ListingCategory { produce, seeds, equipment, services, livestock, other }

class MeshListing {
  final String id;
  final String sellerId;
  final String sellerName;
  final String title;
  final String description;
  final double price;
  final String unit;
  final ListingCategory category;
  final String? location;
  final DateTime createdAt;
  final bool isActive;
  final List<String> tags;

  const MeshListing({
	required this.id,
	required this.sellerId,
	required this.sellerName,
	required this.title,
	required this.description,
	required this.price,
	required this.unit,
	required this.category,
	this.location,
	required this.createdAt,
	this.isActive = true,
	this.tags = const [],
  });

  factory MeshListing.fromFirestore(DocumentSnapshot doc) {
	final d = doc.data() as Map<String, dynamic>;
	return MeshListing(
	  id: doc.id,
	  sellerId: d['sellerId'] ?? '',
	  sellerName: d['sellerName'] ?? 'Farmer',
	  title: d['title'] ?? '',
	  description: d['description'] ?? '',
	  price: (d['price'] ?? 0).toDouble(),
	  unit: d['unit'] ?? 'each',
	  category: ListingCategory.values.firstWhere(
		(e) => e.name == (d['category'] ?? 'other'),
		orElse: () => ListingCategory.other,
	  ),
	  location: d['location'],
	  createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
	  isActive: d['isActive'] ?? true,
	  tags: List<String>.from(d['tags'] ?? []),
	);
  }

  Map<String, dynamic> toFirestore() => {
		'sellerId': sellerId,
		'sellerName': sellerName,
		'title': title,
		'description': description,
		'price': price,
		'unit': unit,
		'category': category.name,
		'location': location,
		'createdAt': FieldValue.serverTimestamp(),
		'isActive': isActive,
		'tags': tags,
	  };
}
