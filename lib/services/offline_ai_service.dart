import '../models/soil_sample.dart';
import '../models/plant_entry.dart';
import '../models/foraging_entry.dart';

/// Lightweight rules-based AI that works 100% offline.
/// Uses the bundled encyclopedia data and soil readings to answer questions.
class OfflineAiService {
  final List<PlantEntry> plants;
  final List<ForagingEntry> foraging;

  OfflineAiService({required this.plants, required this.foraging});

  // ── Entry point ──────────────────────────────────────────────────────────
  String answer(String query, {SoilSample? soilContext}) {
	final q = query.toLowerCase();

	// 1. Soil-contextual responses
	if (soilContext != null && _hasSoilKeywords(q)) {
	  return _soilResponse(q, soilContext);
	}

	// 2. Foraging queries
	if (_hasForagingKeywords(q)) {
	  return _foragingResponse(q);
	}

	// 3. Plant/gardening lookup
	final plantMatch = _findPlant(q);
	if (plantMatch != null) {
	  return _plantResponse(plantMatch, q);
	}

	final rankedPlants = _rankPlantsByQuery(q);
	if (rankedPlants.isNotEmpty) {
	  return _rankedPlantResponse(query, rankedPlants);
	}

	// 4. Companion planting
	if (q.contains('companion')) {
	  return _companionResponse(q);
	}

	// 5. Pest queries
	if (_hasPestKeywords(q)) {
	  return _pestResponse(q);
	}

	// 5b. Advanced topics
	if (_hasAdvancedTopicKeywords(q)) {
	  return _advancedTopicResponse(q);
	}

	// 6. General gardening tips
	if (_hasGardeningKeywords(q)) {
	  return _gardeningTipsResponse(q);
	}

	// 7. Fallback
	return _fallback(query);
  }

  List<PlantEntry> _rankPlantsByQuery(String q) {
	final terms = q
		.split(RegExp(r'[^a-z0-9]+'))
		.where((t) => t.length > 2)
		.toSet();
	if (terms.isEmpty) return const <PlantEntry>[];

	final scored = <MapEntry<PlantEntry, int>>[];
	for (final plant in plants) {
	  var score = 0;
	  final bag = [
		plant.name,
		plant.scientificName,
		plant.family,
		plant.category,
		plant.description,
		plant.tags.join(' '),
		plant.gardeningTips,
	  ].join(' ').toLowerCase();

	  for (final term in terms) {
		if (bag.contains(term)) score += 1;
	  }

	  if (score > 0) {
		scored.add(MapEntry(plant, score));
	  }
	}

	scored.sort((a, b) => b.value.compareTo(a.value));
	return scored.take(3).map((e) => e.key).toList();
  }

  String _rankedPlantResponse(String originalQuery, List<PlantEntry> matches) {
	final buf = StringBuffer();
	buf.writeln('**Offline answer for:** "$originalQuery"\n');
	buf.writeln('Most relevant plants in local data:');
	for (final p in matches) {
	  buf.writeln('- **${p.name}** (*${p.scientificName}*): ${p.gardeningTips}');
	}
	buf.writeln('\nIf you want, ask for one of these by name and I will give full care details.');
	return buf.toString();
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
	  q.contains('aphid') || q.contains('disease');

  bool _hasGardeningKeywords(String q) =>
	  q.contains('plant') || q.contains('grow') || q.contains('garden') ||
	  q.contains('propagat') || q.contains('water') || q.contains('prune') ||
	  q.contains('bloom') || q.contains('seed');

  // ── Response builders ─────────────────────────────────────────────────────
  String _soilResponse(String q, SoilSample soil) {
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

  PlantEntry? _findPlant(String q) {
	for (final p in plants) {
	  if (q.contains(p.name.toLowerCase()) ||
		  q.contains(p.id.replaceAll('_', ' '))) {
		return p;
	  }
	}
	for (final p in plants) {
	  for (final tag in p.tags) {
		if (q.contains(tag)) return p;
	  }
	}
	return null;
  }

  String _plantResponse(PlantEntry p, String q) {
	final buf = StringBuffer();
	buf.writeln('## 🌿 ${p.name}');
	buf.writeln('*${p.scientificName}* · ${p.family} · **${p.category}**\n');
	buf.writeln(p.description);
	buf.writeln('\n**Growing Conditions**');
	buf.writeln('- 🌍 Soil: ${p.soilPreference}');
	buf.writeln('- ☀️ Sunlight: ${p.sunlight}');
	buf.writeln('- 💧 Water: ${p.water}');
	buf.writeln('- 🌡️ Hardiness Zone: ${p.hardinessZone}');
	buf.writeln('- 📏 Size: ${p.heightCm}cm tall × ${p.spreadCm}cm wide');
	buf.writeln('- 🌸 Bloom: ${p.bloomSeason}');

	if (p.companionPlants.isNotEmpty) {
	  buf.writeln('\n**Companion Plants:** ${p.companionPlants.join(', ')}');
	}
	if (p.pestRepellent.isNotEmpty) {
	  buf.writeln('**Repels:** ${p.pestRepellent.join(', ')}');
	}
	if (p.culinaryUses.isNotEmpty && p.culinaryUses != 'None') {
	  buf.writeln('\n🍽️ **Culinary:** ${p.culinaryUses}');
	}
	if (p.medicinalUses.isNotEmpty) {
	  buf.writeln('💊 **Medicinal:** ${p.medicinalUses}');
	}
	buf.writeln('\n🌱 **Gardening Tips:** ${p.gardeningTips}');
	buf.writeln('**Propagation:** ${p.propagation}');
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

  String _pestResponse(String q) {
	final buf = StringBuffer();
	buf.writeln('**🐛 Natural Pest Control (Offline)**\n');
	final repellers =
		plants.where((p) => p.pestRepellent.isNotEmpty).toList();
	for (final p in repellers) {
	  buf.writeln('**${p.name}** repels: ${p.pestRepellent.join(', ')}');
	}
	buf.writeln(
		'\n> Tip: Intercropping pest-repelling plants among vegetables is one of the most effective organic pest management strategies.');
	return buf.toString();
  }

  String _gardeningTipsResponse(String q) {
	final buf = StringBuffer();
	buf.writeln('**🌱 Gardening Tips (Offline)**\n');
	buf.writeln(
		'I have tips for ${plants.length} plants in the offline encyclopedia. Ask me about a specific plant or topic.\n');

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

	return buf.toString();
  }

  String _advancedTopicResponse(String q) {
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

	return buf.toString();
  }

  String _fallback(String userQuery) {
	final buf = StringBuffer();
	buf.writeln('**GardenerGrid Offline Assistant**\n');
	buf.writeln('I could not fully map this question yet: "$userQuery"\n');
	buf.writeln(
		"I'm running in **offline mode** with a local knowledge base. I can help with:\n");
	buf.writeln('- 🌿 **Plant encyclopedia** — Ask about ${plants.take(3).map((p) => p.name).join(', ')}, and more');
	buf.writeln('- 🍃 **Foraging guide** — Wild edibles, identification, safety');
	buf.writeln('- 🧪 **Soil analysis** — Add a soil sample or use a BLE sensor for personalized advice');
	buf.writeln('- 🤝 **Companion planting** — Ask "what are companion plants for basil?"');
	buf.writeln('- 🐛 **Pest control** — Ask "what repels aphids?"');
	buf.writeln('\n> For more detailed, conversational answers, **enable Online Mode** in the AI settings.');
	return buf.toString();
  }
}
