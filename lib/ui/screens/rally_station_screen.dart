import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/rally_service.dart';
import '../../domain/entities/rally.dart';
import '../../domain/value_objects/stamp_window.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/form_helpers.dart';
import '../widgets/stamp_windows_editor.dart';

/// Editor for one station's rally-specific stamp details.
class RallyStationScreen extends ConsumerWidget {
  const RallyStationScreen({
    required this.rallyId,
    required this.rallyStationId,
    super.key,
  });

  final String rallyId;
  final String rallyStationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(rallyStationsProvider(rallyId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (items) {
            final rallyStation = items.firstWhereOrNull(
              (item) => item.id == rallyStationId,
            );
            if (rallyStation == null) {
              return Scaffold(
                appBar: AppBar(title: Text(l10n.stationDetailsForRally)),
                body: Center(child: Text(l10n.rallyStationsEmpty)),
              );
            }
            final stationName = ref
                .watch(stationsProvider)
                .value
                ?.firstWhereOrNull(
                  (station) => station.id == rallyStation.stationId,
                )
                ?.displayName;
            return _RallyStationForm(
              key: ValueKey(rallyStation.id),
              rallyStation: rallyStation,
              stationName: stationName,
            );
          },
        );
  }
}

class _RallyStationForm extends ConsumerStatefulWidget {
  const _RallyStationForm({
    required this.rallyStation,
    required this.stationName,
    super.key,
  });

  final RallyStation rallyStation;
  final String? stationName;

  @override
  ConsumerState<_RallyStationForm> createState() => _RallyStationFormState();
}

class _RallyStationFormState extends ConsumerState<_RallyStationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _stampLocation = TextEditingController(
    text: widget.rallyStation.stampLocation ?? '',
  );
  late final _stampCode = TextEditingController(
    text: widget.rallyStation.stampCode ?? '',
  );
  late final _sequenceHint = TextEditingController(
    text: widget.rallyStation.sequenceHint?.toString() ?? '',
  );
  late final _notes = TextEditingController(
    text: widget.rallyStation.notes ?? '',
  );
  late bool _requiresPurchase = widget.rallyStation.requiresPurchase;
  late List<StampWindow> _windows = [...widget.rallyStation.stampWindows];

  @override
  void dispose() {
    for (final controller in [
      _stampLocation,
      _stampCode,
      _sequenceHint,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stationName ?? l10n.stationDetailsForRally),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _stampLocation,
              decoration: InputDecoration(
                labelText: l10n.fieldStampLocation,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stampCode,
              decoration: InputDecoration(
                labelText: l10n.fieldStampCode,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sequenceHint,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.fieldSequenceHint,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                return text.isEmpty || int.tryParse(text) != null
                    ? null
                    : l10n.validationWholeNumber;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _requiresPurchase,
              title: Text(l10n.fieldRequiresPurchase),
              onChanged: (value) => setState(() => _requiresPurchase = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.fieldNotes,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            StampWindowsEditor(
              windows: _windows,
              hint: l10n.stampWindowsDefaultHint,
              onChanged: (windows) => setState(() => _windows = windows),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final sequence = _sequenceHint.text.trim();
    await ref
        .read(rallyServiceProvider)
        .saveStation(
          RallyStationDraft(
            id: widget.rallyStation.id,
            rallyId: widget.rallyStation.rallyId,
            stationId: widget.rallyStation.stationId,
            stampLocation: optionalText(_stampLocation),
            stampCode: optionalText(_stampCode),
            sequenceHint: sequence.isEmpty ? null : int.parse(sequence),
            requiresPurchase: _requiresPurchase,
            notes: optionalText(_notes),
            stampWindows: _windows,
          ),
        );
    if (navigator.canPop()) navigator.pop();
  }
}
