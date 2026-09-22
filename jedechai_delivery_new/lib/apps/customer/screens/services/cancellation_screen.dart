import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/utils/role_amount_calculator.dart';
import '../../../../utils/debug_logger.dart';

/// Cancellation Screen
///
/// Shows cancellation confirmation and reason selection
class CancellationScreen extends StatefulWidget {
  final Booking booking;

  const CancellationScreen({super.key, required this.booking});

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  int? _selectedReasonIndex;
  final TextEditingController _otherReasonController = TextEditingController();
  bool _isCancelling = false;
  double _couponDiscount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCouponDiscount();
  }

  List<Map<String, dynamic>> _getReasons(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'icon': Icons.access_time, 'text': l10n.cancelReasonWaitTooLong},
      {'icon': Icons.money_off, 'text': l10n.cancelReasonChangedMind},
      {'icon': Icons.wrong_location, 'text': l10n.cancelReasonWrongAddress},
      {'icon': Icons.price_change, 'text': l10n.cancelReasonPriceTooHigh},
      {'icon': Icons.error_outline, 'text': l10n.cancelReasonWrongOrder},
      {'icon': Icons.edit_note, 'text': l10n.cancelReasonOther},
    ];
  }

  Future<void> _fetchCouponDiscount() async {
    try {
      final usage = await SupabaseService.client
          .from('coupon_usages')
          .select('discount_amount')
          .eq('booking_id', widget.booking.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _couponDiscount =
            (usage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (e) {
      debugLog('⚠️ Error fetching cancellation coupon discount: $e');
    }
  }

  double get _displayAmount => RoleAmountCalculator.netDisplayTotalForService(
        serviceType: widget.booking.serviceType,
        price: widget.booking.price,
        deliveryFee: widget.booking.deliveryFee,
        couponDiscountAmount: _couponDiscount,
      );

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  String _getSelectedReasonText(BuildContext context) {
    final reasons = _getReasons(context);
    if (_selectedReasonIndex == null) return '';
    if (_selectedReasonIndex == reasons.length - 1) {
      return _otherReasonController.text.trim().isEmpty
          ? AppLocalizations.of(context)!.cancelReasonOther
          : _otherReasonController.text.trim();
    }
    return reasons[_selectedReasonIndex!]['text'] as String;
  }

  Future<void> _confirmCancellation() async {
    final jdc = JdcColors.of(context);
    if (_selectedReasonIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.cancelSelectReason),
            backgroundColor: jdc.danger),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final jdc2 = JdcColors.of(ctx);
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.card)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: jdc2.danger, size: 28),
              const SizedBox(width: JdcSpacing.sm),
              Text(AppLocalizations.of(context)!.cancelConfirmTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.cancelConfirmBody),
              const SizedBox(height: JdcSpacing.md),
              Container(
                padding: const EdgeInsets.all(JdcSpacing.md),
                decoration: BoxDecoration(
                  color: jdc2.dangerSoft,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: jdc2.dangerInk, size: 18),
                    const SizedBox(width: JdcSpacing.sm),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!
                            .cancelReasonLabel(_getSelectedReasonText(context)),
                        style: TextStyle(fontSize: 13, color: jdc2.dangerInk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancelKeep,
                  style: TextStyle(color: jdc2.muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc2.danger,
                foregroundColor: jdc2.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.small)),
              ),
              child: Text(AppLocalizations.of(context)!.cancelConfirmBtn),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final bookingService = BookingService();
      await bookingService.cancelBooking(
        widget.booking.id,
        reason: _getSelectedReasonText(context),
      );

      if (mounted) {
        final jdc3 = JdcColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cancelSuccess),
            backgroundColor: jdc3.cta,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugLog('Error cancelling booking: $e');
      setState(() => _isCancelling = false);
      if (mounted) {
        final jdc3 = JdcColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.cancelError(e.toString())),
              backgroundColor: jdc3.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final reasons = _getReasons(context);
    final serviceLabel = {
          'food': l10n.cancelServiceFood,
          'ride': l10n.cancelServiceRide,
          'parcel': l10n.cancelServiceParcel,
        }[widget.booking.serviceType] ??
        l10n.cancelServiceDefault;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.cancelTitle),
        backgroundColor: jdc.danger,
        foregroundColor: jdc.onCta,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(JdcSpacing.xl),
              child: JdcContentFrame(
                padded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลออเดอร์
                    Container(
                      padding: const EdgeInsets.all(JdcSpacing.lg),
                      decoration: BoxDecoration(
                        color: jdc.surface,
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                        boxShadow: jdc.shadowCard,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(JdcSpacing.md),
                            decoration: BoxDecoration(
                              color: jdc.dangerSoft,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                            ),
                            child: Icon(Icons.cancel_outlined,
                                color: jdc.danger, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(serviceLabel,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: jdc.text)),
                                const SizedBox(height: JdcSpacing.xs),
                                Text(
                                    OrderCodeFormatter.formatByServiceType(
                                      widget.booking.id,
                                      serviceType: widget.booking.serviceType,
                                    ),
                                    style: TextStyle(
                                        fontSize: 13, color: jdc.muted)),
                              ],
                            ),
                          ),
                          Text('฿${_displayAmount.ceil()}',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: jdc.text)),
                        ],
                      ),
                    ),

                    const SizedBox(height: JdcSpacing.xxl),
                    Text(l10n.cancelReasonsTitle,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: jdc.text)),
                    const SizedBox(height: JdcSpacing.xs),
                    Text(l10n.cancelReasonsSubtitle,
                        style: TextStyle(fontSize: 14, color: jdc.muted)),
                    const SizedBox(height: JdcSpacing.lg),

                    // รายการเหตุผล
                    ...List.generate(reasons.length, (i) {
                      final reason = reasons[i];
                      final isSelected = _selectedReasonIndex == i;
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: JdcSpacing.md),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedReasonIndex = i),
                          borderRadius:
                              BorderRadius.circular(JdcRadius.small),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: JdcSpacing.lg,
                                vertical: JdcSpacing.md),
                            decoration: BoxDecoration(
                              color: isSelected ? jdc.dangerSoft : jdc.surface,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                              border: Border.all(
                                color: isSelected ? jdc.danger : jdc.line,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(reason['icon'] as IconData,
                                    color: isSelected ? jdc.danger : jdc.muted,
                                    size: 22),
                                const SizedBox(width: JdcSpacing.md),
                                Expanded(
                                  child: Text(reason['text'] as String,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? jdc.dangerInk
                                            : jdc.text,
                                      )),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: isSelected ? jdc.danger : jdc.muted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // ช่องพิมพ์เหตุผลอื่น
                    if (_selectedReasonIndex == reasons.length - 1) ...[
                      const SizedBox(height: JdcSpacing.sm),
                      TextField(
                        controller: _otherReasonController,
                        maxLines: 3,
                        maxLength: 300,
                        style: TextStyle(color: jdc.text),
                        decoration: InputDecoration(
                          hintText: l10n.cancelOtherHint,
                          hintStyle: TextStyle(color: jdc.dim),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(JdcRadius.small),
                            borderSide:
                                BorderSide(color: jdc.danger, width: 1.5),
                          ),
                          filled: true,
                          fillColor: jdc.sunken,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ปุ่มยกเลิก
          Container(
            padding: const EdgeInsets.all(JdcSpacing.xl),
            decoration: BoxDecoration(
              color: jdc.surface,
              boxShadow: jdc.shadowSheet,
            ),
            child: SafeArea(
              child: JdcContentFrame(
                padded: false,
                child: SizedBox(
                  width: double.infinity,
                  height: JdcTouch.button,
                  child: ElevatedButton(
                    onPressed: _isCancelling ? null : _confirmCancellation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jdc.danger,
                      foregroundColor: jdc.onCta,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JdcRadius.field)),
                    ),
                    child: _isCancelling
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: jdc.onCta, strokeWidth: 2.5),
                          )
                        : Text(l10n.cancelButton,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
