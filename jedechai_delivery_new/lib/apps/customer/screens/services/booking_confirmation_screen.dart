import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/utils/order_code_formatter.dart';
import 'tracking_screen.dart';

/// Booking Confirmation Screen
///
/// Shows booking confirmation details after successful order placement
class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;

  const BookingConfirmationScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final serviceLabel = {
      'food': l10n.confirmServiceFood,
      'ride': l10n.confirmServiceRide,
      'parcel': l10n.confirmServiceParcel,
    }[booking.serviceType] ??
        booking.serviceType;

    final serviceIcon = {
      'food': Icons.restaurant,
      'ride': Icons.local_taxi,
      'parcel': Icons.inventory_2,
    }[booking.serviceType] ??
        Icons.receipt;

    final dateFormat = DateFormat('d MMM yyyy HH:mm', 'th');

    return Scaffold(
      backgroundColor: jdc.paper,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(JdcSpacing.xxl),
                child: JdcContentFrame(
                  padded: false,
                  child: Column(
                    children: [
                      const SizedBox(height: JdcSpacing.xl),

                      // ไอคอนสำเร็จ
                      Container(
                        padding: const EdgeInsets.all(JdcSpacing.xxl),
                        decoration: BoxDecoration(
                          color: jdc.successSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_circle, size: 80, color: jdc.successInk),
                      ),
                      const SizedBox(height: JdcSpacing.xl),
                      Text(l10n.confirmSuccess,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: jdc.text,
                          )),
                      const SizedBox(height: JdcSpacing.sm),
                      Text(
                          l10n.confirmOrderCode(OrderCodeFormatter.formatByServiceType(
                              booking.id,
                              serviceType: booking.serviceType)),
                          style: TextStyle(fontSize: 15, color: jdc.muted)),

                      const SizedBox(height: JdcSpacing.xxxl),

                      // รายละเอียดออเดอร์
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(JdcSpacing.xl),
                        decoration: BoxDecoration(
                          color: jdc.sunken,
                          borderRadius: BorderRadius.circular(JdcRadius.card),
                          border: Border.all(color: jdc.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(JdcSpacing.md),
                                  decoration: BoxDecoration(
                                    color: jdc.brandSoft,
                                    borderRadius: BorderRadius.circular(JdcRadius.small),
                                  ),
                                  child: Icon(serviceIcon, color: jdc.brandOnSoft, size: 24),
                                ),
                                const SizedBox(width: JdcSpacing.md),
                                Expanded(
                                  child: Text(serviceLabel,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: jdc.text,
                                      )),
                                ),
                              ],
                            ),
                            const SizedBox(height: JdcSpacing.lg),
                            Divider(height: 1, color: jdc.line),
                            const SizedBox(height: JdcSpacing.lg),

                            // จุดรับ
                            _buildInfoRow(context, Icons.circle, jdc.cta, l10n.confirmPickup,
                                booking.pickupAddress ?? l10n.confirmNotSpecified),
                            const SizedBox(height: 14),

                            // จุดส่ง
                            _buildInfoRow(context, Icons.location_on, jdc.danger, l10n.confirmDestination,
                                booking.destinationAddress ?? l10n.confirmNotSpecified),
                            const SizedBox(height: 14),

                            // ระยะทาง
                            _buildInfoRow(context, Icons.straighten, jdc.infoInk, l10n.confirmDistance,
                                l10n.confirmDistanceKm(booking.distanceKm.toStringAsFixed(1))),
                            const SizedBox(height: 14),

                            // วันที่สร้าง
                            _buildInfoRow(context, Icons.access_time, jdc.brand, l10n.confirmOrderTime,
                                dateFormat.format(booking.createdAt)),
                          ],
                        ),
                      ),

                      const SizedBox(height: JdcSpacing.xl),

                      // สรุปราคา
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(JdcSpacing.xl),
                        decoration: BoxDecoration(
                          gradient: jdc.hero2,
                          borderRadius: BorderRadius.circular(JdcRadius.card),
                        ),
                        child: Column(
                          children: [
                            if (booking.serviceType == 'food' && booking.deliveryFee != null) ...[
                              _buildPriceRow(context, l10n.confirmFoodCost, '฿${booking.price.ceil()}'),
                              const SizedBox(height: JdcSpacing.sm),
                              _buildPriceRow(context, l10n.confirmDeliveryFee, '฿${booking.deliveryFee!.ceil()}'),
                              Divider(color: jdc.panelLine, height: JdcSpacing.xl),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.confirmTotal,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: jdc.onPanel,
                                    )),
                                Text('฿${booking.totalAmount.ceil()}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: jdc.onPanel,
                                    )),
                              ],
                            ),
                            const SizedBox(height: JdcSpacing.sm),
                            Row(
                              children: [
                                Icon(Icons.payment, color: jdc.panelDim, size: 16),
                                const SizedBox(width: JdcSpacing.sm),
                                Text(
                                  booking.paymentMethod == 'cash'
                                      ? l10n.confirmPayCash
                                      : (booking.paymentMethod ?? l10n.confirmCash),
                                  style: TextStyle(fontSize: 13, color: jdc.panelDim),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ปุ่มด้านล่าง
            Container(
              padding: const EdgeInsets.all(JdcSpacing.xl),
              decoration: BoxDecoration(
                color: jdc.surface,
                boxShadow: jdc.shadowSheet,
              ),
              child: JdcContentFrame(
                padded: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: JdcTouch.button,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (_) => TrackingScreen(booking: booking)),
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: Text(l10n.confirmTrackOrder,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: jdc.cta,
                          foregroundColor: jdc.onCta,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(JdcRadius.field)),
                        ),
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            Navigator.of(context).popUntil((route) => route.isFirst),
                        child: Text(l10n.confirmBackToHome,
                            style: TextStyle(fontSize: 16, color: jdc.muted)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, Color color, String label, String value) {
    final jdc = JdcColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: JdcSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: jdc.muted)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(fontSize: 15, color: jdc.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, String amount) {
    final jdc = JdcColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: jdc.panelDim)),
        Text(amount,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: jdc.onPanel)),
      ],
    );
  }
}
