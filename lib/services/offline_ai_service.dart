import '../models/soil_sample.dart';
import '../models/plant_entry.dart';
import '../models/foraging_entry.dart';
import 'ai_memory_service.dart';

/// Lightweight rules-based AI that works 100% offline.
/// Uses bundled plant knowledge and soil readings to answer questions.
class OfflineAiService {
  final List<PlantEntry> plants;
  final List<ForagingEntry> foraging;

  OfflineAiService({required this.plants, required this.foraging});

  // ── Entry point ──────────────────────────────────────────────────────────
  String answer(
    String query, {
    SoilSample? soilContext,
    List<String> learnedContext = const [],
    List<VerifiedAiAnswer> verifiedAnswers = const [],
  }) {
	final q = query.toLowerCase();
    final verifiedInsights = _findVerifiedInsights(q, verifiedAnswers);

	// 1. Soil-contextual responses
	if (soilContext != null && _hasSoilKeywords(q)) {
	  return _soilResponse(
        q,
        soilContext,
        learnedContext: learnedContext,
        verifiedInsights: verifiedInsights,
      );
	}

	// 2. Foraging queries
	if (_hasForagingKeywords(q)) {
	  return _foragingResponse(q);
	}

	// 3. Plant/gardening lookup
	final plantMatches = _findPlantMatches(q);
	if (plantMatches.isNotEmpty) {
	  return _plantResponse(
      plantMatches.first,
      q,
      related: plantMatches.skip(1).take(2).toList(),
      learnedContext: learnedContext,
      verifiedInsights: verifiedInsights,
    );
	}

	// 4. Companion planting
	if (q.contains('companion')) {
	  return _companionResponse(q);
	}

	// 5. Pest queries
	if (_hasPestKeywords(q)) {
	  return _pestResponse(q, verifiedInsights: verifiedInsights);
	}

	// 5b. Advanced topics
	if (_hasAdvancedTopicKeywords(q)) {
	  return _advancedTopicResponse(q, verifiedInsights: verifiedInsights);
	}

	// 6. General gardening tips
	if (_hasGardeningKeywords(q)) {
	  return _gardeningTipsResponse(
        q,
        learnedContext: learnedContext,
        verifiedInsights: verifiedInsights,
      );
	}

	// 7. Fallback
	return _fallback(
      q,
      learnedContext: learnedContext,
      verifiedInsights: verifiedInsights,
    );
  }

  bool _hasAdvancedTopicKeywords(String q) =>
		  q.contains('compost') || q.contains('mulch') ||
		  q.contains('prune') || q.contains('succession') ||
		  q.contains('rotation') || q.contains('crop rot') ||
		  q.contains('seed start') || q.contains('transplant') ||
		  q.contains('water') || q.contains('irrigat') ||
		  q.contains('container') || q.contains('pot garden') ||
		  q.contains('permacultur') || q.contains('hydropon') ||
		  q.contains('propagat') || q.contains('cutting') ||
		  q.contains('greenhouse') || q.contains('cold frame');

  // ── Keyword detectors ────────────────────────────────────────────────────
  bool _hasSoilKeywords(String q) =>
	  q.contains('soil') || q.contains('ph') || q.contains('nitrogen') ||
	  q.contains('phosphorus') || q.contains('potassium') ||
	  q.contains('amendment') || q.contains('fertiliz');

  bool _hasForagingKeywords(String q) =>
	  q.contains('forag') || q.contains('wild') || q.contains('edible') ||
	  q.contains('harvest') || q.contains('identify') || q.contains('mushroom') ||
	  q.contains('berry') || q.contains('lookalike');

  bool _hasPestKeywords(String q) =>
	  q.contains('pest') || q.contains('bug') || q.contains('insect') ||
	  q.contains('aphid') || q.contains('disease') ||
    q.contains('mildew') || q.contains('blight') || q.contains('rot');

  bool _hasGardeningKeywords(String q) =>
	  q.contains('plant') || q.contains('grow') || q.contains('garden') ||
	  q.contains('propagat') || q.contains('water') || q.contains('prune') ||
	  q.contains('bloom') || q.contains('seed');

