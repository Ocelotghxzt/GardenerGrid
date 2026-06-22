// Reserved model — will be fully implemented when mesh node hardware specs are provided.

enum NodeStatus { online, offline, error, syncing }

class MeshNode {
  final String id;
  final String name;
  final String bleUuid;
  final String fieldId;
  final int batteryLevel;
  final int signalStrength;
  final DateTime? lastSync;
  final NodeStatus status;
  final Map<String, dynamic> extendedData;

  const MeshNode({
    required this.id,
    required this.name,
    required this.bleUuid,
    required this.fieldId,
    required this.batteryLevel,
    required this.signalStrength,
    this.lastSync,
    required this.status,
    this.extendedData = const {},
  });
}
