import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/soil_provider.dart';
import '../../providers/crop_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/maintenance_task.dart';
import '../../models/crop.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final soil = context.watch<SoilProvider>();
    final uid = auth.userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
        backgroundColor: AppTheme.primary,
        onPressed: () => _showAddTaskSheet(context),
      ),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<MaintenanceTask>>(
              stream: _firestoreService.tasksStream(uid),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tasks = snap.data ?? [];

                if (tasks.isEmpty) {
                  return const EmptyState(
                    icon: Icons.calendar_today,
                    title: 'No Tasks',
                    subtitle:
                        'Add maintenance tasks to track watering, fertilizing, and more.',
                  );
                }

                final pending =
                    tasks.where((t) => t.status == TaskStatus.pending).toList();
                final completed =
                    tasks.where((t) => t.status == TaskStatus.completed).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Soil summary banner
                    if (soil.latestSample != null &&
                        soil.latestSample!.amendments.isNotEmpty)
                      Card(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppTheme.accent),
                                  SizedBox(width: 8),
                                  Text('Soil Recommendations',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...soil.latestSample!.amendments
                                  .map((a) => Text('• $a')),
                            ],
                          ),
                        ),
                      ),

                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Upcoming Tasks',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...pending.map((t) => _TaskTile(
                            task: t,
                            onComplete: () => _firestoreService
                                .updateTaskStatus(
                                    uid, t.id, TaskStatus.completed),
                          )),
                    ],

                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Completed',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...completed.map((t) => _TaskTile(task: t)),
                    ],
                  ],
                );
              },
            ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    final crops = context.read<CropProvider>().allCrops;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddTaskSheet(crops: crops),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final MaintenanceTask task;
  final VoidCallback? onComplete;

  const _TaskTile({required this.task, this.onComplete});

  IconData get _icon => switch (task.taskType) {
        TaskType.watering => Icons.water_drop,
        TaskType.fertilizing => Icons.science,
        TaskType.soilAmendment => Icons.landscape,
        TaskType.pestControl => Icons.bug_report,
        TaskType.harvest => Icons.agriculture,
        TaskType.other => Icons.task_alt,
      };

  Color get _color => switch (task.taskType) {
        TaskType.watering => Colors.blue,
        TaskType.fertilizing => Colors.green,
        TaskType.soilAmendment => AppTheme.soil,
        TaskType.pestControl => Colors.red,
        TaskType.harvest => AppTheme.accent,
        TaskType.other => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.dueDate.isBefore(DateTime.now()) &&
        task.status != TaskStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color.withValues(alpha: 0.15),
          child: Icon(_icon, color: _color, size: 20),
        ),
        title: Text(
          task.description,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.status == TaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
            color: task.status == TaskStatus.completed ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          '${task.cropName} · Due: ${DateFormat("MMM d").format(task.dueDate)}',
          style: TextStyle(color: isOverdue ? AppTheme.error : null),
        ),
        trailing: onComplete != null && task.status != TaskStatus.completed
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: AppTheme.primary,
                onPressed: onComplete,
              )
            : task.status == TaskStatus.completed
                ? const Icon(Icons.check_circle,
                    color: AppTheme.primaryLight)
                : null,
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final List<Crop> crops;
  const _AddTaskSheet({required this.crops});
  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  TaskType _type = TaskType.watering;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  Crop? _selectedCrop;
  bool _saving = false;
  final _firestoreService = FirestoreService();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a crop')));
      return;
    }
    setState(() => _saving = true);
    final uid = context.read<AuthProvider>().userId!;
    final task = MaintenanceTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: uid,
      cropId: _selectedCrop!.id,
      cropName: _selectedCrop!.name,
      fieldId: 'default',
      taskType: _type,
      description: _description.text.trim(),
      dueDate: _dueDate,
      status: TaskStatus.pending,
    );
    await _firestoreService.saveTask(task, uid);
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Maintenance Task',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<Crop>(
              decoration: const InputDecoration(labelText: 'Crop'),
              items: widget.crops
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (c) => setState(() => _selectedCrop = c),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<TaskType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Task Type'),
              items: TaskType.values
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(t.name[0].toUpperCase() + t.name.substring(1))))
                  .toList(),
              onChanged: (t) => setState(() => _type = t!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Due: ${DateFormat("MMM d, y").format(_dueDate)}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Task'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
