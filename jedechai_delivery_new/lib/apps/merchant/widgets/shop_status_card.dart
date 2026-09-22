import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

class MerchantShopStatusCard extends StatelessWidget {
  const MerchantShopStatusCard({
    super.key,
    required this.isShopOpen,
    required this.isAutoAcceptMode,
    required this.isAutoScheduleEnabled,
    required this.onShopStatusChanged,
  });

  final bool isShopOpen;
  final bool isAutoAcceptMode;
  final bool isAutoScheduleEnabled;
  final ValueChanged<bool> onShopStatusChanged;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.xl),
      decoration: BoxDecoration(
        // แถบเข้มตาม artboard: พื้น panel ไล่ hero2 เพื่อมิติแบบ canvas
        gradient: jdc.hero2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        boxShadow: jdc.shadowFloat,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: jdc.panelSoft3,
                  borderRadius: BorderRadius.circular(JdcRadius.field - 1),
                ),
                child: Icon(
                  isShopOpen ? Icons.storefront_outlined : Icons.storefront,
                  color: jdc.onPanel,
                  size: 22,
                ),
              ),
              const SizedBox(width: JdcSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.merchantShopStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _jt(
                        fontSize: 15,
                        color: jdc.onPanel,
                        weight: 700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isShopOpen ? jdc.successDot : jdc.offTrack,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isShopOpen
                                ? localizations.merchantShopOpen
                                : localizations.merchantShopClosed2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _jt(
                              fontSize: 12,
                              color: isShopOpen
                                  ? jdc.successOnPanel
                                  : jdc.panelDim,
                              weight: 600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: isShopOpen,
                onChanged: onShopStatusChanged,
                activeThumbColor: jdc.knob,
                inactiveThumbColor: jdc.knob,
                activeTrackColor: jdc.successFill,
                inactiveTrackColor: jdc.trackEmpty,
              ),
            ],
          ),
          const SizedBox(height: JdcSpacing.md),
          Text(
            isShopOpen
                ? localizations.merchantShopOpenDesc
                : localizations.merchantShopClosedDesc,
            style: _jt(fontSize: 14, color: jdc.panelDim),
          ),
          const SizedBox(height: JdcSpacing.sm),
          Row(
            children: [
              Icon(
                isAutoAcceptMode
                    ? Icons.auto_mode_outlined
                    : Icons.pan_tool_alt_outlined,
                color: jdc.panelDim,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAutoAcceptMode
                      ? localizations.merchantAcceptModeAuto
                      : localizations.merchantAcceptModeManual,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _jt(
                    fontSize: 13,
                    color: jdc.onPanel,
                    weight: 600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isAutoScheduleEnabled
                    ? Icons.av_timer
                    : Icons.av_timer_outlined,
                color: jdc.panelDim,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAutoScheduleEnabled
                      ? localizations.merchantAutoScheduleOn
                      : localizations.merchantAutoScheduleOff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _jt(
                    fontSize: 13,
                    color: jdc.onPanel,
                    weight: 600,
                  ),
                ),
              ),
            ],
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
