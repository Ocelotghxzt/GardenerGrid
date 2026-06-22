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
	static const _defaultEndpoint = 'https://api.duckduckgo.com/';

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
	return true;
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
	final endpoint = await getEndpoint();

	if (apiKey != null && apiKey.isNotEmpty && endpoint != _defaultEndpoint) {
	  final custom = await _chatWithCustomEndpoint(
		apiKey: apiKey,
		endpoint: endpoint,
		history: history,
		userMessage: userMessage,
		soilContext: soilContext,
	  );

	  if (custom != null) {
		return custom;
	  }
	}

	return _chatWithFreeSources(userMessage, soilContext: soilContext);
  }

  Future<String?> _chatWithCustomEndpoint({
	required String apiKey,
	required String endpoint,
	required List<Map<String, String>> history,
	required String userMessage,
	SoilSample? soilContext,
  }) async {
	final messages = [
	  {'role': 'system', 'content': _systemPrompt(soilContext: soilContext)},
	  ...history,
	  {'role': 'user', 'content': userMessage},
	];

	try {
	  final response = await http
		  .post(
			Uri.parse(endpoint),
			headers: {
			  'Content-Type': 'application/json',
			  'Authorization': 'Bearer $apiKey',
			},
			body: jsonEncode({
			  'model': 'deepseek-chat',
			  'messages': messages,
			  'max_tokens': 900,
			  'temperature': 0.5,
			}),
		  )
		  .timeout(const Duration(seconds: 25));

	  if (response.statusCode == 200) {
		final data = jsonDecode(response.body) as Map<String, dynamic>;
		return (data['choices'] as List).first['message']['content'] as String;
	  }

	  if (response.statusCode == 401 ||
		  response.statusCode == 402 ||
		  response.statusCode == 403 ||
		  response.statusCode == 429) {
		return null;
	  }

	  return null;
	} catch (_) {
	  return null;
	}
  }

  Future<String> _chatWithFreeSources(
	String userMessage, {
	SoilSample? soilContext,
  }) async {
	try {
	  final ddgUri = Uri.parse(
		'https://api.duckduckgo.com/?q=${Uri.encodeQueryComponent(userMessage)}&format=json&no_html=1&no_redirect=1',
	  );
	  final ddgResponse = await http.get(ddgUri).timeout(const Duration(seconds: 14));

	  String? heading;
	  String? abstractText;
	  String? abstractUrl;

	  if (ddgResponse.statusCode == 200) {
		final data = jsonDecode(ddgResponse.body) as Map<String, dynamic>;
		heading = (data['Heading'] ?? '').toString().trim();
		abstractText = (data['AbstractText'] ?? '').toString().trim();
		abstractUrl = (data['AbstractURL'] ?? '').toString().trim();
	  }

	  final wikiText = await _wikipediaSummary(userMessage);

	  final sb = StringBuffer();
	  sb.writeln('## Online Answer (Free Sources)');
	  if (heading != null && heading.isNotEmpty) {
		sb.writeln('**Topic:** $heading');
		sb.writeln();
	  }

	  if (abstractText != null && abstractText.isNotEmpty) {
		sb.writeln(abstractText);
		sb.writeln();
	  }

	  if (wikiText != null && wikiText.isNotEmpty) {
		sb.writeln('**Reference summary:**');
		sb.writeln(wikiText);
		sb.writeln();
	  }

	  if (sb.length < 90) {
		sb.writeln('I could not find enough online context for that exact phrasing.');
		sb.writeln('Try a more specific question with plant or crop name.');
	  }

	  if (soilContext != null) {
		sb.writeln('**Your soil context:** pH ${soilContext.ph.toStringAsFixed(1)}, '
			'N ${soilContext.nitrogen.toStringAsFixed(0)}, '
			'P ${soilContext.phosphorus.toStringAsFixed(0)}, '
			'K ${soilContext.potassium.toStringAsFixed(0)}.');
	  }

	  if (abstractUrl != null && abstractUrl.isNotEmpty) {
		sb.writeln();
		sb.writeln('Source: $abstractUrl');
	  }

	  sb.writeln('\n_No sign-in or paid key required for this mode._');
	  return sb.toString();
	} catch (e) {
	  return '📡 **Connection failed.**\n\nFree online sources were unreachable. Error: ${e.toString()}';
	}
  }

  Future<String?> _wikipediaSummary(String query) async {
	try {
	  final title = query.trim().split(RegExp(r'\s+')).take(6).join(' ');
	  if (title.isEmpty) return null;
	  final wikiUri = Uri.parse(
		'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
	  );
	  final response = await http.get(wikiUri).timeout(const Duration(seconds: 10));
	  if (response.statusCode != 200) return null;
	  final data = jsonDecode(response.body) as Map<String, dynamic>;
	  final extract = (data['extract'] ?? '').toString().trim();
	  if (extract.isEmpty) return null;
	  return extract.length > 380 ? '${extract.substring(0, 380)}...' : extract;
	} catch (_) {
	  return null;
	}
  }
}
