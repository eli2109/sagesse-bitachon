import 'package:flutter_test/flutter_test.dart';
import 'package:sagesse_bitachon/models/reading_state.dart';

void main() {
  group('ReadingState', () {
    test('serializes and deserializes correctly', () {
      const state = ReadingState(order: [3, 1, 0, 2], pos: 2);

      final restored = ReadingState.fromJson(state.toJson());

      expect(restored.order, [3, 1, 0, 2]);
      expect(restored.pos, 2);
      expect(restored.currentIndex, 0);
      expect(restored.cycleLength, 4);
    });

    test('handles empty state safely', () {
      const state = ReadingState(order: [], pos: 0);

      expect(state.isEmpty, isTrue);
      expect(state.currentIndex, isNull);
      expect(state.cycleLength, 0);
    });
  });
}