import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<bool> showEntryDeleteConfirmationDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final shouldDelete = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.deleteDialogTitle),
        content: Text(l10n.deleteDialogBody),
        actions: [
          Semantics(
            button: true,
            label: l10n.deleteCancelSemanticsLabel,
            hint: l10n.deleteCancelSemanticsHint,
            child: TextButton(
              key: const ValueKey('entryDeleteCancelButton'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: ExcludeSemantics(child: Text(l10n.deleteCancel)),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.deleteConfirmSemanticsLabel,
            hint: l10n.deleteConfirmSemanticsHint,
            child: TextButton(
              key: const ValueKey('entryDeleteConfirmButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: ExcludeSemantics(child: Text(l10n.deleteConfirm)),
            ),
          ),
        ],
      );
    },
  );

  return shouldDelete ?? false;
}
