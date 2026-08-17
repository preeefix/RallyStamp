import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/station.dart';
import '../../domain/value_objects/time_of_day_value.dart';
import '../../l10n/app_localizations.dart';

/// Splits a comma separated field into trimmed, non-empty values.
List<String> parseCommaSeparated(String value) => [
  for (final part in value.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

/// The trimmed text, or `null` when the user left the field empty.
String? optionalText(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : value;
}

/// Whether [value] is an absolute http(s) URL we can hand to the platform.
bool isValidUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

/// A duration in the compact form used across route and run summaries.
String formatMinutes(AppLocalizations l10n, int minutes) => minutes < 60
    ? l10n.durationMinutes(minutes)
    : l10n.durationHoursMinutes(minutes ~/ 60, minutes % 60);

String mapLinkKindLabel(AppLocalizations l10n, MapLinkKind kind) =>
    switch (kind) {
      MapLinkKind.googleMaps => l10n.linkKindGoogleMaps,
      MapLinkKind.appleMaps => l10n.linkKindAppleMaps,
      MapLinkKind.navitime => l10n.linkKindNavitime,
      MapLinkKind.jorudan => l10n.linkKindJorudan,
      MapLinkKind.officialSite => l10n.linkKindOfficialSite,
      MapLinkKind.custom => l10n.linkKindCustom,
    };

/// Read-only field showing an optional wall-clock time, stored as `HH:mm` so
/// it stays free of any date or time zone.
class TimePickerField extends StatelessWidget {
  const TimePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final TimeOfDayValue? value;
  final ValueChanged<TimeOfDayValue?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value == null
              ? const TimeOfDay(hour: 9, minute: 0)
              : TimeOfDay(hour: value!.hour, minute: value!.minute),
        );
        if (picked != null) {
          onChanged(TimeOfDayValue(hour: picked.hour, minute: picked.minute));
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.schedule_outlined)
              : IconButton(
                  tooltip: l10n.clear,
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value == null ? l10n.notSet : value!.format()),
      ),
    );
  }
}

/// Read-only field showing an optional date, with pick and clear affordances.
class DatePickerField extends StatelessWidget {
  const DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: l10n.clear,
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value == null ? l10n.notSet : formatDate(value!)),
      ),
    );
  }
}
