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
	final direct = _directFactAnswer(userMessage);
	if (direct != null) {
	  return direct;
	}
	final effectiveQuery = _composeEffectiveQuery(history, userMessage);
	return _chatWithFreeSources(
	  userMessage,
	  effectiveQuery: effectiveQuery,
	  soilContext: soilContext,
	);
  }

  Future<String> _chatWithFreeSources(
	String userMessage, {
	String? effectiveQuery,
	SoilSample? soilContext,
  }) async {
	try {
	  final query = effectiveQuery ?? userMessage;
	  final wikiSummaries = await _wikipediaTopSummaries(query, limit: 2);
	  final ddg = await _duckDuckGoSnippets(query);
	  final communityTips = await _stackExchangeTips(query, limit: 2);
	  final conciseAnswer = _conciseSourcedAnswer(
		userMessage,
		ddg: ddg,
		wikiSummaries: wikiSummaries,
	  );

	  final sb = StringBuffer();
	  sb.writeln('## Online Answer (Free Sources)');
	  if (conciseAnswer != null) {
		sb.writeln('**Straight answer:** $conciseAnswer');
		sb.writeln();
	  }

	  if (ddg.heading != null && ddg.heading!.isNotEmpty) {
		sb.writeln('**Topic:** ${ddg.heading}');
		sb.writeln();
	  }

	  if (ddg.primarySnippet != null && ddg.primarySnippet!.isNotEmpty) {
		sb.writeln(ddg.primarySnippet!);
		sb.writeln();
	  }

	  if (wikiSummaries.isNotEmpty) {
		sb.writeln('**Reference summary:**');
		for (final w in wikiSummaries) {
		  sb.writeln('- **${w.title}:** ${w.summary}');
		}
		sb.writeln();
	  }

	  if (communityTips.isNotEmpty) {
		sb.writeln('**Community-tested discussions:**');
		for (final tip in communityTips) {
		  sb.writeln('- ${tip.title}');
		  sb.writeln('  ${tip.link}');
		}
		sb.writeln();
	  }

	  final hasOnlineContext = (ddg.primarySnippet != null && ddg.primarySnippet!.isNotEmpty) ||
		  wikiSummaries.isNotEmpty ||
		  communityTips.isNotEmpty;

	  if (!hasOnlineContext) {
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

	  if (ddg.abstractUrl != null && ddg.abstractUrl!.isNotEmpty) {
		sb.writeln();
		sb.writeln('Source: ${ddg.abstractUrl}');
	  }

	  sb.writeln('\n_No sign-in or paid key required for this mode._');
	  return sb.toString();
	} catch (e) {
	  return '📡 **Connection failed.**\n\nUsing practical fallback guidance:\n\n${_quickGuide(userMessage)}\n\nError: ${e.toString()}';
	}
  }

  String? _directFactAnswer(String query) {
	final q = query.toLowerCase();
	final asksCount = q.contains('how many') || q.contains('number of');
	if (asksCount && q.contains('tomato') && q.contains('seed')) {
	  return '## Straight answer\nA typical tomato usually has **around 100 to 300 seeds**.\n\nSmaller tomatoes often land near the low end, while larger slicing tomatoes can carry several hundred seeds depending on variety and fruit size.';
	}
	return null;
  }

  String _composeEffectiveQuery(List<Map<String, String>> history, String userMessage) {
	if (history.isEmpty) return userMessage;
	final priorUsers = history
		.where((m) => (m['role'] ?? '').toLowerCase() == 'user')
		.map((m) => (m['content'] ?? '').trim())
		.where((m) => m.isNotEmpty)
		.toList();
	if (priorUsers.isEmpty) return userMessage;
	final prior = priorUsers.length > 2
		? priorUsers.sublist(priorUsers.length - 2)
		: priorUsers;
	return '${prior.join(' ; ')} ; $userMessage';
  }

  Future<List<_WikipediaSnippet>> _wikipediaTopSummaries(String query, {int limit = 2}) async {
	try {
	  final queryTokens = _tokens(query);
	  final searchUri = Uri.parse(
		'https://en.wikipedia.org/w/api.php'
		'?action=query&list=search&format=json&utf8=1&srlimit=${limit * 2}&srsearch=${Uri.encodeQueryComponent(query)}',
	  );
	  final searchRes = await http.get(searchUri).timeout(const Duration(seconds: 10));
	  if (searchRes.statusCode != 200) return const <_WikipediaSnippet>[];

	  final data = jsonDecode(searchRes.body) as Map<String, dynamic>;
	  final q = data['query'] as Map<String, dynamic>?;
	  final rows = (q?['search'] as List?)?.cast<Map<String, dynamic>>() ??
		  const <Map<String, dynamic>>[];
	  if (rows.isEmpty) return const <_WikipediaSnippet>[];

	  final out = <_WikipediaSnippet>[];
	  for (final row in rows) {
		if (out.length >= limit) break;
		final title = (row['title'] ?? '').toString().trim();
		if (title.isEmpty) continue;
		final summary = await _wikipediaSummary(title);
		if (summary == null || summary.isEmpty) continue;
		final relevance = _textRelevanceScore(queryTokens, '$title $summary');
		if (relevance < 0.18) continue;
		out.add(_WikipediaSnippet(title: title, summary: summary, relevance: relevance));
	  }
	  out.sort((a, b) => b.relevance.compareTo(a.relevance));
	  return out;
	} catch (_) {
	  return const <_WikipediaSnippet>[];
	}
  }

  String? _conciseSourcedAnswer(
	String userMessage, {
	required _DdgResult ddg,
	required List<_WikipediaSnippet> wikiSummaries,
  }) {
	if (!_isFactQuestion(userMessage)) return null;
	final candidates = <String>[];
	if (ddg.primarySnippet != null && ddg.primarySnippet!.isNotEmpty) {
	  candidates.add(ddg.primarySnippet!);
	}
	for (final wiki in wikiSummaries) {
	  candidates.add(wiki.summary);
	}
	for (final candidate in candidates) {
	  final line = _firstSentence(candidate);
	  if (line == null || line.isEmpty) continue;
	  if (_isLikelyUsableFact(userMessage, line)) {
		return line;
	  }
	}
	return null;
  }

  bool _isFactQuestion(String query) {
	final q = query.toLowerCase();
	return q.startsWith('what ') ||
		q.startsWith('who ') ||
		q.startsWith('when ') ||
		q.startsWith('where ') ||
		q.startsWith('how many ') ||
		q.startsWith('how much ') ||
		q.startsWith('is ') ||
		q.startsWith('are ');
  }

  bool _isLikelyUsableFact(String query, String line) {
	final q = query.toLowerCase();
	final candidate = line.toLowerCase();
	final tokens = _tokens(q);
	final relevance = _textRelevanceScore(tokens, candidate);
	if (q.contains('how many') || q.contains('how much')) {
	  return relevance >= 0.18 && RegExp(r'\d').hasMatch(candidate);
	}
	return relevance >= 0.22;
  }

  String? _firstSentence(String text) {
	final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
	if (cleaned.isEmpty) return null;
	final match = RegExp(r'^.+?[.!?](?:\s|$)').firstMatch(cleaned);
	return (match?.group(0) ?? cleaned).trim();
  }

  Set<String> _tokens(String text) {
	return text
		.toLowerCase()
		.split(RegExp(r'[^a-z0-9]+'))
		.where((t) => t.length > 2)
		.toSet();
  }

  double _textRelevanceScore(Set<String> queryTokens, String text) {
	if (queryTokens.isEmpty) return 0;
	final haystack = text.toLowerCase();
	var hits = 0;
	for (final token in queryTokens) {
	  if (haystack.contains(token)) hits += 1;
	}
	return hits / queryTokens.length;
  }

  Future<_DdgResult> _duckDuckGoSnippets(String query) async {
	try {
	  final ddgUri = Uri.parse(
		'https://api.duckduckgo.com/?q=${Uri.encodeQueryComponent(query)}&format=json&no_html=1&no_redirect=1',
	  );
	  final response = await http.get(ddgUri).timeout(const Duration(seconds: 14));
	  if (response.statusCode != 200) return const _DdgResult();

	  final data = jsonDecode(response.body) as Map<String, dynamic>;
	  final heading = (data['Heading'] ?? '').toString().trim();
	  final abstractText = (data['AbstractText'] ?? '').toString().trim();
	  final abstractUrl = (data['AbstractURL'] ?? '').toString().trim();

	  String? relatedSnippet;
	  final related = (data['RelatedTopics'] as List?)?.cast<dynamic>() ?? const <dynamic>[];
	  if (abstractText.isEmpty && related.isNotEmpty) {
		relatedSnippet = _extractRelatedTopicText(related);
	  }

	  return _DdgResult(
		heading: heading.isEmpty ? null : heading,
		primarySnippet: abstractText.isNotEmpty ? abstractText : relatedSnippet,
		abstractUrl: abstractUrl.isEmpty ? null : abstractUrl,
	  );
	} catch (_) {
	  return const _DdgResult();
	}
  }

  String? _extractRelatedTopicText(List<dynamic> topics) {
	for (final item in topics) {
	  if (item is! Map<String, dynamic>) continue;
	  final text = (item['Text'] ?? '').toString().trim();
	  if (text.isNotEmpty) return text;
	  final nested = item['Topics'];
	  if (nested is List) {
		final nestedText = _extractRelatedTopicText(nested.cast<dynamic>());
		if (nestedText != null && nestedText.isNotEmpty) return nestedText;
	  }
	}
	return null;
  }

  Future<List<_CommunityTip>> _stackExchangeTips(String query, {int limit = 2}) async {
	try {
	  final uri = Uri.parse(
		'https://api.stackexchange.com/2.3/search/advanced'
		'?order=desc&sort=relevance&site=gardening&q=${Uri.encodeQueryComponent(query)}&pagesize=${limit * 2}',
	  );
	  final res = await http.get(uri).timeout(const Duration(seconds: 10));
	  if (res.statusCode != 200) return const <_CommunityTip>[];

	  final data = jsonDecode(res.body) as Map<String, dynamic>;
	  final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ??
		  const <Map<String, dynamic>>[];
	  if (items.isEmpty) return const <_CommunityTip>[];

	  final out = <_CommunityTip>[];
	  for (final item in items) {
		if (out.length >= limit) break;
		final title = (item['title'] ?? '').toString().trim();
		final link = (item['link'] ?? '').toString().trim();
		if (title.isEmpty || link.isEmpty) continue;
		out.add(_CommunityTip(title: title, link: link));
	  }
	  return out;
	} catch (_) {
	  return const <_CommunityTip>[];
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

class _WikipediaSnippet {
	final String title;
	final String summary;
	final double relevance;

	const _WikipediaSnippet({
	  required this.title,
	  required this.summary,
	  required this.relevance,
	});
}

class _DdgResult {
	final String? heading;
	final String? primarySnippet;
	final String? abstractUrl;

	const _DdgResult({this.heading, this.primarySnippet, this.abstractUrl});
}

class _CommunityTip {
	final String title;
	final String link;

	const _CommunityTip({required this.title, required this.link});
}
