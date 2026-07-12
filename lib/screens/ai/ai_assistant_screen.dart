import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../models/soil_sample.dart';
import '../../providers/ai_assistant_provider.dart';
import '../../providers/bluetooth_provider.dart';
import '../../providers/soil_provider.dart';
import '../../theme/app_theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _messageCtrl = TextEditingController();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
	super.initState();
	WidgetsBinding.instance.addPostFrameCallback((_) {
	  final provider = context.read<AiAssistantProvider>();
	  provider.initialize();
	  _startConnectivityMonitor(provider);
	});
  }

  Future<void> _startConnectivityMonitor(AiAssistantProvider provider) async {
	final initial = await _connectivity.checkConnectivity();
	provider.updateConnectivity(_hasConnection(initial));

	_connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
	  provider.updateConnectivity(_hasConnection(results));
	});
  }

  bool _hasConnection(List<ConnectivityResult> results) {
	return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
	_connectivitySub?.cancel();
	_messageCtrl.dispose();
	super.dispose();
  }

  @override
  Widget build(BuildContext context) {
	final ai = context.watch<AiAssistantProvider>();
	final soil = context.watch<SoilProvider>().latestSample;
	final bluetooth = context.watch<BluetoothProvider>();

	return Scaffold(
	  appBar: AppBar(
		title: const Text('AI Assistant'),
		actions: [
		  IconButton(
			icon: const Icon(Icons.delete_sweep_outlined),
			onPressed: ai.clearChat,
		  ),
		],
	  ),
	  body: Column(
		children: [
		  Container(
			width: double.infinity,
			margin: const EdgeInsets.all(16),
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
			  gradient: LinearGradient(
				colors: ai.onlineMode
					? const [Color(0xFF0F766E), Color(0xFF14B8A6)]
					: const [AppTheme.primary, Color(0xFF66BB6A)],
			  ),
			  borderRadius: BorderRadius.circular(20),
			),
			child: Column(
			  crossAxisAlignment: CrossAxisAlignment.start,
			  children: [
				Row(
				  children: [
					Icon(
					  ai.onlineMode
						  ? Icons.cloud_done
						  : ai.preferOnline
							  ? Icons.cloud_off
							  : Icons.offline_bolt,
					  color: Colors.white,
					),
					const SizedBox(width: 10),
					Text(
					  ai.onlineMode
						  ? 'Online AI active'
						  : ai.preferOnline
							  ? 'Offline fallback active'
							  : 'Offline AI active',
					  style: const TextStyle(
						color: Colors.white,
						fontWeight: FontWeight.w800,
						fontSize: 16,
					  ),
					),
					const Spacer(),
					Switch.adaptive(
					  value: ai.preferOnline,
					  onChanged: ai.setOnlineMode,
					  activeThumbColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.35),
					),
				  ],
				),
				const SizedBox(height: 8),
				Text(
				  ai.onlineMode
					  ? 'Your GardenerGrid account is using the cloud assistant.'
					  : ai.preferOnline
						  ? 'Cloud AI is unavailable right now. Using built-in plant knowledge automatically.'
						  : 'Runs fully on-device using built-in plant knowledge and your saved soil data.',
				  style: const TextStyle(color: Colors.white),
				),
				const SizedBox(height: 8),
				Text(
				  ai.hasConnection ? 'Network: Connected' : 'Network: Offline',
				  style: TextStyle(
					color: Colors.white.withValues(alpha: 0.9),
					fontWeight: FontWeight.w600,
				  ),
				),
                if (ai.verifiedAnswerCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Saved offline lessons from verified cloud answers: ${ai.verifiedAnswerCount}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
				if (soil != null) ...[
				  const SizedBox(height: 12),
				  Text(
					'Current soil: pH ${soil.ph.toStringAsFixed(1)} • N ${soil.nitrogen.toStringAsFixed(0)} • P ${soil.phosphorus.toStringAsFixed(0)} • K ${soil.potassium.toStringAsFixed(0)}',
					style: TextStyle(
					  color: Colors.white.withValues(alpha: 0.92),
					  fontWeight: FontWeight.w600,
					),
				  ),
				  if (soil.source == SampleSource.bluetoothSensor)
					Padding(
					  padding: const EdgeInsets.only(top: 8),
					  child: Text(
						'Latest sensor: ${soil.sensorName ?? bluetooth.lastSensorName ?? 'BLE sensor'}',
						style: TextStyle(
						  color: Colors.white.withValues(alpha: 0.9),
						  fontWeight: FontWeight.w600,
						),
					  ),
					),
				],
			  ],
			),
		  ),
		  Expanded(
			child: ai.messages.isEmpty
				? const Center(child: CircularProgressIndicator())
				: ListView.builder(
					padding: const EdgeInsets.symmetric(horizontal: 16),
					itemCount: ai.messages.length,
					itemBuilder: (context, index) {
					  final msg = ai.messages[index];
					  final isUser = msg.role == 'user';
					  return Align(
						alignment:
							isUser ? Alignment.centerRight : Alignment.centerLeft,
						child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              constraints: const BoxConstraints(maxWidth: 720),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isUser
                                      ? AppTheme.primary.withValues(alpha: 0.18)
                                      : Colors.black12,
                                ),
                              ),
                              child: isUser
                                  ? Text(msg.content)
                                  : MarkdownBody(
                                      data: msg.content,
                                      selectable: true,
                                      styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context),
                                      ).copyWith(
                                        p: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                            ),
                            if (!isUser &&
                                (msg.canBeVerifiedUseful || msg.verifiedUseful))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextButton.icon(
                                  onPressed: msg.verifiedUseful || ai.loading
                                      ? null
                                      : () => ai.markMessageUseful(index),
                                  icon: Icon(
                                    msg.verifiedUseful
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    msg.verifiedUseful
                                        ? 'Saved for offline fallback'
                                        : 'Mark useful and teach offline fallback',
                                  ),
                                ),
                              ),
                          ],
                        ),
					  );
					},
				  ),
		  ),
		  if (ai.loading) const LinearProgressIndicator(minHeight: 2),
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
					  maxLines: 5,
					  textInputAction: TextInputAction.newline,
					  decoration: const InputDecoration(
						hintText:
							'Ask about plants, vegetables, fruit trees, herbs, soil, pests, or propagation...',
					  ),
					  onSubmitted: (_) => _send(ai, soil),
					),
				  ),
				  const SizedBox(width: 12),
				  FloatingActionButton.small(
					onPressed: ai.loading ? null : () => _send(ai, soil),
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

  Future<void> _send(AiAssistantProvider ai, SoilSample? soil) async {
	final text = _messageCtrl.text;
	_messageCtrl.clear();
	await ai.sendMessage(text, soilContext: soil);
  }
}
