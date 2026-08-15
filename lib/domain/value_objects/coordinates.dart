import 'package:freezed_annotation/freezed_annotation.dart';

part 'coordinates.freezed.dart';
part 'coordinates.g.dart';

/// A WGS84 geographic position.
@freezed
abstract class Coordinates with _$Coordinates {
  const factory Coordinates({
    required double latitude,
    required double longitude,
  }) = _Coordinates;

  factory Coordinates.fromJson(Map<String, dynamic> json) =>
      _$CoordinatesFromJson(json);

  static bool isValidLatitude(double value) => value >= -90 && value <= 90;

  static bool isValidLongitude(double value) => value >= -180 && value <= 180;
}

extension CoordinatesX on Coordinates {
  bool get isValid =>
      Coordinates.isValidLatitude(latitude) &&
      Coordinates.isValidLongitude(longitude);

  /// `lat,lng` as expected by most map providers.
  String get asQueryValue => '$latitude,$longitude';
}
