import 'package:flutter/material.dart';
import '../models/soil_sample.dart';
import '../services/ai_memory_service.dart';
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
  final AiMemoryService _memoryService;

  OfflineAiService? _offlineService;
  final List<AiChatMessage> _messages = [];
  List<String> _learnedNotes = const [];
  bool _loading = false;
	bool _preferOnline = false;
	bool _hasConnection = true;
  String? _error;

  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
	bool get onlineMode => _preferOnline && _hasConnection;
	bool get preferOnline => _preferOnline;
	bool get hasConnection => _hasConnection;
  List<String> get learnedNotes => List.unmodifiable(_learnedNotes);
  String? get error => _error;

  AiAssistantProvider(this._onlineService, {AiMemoryService? memoryService})
      : _memoryService = memoryService ?? AiMemoryService();

  void setOfflineService(OfflineAiService service) {
	_offlineService = service;
	notifyListeners();
  }

  Future<void> initialize() async {
    _learnedNotes = await _memoryService.loadNotes();

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
			  'Hi. I can help with plants, vegetables, fruit trees, herbs, soil health, botany, propagation, pests, and practical garden planning. ${_learnedNotes.isEmpty ? "I’ll start learning from your gardening context as we chat." : "I’m already tracking ${_learnedNotes.length} details about your growing context."}',
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
      _learnedNotes = await _memoryService.learnFromMessage(message);

	  String response;
	  if (onlineMode) {
		response = await _onlineService.chat(
		  history: _messages
			  .where((m) => m.role == 'user' || m.role == 'assistant')
			  .map((m) => {'role': m.role, 'content': m.content})
			  .toList(),
		  userMessage: message,
		  soilContext: soilContext,
          learnedContext: _learnedNotes,
		);

		if (_shouldFallbackToOffline(response)) {
		  response = _offlineFallbackResponse(
            message,
            soilContext: soilContext,
            cloudAttempted: true,
          );
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

  bool _shouldFallbackToOffline(String response) {
	return response.startsWith('📡 **Connection failed.') ||
		response.startsWith('⚠️ **Online AI not configured.') ||
		response.startsWith('🔑 **Invalid API key') ||
		response.startsWith('⏱️ **Rate limit reached') ||
    response.startsWith('❌ **Server error') ||
		response.contains('Check your internet connection');
  }

  String _offlineFallbackResponse(
    String message, {
    SoilSample? soilContext,
    bool cloudAttempted = false,
  }) {
	final offline = _offlineService;
	if (offline == null) {
	  return 'Offline knowledge is still loading.';
	}

	final note = cloudAttempted
        ? 'Cloud AI was unavailable, so I switched to the built-in plant knowledge base.\n\n'
        : _preferOnline && !_hasConnection
		    ? 'No network detected. Using the built-in plant knowledge base.\n\n'
		    : '';
	return '$note${offline.answer(message, soilContext: soilContext, learnedContext: _learnedNotes)}';
  }

  void clearChat() {
	_messages.clear();
	_messages.add(
	  AiChatMessage(
		role: 'assistant',
		content:
	  	'Chat cleared. Ask about plant care, vegetables, fruit, herbs, botany, soil, pests, or propagation.',
		timestamp: DateTime.now(),
	  ),
	);
	notifyListeners();
  }
}
