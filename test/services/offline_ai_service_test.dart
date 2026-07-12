import 'package:flutter_test/flutter_test.dart';
import 'package:gardenergrid/models/foraging_entry.dart';
import 'package:gardenergrid/models/plant_entry.dart';
import 'package:gardenergrid/services/offline_ai_service.dart';

void main() {
  final basil = PlantEntry(
    id: 'basil',
    name: 'Basil',
    scientificName: 'Ocimum basilicum',
    family: 'Lamiaceae',
    category: 'Herb',
    tags: const ['culinary', 'annual', 'aromatic', 'companion'],
    description: 'A warm-season herb grown for fragrant leaves.',
    soilPreference: 'Rich, well-drained soil',
    sunlight: 'Full sun',
    water: 'Even moisture',
    phMin: 6,
    phMax: 7.5,
    hardinessZone: '10-11',
    heightCm: 45,
    spreadCm: 30,
    bloomSeason: 'Summer',
    companionPlants: const ['Tomatoes'],
    pestRepellent: const ['aphids'],
    culinaryUses: 'Fresh leaves for sauces and salads',
    medicinalUses: 'Traditional calming herb',
    gardeningTips: 'Pinch flower buds to keep leaf production high.',
    propagation: 'Seed or cuttings',
  );

  final foraging = ForagingEntry(
    id: 'blackberry',
    name: 'Blackberry',
    scientificName: 'Rubus fruticosus',
    category: 'Berry',
    tags: const ['edible'],
    edibility: 'Edible',
    season: 'Summer',
    habitat: const ['Edges', 'Fields'],
    description: 'A thorny berry-producing bramble.',
    identification: const ForagingIdentification(
      leaves: 'Compound leaves',
      stem: 'Arching canes',
      flower: 'White or pink flowers',
      fruit: 'Black aggregate berries',
      lookalikes: 'Unripe raspberries',
    ),
    lookalikeDanger: 'Low',
    harvestNotes: 'Pick fully black berries.',
    nutritionHighlights: 'Vitamin C',
    preparationMethods: const ['Fresh', 'Jam'],
    medicinalUses: 'Traditional food plant',
    ecologicalRole: 'Supports wildlife',
    safetyWarnings: const ['Wash before eating'],
  );

  test('answers using common plant names and learned context', () {
    final service = OfflineAiService(plants: [basil], foraging: [foraging]);

    final answer = service.answer(
      'How do I care for basil?',
      learnedContext: const ['My garden is mostly containers on a sunny patio'],
    );

    expect(answer, contains('Basil'));
    expect(answer, contains('Ocimum basilicum'));
    expect(answer, contains('Remembered growing context'));
  });
}
