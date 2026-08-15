import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/domain/entities/rally.dart';

import '../support/fixtures.dart';

void main() {
  group('Rally.isActiveOn', () {
    Rally limited() => rally(
      'rally-1',
    ).copyWith(startsOn: DateTime(2026, 8, 10), endsOn: DateTime(2026, 8, 20));

    test('covers the whole of the first and last day', () {
      expect(limited().isActiveOn(DateTime(2026, 8, 10, 0, 1)), isTrue);
      expect(limited().isActiveOn(DateTime(2026, 8, 20, 18)), isTrue);
    });

    test('excludes days outside the range', () {
      expect(limited().isActiveOn(DateTime(2026, 8, 9, 23)), isFalse);
      expect(limited().isActiveOn(DateTime(2026, 8, 21)), isFalse);
    });

    test('is always active without dates', () {
      expect(rally('rally-1').isActiveOn(DateTime(2026, 1, 1)), isTrue);
    });
  });
}
