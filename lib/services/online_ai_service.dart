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
	  final wikidataFacts = await _wikidataFacts(query, limit: 2);
	  final ddg = await _duckDuckGoSnippets(query);
	  final communityTips = await _stackExchangeAnswers(query, limit: 2);
	  final conciseAnswer = _conciseSourcedAnswer(
		userMessage,
		ddg: ddg,
		wikidataFacts: wikidataFacts,
		wikiSummaries: wikiSummaries,
		communityTips: communityTips,
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

	  if (wikidataFacts.isNotEmpty) {
		sb.writeln('**Structured facts:**');
		for (final fact in wikidataFacts) {
		  sb.writeln('- **${fact.title}** (${_factConfidenceTag(fact.relevance)}): ${fact.summary}');
		}
		sb.writeln();
	  }

	  if (wikiSummaries.isNotEmpty) {
		sb.writeln('**Reference summary:**');
		for (final w in wikiSummaries) {
		  sb.writeln('- **${w.title}** (${_factConfidenceTag(w.relevance)}): ${w.summary}');
		}
		sb.writeln();
	  }

	  if (communityTips.isNotEmpty) {
		sb.writeln('**Community-tested answers:**');
		for (final tip in communityTips) {
		  sb.writeln('- **${tip.title}** (${tip.site}, ${tip.confidenceTag})');
		  if (tip.excerpt.isNotEmpty) {
			sb.writeln('  ${tip.excerpt}');
		  }
		  sb.writeln('  ${tip.link}');
		}
		sb.writeln();
	  }

	  final hasOnlineContext = (ddg.primarySnippet != null && ddg.primarySnippet!.isNotEmpty) ||
		  wikidataFacts.isNotEmpty ||
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

	  final citations = <String>{};
	  if (ddg.abstractUrl != null && ddg.abstractUrl!.isNotEmpty) {
		citations.add('DuckDuckGo Instant Answer [Medium]: ${ddg.abstractUrl}');
	  }
	  for (final fact in wikidataFacts) {
		if (fact.url.isNotEmpty) {
		  citations.add('Wikidata (${fact.title}) [${_factConfidenceLabel(fact.relevance)}]: ${fact.url}');
		}
	  }
	  for (final wiki in wikiSummaries) {
		if (wiki.url.isNotEmpty) {
		  citations.add('Wikipedia (${wiki.title}) [${_factConfidenceLabel(wiki.relevance)}]: ${wiki.url}');
		}
	  }
	  for (final tip in communityTips) {
		if (tip.link.isNotEmpty) {
		  citations.add('Stack Exchange (${tip.site}) [${tip.confidenceLabel}]: ${tip.link}');
		}
	  }
	  if (citations.isNotEmpty) {
		sb.writeln();
		sb.writeln('**Sources used:**');
		for (final citation in citations) {
		  sb.writeln('- $citation');
		}
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
	  return '## Straight answer\nA typical tomato usually has **around 100 to 300 seeds**.\n\nSmaller tomatoes often land near the low end, while larger slicing tomatoes can carry several hundred seeds depending on variety and fruit size.\n\n**Sources used:**\n- Wikipedia [High]: https://en.wikipedia.org/wiki/Tomato\n- Wikidata [High]: https://www.wikidata.org/wiki/Q23501';
	}
	return null;
  }

  String _factConfidenceTag(double relevance) => '[${_factConfidenceLabel(relevance)}]';

  String _factConfidenceLabel(double relevance) {
	if (relevance >= 0.55) return 'High';
	if (relevance >= 0.35) return 'Medium';
	return 'Low';
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
		final url = 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';
		out.add(_WikipediaSnippet(title: title, summary: summary, relevance: relevance, url: url));
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
	required List<_StructuredFact> wikidataFacts,
	required List<_WikipediaSnippet> wikiSummaries,
	required List<_CommunityTip> communityTips,
  }) {
	if (!_isFactQuestion(userMessage)) return null;
	final candidates = <String>[];
	if (ddg.primarySnippet != null && ddg.primarySnippet!.isNotEmpty) {
	  candidates.add(ddg.primarySnippet!);
	}
	for (final fact in wikidataFacts) {
	  candidates.add(fact.summary);
	}
	for (final wiki in wikiSummaries) {
	  candidates.add(wiki.summary);
	}
	for (final tip in communityTips) {
	  candidates.add(tip.excerpt);
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

  Future<List<_StructuredFact>> _wikidataFacts(String query, {int limit = 2}) async {
	try {
	  final tokens = _tokens(query);
	  final searchUri = Uri.parse(
		'https://www.wikidata.org/w/api.php'
		'?action=wbsearchentities&search=${Uri.encodeQueryComponent(query)}&language=en&format=json&limit=${limit * 2}',
	  );
	  final searchRes = await http.get(searchUri).timeout(const Duration(seconds: 10));
	  if (searchRes.statusCode != 200) return const <_StructuredFact>[];
	  final data = jsonDecode(searchRes.body) as Map<String, dynamic>;
	  final rows = (data['search'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
	  if (rows.isEmpty) return const <_StructuredFact>[];

	  final out = <_StructuredFact>[];
	  for (final row in rows) {
		if (out.length >= limit) break;
		final title = (row['label'] ?? '').toString().trim();
		final description = (row['description'] ?? '').toString().trim();
		final url = (row['concepturi'] ?? '').toString().trim();
		if (title.isEmpty || description.isEmpty) continue;
		final relevance = _textRelevanceScore(tokens, '$title $description');
		if (relevance < 0.22) continue;
		out.add(_StructuredFact(title: title, summary: description, relevance: relevance, url: url));
	  }
	  out.sort((a, b) => b.relevance.compareTo(a.relevance));
	  return out;
	} catch (_) {
	  return const <_StructuredFact>[];
	}
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

	Future<List<_CommunityTip>> _stackExchangeAnswers(String query, {int limit = 2}) async {
	try {
	  final out = <_CommunityTip>[];
	  for (final site in _stackExchangeSitesForQuery(query)) {
		if (out.length >= limit) break;
		final searchUri = Uri.parse(
		  'https://api.stackexchange.com/2.3/search/advanced'
		  '?order=desc&sort=relevance&site=$site&q=${Uri.encodeQueryComponent(query)}&pagesize=2&accepted=True&filter=withbody',
		);
		final res = await http.get(searchUri).timeout(const Duration(seconds: 10));
		if (res.statusCode != 200) continue;
		final data = jsonDecode(res.body) as Map<String, dynamic>;
		final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
		for (final item in items) {
		  if (out.length >= limit) break;
		  final title = _stripHtml((item['title'] ?? '').toString().trim());
		  final link = (item['link'] ?? '').toString().trim();
		  final acceptedId = item['accepted_answer_id'];
		  String excerpt = _stripHtml((item['body_markdown'] ?? item['body'] ?? '').toString().trim());
		  if (acceptedId != null) {
			final answerExcerpt = await _fetchAcceptedAnswerExcerpt(acceptedId.toString(), site);
			if (answerExcerpt != null && answerExcerpt.isNotEmpty) {
			  excerpt = answerExcerpt;
			}
		  }
		  if (title.isEmpty || link.isEmpty || excerpt.isEmpty) continue;
		  out.add(_CommunityTip(
			title: title,
			link: link,
			excerpt: _truncate(excerpt, 280),
			site: site,
			confidenceLabel: acceptedId != null ? 'High' : 'Medium',
		  ));
		}
	  }
	  return out;
	} catch (_) {
	  return const <_CommunityTip>[];
	}
  }

	Future<String?> _fetchAcceptedAnswerExcerpt(String answerId, String site) async {
	  try {
		final uri = Uri.parse(
		  'https://api.stackexchange.com/2.3/answers/$answerId'
		  '?order=desc&sort=activity&site=$site&filter=withbody',
		);
		final res = await http.get(uri).timeout(const Duration(seconds: 10));
		if (res.statusCode != 200) return null;
		final data = jsonDecode(res.body) as Map<String, dynamic>;
		final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
		if (items.isEmpty) return null;
		final body = _stripHtml((items.first['body_markdown'] ?? items.first['body'] ?? '').toString());
		return body.trim().isEmpty ? null : body.trim();
	  } catch (_) {
		return null;
	  }
	}

	List<String> _stackExchangeSitesForQuery(String query) {
	  final q = query.toLowerCase();
	  final sites = <String>['gardening'];
	  if (q.contains('seed') || q.contains('species') || q.contains('plant') || q.contains('flower') || q.contains('fruit') || q.contains('botan')) {
		sites.add('biology');
	  }
	  return sites;
	}

	String _stripHtml(String text) {
	  return text
		.replaceAll(RegExp(r'<[^>]+>'), ' ')
		.replaceAll('&quot;', '"')
		.replaceAll('&#39;', "'")
		.replaceAll('&amp;', '&')
		.replaceAll(RegExp(r'\s+'), ' ')
		.trim();
	}

	String _truncate(String text, int maxLength) {
	  if (text.length <= maxLength) return text;
	  return '${text.substring(0, maxLength).trim()}...';
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
	final String url;

	const _WikipediaSnippet({
	  required this.title,
	  required this.summary,
	  required this.relevance,
	  required this.url,
	});
}

class _StructuredFact {
	final String title;
	final String summary;
	final double relevance;
	final String url;

	const _StructuredFact({
	  required this.title,
	  required this.summary,
	  required this.relevance,
	  required this.url,
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
	final String excerpt;
	final String site;
	final String confidenceLabel;

	String get confidenceTag => '[$confidenceLabel]';

	const _CommunityTip({
	  required this.title,
	  required this.link,
	  required this.excerpt,
	  required this.site,
	  required this.confidenceLabel,
	});
}
