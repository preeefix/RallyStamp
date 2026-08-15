import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rallystamp/application/station_service.dart';
import 'package:rallystamp/data/database/app_database.dart';
import 'package:rallystamp/data/repositories/drift_station_repository.dart';
import 'package:rallystamp/domain/entities/station.dart';
import 'package:rallystamp/domain/value_objects/coordinates.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase database;
  late DriftStationRepository repository;
  late StationService service;
  var now = testMoment;

  setUp(() {
    now = testMoment;
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftStationRepository(database);
    service = StationService(repository, incrementingIds('station'), () => now);
  });

  tearDown(() => database.close());

  const tokyo = Coordinates(latitude: 35.681236, longitude: 139.767125);

  test('saving a new draft assigns an id and both timestamps', () async {
    final saved = await service.save(
      const StationDraft(name: 'Tokyo', coordinates: tokyo),
    );

    expect(saved.id, 'station-0');
    expect(saved.createdAt, testMoment);
    expect(saved.updatedAt, testMoment);
    expect(await repository.findById(saved.id), saved);
  });

  test('editing keeps the creation time and clears emptied fields', () async {
    final created = await service.save(
      const StationDraft(
        name: 'Tokyo',
        coordinates: tokyo,
        nameLocal: '東京駅',
        lines: ['Yamanote'],
      ),
    );

    now = testMoment.add(const Duration(hours: 2));
    final edited = await service.save(
      StationDraft(id: created.id, name: 'Tokyo Station', coordinates: tokyo),
    );

    expect(edited.name, 'Tokyo Station');
    expect(edited.nameLocal, isNull);
    expect(edited.lines, isEmpty);
    expect(edited.createdAt, testMoment);
    expect(edited.updatedAt, now);
  });

  test('links survive a save round trip', () async {
    final saved = await service.save(
      StationDraft(
        name: 'Tokyo',
        coordinates: tokyo,
        links: [
          StationLink(
            id: service.newLinkId(),
            kind: MapLinkKind.googleMaps,
            url: 'https://maps.example/tokyo',
          ),
        ],
      ),
    );

    expect(
      (await repository.findById(saved.id))!.links.single.url,
      'https://maps.example/tokyo',
    );
  });

  test('deleting hides the station without dropping the row', () async {
    final saved = await service.save(
      const StationDraft(name: 'Tokyo', coordinates: tokyo),
    );

    await service.delete(saved.id);

    expect(await repository.findById(saved.id), isNull);
    expect(await repository.findAll(), isEmpty);
  });

  group('filterStations', () {
    final stations = [
      station(
        'a',
        name: 'Tokyo',
      ).copyWith(nameLocal: '東京', lines: const ['Yamanote']),
      station('b', name: 'Shinjuku').copyWith(aliases: const ['SJK']),
    ];

    test('an empty query keeps every station', () {
      expect(filterStations(stations, '  '), stations);
    });

    test('matches name, local name, aliases and lines case-insensitively', () {
      expect(filterStations(stations, 'tok').single.name, 'Tokyo');
      expect(filterStations(stations, '東京').single.name, 'Tokyo');
      expect(filterStations(stations, 'sjk').single.name, 'Shinjuku');
      expect(filterStations(stations, 'yamanote').single.name, 'Tokyo');
    });

    test('an unmatched query returns nothing', () {
      expect(filterStations(stations, 'osaka'), isEmpty);
    });
  });
}
