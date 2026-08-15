import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/rally_route.dart';
import '../../domain/entities/station.dart';
import '../../domain/value_objects/stamp_window.dart';

/// Stores a list of strings (aliases, rail lines, tags) as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String>
    with JsonTypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class StationLinkListConverter extends TypeConverter<List<StationLink>, String>
    with JsonTypeConverter<List<StationLink>, String> {
  const StationLinkListConverter();

  @override
  List<StationLink> fromSql(String fromDb) => [
    for (final entry in jsonDecode(fromDb) as List<dynamic>)
      StationLink.fromJson(entry as Map<String, dynamic>),
  ];

  @override
  String toSql(List<StationLink> value) =>
      jsonEncode([for (final link in value) link.toJson()]);
}

class StampWindowListConverter extends TypeConverter<List<StampWindow>, String>
    with JsonTypeConverter<List<StampWindow>, String> {
  const StampWindowListConverter();

  @override
  List<StampWindow> fromSql(String fromDb) => [
    for (final entry in jsonDecode(fromDb) as List<dynamic>)
      StampWindow.fromJson(entry as Map<String, dynamic>),
  ];

  @override
  String toSql(List<StampWindow> value) =>
      jsonEncode([for (final window in value) window.toJson()]);
}

/// Frozen copy of the route a run started from.
class RouteSnapshotConverter extends TypeConverter<RallyRoute, String>
    with JsonTypeConverter<RallyRoute, String> {
  const RouteSnapshotConverter();

  @override
  RallyRoute fromSql(String fromDb) =>
      RallyRoute.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(RallyRoute value) => jsonEncode(value.toJson());
}
