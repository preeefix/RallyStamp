import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/coordinates.dart';

part 'station.freezed.dart';
part 'station.g.dart';

/// Where a [StationLink] points, so the UI can label and order links.
enum MapLinkKind {
  googleMaps,
  appleMaps,
  navitime,
  jorudan,
  officialSite,
  custom,
}

/// An external link attached to a station, e.g. a Google Maps or Navitime URL.
@freezed
abstract class StationLink with _$StationLink {
  const factory StationLink({
    required String id,
    required MapLinkKind kind,
    required String url,
    String? label,
  }) = _StationLink;

  factory StationLink.fromJson(Map<String, dynamic> json) =>
      _$StationLinkFromJson(json);
}

/// A reusable, rally-independent place where stamps may be collected.
///
/// Stations are shared across rallies; anything rally-specific belongs on
/// `RallyStation` instead.
@freezed
abstract class Station with _$Station {
  const factory Station({
    required String id,
    required String name,
    required Coordinates coordinates,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? nameLocal,
    @Default(<String>[]) List<String> aliases,
    String? address,
    String? operatorName,
    @Default(<String>[]) List<String> lines,
    @Default(<String>[]) List<String> tags,
    String? notes,
    @Default(<StationLink>[]) List<StationLink> links,
    DateTime? deletedAt,
  }) = _Station;

  const Station._();

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);

  bool get isDeleted => deletedAt != null;

  /// Name plus local-language name when they differ, for list rows.
  String get displayName =>
      (nameLocal == null || nameLocal == name) ? name : '$name ($nameLocal)';
}
