import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/utils/order_code_formatter.dart';
import 'tracking_screen.dart';

/// Booking Confirmation Screen — Wave 1.5 b2ride layout
///
/// Shows booking confirmation details after successful order placement
class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;

  const BookingConfirmationScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isShort = MediaQuery.sizeOf(context).height < 480;

    final serviceLabel = {
      'food': l10n.confirmServiceFood,
      'ride': l10n.confirmServiceRide,
      'parcel': l10n.confirmServiceParcel,
    }[booking.serviceType] ??
        booking.serviceType;

    final orderId = OrderCodeFormatter.formatByServiceType(
        booking.id,
        serviceType: booking.serviceType);

    // แมปวิธีชำระทุกแบบผ่าน l10n (เดิม wallet จะโชว์คำว่า 'wallet' ดิบ ๆ และ null โชว์เป็นเงินสด)
    final paymentLabel = switch (booking.paymentMethod) {
      'cash' => l10n.confirmPayCash,
      'wallet' => l10n.confirmPayWallet,
      null || '' => l10n.confirmPayUnknown,
      final other => other,
    };

    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header
          Container(
            decoration: BoxDecoration(gradient: jdc.hero2),
            child: SafeArea(
              bottom: false,
              child: Padding(
                // จอเตี้ย (แนวนอน) ลดระยะและขนาดไอคอน ไม่งั้น hero กินที่จนล้น
                padding: isShort
                    ? const EdgeInsets.fromLTRB(20, 16, 20, 14)
                    : const EdgeInsets.fromLTRB(20, 44, 20, 34),
                child: Column(
                  children: [
                    Container(
                      width: isShort ? 44 : 68,
                      height: isShort ? 44 : 68,
                      decoration: BoxDecoration(
                        color: jdc.successPanel,
                        shape: BoxShape.circle,
                        border: Border.all(color: jdc.successPanelLine),
                      ),
                      child: Icon(Icons.check_rounded,
                          color: jdc.onPanel, size: isShort ? 22 : 34),
                    ),
                    SizedBox(height: isShort ? 8 : 16),
                    Text(l10n.confirmSent,
                        style: TextStyle(
                            fontSize: isShort ? 18 : 23,
                            fontWeight: FontWeight.bold,
                            color: jdc.onPanel)),
                    const SizedBox(height: 6),
                    Text(l10n.confirmMatchingDriver,
                        style: TextStyle(
                            fontSize: 13, color: jdc.panelDim)),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Detail card
                  _buildDetailCard(
                      context, jdc, l10n, orderId, serviceLabel, paymentLabel),
                  const SizedBox(height: 14),

                  // Info banner
                  _buildInfoBanner(context, jdc, l10n),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
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
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) =>
                                TrackingScreen(booking: booking)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jdc.cta,
                      foregroundColor: jdc.onCta,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.confirmTrackStatus,
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
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: jdc.text,
                      side: BorderSide(color: jdc.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.confirmBackToHome,
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

  Widget _buildDetailCard(
      BuildContext context,
      JdcColors jdc,
      AppLocalizations l10n,
      String orderId,
      String serviceLabel,
      String paymentLabel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.confirmDetailTitle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: jdc.text)),
              ),
              Text(orderId,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: jdc.muted)),
            ],
          ),
          const SizedBox(height: 14),

          // Origin → Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: jdc.panel, width: 3),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: jdc.line,
                  ),
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: jdc.cta,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.confirmOriginLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: jdc.muted)),
                        const SizedBox(height: 2),
                        Text(
                            booking.pickupAddress ??
                                l10n.confirmNotSpecified,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: jdc.text)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.confirmDestLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: jdc.muted)),
                        const SizedBox(height: 2),
                        Text(
                            booking.destinationAddress ??
                                l10n.confirmNotSpecified,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: jdc.text)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Divider(height: 24, color: jdc.line),

          _detailRow(context, jdc, l10n.confirmService, serviceLabel,
              valueBold: true),
          const SizedBox(height: 10),
          _detailRow(context, jdc, l10n.confirmDistance,
              l10n.confirmDistanceKm(
                  booking.distanceKm.toStringAsFixed(1))),
          const SizedBox(height: 10),

          // Fare
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l10n.confirmTotal,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: jdc.text)),
              ),
              Text('฿${booking.totalAmount.ceil()}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
            ],
          ),
          const SizedBox(height: 4),
          _detailRow(context, jdc, l10n.confirmPaymentLabel,
              paymentLabel),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(
      BuildContext context, JdcColors jdc, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        color: jdc.infoSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: jdc.infoInk, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.confirmInfoText,
                style: TextStyle(
                    fontSize: 12,
                    color: jdc.infoInk,
                    height: 1.7)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, JdcColors jdc, String label,
      String value,
      {bool valueBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: jdc.muted))),
        const SizedBox(width: 12),
        // ค่าบางอย่างยาว (เช่น ข้อความวิธีชำระเงิน) ต้องยืดหยุ่นไม่ให้ล้นขอบ
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      valueBold ? FontWeight.w600 : FontWeight.normal,
                  color: jdc.text)),
        ),
      ],
    );
  }
}
