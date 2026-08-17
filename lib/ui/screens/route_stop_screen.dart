import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/route_service.dart';
import '../../domain/entities/rally_route.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/form_helpers.dart';

/// Editor for one stop's planned timings, and for an extra stop's label.
class RouteStopScreen extends ConsumerWidget {
  const RouteStopScreen({
    required this.routeId,
    required this.stopId,
    super.key,
  });

  final String routeId;
  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ref
        .watch(routeProvider(routeId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (route) {
            final stop = route?.stops.firstWhereOrNull(
              (item) => item.id == stopId,
            );
            if (stop == null) {
              return Scaffold(
                appBar: AppBar(title: Text(l10n.stopDetails)),
                body: Center(child: Text(l10n.routeStopsEmpty)),
              );
            }
            final stationName = ref
                .watch(stationsProvider)
                .value
                ?.firstWhereOrNull((station) => station.id == stop.stationId)
                ?.displayName;
            return _RouteStopForm(
              key: ValueKey(stop.id),
              routeId: routeId,
              stop: stop,
              stationName: stationName,
            );
          },
        );
  }
}

class _RouteStopForm extends ConsumerStatefulWidget {
  const _RouteStopForm({
    required this.routeId,
    required this.stop,
    required this.stationName,
    super.key,
  });

  final String routeId;
  final RouteStop stop;
  final String? stationName;

  @override
  ConsumerState<_RouteStopForm> createState() => _RouteStopFormState();
}

class _RouteStopFormState extends ConsumerState<_RouteStopForm> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.stop.label ?? '');
  late final _travel = TextEditingController(
    text: widget.stop.plannedTravelMinutes?.toString() ?? '',
  );
  late final _dwell = TextEditingController(
    text: widget.stop.plannedDwellMinutes?.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.stop.notes ?? '');

  @override
  void dispose() {
    for (final controller in [_label, _travel, _dwell, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isExtra = widget.stop.kind == StopKind.extra;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.stationName ?? l10n.stopDetails),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // A stamp stop is named by its station; only an extra stop needs a
            // label of its own.
            if (isExtra) ...[
              TextFormField(
                controller: _label,
                decoration: InputDecoration(
                  labelText: l10n.fieldLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? l10n.validationRequired
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _travel,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.fieldTravelMinutes,
                border: const OutlineInputBorder(),
              ),
              validator: _validateMinutes,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dwell,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.fieldDwellMinutes,
                border: const OutlineInputBorder(),
              ),
              validator: _validateMinutes,
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
          ],
        ),
      ),
    );
  }

  String? _validateMinutes(String? value) {
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final minutes = int.tryParse(text);
    return minutes == null || minutes < 0 ? l10n.validationWholeNumber : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    await ref
        .read(routeServiceProvider)
        .saveStop(
          RouteStopDraft(
            routeId: widget.routeId,
            stopId: widget.stop.id,
            label: optionalText(_label),
            plannedTravelMinutes: int.tryParse(_travel.text.trim()),
            plannedDwellMinutes: int.tryParse(_dwell.text.trim()),
            notes: optionalText(_notes),
          ),
        );
    if (navigator.canPop()) navigator.pop();
  }
}
