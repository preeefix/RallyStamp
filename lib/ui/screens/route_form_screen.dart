import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/route_service.dart';
import '../../domain/entities/rally_route.dart';
import '../../domain/value_objects/time_of_day_value.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/form_helpers.dart';

/// Creates a route for [rallyId], or edits the route identified by [routeId].
class RouteFormScreen extends ConsumerWidget {
  const RouteFormScreen({this.rallyId, this.routeId, super.key})
    : assert(
        rallyId != null || routeId != null,
        'a new route needs a rally, an edited one is found by id',
      );

  final String? rallyId;
  final String? routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeId == null) return _RouteForm(rallyId: rallyId!);
    return ref
        .watch(routeProvider(routeId!))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (route) => route == null
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _RouteForm(rallyId: route.rallyId, initial: route),
        );
  }
}

class _RouteForm extends ConsumerStatefulWidget {
  const _RouteForm({required this.rallyId, this.initial});

  final String rallyId;
  final RallyRoute? initial;

  @override
  ConsumerState<_RouteForm> createState() => _RouteFormState();
}

class _RouteFormState extends ConsumerState<_RouteForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _author = TextEditingController(
    text: widget.initial?.author ?? '',
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late TimeOfDayValue? _startTime = _parseTime(
    widget.initial?.plannedStartTime,
  );

  @override
  void dispose() {
    for (final controller in [_name, _author, _description]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? l10n.newRoute : l10n.editRoute),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              autofocus: widget.initial == null,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.validationRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _author,
              decoration: InputDecoration(
                labelText: l10n.fieldAuthor,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.fieldDescription,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TimePickerField(
              label: l10n.fieldPlannedStartTime,
              value: _startTime,
              onChanged: (value) => setState(() => _startTime = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final saved = await ref
        .read(routeServiceProvider)
        .save(
          RouteDraft(
            id: widget.initial?.id,
            rallyId: widget.rallyId,
            name: _name.text.trim(),
            author: optionalText(_author),
            description: optionalText(_description),
            plannedStartTime: _startTime?.format(),
          ),
        );
    // A new route opens its builder, since planning stops is the point of it.
    if (widget.initial == null) {
      router.go('/routes/${saved.id}');
    } else if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

TimeOfDayValue? _parseTime(String? value) {
  if (value == null) return null;
  try {
    return TimeOfDayValue.parse(value);
  } on FormatException {
    return null;
  }
}
