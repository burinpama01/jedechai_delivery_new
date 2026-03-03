import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
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
    if (_selectedReasonIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cancelSelectReason), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.cancelConfirmTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.cancelConfirmBody),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.cancelReasonLabel(_getSelectedReasonText(context)),
                      style: TextStyle(fontSize: 13, color: Colors.red.shade700),
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
            child: Text(AppLocalizations.of(context)!.cancelKeep, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppLocalizations.of(context)!.cancelConfirmBtn),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final bookingService = BookingService();
      await bookingService.updateBookingStatus(
        widget.booking.id,
        'cancelled',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cancelSuccess),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugLog('Error cancelling booking: $e');
      setState(() => _isCancelling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cancelError(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serviceLabel = {
      'food': l10n.cancelServiceFood,
      'ride': l10n.cancelServiceRide,
      'parcel': l10n.cancelServiceParcel,
    }[widget.booking.serviceType] ?? l10n.cancelServiceDefault;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cancelTitle),
        backgroundColor: Colors.red.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ข้อมูลออเดอร์
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(serviceLabel,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                  OrderCodeFormatter.formatByServiceType(
                                    widget.booking.id,
                                    serviceType: widget.booking.serviceType,
                                  ),
                                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('฿${widget.booking.totalAmount.ceil()}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(l10n.cancelReasonsTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l10n.cancelReasonsSubtitle,
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),

                  // รายการเหตุผล
                  ...List.generate(_getReasons(context).length, (i) {
                    final reason = _getReasons(context)[i];
                    final isSelected = _selectedReasonIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedReasonIndex = i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.red : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(reason['icon'] as IconData,
                                  color: isSelected ? Colors.red : Colors.grey, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(reason['text'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.red.shade700
                                          : Theme.of(context).colorScheme.onSurface,
                                    )),
                              ),
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? Colors.red : Colors.grey.shade400,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // ช่องพิมพ์เหตุผลอื่น
                  if (_selectedReasonIndex == _getReasons(context).length - 1) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otherReasonController,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: InputDecoration(
                        hintText: l10n.cancelOtherHint,
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ปุ่มยกเลิก
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCancelling ? null : _confirmCancellation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(l10n.cancelButton, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
