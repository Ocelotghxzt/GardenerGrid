import 'package:flutter/material.dart';
import '../models/soil_sample.dart';
import '../services/offline_ai_service.dart';
import '../services/online_ai_service.dart';

class AiChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  const AiChatMessage({
	required this.role,
	required this.content,
	required this.timestamp,
  });
}

class AiAssistantProvider extends ChangeNotifier {
  final OnlineAiService _onlineService;

  OfflineAiService? _offlineService;
  final List<AiChatMessage> _messages = [];
  bool _loading = false;
	bool _preferOnline = false;
	bool _hasConnection = true;
  String? _error;

  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
	bool get onlineMode => _preferOnline && _hasConnection;
	bool get preferOnline => _preferOnline;
	bool get hasConnection => _hasConnection;
  String? get error => _error;

  AiAssistantProvider(this._onlineService);

  void setOfflineService(OfflineAiService service) {
	_offlineService = service;
	notifyListeners();
  }

  Future<void> initialize() async {
	if (!_preferOnline) {
	  final configured = await _onlineService.isConfigured();
	  if (configured) {
		_preferOnline = true;
	  }
	}

	if (_messages.isEmpty) {
	  _messages.add(
		AiChatMessage(
		  role: 'assistant',
		  content:
			  'Hi. I can help with soil health, gardening, botany, foraging, and local farmer coordination. Enable online mode for cloud AI, or stay offline for local encyclopedia answers.',
		  timestamp: DateTime.now(),
		),
	  );
	}
	notifyListeners();
  }

  void setOnlineMode(bool enabled) {
	_preferOnline = enabled;
	notifyListeners();
  }

  void updateConnectivity(bool connected) {
	if (_hasConnection == connected) return;
	_hasConnection = connected;
	notifyListeners();
  }

  Future<void> sendMessage(String text, {SoilSample? soilContext}) async {
	final message = text.trim();
	if (message.isEmpty) return;

	_error = null;
	_messages.add(
	  AiChatMessage(
		role: 'user',
		content: message,
		timestamp: DateTime.now(),
	  ),
	);
	_loading = true;
	notifyListeners();

	try {
	  String response;
	  if (onlineMode) {
		response = await _onlineService.chat(
		  history: _messages
			  .where((m) => m.role == 'user' || m.role == 'assistant')
			  .map((m) => {'role': m.role, 'content': m.content})
			  .toList(),
		  userMessage: message,
		  soilContext: soilContext,
		);

		if (_looksLikeConnectivityFailure(response)) {
		  response = _offlineFallbackResponse(message, soilContext: soilContext);
		}
	  } else {
		response = _offlineFallbackResponse(message, soilContext: soilContext);
	  }

	  _messages.add(
		AiChatMessage(
		  role: 'assistant',
		  content: response,
		  timestamp: DateTime.now(),
		),
	  );
	} catch (e) {
	  _error = e.toString();
	  _messages.add(
		AiChatMessage(
		  role: 'assistant',
		  content: '❌ Error: ${e.toString()}',
		  timestamp: DateTime.now(),
		),
	  );
	}

	_loading = false;
	notifyListeners();
  }

  bool _looksLikeConnectivityFailure(String response) {
	return response.startsWith('📡 **Connection failed.') ||
		response.contains('Check your internet connection');
  }

  String _offlineFallbackResponse(String message, {SoilSample? soilContext}) {
	final offline = _offlineService;
	if (offline == null) {
	  return 'Offline knowledge is still loading.';
	}

	final note = _preferOnline && !_hasConnection
		? 'No network detected. Using offline knowledge base.\n\n'
		: '';
	return '$note${offline.answer(message, soilContext: soilContext)}';
  }

  void clearChat() {
	_messages.clear();
	_messages.add(
	  AiChatMessage(
		role: 'assistant',
		content:
			'Chat cleared. Ask about soil, gardening, medicinal plants, foraging, or mesh coordination.',
		timestamp: DateTime.now(),
	  ),
	);
	notifyListeners();
  }
}
