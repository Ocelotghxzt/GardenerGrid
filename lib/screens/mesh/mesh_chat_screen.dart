import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/mesh_provider.dart';
import '../../widgets/empty_state.dart';

class MeshChatScreen extends StatefulWidget {
  const MeshChatScreen({super.key});

  @override
  State<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  final _messageCtrl = TextEditingController();

  @override
  void initState() {
	super.initState();
	WidgetsBinding.instance.addPostFrameCallback((_) {
	  context.read<MeshProvider>().listenToChannel(
			context.read<MeshProvider>().activeChannel,
		  );
	});
  }

  @override
  void dispose() {
	_messageCtrl.dispose();
	super.dispose();
  }

  @override
  Widget build(BuildContext context) {
	final mesh = context.watch<MeshProvider>();
	final ble = context.watch<BluetoothProvider>();
	final auth = context.watch<AuthProvider>();
	final userName = auth.user?.displayName?.trim().isNotEmpty == true
		? auth.user!.displayName!
		: 'Farmer';

	return Scaffold(
	  appBar: AppBar(title: const Text('Mesh Community Chat')),
	  body: Column(
		children: [
		  if (ble.connectedMeshNodeIds.isNotEmpty)
			Container(
			  width: double.infinity,
			  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
			  padding: const EdgeInsets.all(10),
			  decoration: BoxDecoration(
				color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
				borderRadius: BorderRadius.circular(12),
			  ),
			  child: Text(
				'${ble.connectedMeshNodeIds.length} mesh node(s) connected for packet relay',
				style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
			  ),
			),
		  SizedBox(
			height: 58,
			child: ListView.separated(
			  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
			  scrollDirection: Axis.horizontal,
			  itemBuilder: (context, index) {
				final channel = mesh.channels[index];
				final selected = channel == mesh.activeChannel;
				return ChoiceChip(
				  label: Text(channel),
				  selected: selected,
				  onSelected: (_) => context.read<MeshProvider>().listenToChannel(channel),
				);
			  },
			  separatorBuilder: (_, __) => const SizedBox(width: 8),
			  itemCount: mesh.channels.length,
			),
		  ),
		  Expanded(
			child: mesh.messages.isEmpty
				? const EmptyState(
					icon: Icons.forum_outlined,
					title: 'No messages yet',
					subtitle: 'Start the first local conversation in this mesh channel.',
				  )
				: ListView.builder(
					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
					itemCount: mesh.messages.length,
					itemBuilder: (context, index) {
					  final message = mesh.messages[index];
					  final mine = message.senderId == auth.userId;
					  return Align(
						alignment:
							mine ? Alignment.centerRight : Alignment.centerLeft,
						child: Container(
						  margin: const EdgeInsets.only(bottom: 10),
						  padding: const EdgeInsets.all(14),
						  constraints: const BoxConstraints(maxWidth: 420),
						  decoration: BoxDecoration(
							color: mine
								? Theme.of(context).colorScheme.primaryContainer
								: Theme.of(context).cardColor,
							borderRadius: BorderRadius.circular(18),
						  ),
						  child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
							  Row(
								mainAxisSize: MainAxisSize.min,
								children: [
								  Text(
									message.senderName,
									style: const TextStyle(fontWeight: FontWeight.w700),
								  ),
								  if (message.isOffline) ...[
									const SizedBox(width: 8),
									const Icon(Icons.offline_bolt, size: 14),
								  ],
								],
							  ),
							  const SizedBox(height: 4),
							  Text(message.text),
							],
						  ),
						),
					  );
					},
				  ),
		  ),
		  SafeArea(
			top: false,
			child: Padding(
			  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
			  child: Row(
				children: [
				  Expanded(
					child: TextField(
					  controller: _messageCtrl,
					  minLines: 1,
					  maxLines: 4,
					  decoration: const InputDecoration(
						hintText: 'Share field updates, request help, or coordinate locally...',
					  ),
					),
				  ),
				  const SizedBox(width: 12),
				  FloatingActionButton.small(
					onPressed: mesh.loading
						? null
						: () async {
							final meshProvider = context.read<MeshProvider>();
							final text = _messageCtrl.text.trim();
							if (text.isEmpty || auth.userId == null) return;
							_messageCtrl.clear();
							await meshProvider.sendMessage(
								  senderId: auth.userId!,
								  senderName: userName,
								  text: text,
								);
						  },
					child: const Icon(Icons.send),
				  ),
				],
			  ),
			),
		  ),
		],
	  ),
	);
  }
}
