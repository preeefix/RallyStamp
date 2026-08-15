import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/rally.dart';
import '../domain/repositories/repositories.dart';
import '../domain/value_objects/stamp_window.dart';
import 'providers.dart';

/// The editable fields of a rally, before ids and timestamps are applied.
class RallyDraft {
  const RallyDraft({
    required this.name,
    this.id,
    this.organizer,
    this.description,
    this.startsOn,
    this.endsOn,
    this.externalUrl,
    this.defaultStampWindows = const [],
  });

  final String? id;
  final String name;
  final String? organizer;
  final String? description;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String? externalUrl;
  final List<StampWindow> defaultStampWindows;
}

/// The editable fields of a station's rally-specific overlay.
class RallyStationDraft {
  const RallyStationDraft({
    required this.rallyId,
    required this.stationId,
    this.id,
    this.stampLocation,
    this.stampCode,
    this.sequenceHint,
    this.requiresPurchase = false,
    this.notes,
    this.stampWindows = const [],
  });

  final String? id;
  final String rallyId;
  final String stationId;
  final String? stampLocation;
  final String? stampCode;
  final int? sequenceHint;
  final bool requiresPurchase;
  final String? notes;
  final List<StampWindow> stampWindows;
}

/// Creates and edits rallies and the stations taking part in them.
class RallyService {
  RallyService(this._repository, this._idFactory, this._clock);

  final RallyRepository _repository;
  final String Function() _idFactory;
  final DateTime Function() _clock;

  Future<Rally> save(RallyDraft draft) async {
    final now = _clock();
    final existing = draft.id == null
        ? null
        : await _repository.findById(draft.id!);
    final rally =
        (existing ??
                Rally(
                  id: draft.id ?? _idFactory(),
                  name: draft.name,
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(
              name: draft.name,
              organizer: draft.organizer,
              description: draft.description,
              startsOn: draft.startsOn,
              endsOn: draft.endsOn,
              externalUrl: draft.externalUrl,
              defaultStampWindows: draft.defaultStampWindows,
              updatedAt: now,
            );
    await _repository.save(rally);
    return rally;
  }

  Future<void> delete(String id) => _repository.delete(id, deletedAt: _clock());

  Future<void> saveStation(RallyStationDraft draft) async {
    final now = _clock();
    final existing = draft.id == null
        ? null
        : (await _repository.findStations(
            draft.rallyId,
          )).where((station) => station.id == draft.id).firstOrNull;
    await _repository.saveStation(
      (existing ??
              RallyStation(
                id: draft.id ?? _idFactory(),
                rallyId: draft.rallyId,
                stationId: draft.stationId,
                createdAt: now,
                updatedAt: now,
              ))
          .copyWith(
            stampLocation: draft.stampLocation,
            stampCode: draft.stampCode,
            sequenceHint: draft.sequenceHint,
            requiresPurchase: draft.requiresPurchase,
            notes: draft.notes,
            stampWindows: draft.stampWindows,
            updatedAt: now,
          ),
    );
  }

  /// Adds stations that are not in the rally yet, keeping existing overlays.
  Future<void> addStations(String rallyId, Iterable<String> stationIds) async {
    final existing = {
      for (final station in await _repository.findStations(rallyId))
        station.stationId,
    };
    for (final stationId in stationIds) {
      if (existing.contains(stationId)) continue;
      await saveStation(
        RallyStationDraft(rallyId: rallyId, stationId: stationId),
      );
    }
  }

  Future<void> removeStation(String rallyStationId) =>
      _repository.removeStation(rallyStationId, deletedAt: _clock());
}

final rallyServiceProvider = Provider<RallyService>(
  (ref) => RallyService(
    ref.watch(rallyRepositoryProvider),
    ref.watch(idFactoryProvider),
    ref.watch(clockProvider),
  ),
);

final rallyProvider = FutureProvider.family<Rally?, String>(
  (ref, id) => ref.watch(rallyRepositoryProvider).findById(id),
);

final rallyStationsProvider = StreamProvider.family<List<RallyStation>, String>(
  (ref, rallyId) => ref.watch(rallyRepositoryProvider).watchStations(rallyId),
);
