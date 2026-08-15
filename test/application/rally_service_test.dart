import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/application/rally_service.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_rally_repository.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';
import 'package:rallystamp/domain/value_objects/stamp_window.dart';
import 'package:rallystamp/domain/value_objects/time_of_day_value.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase database;
  late DriftRallyRepository repository;
  late RallyService service;
  var now = testMoment;

  setUp(() {
    now = testMoment;
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftRallyRepository(database);
    service = RallyService(repository, incrementingIds('rally'), () => now);
  });

  tearDown(() => database.close());

  /// Rally stations reference real rows, so seed both sides first.
  Future<String> seedRallyWithStations(List<String> stationIds) async {
    final rally = await service.save(const RallyDraft(name: 'Seeded rally'));
    await DriftStationRepository(
      database,
    ).saveAll([for (final id in stationIds) station(id)]);
    return rally.id;
  }

  test('saving a new draft assigns an id and timestamps', () async {
    final saved = await service.save(const RallyDraft(name: 'Spring rally'));

    expect(saved.id, isNotEmpty);
    expect(saved.createdAt, testMoment);
    expect(await repository.findById(saved.id), saved);
  });

  test('editing preserves the creation time and updates defaults', () async {
    final created = await service.save(const RallyDraft(name: 'Spring rally'));

    now = testMoment.add(const Duration(days: 1));
    final edited = await service.save(
      RallyDraft(
        id: created.id,
        name: 'Spring rally 2026',
        defaultStampWindows: const [
          StampWindow(
            start: TimeOfDayValue(hour: 9, minute: 0),
            end: TimeOfDayValue(hour: 17, minute: 0),
          ),
        ],
      ),
    );

    expect(edited.name, 'Spring rally 2026');
    expect(edited.defaultStampWindows.single.start.format(), '09:00');
    expect(edited.createdAt, testMoment);
    expect(edited.updatedAt, now);
  });

  test('adding stations skips the ones already in the rally', () async {
    final rallyId = await seedRallyWithStations([
      'station-a',
      'station-b',
      'station-c',
    ]);

    await service.addStations(rallyId, ['station-a', 'station-b']);
    await service.addStations(rallyId, ['station-b', 'station-c']);

    final stations = await repository.findStations(rallyId);
    expect(
      stations.map((station) => station.stationId),
      unorderedEquals(['station-a', 'station-b', 'station-c']),
    );
  });

  test('overlay edits keep the same rally station row', () async {
    final rallyId = await seedRallyWithStations(['station-a']);
    await service.addStations(rallyId, ['station-a']);
    final original = (await repository.findStations(rallyId)).single;

    now = testMoment.add(const Duration(hours: 1));
    await service.saveStation(
      RallyStationDraft(
        id: original.id,
        rallyId: original.rallyId,
        stationId: original.stationId,
        stampLocation: 'Next to the ticket gates',
        sequenceHint: 2,
        requiresPurchase: true,
      ),
    );

    final updated = (await repository.findStations(rallyId)).single;
    expect(updated.id, original.id);
    expect(updated.stampLocation, 'Next to the ticket gates');
    expect(updated.sequenceHint, 2);
    expect(updated.requiresPurchase, isTrue);
    expect(updated.createdAt, testMoment);
    expect(updated.updatedAt, now);
  });

  test('removing a station takes it out of the rally listing', () async {
    final rallyId = await seedRallyWithStations(['station-a']);
    await service.addStations(rallyId, ['station-a']);
    final added = (await repository.findStations(rallyId)).single;

    await service.removeStation(added.id);

    expect(await repository.findStations(rallyId), isEmpty);
  });
}
