import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/soil_sample.dart';

/// Uses open-source web sources without requiring API keys.
class OnlineAiService {
  Future<bool> isConfigured() async {
	return true;
  }

  // ── Chat completion ────────────────────────────────────────────────────────
  Future<String> chat({
	required List<Map<String, String>> history,
	required String userMessage,
	SoilSample? soilContext,
  }) async {
	// History remains part of the interface for compatibility with callers.
	if (history.isNotEmpty) {
	  // Intentionally no-op: free-source mode does not require full chat payloads.
	}
	return _chatWithFreeSources(userMessage, soilContext: soilContext);
  }

  Future<String> _chatWithFreeSources(
	String userMessage, {
	SoilSample? soilContext,
  }) async {
	try {
	  final searchTitle = await _wikipediaSearchTopTitle(userMessage);
	  final wikiTitle = searchTitle ?? userMessage;
	  final wikiText = await _wikipediaSummary(wikiTitle);

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

	  if ((abstractText == null || abstractText.isEmpty) &&
		  (wikiText == null || wikiText.isEmpty)) {
		sb.writeln(_quickGuide(userMessage));
		sb.writeln();
	  } else {
		sb.writeln('**Actionable steps:**');
		sb.writeln(_quickGuide(userMessage));
		sb.writeln();
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
	  return '📡 **Connection failed.**\n\nUsing practical fallback guidance:\n\n${_quickGuide(userMessage)}\n\nError: ${e.toString()}';
	}
  }

  Future<String?> _wikipediaSearchTopTitle(String query) async {
	try {
	  final uri = Uri.parse(
		'https://en.wikipedia.org/w/api.php'
		'?action=query&list=search&format=json&utf8=1&srlimit=1&srsearch=${Uri.encodeQueryComponent(query)}',
	  );
	  final response = await http.get(uri).timeout(const Duration(seconds: 10));
	  if (response.statusCode != 200) return null;
	  final data = jsonDecode(response.body) as Map<String, dynamic>;
	  final q = data['query'] as Map<String, dynamic>?;
	  final rows = (q?['search'] as List?)?.cast<Map<String, dynamic>>() ??
		  const <Map<String, dynamic>>[];
	  if (rows.isEmpty) return null;
	  return (rows.first['title'] ?? '').toString().trim();
	} catch (_) {
	  return null;
	}
  }

  String _quickGuide(String query) {
	final q = query.toLowerCase();
	final crop = _detectCrop(q);
	final title = crop ?? 'general gardening';

	final steps = <String>[];
	if (crop == 'tomato' || crop == 'tomatoes') {
	  steps.addAll([
		'1. Start seeds indoors 6-8 weeks before last frost, or transplant healthy starts.',
		'2. Plant in full sun with rich, well-drained soil; mix in compost before planting.',
		'3. Bury stems deep to encourage stronger rooting and spacing of 18-24 inches.',
		'4. Water deeply 1-2 times weekly and mulch to stabilize moisture.',
		'5. Add support early (cage/stake) and feed every 2-3 weeks once fruit sets.',
	  ]);
	} else if (crop == 'apple' || crop == 'apples') {
	  steps.addAll([
		'1. Choose a cultivar matched to your chill hours and hardiness zone.',
		'2. Plant in full sun with excellent drainage and proper root flare at soil line.',
		'3. Maintain pruning for open canopy and strong scaffold structure.',
		'4. Water consistently during establishment and apply mulch away from trunk.',
		'5. Use pollination-compatible varieties for stronger fruit set.',
	  ]);
	} else {
	  steps.addAll([
		'1. Match crop to your local season and temperature window.',
		'2. Prepare soil with compost and verify pH for that crop range.',
		'3. Plant at correct depth/spacing and keep moisture consistent during establishment.',
		'4. Monitor for pests/disease weekly and intervene early with integrated methods.',
		'5. Feed at key growth stages (vegetative, flowering, fruiting) rather than all at once.',
	  ]);
	}

	return 'Practical plan for **$title**:\n\n${steps.join('\n')}';
  }

  String? _detectCrop(String q) {
	const crops = [
	  'tomato',
	  'tomatoes',
	  'apple',
	  'apples',
	  'pepper',
	  'peppers',
	  'cucumber',
	  'cucumbers',
	  'lettuce',
	  'basil',
	  'potato',
	  'potatoes',
	  'onion',
	  'onions',
	];
	for (final crop in crops) {
	  if (q.contains(crop)) return crop;
	}
	return null;
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
