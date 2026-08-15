import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/rally_service.dart';
import '../../domain/entities/rally.dart';
import '../../domain/value_objects/stamp_window.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/form_helpers.dart';
import '../widgets/stamp_windows_editor.dart';

/// Creates a rally, or edits the rally identified by [rallyId].
class RallyFormScreen extends ConsumerWidget {
  const RallyFormScreen({this.rallyId, super.key});

  final String? rallyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rallyId == null) return const _RallyForm();
    return ref
        .watch(rallyProvider(rallyId!))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (rally) =>
              rally == null ? const _RallyForm() : _RallyForm(initial: rally),
        );
  }
}

class _RallyForm extends ConsumerStatefulWidget {
  const _RallyForm({this.initial});

  final Rally? initial;

  @override
  ConsumerState<_RallyForm> createState() => _RallyFormState();
}

class _RallyFormState extends ConsumerState<_RallyForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _organizer = TextEditingController(
    text: widget.initial?.organizer ?? '',
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _url = TextEditingController(
    text: widget.initial?.externalUrl ?? '',
  );
  late DateTime? _startsOn = widget.initial?.startsOn;
  late DateTime? _endsOn = widget.initial?.endsOn;
  late List<StampWindow> _windows = [...?widget.initial?.defaultStampWindows];

  bool get _endsBeforeStart =>
      _startsOn != null && _endsOn != null && _endsOn!.isBefore(_startsOn!);

  @override
  void dispose() {
    for (final controller in [_name, _organizer, _description, _url]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? l10n.newRally : l10n.editRally),
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
              controller: _organizer,
              decoration: InputDecoration(
                labelText: l10n.fieldOrganizer,
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
            TextFormField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.fieldUrl,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty || isValidUrl(value))
                  ? null
                  : l10n.validationUrl,
            ),
            const SizedBox(height: 12),
            DatePickerField(
              label: l10n.fieldStartsOn,
              value: _startsOn,
              onChanged: (value) => setState(() => _startsOn = value),
            ),
            const SizedBox(height: 12),
            DatePickerField(
              label: l10n.fieldEndsOn,
              value: _endsOn,
              errorText: _endsBeforeStart
                  ? l10n.validationEndBeforeStart
                  : null,
              onChanged: (value) => setState(() => _endsOn = value),
            ),
            const SizedBox(height: 24),
            StampWindowsEditor(
              windows: _windows,
              hint: l10n.stampWindowsRallyHint,
              onChanged: (windows) => setState(() => _windows = windows),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _endsBeforeStart) {
      setState(() {});
      return;
    }
    final navigator = Navigator.of(context);
    await ref
        .read(rallyServiceProvider)
        .save(
          RallyDraft(
            id: widget.initial?.id,
            name: _name.text.trim(),
            organizer: optionalText(_organizer),
            description: optionalText(_description),
            externalUrl: optionalText(_url),
            startsOn: _startsOn,
            endsOn: _endsOn,
            defaultStampWindows: _windows,
          ),
        );
    if (navigator.canPop()) navigator.pop();
  }
}
