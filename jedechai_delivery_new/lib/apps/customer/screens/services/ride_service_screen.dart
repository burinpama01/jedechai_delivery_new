import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../ride/ride_home_screen.dart';

/// Ride Service Screen — Wave 1.5 b2ride layout
///
/// Entry point for ride booking. When accessed directly (no params),
/// delegates to RideHomeScreen for the full ride booking flow.
/// When constructed with ride details, shows the "ยืนยันการเดินทาง" confirmation view.
class RideServiceScreen extends StatelessWidget {
  /// Optional: pre-filled origin address for confirmation view
  final String? originAddress;

  /// Optional: pre-filled destination address for confirmation view
  final String? destinationAddress;

  /// Optional: selected vehicle display name (e.g. "มอเตอร์ไซค์")
  final String? vehicleDisplayName;

  /// Optional: estimated distance in km
  final double? distanceKm;

  /// Optional: base fare amount
  final double? baseFare;

  /// Optional: pickup surcharge
  final double? pickupSurcharge;

  /// Optional: total fare
  final double? totalFare;

  /// Optional: payment method ('wallet' | 'cash')
  final String? paymentMethod;

  /// Optional: wallet balance for display
  final double? walletBalance;

  /// Optional: callback when user confirms the ride
  final VoidCallback? onConfirm;

  const RideServiceScreen({
    super.key,
    this.originAddress,
    this.destinationAddress,
    this.vehicleDisplayName,
    this.distanceKm,
    this.baseFare,
    this.pickupSurcharge,
    this.totalFare,
    this.paymentMethod,
    this.walletBalance,
    this.onConfirm,
  });

  bool get _hasDetails =>
      originAddress != null && destinationAddress != null && totalFare != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasDetails) {
      // Fallback: go to full ride booking flow
      return const RideHomeScreen();
    }
    return _RideConfirmView(
      originAddress: originAddress!,
      destinationAddress: destinationAddress!,
      vehicleDisplayName: vehicleDisplayName,
      distanceKm: distanceKm,
      baseFare: baseFare,
      pickupSurcharge: pickupSurcharge,
      totalFare: totalFare!,
      paymentMethod: paymentMethod ?? 'cash',
      walletBalance: walletBalance,
      onConfirm: onConfirm,
    );
  }
}

/// Internal confirmation view — shown when ride details are provided
class _RideConfirmView extends StatefulWidget {
  final String originAddress;
  final String destinationAddress;
  final String? vehicleDisplayName;
  final double? distanceKm;
  final double? baseFare;
  final double? pickupSurcharge;
  final double totalFare;
  final String paymentMethod;
  final double? walletBalance;
  final VoidCallback? onConfirm;

  const _RideConfirmView({
    required this.originAddress,
    required this.destinationAddress,
    this.vehicleDisplayName,
    this.distanceKm,
    this.baseFare,
    this.pickupSurcharge,
    required this.totalFare,
    required this.paymentMethod,
    this.walletBalance,
    this.onConfirm,
  });

  @override
  State<_RideConfirmView> createState() => _RideConfirmViewState();
}

class _RideConfirmViewState extends State<_RideConfirmView> {
  late String _selectedPayment;

  @override
  void initState() {
    super.initState();
    _selectedPayment = widget.paymentMethod;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final distKm = widget.distanceKm;
    final vehicle = widget.vehicleDisplayName ?? l10n.rideMotorcycle;
    final base = widget.baseFare ?? 0.0;
    final pickup = widget.pickupSurcharge ?? 0.0;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.rideServiceTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
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
                children: [
                  // Route card
                  _buildRouteCard(jdc, l10n),
                  const SizedBox(height: 14),

                  // Vehicle card
                  _buildVehicleCard(jdc, l10n, vehicle, distKm),
                  const SizedBox(height: 14),

                  // Payment method
                  _buildPaymentCard(jdc, l10n),
                  const SizedBox(height: 14),

                  // Fare breakdown
                  _buildFareCard(jdc, l10n, distKm, base, pickup),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // CTA
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: jdc.surface,
              border: Border(top: BorderSide(color: jdc.line)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                // ส่งวิธีชำระเงินที่ผู้ใช้เลือกกลับไปให้ผู้เรียก (เดิม pop(true) ทำให้ค่าที่เลือกหาย)
                onPressed: widget.onConfirm ??
                    () => Navigator.of(context).pop(_selectedPayment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: jdc.cta,
                  foregroundColor: jdc.onCta,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(l10n.rideServiceCallBtn,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(JdcColors jdc, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
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
                  width: 2, height: 30, color: jdc.line),
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
                    Text(l10n.rideServiceOriginLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.06,
                            color: jdc.muted)),
                    const SizedBox(height: 2),
                    Text(widget.originAddress,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: jdc.text)),
                  ],
                ),
                const SizedBox(height: 22),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.rideServiceDestLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.06,
                            color: jdc.muted)),
                    const SizedBox(height: 2),
                    Text(widget.destinationAddress,
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
    );
  }

  Widget _buildVehicleCard(JdcColors jdc, AppLocalizations l10n,
      String vehicle, double? distKm) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: jdc.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.two_wheeler,
                color: jdc.brandOnSoft, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: jdc.text)),
                if (distKm != null)
                  Text(
                      l10n.confirmDistanceKm(distKm.toStringAsFixed(1)),
                      style:
                          TextStyle(fontSize: 12, color: jdc.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            child: Text(l10n.rideServiceChange,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: jdc.link)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(JdcColors jdc, AppLocalizations l10n) {
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
          Text(l10n.rideServicePaymentTitle,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: jdc.text)),
          const SizedBox(height: 10),
          _payOption(jdc, 'wallet', l10n.rideServicePayWallet,
              widget.walletBalance != null
                  ? '฿${widget.walletBalance!.toStringAsFixed(2)}'
                  : null),
          const SizedBox(height: 10),
          _payOption(jdc, 'cash', l10n.rideServicePayCash, null),
        ],
      ),
    );
  }

  Widget _payOption(
      JdcColors jdc, String value, String label, String? trailing) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Radio<String>(
              value: value,
              groupValue: _selectedPayment,
              activeColor: jdc.cta,
              visualDensity: VisualDensity.compact,
              onChanged: (v) =>
                  setState(() => _selectedPayment = v ?? value),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: jdc.text)),
          ),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: jdc.muted)),
        ],
      ),
    );
  }

  Widget _buildFareCard(JdcColors jdc, AppLocalizations l10n,
      double? distKm, double base, double pickup) {
    final distLabel = distKm != null
        ? '${distKm.toStringAsFixed(1)} กม.'
        : '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        children: [
          if (base > 0) ...[
            _fareRow(
                jdc,
                '${l10n.rideServiceBaseFare}${distLabel.isNotEmpty ? ' ($distLabel)' : ''}',
                '฿${base.toStringAsFixed(2)}',
                jdc.muted),
            const SizedBox(height: 10),
          ],
          if (pickup > 0) ...[
            _fareRow(jdc, l10n.rideServicePickupFee,
                '฿${pickup.toStringAsFixed(2)}', jdc.muted),
            const SizedBox(height: 10),
          ],
          Divider(height: 1, color: jdc.line),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(l10n.rideServiceFareTitle,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: jdc.text)),
              ),
              Text('฿${widget.totalFare.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fareRow(
      JdcColors jdc, String label, String value, Color valueColor) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: jdc.muted))),
        Text(value,
            style: TextStyle(fontSize: 13, color: valueColor)),
      ],
    );
  }
}
