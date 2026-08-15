import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/station_service.dart';
import '../../domain/entities/station.dart';
import '../../domain/value_objects/coordinates.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/form_helpers.dart';

/// Creates a station, or edits the station identified by [stationId].
class StationFormScreen extends ConsumerWidget {
  const StationFormScreen({this.stationId, super.key});

  final String? stationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stationId == null) return const _StationForm();
    return ref
        .watch(stationProvider(stationId!))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (station) => station == null
              ? const _StationForm()
              : _StationForm(initial: station),
        );
  }
}

class _StationForm extends ConsumerStatefulWidget {
  const _StationForm({this.initial});

  final Station? initial;

  @override
  ConsumerState<_StationForm> createState() => _StationFormState();
}

class _StationFormState extends ConsumerState<_StationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _nameLocal = TextEditingController(
    text: widget.initial?.nameLocal ?? '',
  );
  late final _aliases = TextEditingController(
    text: widget.initial?.aliases.join(', ') ?? '',
  );
  late final _latitude = TextEditingController(
    text: widget.initial?.coordinates.latitude.toString() ?? '',
  );
  late final _longitude = TextEditingController(
    text: widget.initial?.coordinates.longitude.toString() ?? '',
  );
  late final _address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  late final _operator = TextEditingController(
    text: widget.initial?.operatorName ?? '',
  );
  late final _lines = TextEditingController(
    text: widget.initial?.lines.join(', ') ?? '',
  );
  late final _tags = TextEditingController(
    text: widget.initial?.tags.join(', ') ?? '',
  );
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late List<StationLink> _links = [...?widget.initial?.links];

  @override
  void dispose() {
    for (final controller in [
      _name,
      _nameLocal,
      _aliases,
      _latitude,
      _longitude,
      _address,
      _operator,
      _lines,
      _tags,
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
        title: Text(
          widget.initial == null ? l10n.newStation : l10n.editStation,
        ),
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
            _text(_nameLocal, l10n.fieldNameLocal),
            const SizedBox(height: 12),
            _text(_aliases, l10n.fieldAliases, helper: l10n.commaSeparatedHint),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _coordinate(
                    _latitude,
                    l10n.fieldLatitude,
                    l10n.validationLatitude,
                    Coordinates.isValidLatitude,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _coordinate(
                    _longitude,
                    l10n.fieldLongitude,
                    l10n.validationLongitude,
                    Coordinates.isValidLongitude,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _text(_address, l10n.fieldAddress),
            const SizedBox(height: 12),
            _text(_operator, l10n.fieldOperator),
            const SizedBox(height: 12),
            _text(_lines, l10n.fieldLines, helper: l10n.commaSeparatedHint),
            const SizedBox(height: 12),
            _text(_tags, l10n.fieldTags, helper: l10n.commaSeparatedHint),
            const SizedBox(height: 12),
            _text(_notes, l10n.fieldNotes, maxLines: 3),
            const SizedBox(height: 24),
            _LinksEditor(
              links: _links,
              onChanged: (links) => setState(() => _links = links),
              newLinkId: ref.read(stationServiceProvider).newLinkId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    String? helper,
    int maxLines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _coordinate(
    TextEditingController controller,
    String label,
    String error,
    bool Function(double) isValid,
  ) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      final parsed = double.tryParse(value?.trim() ?? '');
      return parsed == null || !isValid(parsed) ? error : null;
    },
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    await ref
        .read(stationServiceProvider)
        .save(
          StationDraft(
            id: widget.initial?.id,
            name: _name.text.trim(),
            coordinates: Coordinates(
              latitude: double.parse(_latitude.text.trim()),
              longitude: double.parse(_longitude.text.trim()),
            ),
            nameLocal: optionalText(_nameLocal),
            aliases: parseCommaSeparated(_aliases.text),
            address: optionalText(_address),
            operatorName: optionalText(_operator),
            lines: parseCommaSeparated(_lines.text),
            tags: parseCommaSeparated(_tags.text),
            notes: optionalText(_notes),
            links: _links,
          ),
        );
    if (navigator.canPop()) navigator.pop();
  }
}

class _LinksEditor extends StatelessWidget {
  const _LinksEditor({
    required this.links,
    required this.onChanged,
    required this.newLinkId,
  });

  final List<StationLink> links;
  final ValueChanged<List<StationLink>> onChanged;
  final String Function() newLinkId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sectionLinks, style: Theme.of(context).textTheme.titleMedium),
        for (var index = 0; index < links.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(
              links[index].label ?? mapLinkKindLabel(l10n, links[index].kind),
            ),
            subtitle: Text(links[index].url, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: l10n.remove,
              icon: const Icon(Icons.close),
              onPressed: () => onChanged([...links]..removeAt(index)),
            ),
            onTap: () async {
              final edited = await _editLink(context, links[index]);
              if (edited != null) onChanged([...links]..[index] = edited);
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              final added = await _editLink(
                context,
                StationLink(
                  id: newLinkId(),
                  kind: MapLinkKind.googleMaps,
                  url: '',
                ),
              );
              if (added != null) onChanged([...links, added]);
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.addLink),
          ),
        ),
      ],
    );
  }
}

Future<StationLink?> _editLink(BuildContext context, StationLink initial) =>
    showDialog<StationLink>(
      context: context,
      builder: (context) => _LinkDialog(initial: initial),
    );

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initial});

  final StationLink initial;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _formKey = GlobalKey<FormState>();
  late MapLinkKind _kind = widget.initial.kind;
  late final _url = TextEditingController(text: widget.initial.url);
  late final _label = TextEditingController(text: widget.initial.label ?? '');

  @override
  void dispose() {
    _url.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sectionLinks),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MapLinkKind>(
              initialValue: _kind,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final kind in MapLinkKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(mapLinkKindLabel(l10n, kind)),
                  ),
              ],
              onChanged: (kind) => setState(() => _kind = kind ?? _kind),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.fieldUrl,
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  isValidUrl(value ?? '') ? null : l10n.validationUrl,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.fieldLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              widget.initial.copyWith(
                kind: _kind,
                url: _url.text.trim(),
                label: optionalText(_label),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
