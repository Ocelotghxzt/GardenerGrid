class ForagingIdentification {
  final String leaves;
  final String stem;
  final String flower;
  final String fruit;
  final String lookalikes;

  const ForagingIdentification({
	required this.leaves,
	required this.stem,
	required this.flower,
	required this.fruit,
	required this.lookalikes,
  });

  factory ForagingIdentification.fromJson(Map<String, dynamic> j) =>
	  ForagingIdentification(
		leaves: j['leaves'] as String,
		stem: j['stem'] as String,
		flower: j['flower'] as String,
		fruit: j['fruit'] as String,
		lookalikes: j['lookalikes'] as String,
	  );
}

class ForagingEntry {
  final String id;
  final String name;
  final String scientificName;
  final String category;
  final List<String> tags;
  final String edibility;
  final String season;
  final List<String> habitat;
  final String description;
  final ForagingIdentification identification;
  final String lookalikeDanger;
  final String harvestNotes;
  final String nutritionHighlights;
  final List<String> preparationMethods;
  final String medicinalUses;
  final String ecologicalRole;
  final List<String> safetyWarnings;
  final String? imageAsset;

  const ForagingEntry({
	required this.id,
	required this.name,
	required this.scientificName,
	required this.category,
	required this.tags,
	required this.edibility,
	required this.season,
	required this.habitat,
	required this.description,
	required this.identification,
	required this.lookalikeDanger,
	required this.harvestNotes,
	required this.nutritionHighlights,
	required this.preparationMethods,
	required this.medicinalUses,
	required this.ecologicalRole,
	required this.safetyWarnings,
	this.imageAsset,
  });

  factory ForagingEntry.fromJson(Map<String, dynamic> j) => ForagingEntry(
		id: j['id'] as String,
		name: j['name'] as String,
		scientificName: j['scientificName'] as String,
		category: j['category'] as String,
		tags: List<String>.from(j['tags'] ?? []),
		edibility: j['edibility'] as String,
		season: j['season'] as String,
		habitat: List<String>.from(j['habitat'] ?? []),
		description: j['description'] as String,
		identification:
			ForagingIdentification.fromJson(j['identification'] as Map<String, dynamic>),
		lookalikeDanger: j['lookalikeDanger'] as String,
		harvestNotes: j['harvestNotes'] as String,
		nutritionHighlights: j['nutritionHighlights'] as String,
		preparationMethods: List<String>.from(j['preparationMethods'] ?? []),
		medicinalUses: j['medicinalUses'] as String,
		ecologicalRole: j['ecologicalRole'] as String,
		safetyWarnings: List<String>.from(j['safetyWarnings'] ?? []),
		imageAsset: j['imageAsset'] as String?,
	  );
}
