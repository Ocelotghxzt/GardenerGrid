import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/soil_sample.dart';

/// Calls an OpenAI-compatible chat-completion endpoint.
/// API key and endpoint are stored in SharedPreferences so the user can
/// configure them inside the app without a rebuild.
class OnlineAiService {
  static const _keyApiKey = 'ai_api_key';
  static const _keyEndpoint = 'ai_endpoint';
	static const _defaultEndpoint = 'https://api.deepseek.com/chat/completions';
  static const _defaultModel = 'deepseek-chat';

  // ── Configuration ─────────────────────────────────────────────────────────
  Future<String?> getApiKey() async {
	final prefs = await SharedPreferences.getInstance();
	return prefs.getString(_keyApiKey);
  }

  Future<void> saveApiKey(String key) async {
	final prefs = await SharedPreferences.getInstance();
	await prefs.setString(_keyApiKey, key);
  }

  Future<String> getEndpoint() async {
	final prefs = await SharedPreferences.getInstance();
	return prefs.getString(_keyEndpoint) ?? _defaultEndpoint;
  }

  Future<void> saveEndpoint(String url) async {
	final prefs = await SharedPreferences.getInstance();
	await prefs.setString(_keyEndpoint, url);
  }

  Future<bool> isConfigured() async {
	final key = await getApiKey();
	return key != null && key.isNotEmpty;
  }

  // ── System prompt ─────────────────────────────────────────────────────────
  String _systemPrompt({SoilSample? soilContext}) {
	final soilSection = soilContext != null
		? '''
The user's current soil readings are:
- pH: ${soilContext.ph.toStringAsFixed(1)}
- Nitrogen: ${soilContext.nitrogen.toStringAsFixed(0)} ppm
- Phosphorus: ${soilContext.phosphorus.toStringAsFixed(0)} ppm
- Potassium: ${soilContext.potassium.toStringAsFixed(0)} ppm
- Moisture: ${soilContext.moisture.toStringAsFixed(0)}%
- Organic Matter: ${soilContext.organicMatter.toStringAsFixed(1)}%
- Deficiencies: ${soilContext.deficiencies.isEmpty ? 'None detected' : soilContext.deficiencies.join(', ')}
- Health Score: ${soilContext.healthScore ?? 'N/A'}/100
- Source: ${soilContext.source.name}
- Sensor Name: ${soilContext.sensorName ?? 'N/A'}
- Sensor ID: ${soilContext.sensorId ?? 'N/A'}
- Signal Strength: ${soilContext.signalStrength?.toString() ?? 'N/A'}
Use this data to give personalized soil and plant recommendations.
'''
		: '';

	return '''You are GardenerGrid AI — an expert assistant specializing in:
- Botany, plant science, and horticulture
- Organic gardening and sustainable agriculture  
- Foraging, wild edibles, and plant identification
- Soil science, amendments, and composting
- Companion planting and permaculture design
- Farmers market strategy and local food systems
- Mesh networking for rural agriculture communication

$soilSection

Guidelines:
- Give practical, actionable advice tailored to the user's context.
- When discussing foraging, ALWAYS include safety warnings and lookalike hazards.
- Format responses in Markdown with headers, bullet points, and bold text.
- Keep responses concise but thorough — prioritize clarity.
- If the user asks about their specific soil data, always reference the readings provided.
- For dangerous plant identification questions, emphasize consulting multiple sources.''';
  }

  // ── Chat completion ────────────────────────────────────────────────────────
  Future<String> chat({
	required List<Map<String, String>> history,
	required String userMessage,
	SoilSample? soilContext,
  }) async {
	final apiKey = await getApiKey();
	if (apiKey == null || apiKey.isEmpty) {
	  return '⚠️ **Online AI not configured.**\n\nNo API key found. To enable online mode, you need to set your API key in app preferences.\n\nEndpoint: ${await getEndpoint()}\nModel: $_defaultModel';
	}

	final endpoint = await getEndpoint();

	final messages = [
	  {'role': 'system', 'content': _systemPrompt(soilContext: soilContext)},
	  ...history,
	  {'role': 'user', 'content': userMessage},
	];

	try {
	  final response = await http.post(
		Uri.parse(endpoint),
		headers: {
		  'Content-Type': 'application/json',
		  'Authorization': 'Bearer $apiKey',
		},
		body: jsonEncode({
		  'model': _defaultModel,
		  'messages': messages,
		  'max_tokens': 1024,
		  'temperature': 0.7,
		}),
	  ).timeout(const Duration(seconds: 30));

	  if (response.statusCode == 200) {
		final data = jsonDecode(response.body) as Map<String, dynamic>;
		return (data['choices'] as List).first['message']['content'] as String;
	  } else if (response.statusCode == 401) {
		return "🔑 **Invalid API key (401).**\n\nYour API key was rejected by the server. Check:\n- The key is correct and hasn't expired\n- The key has access to the $_defaultModel model\n\nEndpoint used: $endpoint";
	  } else if (response.statusCode == 429) {
		return '⏱️ **Rate limit reached (429).**\n\nToo many requests. Wait a moment before trying again.';
	  } else {
		return '❌ **Server error (${response.statusCode}).**\n\nEndpoint: $endpoint\nResponse: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}';
	  }
	} catch (e) {
	  return '📡 **Connection failed.**\n\nEndpoint: $endpoint\nError: ${e.toString()}\n\nCheck your internet connection or switch to Offline mode.';
	}
  }
}
