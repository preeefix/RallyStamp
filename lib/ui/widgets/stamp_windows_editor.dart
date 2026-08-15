import 'package:flutter/material.dart';

import '../../domain/value_objects/stamp_window.dart';
import '../../domain/value_objects/time_of_day_value.dart';
import '../../l10n/app_localizations.dart';

/// Edits the hours during which a stamp can be collected.
///
/// An empty list means "inherit": rally defaults for a station, or always
/// available when the rally has no defaults either.
class StampWindowsEditor extends StatelessWidget {
  const StampWindowsEditor({
    required this.windows,
    required this.onChanged,
    required this.hint,
    super.key,
  });

  final List<StampWindow> windows;
  final ValueChanged<List<StampWindow>> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sectionStampWindows, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        for (var index = 0; index < windows.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(
              l10n.stampWindowRange(
                windows[index].start.format(),
                windows[index].end.format(),
              ),
            ),
            subtitle: Text(_days(context, windows[index])),
            trailing: IconButton(
              tooltip: l10n.remove,
              icon: const Icon(Icons.close),
              onPressed: () => onChanged([...windows]..removeAt(index)),
            ),
            onTap: () async {
              final edited = await _editWindow(context, windows[index]);
              if (edited != null) {
                onChanged([...windows]..[index] = edited);
              }
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final added = await _editWindow(context, null);
              if (added != null) onChanged([...windows, added]);
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addStampWindow),
          ),
        ),
      ],
    );
  }

  String _days(BuildContext context, StampWindow window) {
    final l10n = AppLocalizations.of(context);
    if (window.daysOfWeek.isEmpty) return l10n.everyDay;
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    final sorted = [...window.daysOfWeek]..sort();
    return [
      for (final day in sorted) narrow[day % DateTime.daysPerWeek],
    ].join(' ');
  }
}

Future<StampWindow?> _editWindow(BuildContext context, StampWindow? initial) =>
    showDialog<StampWindow>(
      context: context,
      builder: (context) => _StampWindowDialog(initial: initial),
    );

class _StampWindowDialog extends StatefulWidget {
  const _StampWindowDialog({this.initial});

  final StampWindow? initial;

  @override
  State<_StampWindowDialog> createState() => _StampWindowDialogState();
}

class _StampWindowDialogState extends State<_StampWindowDialog> {
  late TimeOfDay _start = _toTimeOfDay(
    widget.initial?.start ?? const TimeOfDayValue(hour: 9, minute: 0),
  );
  late TimeOfDay _end = _toTimeOfDay(
    widget.initial?.end ?? const TimeOfDayValue(hour: 17, minute: 0),
  );
  late final Set<int> _days = {...?widget.initial?.daysOfWeek};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    return AlertDialog(
      title: Text(l10n.sectionStampWindows),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(isStart: true),
                  child: Text(_start.format(context)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('-'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(isStart: false),
                  child: Text(_end.format(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            children: [
              for (
                var weekday = DateTime.monday;
                weekday <= DateTime.sunday;
                weekday++
              )
                FilterChip(
                  label: Text(narrow[weekday % DateTime.daysPerWeek]),
                  selected: _days.contains(weekday),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _days.add(weekday);
                    } else {
                      _days.remove(weekday);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _days.isEmpty ? l10n.everyDay : '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            StampWindow(
              start: _fromTimeOfDay(_start),
              end: _fromTimeOfDay(_end),
              daysOfWeek: [..._days]..sort(),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }
}

TimeOfDay _toTimeOfDay(TimeOfDayValue value) =>
    TimeOfDay(hour: value.hour, minute: value.minute);

TimeOfDayValue _fromTimeOfDay(TimeOfDay value) =>
    TimeOfDayValue(hour: value.hour, minute: value.minute);
