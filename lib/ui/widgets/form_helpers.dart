import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/station.dart';
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

String mapLinkKindLabel(AppLocalizations l10n, MapLinkKind kind) =>
    switch (kind) {
      MapLinkKind.googleMaps => l10n.linkKindGoogleMaps,
      MapLinkKind.appleMaps => l10n.linkKindAppleMaps,
      MapLinkKind.navitime => l10n.linkKindNavitime,
      MapLinkKind.jorudan => l10n.linkKindJorudan,
      MapLinkKind.officialSite => l10n.linkKindOfficialSite,
      MapLinkKind.custom => l10n.linkKindCustom,
    };

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