  // ── Response builders ─────────────────────────────────────────────────────
  String _soilResponse(
    String q,
    SoilSample soil, {
    List<String> learnedContext = const [],
    List<String> verifiedInsights = const [],
  }) {
	final buf = StringBuffer();
	buf.writeln('**Soil Analysis (offline)**\n');
	if (soil.source == SampleSource.bluetoothSensor) {
	  final sensorLabel = soil.sensorName ?? 'BLE soil sensor';
	  buf.writeln('📡 **Source**: Live reading from $sensorLabel');
	  if (soil.sensorId != null && soil.sensorId!.isNotEmpty) {
		buf.writeln('- Sensor ID: ${soil.sensorId}');
	  }
	  if (soil.signalStrength != null) {
		buf.writeln('- Signal strength: ${soil.signalStrength} dBm');
	  }
	  buf.writeln();
	}
	buf.writeln('📊 **Current Readings**');
	buf.writeln('- pH: ${soil.ph.toStringAsFixed(1)}');
	buf.writeln('- Nitrogen: ${soil.nitrogen.toStringAsFixed(0)} ppm');
	buf.writeln('- Phosphorus: ${soil.phosphorus.toStringAsFixed(0)} ppm');
	buf.writeln('- Potassium: ${soil.potassium.toStringAsFixed(0)} ppm');
	buf.writeln('- Moisture: ${soil.moisture.toStringAsFixed(0)}%');
	if (soil.organicMatter > 0) {
	  buf.writeln('- Organic Matter: ${soil.organicMatter.toStringAsFixed(1)}%');
	}

	if (soil.deficiencies.isNotEmpty) {
	  buf.writeln('\n⚠️ **Deficiencies Detected**');
	  for (final d in soil.deficiencies) {
		buf.writeln('- $d');
	  }
	}

	if (soil.amendments.isNotEmpty) {
	  buf.writeln('\n💡 **Recommended Amendments**');
	  for (final a in soil.amendments) {
		buf.writeln('- $a');
	  }
	}

	// Plants that match current soil pH
	final compatible = plants
		.where((p) => soil.ph >= p.phMin && soil.ph <= p.phMax)
		.take(5)
		.map((p) => p.name)
		.join(', ');

	if (compatible.isNotEmpty) {
	  buf.writeln('\n🌿 **Plants suited to your current pH (${soil.ph.toStringAsFixed(1)})**');
	  buf.writeln(compatible);
	}

    _appendVerifiedInsights(buf, verifiedInsights);
    _appendLearnedContext(buf, learnedContext);
	return buf.toString();
  }

  String _foragingResponse(String q) {
	// Try exact name match first
	for (final f in foraging) {
	  if (q.contains(f.name.toLowerCase()) ||
		  q.contains(f.scientificName.toLowerCase().split(' ')[0])) {
		return _forageDetail(f);
	  }
	}
	// Category filters
	if (q.contains('mushroom')) {
	  final mushrooms = foraging.where((f) => f.category == 'Mushroom').toList();
	  if (mushrooms.isNotEmpty) return _forageDetail(mushrooms.first);
	}
	if (q.contains('berry') || q.contains('berries')) {
	  final berries = foraging.where((f) => f.category == 'Berry').toList();
	  if (berries.isNotEmpty) return _forageDetail(berries.first);
	}
	// General foraging intro
	final buf = StringBuffer();
	buf.writeln('**🌿 Foraging Guide (Offline)**\n');
	buf.writeln('I have **${foraging.length}** foraging entries available offline.\n');
	buf.writeln('**Categories:**');
	final cats = foraging.map((f) => f.category).toSet().toList()..sort();
	for (final c in cats) {
	  final items = foraging.where((f) => f.category == c).map((f) => f.name).join(', ');
	  buf.writeln('- **$c:** $items');
	}
	buf.writeln('\n> Ask me about a specific plant (e.g., "tell me about blackberry") or category.');
	return buf.toString();
  }

