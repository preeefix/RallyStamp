import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/station.dart';
import '../domain/repositories/repositories.dart';
import '../domain/value_objects/coordinates.dart';
import 'providers.dart';

/// Everything the station form needs to produce a saved [Station].
///
/// Drafts carry the raw editable values so the form stays free of timestamp
/// and identifier concerns; those are applied here on save.
class StationDraft {
  const StationDraft({
    required this.name,
    required this.coordinates,
    this.id,
    this.nameLocal,
    this.aliases = const [],
    this.address,
    this.operatorName,
    this.lines = const [],
    this.tags = const [],
    this.notes,
    this.links = const [],
  });

  final String? id;
  final String name;
  final Coordinates coordinates;
  final String? nameLocal;
  final List<String> aliases;
  final String? address;
  final String? operatorName;
  final List<String> lines;
  final List<String> tags;
  final String? notes;
  final List<StationLink> links;
}

/// Creates, updates and deletes stations, keeping ids and timestamps in one
/// place so screens only deal with the values a user typed.
class StationService {
  StationService(this._repository, this._idFactory, this._clock);

  final StationRepository _repository;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  Future<Station> save(StationDraft draft) async {
    final now = _clock();
    final existing = draft.id == null
        ? null
        : await _repository.findById(draft.id!);
    final station =
        (existing ??
                Station(
                  id: draft.id ?? _idFactory(),
                  name: draft.name,
                  coordinates: draft.coordinates,
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(
              name: draft.name,
              coordinates: draft.coordinates,
              nameLocal: draft.nameLocal,
              aliases: draft.aliases,
              address: draft.address,
              operatorName: draft.operatorName,
              lines: draft.lines,
              tags: draft.tags,
              notes: draft.notes,
              links: draft.links,
              updatedAt: now,
            );
    await _repository.save(station);
    return station;
  }

  Future<void> delete(String id) => _repository.delete(id, deletedAt: _clock());

  String newLinkId() => _idFactory();
}

final stationServiceProvider = Provider<StationService>(
  (ref) => StationService(
    ref.watch(stationRepositoryProvider),
    ref.watch(idFactoryProvider),
    ref.watch(clockProvider),
  ),
);

/// Watched rather than fetched once, so an edited station is never rendered
/// from a value cached before the last save.
final stationProvider = StreamProvider.family<Station?, String>(
  (ref, id) => ref
      .watch(stationRepositoryProvider)
      .watchAll()
      .map(
        (stations) => stations.firstWhereOrNull((station) => station.id == id),
      ),
);

/// Stations matching a case-insensitive query over name, local name, aliases
/// and lines, so a long list stays usable on a phone.
List<Station> filterStations(List<Station> stations, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return stations;
  return [
    for (final station in stations)
      if ([
        station.name,
        station.nameLocal ?? '',
        ...station.aliases,
        ...station.lines,
      ].any((value) => value.toLowerCase().contains(needle)))
        station,
  ];
}
