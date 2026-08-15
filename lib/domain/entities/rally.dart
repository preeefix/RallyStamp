import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/stamp_window.dart';

part 'rally.freezed.dart';
part 'rally.g.dart';

/// A stamp rally: a named collection of stations, usually time limited.
@freezed
abstract class Rally with _$Rally {
  const factory Rally({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? organizer,
    String? description,
    DateTime? startsOn,
    DateTime? endsOn,
    String? externalUrl,
    @Default(<StampWindow>[]) List<StampWindow> defaultStampWindows,
    DateTime? deletedAt,
  }) = _Rally;

  const Rally._();

  factory Rally.fromJson(Map<String, dynamic> json) => _$RallyFromJson(json);

  bool get isDeleted => deletedAt != null;

  bool isActiveOn(DateTime day) {
    if (startsOn != null && day.isBefore(startsOn!)) return false;
    if (endsOn != null && day.isAfter(endsOn!)) return false;
    return true;
  }
}

/// Rally-specific overlay data for one station participating in a rally.
///
/// The same station can participate in many rallies with different stamp
/// locations and hours, so this data lives here instead of on `Station`.
@freezed
abstract class RallyStation with _$RallyStation {
  const factory RallyStation({
    required String id,
    required String rallyId,
    required String stationId,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? stampLocation,
    String? stampCode,
    int? sequenceHint,
    @Default(false) bool requiresPurchase,
    String? notes,
    @Default(<StampWindow>[]) List<StampWindow> stampWindows,
    DateTime? deletedAt,
  }) = _RallyStation;

  const RallyStation._();

  factory RallyStation.fromJson(Map<String, dynamic> json) =>
      _$RallyStationFromJson(json);

  bool get isDeleted => deletedAt != null;

  /// Whether a stamp can be collected at [moment], falling back to the rally's
  /// default windows when this station defines none.
  bool isStampAvailableAt(
    DateTime moment, {
    List<StampWindow> rallyDefaults = const [],
  }) {
    final windows = stampWindows.isNotEmpty ? stampWindows : rallyDefaults;
    if (windows.isEmpty) return true;
    return windows.any((window) => window.contains(moment));
  }
}
