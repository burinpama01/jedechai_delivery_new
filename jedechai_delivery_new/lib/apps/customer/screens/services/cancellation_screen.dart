import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/services/supabase_service.dart';
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

  // ตรวจว่าร้านเริ่มทำงานแล้วหรือไม่ (สำหรับ warning banner)
  bool get _shopStarted {
    final s = widget.booking.status;
    return s == 'accepted' ||
        s == 'driver_arrived_merchant' ||
        s == 'food_ready' ||
        s == 'picked_up';
  }

  // ค่าธรรมเนียมยกเลิก (ถ้ามี)
  double get _cancellationFee {
    final paid = widget.booking.totalAmount;
    final refund = _displayAmount;
    final fee = paid - refund;
    return fee > 0 ? fee : 0;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final reasons = _getReasons(context);

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.cancelTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        iconTheme: IconThemeData(color: jdc.text),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: jdc.line),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning banner (contextual)
                  if (_shopStarted) ...[
                    _buildWarningBanner(jdc, l10n),
                    const SizedBox(height: 16),
                  ],

                  // เหตุผล
                  Text(l10n.cancelReasonsTitle,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: jdc.text)),
                  const SizedBox(height: 10),

                  ...List.generate(reasons.length, (i) {
                    final reason = reasons[i];
                    final isSelected = _selectedReasonIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedReasonIndex = i),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 13),
                          decoration: BoxDecoration(
                            color: jdc.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? jdc.cta : jdc.line,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Radio<int>(
                                  value: i,
                                  groupValue: _selectedReasonIndex,
                                  activeColor: jdc.cta,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (v) => setState(
                                      () => _selectedReasonIndex = v),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(reason['text'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: jdc.text,
                                    )),
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
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: jdc.danger, width: 1.5),
                        ),
                        filled: true,
                        fillColor: jdc.sunken,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Refund summary card
                  _buildRefundSummary(jdc, l10n),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom 2 buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: jdc.surface,
              border: Border(top: BorderSide(color: jdc.line)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isCancelling ? null : _confirmCancellation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jdc.dangerInk,
                      foregroundColor: jdc.onCta,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isCancelling
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: jdc.onCta, strokeWidth: 2.5),
                          )
                        : Text(l10n.cancelConfirmBtn,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isCancelling
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: jdc.text,
                      side: BorderSide(color: jdc.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.cancelNotCancel,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(JdcColors jdc, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jdc.dangerLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: jdc.dangerInk, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.cancelWarnStartedTitle,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: jdc.dangerInk)),
                const SizedBox(height: 3),
                Text(
                  _cancellationFee > 0
                      ? '${l10n.cancelWarnFee} ฿${_cancellationFee.ceil()} หักจากยอดคืน'
                      : l10n.cancelWarnFee,
                  style:
                      TextStyle(fontSize: 12, color: jdc.dangerInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundSummary(JdcColors jdc, AppLocalizations l10n) {
    final paid = widget.booking.totalAmount;
    final fee = _cancellationFee;
    final refund = _displayAmount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cancelRefundTitle,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: jdc.text)),
          const SizedBox(height: 9),
          _refundRow(jdc, l10n.cancelAmountPaid,
              '฿${paid.ceil()}', jdc.muted),
          if (fee > 0) ...[
            const SizedBox(height: 4),
            _refundRow(jdc, l10n.cancelFee,
                '-฿${fee.ceil()}', jdc.dangerInk,
                bold: true),
          ],
          const SizedBox(height: 8),
          Divider(height: 1, color: jdc.line),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l10n.cancelRefundToWallet,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: jdc.text)),
              ),
              Text('฿${refund.ceil()}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.cancelRefundNote,
              style: TextStyle(fontSize: 12, color: jdc.muted)),
        ],
      ),
    );
  }

  Widget _refundRow(JdcColors jdc, String label, String value, Color color,
      {bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: jdc.muted)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color)),
      ],
    );
  }
}
