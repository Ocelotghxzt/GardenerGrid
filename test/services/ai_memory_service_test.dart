import 'package:flutter_test/flutter_test.dart';
import 'package:gardenergrid/services/ai_memory_service.dart';

void main() {
  test('extracts gardening notes from personal statements', () {
    final service = AiMemoryService();

    final notes = service.extractNotes(
      'Remember that I grow tomatoes in containers. My soil is heavy clay.',
    );

    expect(notes, isNotEmpty);
    expect(notes.join(' '), contains('grow tomatoes'));
  });
}
