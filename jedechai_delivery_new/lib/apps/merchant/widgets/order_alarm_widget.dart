import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

class MerchantOrderAlarmDialog extends StatelessWidget {
  const MerchantOrderAlarmDialog({
    super.key,
    required this.onStopAlarm,
  });

  final VoidCallback onStopAlarm;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final localizations = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.card),
          side: BorderSide(color: jdc.dangerLine),
        ),
        title: Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: jdc.danger,
              size: 32,
            ),
            const SizedBox(width: JdcSpacing.md),
            Expanded(
              child: Text(
                localizations.merchantNewOrderAlert,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _jt(fontSize: 22, color: jdc.danger, weight: 700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(JdcSpacing.lg),
              decoration: BoxDecoration(
                color: jdc.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining,
                size: 56,
                color: jdc.danger,
              ),
            ),
            const SizedBox(height: JdcSpacing.lg),
            Text(
              localizations.merchantNewOrderWaiting,
              style: _jt(fontSize: 18, color: jdc.text, weight: 600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              localizations.merchantAlarmDesc,
              style: _jt(fontSize: 14, color: jdc.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onStopAlarm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.danger,
                foregroundColor: jdc.onCta,
                minimumSize: Size.fromHeight(JdcTouch.button),
                padding: const EdgeInsets.symmetric(vertical: JdcSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stop),
                  const SizedBox(width: JdcSpacing.sm),
                  Text(
                    localizations.merchantStopAlarm,
                    style: _jt(fontSize: 16, color: jdc.onCta, weight: 700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// TextStyle มาตรฐานของกลุ่มหน้าออเดอร์ — ผูก fontWeight กับ fontVariations
/// ให้คู่กันเสมอตามธีม JDC
TextStyle _jt({
  double? fontSize,
  Color? color,
  double weight = 400,
  double? height,
  double? letterSpacing,
}) {
  const weightMap = <int, FontWeight>{
    400: FontWeight.w400,
    500: FontWeight.w500,
    600: FontWeight.w600,
    700: FontWeight.w700,
    800: FontWeight.w800,
    900: FontWeight.w900,
  };
  return TextStyle(
    fontSize: fontSize,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: weightMap[weight.round()] ?? FontWeight.w400,
    fontVariations: [FontVariation('wght', weight)],
  );
}
