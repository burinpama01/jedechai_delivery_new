import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

class MerchantOrderList extends StatelessWidget {
  const MerchantOrderList({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.error,
    required this.isShopOpen,
    required this.onRetry,
    required this.orderBuilder,
  });

  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? error;
  final bool isShopOpen;
  final VoidCallback onRetry;
  final Widget Function(Map<String, dynamic> order) orderBuilder;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(jdc.brand),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error!,
              textAlign: TextAlign.center,
              style: _jt(fontSize: 14, color: jdc.danger),
            ),
            const SizedBox(height: JdcSpacing.lg),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                minimumSize: Size.fromHeight(JdcTouch.field),
                padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.xl),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                ),
              ),
              child: Text(
                localizations.merchantRetry,
                style: _jt(fontSize: 14, color: jdc.onCta, weight: 600),
              ),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(JdcSpacing.xxxl),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
          boxShadow: jdc.shadowCard,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(JdcSpacing.xxl),
              decoration: BoxDecoration(
                color: jdc.brandSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_outlined,
                size: 64,
                color: jdc.brandOnSoft,
              ),
            ),
            const SizedBox(height: JdcSpacing.xl),
            Text(
              localizations.merchantNoOrders,
              textAlign: TextAlign.center,
              style: _jt(fontSize: 20, color: jdc.text, weight: 600),
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              isShopOpen
                  ? localizations.merchantOrdersWillAppear
                  : localizations.merchantOpenShopToReceive,
              textAlign: TextAlign.center,
              style: _jt(fontSize: 14, color: jdc.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: orders.map(orderBuilder).toList(),
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
