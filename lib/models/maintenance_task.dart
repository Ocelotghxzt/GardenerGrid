import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskType { watering, fertilizing, soilAmendment, pestControl, harvest, other }
enum TaskStatus { pending, completed, overdue }

class MaintenanceTask {
  final String id;
  final String userId;
  final String cropId;
  final String cropName;
  final String fieldId;
  final TaskType taskType;
  final String description;
  final DateTime dueDate;
  final TaskStatus status;
  final String? notes;

  const MaintenanceTask({
    required this.id,
    required this.userId,
    required this.cropId,
    required this.cropName,
    required this.fieldId,
    required this.taskType,
    required this.description,
    required this.dueDate,
    required this.status,
    this.notes,
  });

  factory MaintenanceTask.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MaintenanceTask(
      id: doc.id,
      userId: d['userId'] ?? '',
      cropId: d['cropId'] ?? '',
      cropName: d['cropName'] ?? '',
      fieldId: d['fieldId'] ?? '',
      taskType: TaskType.values.firstWhere(
        (e) => e.name == (d['taskType'] ?? 'other'),
        orElse: () => TaskType.other,
      ),
      description: d['description'] ?? '',
      dueDate: (d['dueDate'] as Timestamp).toDate(),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == (d['status'] ?? 'pending'),
        orElse: () => TaskStatus.pending,
      ),
      notes: d['notes'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'cropId': cropId,
    'cropName': cropName,
    'fieldId': fieldId,
    'taskType': taskType.name,
    'description': description,
    'dueDate': Timestamp.fromDate(dueDate),
    'status': status.name,
    'notes': notes,
  };

  MaintenanceTask copyWith({TaskStatus? status, String? notes}) => MaintenanceTask(
    id: id,
    userId: userId,
    cropId: cropId,
    cropName: cropName,
    fieldId: fieldId,
    taskType: taskType,
    description: description,
    dueDate: dueDate,
    status: status ?? this.status,
    notes: notes ?? this.notes,
  );
}
