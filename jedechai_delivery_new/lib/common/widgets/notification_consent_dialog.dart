import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

Future<bool?> showNotificationConsentDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.notificationConsentTitle),
      content: Text(l10n.notificationConsentBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.notificationConsentNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.notificationConsentAllow),
        ),
      ],
    ),
  );
}
