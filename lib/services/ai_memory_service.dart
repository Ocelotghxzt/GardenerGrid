import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VerifiedAiAnswer {
  final String question;
  final List<String> insights;
  final DateTime savedAt;

  const VerifiedAiAnswer({
    required this.question,
    required this.insights,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'insights': insights,
        'savedAt': savedAt.toIso8601String(),
      };

  factory VerifiedAiAnswer.fromJson(Map<String, dynamic> json) {
    final insights = (json['insights'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    return VerifiedAiAnswer(
      question: (json['question'] ?? '').toString().trim(),
      insights: insights,
      savedAt:
          DateTime.tryParse((json['savedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class AiMemoryService {
  static const _notesKey = 'ai_learning_notes';
  static const _verifiedAnswersKey = 'ai_verified_answers';
  static const _maxNotes = 24;
  static const _maxVerifiedAnswers = 24;

  Future<List<String>> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => item.toString()).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> learnFromMessage(String message) async {
    final extracted = extractNotes(message);
    if (extracted.isEmpty) {
      return loadNotes();
    }

    final existing = await loadNotes();
    final merged = <String>[...existing];

    for (final note in extracted) {
      final alreadyStored = merged.any(
        (entry) => entry.toLowerCase() == note.toLowerCase(),
      );
      if (!alreadyStored) {
        merged.add(note);
      }
    }

    final trimmed = merged.length <= _maxNotes
        ? merged
        : merged.sublist(merged.length - _maxNotes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, jsonEncode(trimmed));
    return trimmed;
  }

  Future<List<VerifiedAiAnswer>> loadVerifiedAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_verifiedAnswersKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (item) => VerifiedAiAnswer.fromJson(
              Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            ),
          )
          .where((entry) => entry.question.isNotEmpty && entry.insights.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<VerifiedAiAnswer>> learnFromVerifiedAnswer({
    required String question,
    required String answer,
  }) async {
    final normalizedQuestion = _normalizeText(question);
    final insights = extractVerifiedInsights(question: question, answer: answer);
    if (normalizedQuestion.isEmpty || insights.isEmpty) {
      return loadVerifiedAnswers();
    }

    final existing = await loadVerifiedAnswers();
    final merged = <VerifiedAiAnswer>[...existing];
    final matchIndex = merged.indexWhere(
      (entry) => entry.question.toLowerCase() == normalizedQuestion.toLowerCase(),
    );

    if (matchIndex >= 0) {
      final current = merged[matchIndex];
      final combined = <String>[...current.insights];
      for (final insight in insights) {
        final alreadyStored = combined.any(
          (entry) => entry.toLowerCase() == insight.toLowerCase(),
        );
        if (!alreadyStored) {
          combined.add(insight);
        }
      }
      merged[matchIndex] = VerifiedAiAnswer(
        question: current.question,
        insights: combined.take(6).toList(growable: false),
        savedAt: DateTime.now(),
      );
    } else {
      merged.add(
        VerifiedAiAnswer(
          question: normalizedQuestion,
          insights: insights.take(6).toList(growable: false),
          savedAt: DateTime.now(),
        ),
      );
    }

    merged.sort((a, b) => a.savedAt.compareTo(b.savedAt));
    final trimmed = merged.length <= _maxVerifiedAnswers
        ? merged
        : merged.sublist(merged.length - _maxVerifiedAnswers);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _verifiedAnswersKey,
      jsonEncode(trimmed.map((entry) => entry.toJson()).toList()),
    );
    return trimmed;
  }

  List<String> extractNotes(String message) {
    final normalized = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    final notes = <String>[];

    void add(String value) {
      final note = value.trim();
      if (note.length < 12) return;
      if (notes.any((entry) => entry.toLowerCase() == note.toLowerCase())) {
        return;
      }
      notes.add(note);
    }

    final rememberMatch = RegExp(
      r'(?:remember|keep in mind)\s+(?:that\s+)?(.+)',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (rememberMatch != null) {
      add(rememberMatch.group(1)!);
    }

    final clauses = normalized.split(RegExp(r'[.!?;]'));
    for (final rawClause in clauses) {
      final clause = rawClause.trim();
      if (clause.isEmpty) continue;

      final lower = clause.toLowerCase();
      final soundsPersonal = lower.startsWith('i ') ||
          lower.startsWith('my ') ||
          lower.contains(' i ') ||
          lower.contains(' my ');
      final hasGardeningContext = RegExp(
        r'\b(grow|growing|garden|soil|zone|climate|yard|orchard|bed|container|greenhouse|watering|compost|mulch|prune|fertiliz|tomato|pepper|lettuce|fruit|vegetable|herb|flower|plant)\b',
        caseSensitive: false,
      ).hasMatch(clause);

      if (soundsPersonal && hasGardeningContext) {
        add(clause);
      }
    }

    return notes;
  }

  List<String> extractVerifiedInsights({
    required String question,
    required String answer,
  }) {
    final normalizedQuestion = _normalizeText(question);
    final cleanedAnswer = answer
        .replaceAll(RegExp(r'[*_`>#]'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\((.*?)\)'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalizedQuestion.isEmpty || cleanedAnswer.isEmpty) return const [];

    final candidates = <String>[];

    void addCandidate(String value) {
      final note = _normalizeText(value);
      if (note.length < 18) return;
      if (note.length > 220) return;
      if (!_looksLikeGardeningAdvice(note)) return;
      if (candidates.any((entry) => entry.toLowerCase() == note.toLowerCase())) {
        return;
      }
      candidates.add(note);
    }

    for (final rawLine in answer.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(RegExp(r'^[-*•\d.\)\s]+'), '');
      line = line.replaceAll(RegExp(r'[*_`>#]'), '').trim();
      if (line.toLowerCase() == 'next steps') continue;
      addCandidate(line);
    }

    if (candidates.isEmpty) {
      for (final sentence in cleanedAnswer.split(RegExp(r'(?<=[.!?])\s+'))) {
        addCandidate(sentence);
      }
    }

    if (candidates.isEmpty) {
      addCandidate(cleanedAnswer);
    }

    return candidates.take(4).toList(growable: false);
  }

  List<String> relevantVerifiedInsights({
    required String question,
    required List<VerifiedAiAnswer> verifiedAnswers,
    int maxInsights = 6,
  }) {
    if (verifiedAnswers.isEmpty) return const [];

    final normalizedQuestion = _normalizeText(question).toLowerCase();
    final tokens = normalizedQuestion
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 4)
        .toSet();
    if (normalizedQuestion.isEmpty && tokens.isEmpty) return const [];

    final scored = <MapEntry<VerifiedAiAnswer, double>>[];
    for (final answer in verifiedAnswers) {
      final haystack =
          '${answer.question} ${answer.insights.join(' ')}'.toLowerCase();
      double score = 0;

      if (normalizedQuestion.isNotEmpty && haystack.contains(normalizedQuestion)) {
        score += 6;
      }

      for (final token in tokens) {
        if (answer.question.toLowerCase().contains(token)) {
          score += 2.2;
        } else if (haystack.contains(token)) {
          score += 0.9;
        }
      }

      if (score >= 1.8) {
        scored.add(MapEntry(answer, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final merged = <String>[];
    for (final answer in scored.take(3).map((entry) => entry.key)) {
      for (final insight in answer.insights) {
        if (merged.any((entry) => entry.toLowerCase() == insight.toLowerCase())) {
          continue;
        }
        merged.add(insight);
        if (merged.length >= maxInsights) {
          return merged;
        }
      }
    }

    return merged;
  }

  String _normalizeText(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  bool _looksLikeGardeningAdvice(String value) {
    final lower = value.toLowerCase();
    final hasGardeningContext = RegExp(
      r'\b(plant|garden|soil|compost|mulch|prune|seed|transplant|water|moisture|fertiliz|container|tomato|pepper|fruit|berry|herb|flower|tree|root|leaf|harvest|pest|disease|fung|aphid|pollinat|sun|shade|drain|calcium|nitrogen|phosphorus|potassium|blight|mildew|rot)\b',
    ).hasMatch(lower);
    final soundsActionable = RegExp(
      r'\b(use|keep|avoid|apply|water|plant|prune|space|harvest|start|feed|mulch|rotate|remove|improve|check|give|protect|thin)\b',
    ).hasMatch(lower);
    final hasMeasuredGuidance = RegExp(r'\b\d+\b|%|cm|inch|hours?\b').hasMatch(lower);
    return hasGardeningContext && (soundsActionable || hasMeasuredGuidance);
  }
}
