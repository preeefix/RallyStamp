import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/data/database/app_database.dart';

void main() {
  WebStorageReport report(String implementation) => WebStorageReport(
    implementation: implementation,
    missingFeatures: const [],
  );

  test('drift fallbacks that can lose writes are not durable', () {
    expect(report('unsafeIndexedDb').isDurable, isFalse);
    expect(report('inMemory').isDurable, isFalse);
  });

  test('worker-backed implementations are durable', () {
    for (final implementation in [
      'opfsShared',
      'opfsLocks',
      'sharedIndexedDb',
    ]) {
      expect(report(implementation).isDurable, isTrue, reason: implementation);
    }
  });
}
