import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiMemoryService {
  static const _notesKey = 'ai_learning_notes';
  static const _maxNotes = 12;

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
        r'\b(grow|growing|garden|soil|zone|climate|yard|orchard|bed|container|greenhouse|watering|compost|mulch|prune|fertiliz|tomato|pepper|pepper|lettuce|fruit|vegetable|herb|flower|plant)\b',
        caseSensitive: false,
      ).hasMatch(clause);

      if (soundsPersonal && hasGardeningContext) {
        add(clause);
      }
    }

    return notes;
  }
}
