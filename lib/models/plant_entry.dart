class PlantEntry {
  final String id;
  final String name;
  final String scientificName;
  final String family;
  final String category;
  final List<String> tags;
  final String description;
  final String soilPreference;
  final String sunlight;
  final String water;
  final double phMin;
  final double phMax;
  final String hardinessZone;
  final double heightCm;
  final double spreadCm;
  final String bloomSeason;
  final List<String> companionPlants;
  final List<String> pestRepellent;
  final String culinaryUses;
  final String medicinalUses;
  final String gardeningTips;
  final String propagation;
  final String? imageAsset;

  const PlantEntry({
	required this.id,
	required this.name,
	required this.scientificName,
	required this.family,
	required this.category,
	required this.tags,
	required this.description,
	required this.soilPreference,
	required this.sunlight,
	required this.water,
	required this.phMin,
	required this.phMax,
	required this.hardinessZone,
	required this.heightCm,
	required this.spreadCm,
	required this.bloomSeason,
	required this.companionPlants,
	required this.pestRepellent,
	required this.culinaryUses,
	required this.medicinalUses,
	required this.gardeningTips,
	required this.propagation,
	this.imageAsset,
  });

  factory PlantEntry.fromJson(Map<String, dynamic> j) => PlantEntry(
		id: j['id'] as String,
		name: j['name'] as String,
		scientificName: j['scientificName'] as String,
		family: j['family'] as String,
		category: j['category'] as String,
		tags: List<String>.from(j['tags'] ?? []),
		description: j['description'] as String,
		soilPreference: j['soilPreference'] as String,
		sunlight: j['sunlight'] as String,
		water: j['water'] as String,
		phMin: (j['phMin'] ?? 5.5).toDouble(),
		phMax: (j['phMax'] ?? 7.5).toDouble(),
		hardinessZone: j['hardinessZone'] as String,
		heightCm: (j['heightCm'] ?? 0).toDouble(),
		spreadCm: (j['spreadCm'] ?? 0).toDouble(),
		bloomSeason: j['bloomSeason'] as String,
		companionPlants: List<String>.from(j['companionPlants'] ?? []),
		pestRepellent: List<String>.from(j['pestRepellent'] ?? []),
		culinaryUses: j['culinaryUses'] as String,
		medicinalUses: j['medicinalUses'] as String,
		gardeningTips: j['gardeningTips'] as String,
		propagation: j['propagation'] as String,
		imageAsset: j['imageAsset'] as String?,
	  );
}