  String _forageDetail(ForagingEntry f) {
	final buf = StringBuffer();
	buf.writeln('## 🍃 ${f.name}');
	buf.writeln('*${f.scientificName}* · **${f.category}**\n');
	buf.writeln('**Edibility:** ${f.edibility}');
	buf.writeln('**Season:** ${f.season}\n');
	buf.writeln(f.description);
	buf.writeln('\n**Identification**');
	buf.writeln('- **Leaves:** ${f.identification.leaves}');
	buf.writeln('- **Stem:** ${f.identification.stem}');
	buf.writeln('- **Flower:** ${f.identification.flower}');
	buf.writeln('- **Fruit:** ${f.identification.fruit}');
	buf.writeln('- **Lookalikes:** ${f.identification.lookalikes}');
	buf.writeln('\n⚠️ **Lookalike Danger:** ${f.lookalikeDanger}');
	buf.writeln('\n**Harvest Notes:** ${f.harvestNotes}');
	buf.writeln('\n**Nutrition:** ${f.nutritionHighlights}');
	if (f.safetyWarnings.isNotEmpty) {
	  buf.writeln('\n🚨 **Safety Warnings:**');
	  for (final w in f.safetyWarnings) {
		buf.writeln('- $w');
	  }
	}
	return buf.toString();
  }

