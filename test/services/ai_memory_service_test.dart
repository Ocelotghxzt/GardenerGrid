import 'package:flutter_test/flutter_test.dart';
import 'package:gardenergrid/services/ai_memory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('extracts gardening notes from personal statements', () {
    final service = AiMemoryService();

    final notes = service.extractNotes(
      'Remember that I grow tomatoes in containers. My soil is heavy clay.',
    );

    expect(notes, isNotEmpty);
    expect(notes.join(' '), contains('grow tomatoes'));
  });

  test('stores verified gardening insights from useful cloud answers', () async {
    final service = AiMemoryService();

    final learned = await service.learnFromVerifiedAnswer(
      question: 'How do I prevent blossom end rot in tomatoes?',
      answer: '''
## Tomato care
- Keep soil moisture even so calcium uptake stays steady.
- Mulch the root zone to reduce moisture swings.
- Avoid overfeeding with high-nitrogen fertilizer during fruit set.
''',
    );

    expect(learned, hasLength(1));
    expect(
      learned.single.question,
      'How do I prevent blossom end rot in tomatoes?',
    );
    expect(
      learned.single.insights,
      contains('Keep soil moisture even so calcium uptake stays steady.'),
    );
  });
}
