import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../../l10n/app_localizations.dart';

/// Warns when the browser only gave drift a non-durable database.
///
/// Chrome on Android has no shared workers, so without COOP/COEP headers drift
/// can fall back to storage that may lose data; the user deserves to know
/// before recording a whole run.
class StorageWarningBanner extends StatefulWidget {
  const StorageWarningBanner({super.key});

  @override
  State<StorageWarningBanner> createState() => _StorageWarningBannerState();
}

class _StorageWarningBannerState extends State<StorageWarningBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final report = AppDatabase.webStorageReport;
    if (_dismissed || report == null || report.isDurable) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.storageWarningTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(l10n.storageWarningBody),
        ],
      ),
      leading: const Icon(Icons.warning_amber_rounded),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = true),
          child: Text(l10n.dismiss),
        ),
      ],
    );
  }
}
