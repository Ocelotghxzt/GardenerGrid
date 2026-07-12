import 'package:flutter/material.dart';
import '../models/soil_sample.dart';
import '../services/ai_memory_service.dart';
import '../services/offline_ai_service.dart';
import '../services/online_ai_service.dart';

class AiChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final String source;
  final String? prompt;
  final bool canBeVerifiedUseful;
  final bool verifiedUseful;

  const AiChatMessage({
    required this.id,
	required this.role,
	required this.content,
	required this.timestamp,
    this.source = 'system',
    this.prompt,
    this.canBeVerifiedUseful = false,
    this.verifiedUseful = false,
  });

  AiChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    String? source,
    String? prompt,
    bool? canBeVerifiedUseful,
    bool? verifiedUseful,
  }) {
    return AiChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      prompt: prompt ?? this.prompt,
      canBeVerifiedUseful: canBeVerifiedUseful ?? this.canBeVerifiedUseful,
      verifiedUseful: verifiedUseful ?? this.verifiedUseful,
    );
  }
}

class AiAssistantProvider extends ChangeNotifier {
  final OnlineAiService _onlineService;
  final AiMemoryService _memoryService;

  OfflineAiService? _offlineService;
  final List<AiChatMessage> _messages = [];
  List<String> _learnedNotes = const [];
  List<VerifiedAiAnswer> _verifiedAnswers = const [];
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
  int get verifiedAnswerCount => _verifiedAnswers.length;
  String? get error => _error;

  AiAssistantProvider(this._onlineService, {AiMemoryService? memoryService})
      : _memoryService = memoryService ?? AiMemoryService();

  void setOfflineService(OfflineAiService service) {
	_offlineService = service;
	notifyListeners();
  }

  Future<void> initialize() async {
    _learnedNotes = await _memoryService.loadNotes();
    _verifiedAnswers = await _memoryService.loadVerifiedAnswers();

	if (!_preferOnline) {
	  final configured = await _onlineService.isConfigured();
	  if (configured) {
		_preferOnline = true;
	  }
	}

	if (_messages.isEmpty) {
	  _messages.add(
		AiChatMessage(
          id: _messageId('assistant'),
		  role: 'assistant',
		  content:
			  'Hi. I can help with plants, vegetables, fruit trees, herbs, soil health, botany, propagation, pests, and practical garden planning. ${_learnedNotes.isEmpty ? "Your GardenerGrid account can use cloud AI automatically, and I’ll start learning from your gardening context as we chat." : "Your GardenerGrid account is ready for cloud AI, and I’m already tracking ${_learnedNotes.length} details about your growing context."}${_verifiedAnswers.isEmpty ? "" : " I also have ${_verifiedAnswers.length} user-verified cloud lessons saved for offline fallback."}',
		  timestamp: DateTime.now(),
          source: 'system',
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
        id: _messageId('user'),
		role: 'user',
		content: message,
		timestamp: DateTime.now(),
	  ),
	);
	_loading = true;
	notifyListeners();

	try {
      _learnedNotes = await _memoryService.learnFromMessage(message);
      final relevantVerifiedInsights = _memoryService.relevantVerifiedInsights(
        question: message,
        verifiedAnswers: _verifiedAnswers,
      );

	  String response;
      var responseSource = 'offline';
      var canBeVerifiedUseful = false;
	  if (onlineMode) {
        final history = _messages
            .take(_messages.length - 1)
            .where((m) => m.role == 'user' || m.role == 'assistant')
            .map((m) => {'role': m.role, 'content': m.content})
            .toList();

		response = await _onlineService.chat(
		  history: history,
		  userMessage: message,
		  soilContext: soilContext,
          learnedContext: _learnedNotes,
          verifiedInsights: relevantVerifiedInsights,
		);

		if (_shouldFallbackToOffline(response)) {
		  response = _offlineFallbackResponse(
            message,
            soilContext: soilContext,
            cloudAttempted: true,
          );
        } else {
          responseSource = 'cloud';
          canBeVerifiedUseful = true;
		}
	  } else {
		response = _offlineFallbackResponse(message, soilContext: soilContext);
	  }

	  _messages.add(
		AiChatMessage(
          id: _messageId('assistant'),
		  role: 'assistant',
		  content: response,
		  timestamp: DateTime.now(),
          source: responseSource,
          prompt: message,
          canBeVerifiedUseful: canBeVerifiedUseful,
		),
	  );
	} catch (e) {
	  _error = e.toString();
	  _messages.add(
		AiChatMessage(
          id: _messageId('assistant'),
		  role: 'assistant',
		  content: '❌ Error: ${e.toString()}',
		  timestamp: DateTime.now(),
          source: 'system',
		),
	  );
	}

	_loading = false;
	notifyListeners();
  }

  bool _shouldFallbackToOffline(String response) {
	return response.startsWith('📡 **Connection failed.') ||
		response.startsWith('🛠️ **Cloud AI not available yet.') ||
		response.startsWith('⏱️ **Cloud AI timed out.') ||
		response.startsWith('⏱️ **Cloud AI is busy.') ||
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
        ? 'Cloud AI was unavailable, so I switched to the built-in plant knowledge base automatically.\n\n'
        : _preferOnline && !_hasConnection
		    ? 'No network detected. Using the built-in plant knowledge base automatically.\n\n'
		    : '';
	return '$note${offline.answer(
      message,
      soilContext: soilContext,
      learnedContext: _learnedNotes,
      verifiedAnswers: _verifiedAnswers,
    )}';
  }

  Future<void> markMessageUseful(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final message = _messages[index];
    if (!message.canBeVerifiedUseful ||
        message.verifiedUseful ||
        message.prompt == null) {
      return;
    }

    _verifiedAnswers = await _memoryService.learnFromVerifiedAnswer(
      question: message.prompt!,
      answer: message.content,
    );
    _messages[index] = message.copyWith(verifiedUseful: true);
    notifyListeners();
  }

  void clearChat() {
	_messages.clear();
	_messages.add(
	  AiChatMessage(
        id: _messageId('assistant'),
		role: 'assistant',
		content:
	  	'Chat cleared. Ask about plant care, vegetables, fruit, herbs, botany, soil, pests, or propagation.',
		timestamp: DateTime.now(),
        source: 'system',
	  ),
	);
	notifyListeners();
  }

  String _messageId(String role) =>
      '$role-${DateTime.now().microsecondsSinceEpoch}-${_messages.length}';
}