  List<PlantEntry> _findPlantMatches(String q) {
    final tokens = _queryTokens(q);
    final scored = <MapEntry<PlantEntry, double>>[];

    for (final plant in plants) {
      final haystack = [
        plant.name,
        plant.scientificName,
        plant.family,
        plant.category,
        plant.description,
        plant.soilPreference,
        plant.sunlight,
        plant.water,
        plant.bloomSeason,
        plant.culinaryUses,
        plant.medicinalUses,
        plant.gardeningTips,
        plant.propagation,
        ...plant.tags,
        ...plant.companionPlants,
        ...plant.pestRepellent,
      ].join(' ').toLowerCase();

      double score = 0;
      final commonName = plant.name.toLowerCase();
      final scientific = plant.scientificName.toLowerCase();

      if (q.contains(commonName)) score += 5;
      if (q.contains(scientific)) score += 4;
      if (q.contains(plant.id.replaceAll('_', ' '))) score += 3;

      for (final token in tokens) {
        if (token.length < 3) continue;
        if (commonName.contains(token)) {
          score += 2.4;
        } else if (scientific.contains(token)) {
          score += 1.8;
        } else if (plant.tags.any((tag) => tag.toLowerCase().contains(token))) {
          score += 1.4;
        } else if (haystack.contains(token)) {
          score += 0.6;
        }
      }

      if (score > 1.2) {
        scored.add(MapEntry(plant, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((entry) => entry.key).take(3).toList();
  }

  String _plantResponse(
    PlantEntry p,
    String q, {
    List<PlantEntry> related = const [],
    List<String> learnedContext = const [],
    List<String> verifiedInsights = const [],
  }) {
	final buf = StringBuffer();
	buf.writeln('## 🌿 ${p.name}');
	buf.writeln('*${p.scientificName}* · ${p.family} · **${p.category}**\n');
	buf.writeln(p.description);
	buf.writeln('\n**Quick care**');
	buf.writeln('- 🌍 Soil: ${p.soilPreference}');
	buf.writeln('- ☀️ Light: ${p.sunlight}');
	buf.writeln('- 💧 Water: ${p.water}');
	buf.writeln('- 🌡️ Hardiness zone: ${p.hardinessZone}');
	buf.writeln('- 📏 Typical size: ${p.heightCm}cm tall × ${p.spreadCm}cm wide');
	buf.writeln('- 🌸 Bloom season: ${p.bloomSeason}');

	if (p.companionPlants.isNotEmpty) {
	  buf.writeln('\n**Companion plants:** ${p.companionPlants.join(', ')}');
	}
	if (p.pestRepellent.isNotEmpty) {
	  buf.writeln('**Repels:** ${p.pestRepellent.join(', ')}');
	}
	if (p.culinaryUses.isNotEmpty && p.culinaryUses != 'None') {
	  buf.writeln('\n🍽️ **Common uses:** ${p.culinaryUses}');
	}
	if (p.medicinalUses.isNotEmpty) {
	  buf.writeln('💊 **Traditional uses:** ${p.medicinalUses}');
	}
	buf.writeln('\n🌱 **Growing tips:** ${p.gardeningTips}');
	buf.writeln('**Propagation:** ${p.propagation}');
    if (related.isNotEmpty) {
      buf.writeln(
        '\n**Related plants you may also mean:** ${related.map((plant) => plant.name).join(', ')}',
      );
    }
    _appendVerifiedInsights(buf, verifiedInsights);
    _appendLearnedContext(buf, learnedContext);
	return buf.toString();
  }

  String _companionResponse(String q) {
	final buf = StringBuffer();
	buf.writeln('**🤝 Companion Planting Guide (Offline)**\n');
	for (final p in plants) {
	  if (p.companionPlants.isNotEmpty) {
		buf.writeln('**${p.name}** pairs well with: ${p.companionPlants.join(', ')}');
	  }
	}
	return buf.toString();
  }

  String _pestResponse(
    String q, {
    List<String> verifiedInsights = const [],
  }) {
	final buf = StringBuffer();
	buf.writeln('**🐛 Natural Pest Control (Offline)**\n');
	final repellers =
		plants.where((p) => p.pestRepellent.isNotEmpty).toList();
	for (final p in repellers) {
	  buf.writeln('**${p.name}** repels: ${p.pestRepellent.join(', ')}');
	}
	buf.writeln(
		'\n> Tip: Intercropping pest-repelling plants among vegetables is one of the most effective organic pest management strategies.');
    if (q.contains('disease') ||
        q.contains('mildew') ||
        q.contains('blight') ||
        q.contains('rot')) {
      buf.writeln('\n**Disease prevention basics**');
      buf.writeln('- Improve airflow and avoid wetting foliage late in the day.');
      buf.writeln('- Remove badly infected leaves instead of composting them cold.');
      buf.writeln('- Rotate crops and sanitize tools between affected plants.');
    }
    _appendVerifiedInsights(buf, verifiedInsights);
	return buf.toString();
  }

  String _gardeningTipsResponse(
    String q, {
    List<String> learnedContext = const [],
    List<String> verifiedInsights = const [],
  }) {
	final buf = StringBuffer();
	buf.writeln('**🌱 Gardening Tips (Offline)**\n');
	buf.writeln(
		'I can help with practical plant care, vegetables, fruit, herbs, flowers, and basic botany.\n');

    if (q.contains('vegetable') || q.contains('tomato') || q.contains('lettuce')) {
      buf.writeln('**Vegetables**');
      buf.writeln('- Start with full sun, steady moisture, and compost-rich soil.');
      buf.writeln('- Feed heavy crops such as tomatoes and peppers consistently once flowering starts.');
      buf.writeln('- Mulch warm-season vegetables to reduce stress and water loss.\n');
    }

    if (q.contains('fruit') || q.contains('berry') || q.contains('tree')) {
      buf.writeln('**Fruit & berries**');
      buf.writeln('- Prioritize sun, airflow, and annual pruning for structure.');
      buf.writeln('- Thin fruit when trees set heavily to improve size and reduce breakage.');
      buf.writeln('- Keep watering deep and infrequent rather than shallow and daily.\n');
    }

    if (q.contains('herb') || q.contains('basil') || q.contains('rosemary')) {
      buf.writeln('**Herbs**');
      buf.writeln('- Harvest often to keep herbs compact and productive.');
      buf.writeln('- Avoid overwatering Mediterranean herbs such as rosemary and lavender.');
      buf.writeln('- Pinch flowering stems on leafy culinary herbs when you want more foliage.\n');
    }

    if (q.contains('seed') || q.contains('transplant')) {
      buf.writeln('**Seed starting**');
      buf.writeln('- Use bright light immediately after germination to prevent legginess.');
      buf.writeln('- Harden seedlings off gradually for about a week before planting out.');
      buf.writeln('- Keep the medium evenly moist, not soggy.\n');
    }

    _appendTopicKnowledge(buf, q);

	// Surface relevant tips
	final relevant = plants.where((p) {
	  return p.gardeningTips.toLowerCase().contains(q.split(' ').first);
	}).take(3);

	for (final p in relevant) {
	  buf.writeln('**${p.name}:** ${p.gardeningTips}\n');
	}

	if (buf.length < 200) {
	  for (final p in plants.take(3)) {
		buf.writeln('**${p.name}:** ${p.gardeningTips}\n');
	  }
	}

    _appendVerifiedInsights(buf, verifiedInsights);
    _appendLearnedContext(buf, learnedContext);
	return buf.toString();
  }

  String _advancedTopicResponse(
    String q, {
    List<String> verifiedInsights = const [],
  }) {
	final buf = StringBuffer();
	buf.writeln('**Advanced Gardening Guidance (Offline)**\n');

	if (q.contains('compost')) {
	  buf.writeln('- Build compost with roughly 2:1 browns-to-greens.');
	  buf.writeln('- Keep moisture near a wrung-out sponge and turn weekly.');
	}
	if (q.contains('mulch')) {
	  buf.writeln('- Apply 5-8 cm mulch, keeping stems clear to prevent rot.');
	}
	if (q.contains('prune')) {
	  buf.writeln('- Prune during dormancy for structure, and after bloom for shaping.');
	}
	if (q.contains('rotation') || q.contains('crop rot')) {
	  buf.writeln('- Rotate plant families on a 3-4 year cycle to reduce pest pressure.');
	}
	if (q.contains('seed start') || q.contains('transplant')) {
	  buf.writeln('- Harden seedlings for 7-10 days before transplanting.');
	}
	if (q.contains('container') || q.contains('pot garden')) {
	  buf.writeln('- Use large containers, quality mix, and frequent feeding.');
	}

	if (buf.length < 80) {
	  buf.writeln('- Ask about compost, mulching, pruning, rotation, or seed starting.');
	}

    _appendTopicKnowledge(buf, q);
    _appendVerifiedInsights(buf, verifiedInsights);
	return buf.toString();
  }

  String _fallback(
    String q, {
    List<String> learnedContext = const [],
    List<String> verifiedInsights = const [],
  }) {
	final buf = StringBuffer();
	buf.writeln('**GardenerGrid Offline Assistant**\n');
	buf.writeln(
		"I'm running in **offline mode** with built-in plant knowledge. I can help with:\n");
	buf.writeln('- 🌿 **Plant care** — Ask about ${plants.take(3).map((p) => p.name).join(', ')}, and more');
	buf.writeln('- 🍅 **Vegetables, fruit, and herbs** — growing basics, watering, pruning, and propagation');
	buf.writeln('- 🍃 **Foraging guide** — Wild edibles, identification, safety');
	buf.writeln('- 🧪 **Soil analysis** — Add a soil sample or use a BLE sensor for personalized advice');
	buf.writeln('- 🤝 **Companion planting** — Ask "what are companion plants for basil?"');
	buf.writeln('- 🐛 **Pest control** — Ask "what repels aphids?"');
    _appendTopicKnowledge(buf, q);
    _appendVerifiedInsights(buf, verifiedInsights);
    if (learnedContext.isNotEmpty) {
      buf.writeln('\n**What I remember about your growing context**');
      for (final note in learnedContext.take(3)) {
        buf.writeln('- $note');
      }
    }
	return buf.toString();
  }

  List<String> _queryTokens(String q) => q
      .split(RegExp(r'[^a-z0-9]+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList(growable: false);

  void _appendLearnedContext(
    StringBuffer buffer,
    List<String> learnedContext,
  ) {
    if (learnedContext.isEmpty) return;
    buffer.writeln('\n**Remembered growing context**');
    for (final note in learnedContext.take(3)) {
      buffer.writeln('- $note');
    }
  }

  List<String> _findVerifiedInsights(
    String query,
    List<VerifiedAiAnswer> verifiedAnswers,
  ) {
    if (verifiedAnswers.isEmpty) return const [];

    final tokens = _queryTokens(query).where((token) => token.length >= 4).toSet();
    if (tokens.isEmpty) return const [];

    final scored = <MapEntry<VerifiedAiAnswer, double>>[];
    for (final answer in verifiedAnswers) {
      final haystack =
          '${answer.question} ${answer.insights.join(' ')}'.toLowerCase();
      double score = 0;

      if (haystack.contains(query)) score += 6;
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
    for (final answer in scored.take(2).map((entry) => entry.key)) {
      for (final insight in answer.insights) {
        if (merged.any((entry) => entry.toLowerCase() == insight.toLowerCase())) {
          continue;
        }
        merged.add(insight);
      }
    }

    return merged.take(4).toList(growable: false);
  }

  void _appendVerifiedInsights(StringBuffer buffer, List<String> verifiedInsights) {
    if (verifiedInsights.isEmpty) return;
    buffer.writeln('\n**Verified useful advice I learned from past cloud answers**');
    for (final insight in verifiedInsights.take(4)) {
      buffer.writeln('- $insight');
    }
  }

  void _appendTopicKnowledge(StringBuffer buffer, String q) {
    final matches = _knowledgeTopics.where(
      (topic) => topic.keywords.any((keyword) => q.contains(keyword)),
    );

    for (final topic in matches.take(3)) {
      buffer.writeln('\n**${topic.title}**');
      for (final tip in topic.tips) {
        buffer.writeln('- $tip');
      }
    }
  }
}

class _OfflineKnowledgeTopic {
  final String title;
  final List<String> keywords;
  final List<String> tips;

  const _OfflineKnowledgeTopic({
    required this.title,
    required this.keywords,
    required this.tips,
  });
}

const List<_OfflineKnowledgeTopic> _knowledgeTopics = [
  _OfflineKnowledgeTopic(
    title: 'Watering and irrigation',
    keywords: ['water', 'watering', 'irrigat', 'dry', 'drought'],
    tips: [
      'Water deeply so moisture reaches the root zone instead of only wetting the surface.',
      'Check the top few centimeters of soil before watering again to avoid overwatering.',
      'Use mulch to slow evaporation and reduce plant stress during heat.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Feeding and soil fertility',
    keywords: ['fertiliz', 'feed', 'nitrogen', 'phosphorus', 'potassium', 'nutrient'],
    tips: [
      'Match fertilizer strength to growth stage: leafy growth needs more nitrogen, flowering and fruiting need balanced feeding.',
      'Add compost regularly to improve structure, moisture retention, and slow nutrient release.',
      'Avoid heavy feeding in dry soil because it can stress roots.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Containers and raised beds',
    keywords: ['container', 'pot', 'raised bed', 'planter'],
    tips: [
      'Choose larger containers whenever possible because they dry out more slowly and buffer roots from heat.',
      'Refresh container mix with compost and slow-release nutrients during long growing seasons.',
      'Check containers more often during hot weather because they can need water daily.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Tomatoes and peppers',
    keywords: ['tomato', 'pepper', 'blossom end rot', 'nightshade'],
    tips: [
      'Keep soil moisture even to prevent stress-related issues such as blossom drop and blossom end rot.',
      'Support plants early with stakes or cages so stems are not damaged later.',
      'Remove lower leaves if they touch soil to reduce splash-borne disease pressure.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Compost and mulch',
    keywords: ['compost', 'mulch'],
    tips: [
      'Compost feeds soil biology best when applied regularly in thin layers rather than all at once.',
      'Keep mulch slightly away from stems and trunks to reduce rot and pest shelter.',
      'Shredded leaves and straw are useful mulches for retaining moisture and reducing weeds.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Pruning and training',
    keywords: ['prune', 'pruning', 'trim', 'train'],
    tips: [
      'Prune with a goal: improve structure, airflow, light penetration, or harvest access.',
      'Use clean tools and avoid removing too much live growth at one time.',
      'Time pruning around the plant type, since spring bloomers and fruiting crops respond differently.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Pests and disease prevention',
    keywords: ['pest', 'aphid', 'bug', 'disease', 'mildew', 'blight', 'rot'],
    tips: [
      'Scout often so small pest outbreaks can be handled before they spread.',
      'Prioritize airflow, sanitation, and spacing because they prevent many fungal problems.',
      'Remove heavily infested growth promptly and monitor the newest growth for reinfestation.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Seed starting and transplanting',
    keywords: ['seed', 'seedling', 'transplant', 'germinat'],
    tips: [
      'Give seedlings strong light early and rotate trays if light is uneven.',
      'Transplant when roots hold the potting mix together but are not yet circling tightly.',
      'Harden plants off gradually before exposing them to full sun and wind outdoors.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Fruit trees and berries',
    keywords: ['fruit', 'berry', 'tree', 'orchard'],
    tips: [
      'Maintain airflow and open structure to improve fruit quality and disease resistance.',
      'Thin overloaded branches so the plant can size fruit properly and avoid breakage.',
      'Deep watering is usually better than frequent shallow watering for woody crops.',
    ],
  ),
  _OfflineKnowledgeTopic(
    title: 'Pollinators and flowering plants',
    keywords: ['pollinat', 'bee', 'flower', 'bloom'],
    tips: [
      'Provide a sequence of blooms through the season to keep pollinators visiting.',
      'Avoid spraying even low-toxicity products when flowers are actively visited.',
      'Leave some habitat and water sources nearby for beneficial insects.',
    ],
  ),
];
