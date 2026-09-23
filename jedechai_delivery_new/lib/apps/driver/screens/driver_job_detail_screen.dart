import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../common/config/env_config.dart';
import '../../../common/models/booking.dart';
import '../../../common/models/coupon.dart';
import '../../../common/utils/driver_amount_calculator.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/services/supabase_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/services/merchant_food_config_service.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import '../../../utils/debug_logger.dart';

/// Driver Job Detail Screen — Grab-style
///
/// Shows completed job details with:
/// - Route map (origin → destination)
/// - Service info chips (payment, type, distance, time)
/// - Net earnings prominently
/// - Earnings breakdown (trip fare, commission, net)
/// - Cash collection details
class DriverJobDetailScreen extends StatefulWidget {
  final Booking booking;

  const DriverJobDetailScreen({super.key, required this.booking});

  @override
  State<DriverJobDetailScreen> createState() => _DriverJobDetailScreenState();
}

class _DriverJobDetailScreenState extends State<DriverJobDetailScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  static String get _googleApiKey => EnvConfig.googleMapsApiKey;
  double _couponDiscount = 0.0;
  String? _couponCode;
  double _merchantSystemRate = 0.10;
  double _merchantDriverRate = 0.0;
  double _deliverySystemRate = 0.02;

  @override
  void initState() {
    super.initState();
    _setupMap();
    _loadCouponUsage();
    _loadFoodSettlementRates();
  }

  Future<void> _loadFoodSettlementRates() async {
    final booking = widget.booking;
    if (booking.serviceType != 'food') return;

    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();

      Map<String, dynamic>? merchantProfile;
      final merchantId = booking.merchantId;
      if (merchantId != null && merchantId.isNotEmpty) {
        merchantProfile = await SupabaseService.client
            .from('profiles')
            .select(
              'gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_base_fare, custom_base_distance, custom_per_km, custom_delivery_fee',
            )
            .eq('id', merchantId)
            .maybeSingle();
      }

      final config = MerchantFoodConfigService.resolve(
        merchantProfile: merchantProfile,
        defaultMerchantSystemRate: configService.merchantGpSystemRateDefault,
        defaultMerchantDriverRate: configService.merchantGpDriverRateDefault,
        defaultDeliverySystemRate: configService.platformFeeRate,
      );

      double? driverDeliverySystemRate;
      final driverId = booking.driverId;
      if (driverId != null && driverId.isNotEmpty) {
        try {
          final driverProfile = await SupabaseService.client
              .from('profiles')
              .select('driver_delivery_system_rate')
              .eq('id', driverId)
              .maybeSingle();
          final raw = driverProfile?['driver_delivery_system_rate'];
          if (raw != null) {
            final rate = (raw as num).toDouble();
            if (rate >= 0 && rate <= 1) driverDeliverySystemRate = rate;
          }
        } catch (e) {
          debugLog('⚠️ Error loading driver delivery fee override: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _merchantSystemRate = config.merchantGpSystemRate;
        _merchantDriverRate = config.merchantGpDriverRate;
        _deliverySystemRate = driverDeliverySystemRate ?? config.deliverySystemRate;
      });
    } catch (e) {
      debugLog('⚠️ Error loading food settlement rates in job detail: $e');
    }
  }

  FoodOrderSettlement? _foodSettlement() {
    final booking = widget.booking;
    if (booking.serviceType != 'food') return null;
    return DriverAmountCalculator.foodOrderSettlement(
      foodPrice: booking.price,
      deliveryFee: booking.deliveryFee ?? 0,
      deliverySystemRate: _deliverySystemRate,
      merchantGpSystemRate: _merchantSystemRate,
      merchantGpDriverRate: _merchantDriverRate,
    );
  }

  Future<void> _loadCouponUsage() async {
    try {
      final usage = await SupabaseService.client
          .from('coupon_usages')
          .select('discount_amount, coupon_id')
          .eq('booking_id', widget.booking.id)
          .maybeSingle();

      if (usage == null) return;

      String? couponCode;
      final couponId = usage['coupon_id'] as String?;
      if (couponId != null && couponId.isNotEmpty) {
        final coupon = await SupabaseService.client
            .from('coupons')
            .select('code')
            .eq('id', couponId)
            .maybeSingle();
        couponCode = coupon?['code'] as String?;
      }

      if (mounted) {
        setState(() {
          _couponDiscount = (usage['discount_amount'] as num?)?.toDouble() ?? 0.0;
          _couponCode = couponCode;
        });
      }
    } catch (e) {
      debugLog('⚠️ Error loading coupon usage in driver job detail: $e');
    }
  }

  bool get _hasValidCoordinates =>
      widget.booking.originLat != 0.0 && widget.booking.originLng != 0.0 &&
      widget.booking.destLat != 0.0 && widget.booking.destLng != 0.0;

  void _setupMap() {
    if (!_hasValidCoordinates) return;
    final b = widget.booking;
    _markers.addAll([
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(b.originLat, b.originLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: b.pickupAddress ?? 'Pickup'),
      ),
      Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(b.destLat, b.destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: b.destinationAddress ?? 'Destination'),
      ),
    ]);
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final b = widget.booking;
    final jdc = JdcColors.of(context);
    try {
      final polylinePoints = PolylinePoints();
      final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _googleApiKey,
        request: PolylineRequest(
          origin: PointLatLng(b.originLat, b.originLng),
          destination: PointLatLng(b.destLat, b.destLng),
          mode: TravelMode.driving,
        ),
      );
      if (result.points.isNotEmpty && mounted) {
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            color: jdc.route,
            width: 5,
            points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          ));
        });
      } else if (mounted) {
        // API returned OK but no points, or non-OK status — draw dashed fallback
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            color: jdc.offTrack,
            width: 3,
            patterns: [PatternItem.dash(12), PatternItem.gap(6)],
            points: [LatLng(b.originLat, b.originLng), LatLng(b.destLat, b.destLng)],
          ));
        });
      }
    } catch (e) {
      debugLog('⚠️ Route fetch error: $e');
      // Fallback: straight line
      if (mounted) {
        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            color: jdc.route,
            width: 4,
            patterns: [PatternItem.dash(16), PatternItem.gap(8)],
            points: [
              LatLng(b.originLat, b.originLng),
              LatLng(b.destLat, b.destLng),
            ],
          ));
        });
      }
    }
  }

  // Compute trip duration from timestamps or stored value
  String _tripDuration() {
    final b = widget.booking;
    if (b.tripDurationMinutes != null) {
      final mins = b.tripDurationMinutes!.abs();
      if (mins >= 60) {
        return AppLocalizations.of(context)!.jobDetailDurationHrMin((mins ~/ 60).toString(), (mins % 60).toString());
      }
      return AppLocalizations.of(context)!.jobDetailDurationMin(mins.toString());
    }
    if (b.startedAt != null && b.completedAt != null) {
      final dur = b.completedAt!.difference(b.startedAt!).abs();
      if (dur.inHours > 0) return AppLocalizations.of(context)!.jobDetailDurationHrMin(dur.inHours.toString(), (dur.inMinutes % 60).toString());
      return AppLocalizations.of(context)!.jobDetailDurationMin(dur.inMinutes.toString());
    }
    if (b.assignedAt != null && b.completedAt != null) {
      final dur = b.completedAt!.difference(b.assignedAt!).abs();
      if (dur.inHours > 0) return AppLocalizations.of(context)!.jobDetailDurationHrMin(dur.inHours.toString(), (dur.inMinutes % 60).toString());
      return AppLocalizations.of(context)!.jobDetailDurationMin(dur.inMinutes.toString());
    }
    return '-';
  }

  String _serviceDateTimeSummary() {
    final b = widget.booking;
    final dateText = DateFormat('dd MMM yyyy').format(b.createdAt.toLocal());

    final assigned = b.assignedAt?.toLocal();
    final completed = b.completedAt?.toLocal();
    if (assigned != null && completed != null) {
      return '$dateText, ${DateFormat('HH:mm').format(assigned)} - ${DateFormat('HH:mm').format(completed)}';
    }

    final created = b.createdAt.toLocal();
    return '$dateText, ${DateFormat('HH:mm').format(created)}';
  }

  double _displayDistance() {
    return widget.booking.actualDistanceKm ?? widget.booking.distanceKm;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final b = widget.booking;
    final isFood = b.serviceType == 'food';
    final totalCollect = DriverAmountCalculator.netCollect(
      booking: b,
      couponDiscountAmount: _couponDiscount,
    );
    final normalizedCouponCode = _couponCode?.trim().toUpperCase();
    final hideCouponBreakdown = Coupon.isSystemCouponCode(normalizedCouponCode);
    final foodSettlement = _foodSettlement();
    final commission = DriverAmountCalculator.appFeeWithFoodFallback(
      booking: b,
      netCollectAmount: totalCollect,
      foodSettlement: foodSettlement,
    );
    final netEarnings = DriverAmountCalculator.netEarningsWithFoodFallback(
      booking: b,
      netCollectAmount: totalCollect,
      appFeeAmount: commission,
      foodSettlement: foodSettlement,
    );
    final l10n = AppLocalizations.of(context)!;
    final paymentLabel = (b.paymentMethod ?? 'cash') == 'cash' ? l10n.jobDetailCash : b.paymentMethod ?? '-';
    final serviceLabel = isFood
        ? l10n.jobDetailOrderFood
        : b.serviceType == 'ride'
            ? l10n.jobDetailRide
            : l10n.jobDetailParcel;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        backgroundColor: jdc.panel,
        foregroundColor: jdc.onPanel,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.jobDetailTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: jdc.onPanel,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
      ),
      body: Column(
        children: [
          // The route remains the primary visual anchor of the job summary.
          if (_hasValidCoordinates)
            SizedBox(
              height: 220,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (b.originLat + b.destLat) / 2,
                    (b.originLng + b.destLng) / 2,
                  ),
                  zoom: 12,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                liteModeEnabled: true,
                onMapCreated: (c) {
                  _mapController = c;
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (_mapController != null && mounted) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngBounds(
                          LatLngBounds(
                            southwest: LatLng(
                              b.originLat < b.destLat ? b.originLat : b.destLat,
                              b.originLng < b.destLng ? b.originLng : b.destLng,
                            ),
                            northeast: LatLng(
                              b.originLat > b.destLat ? b.originLat : b.destLat,
                              b.originLng > b.destLng ? b.originLng : b.destLng,
                            ),
                          ),
                          50,
                        ),
                      );
                    }
                  });
                },
              ),
            )
          else
            Container(
              height: 160,
              color: jdc.panel,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, color: jdc.panelDim, size: 40),
                    const SizedBox(height: 8),
                    Text(l10n.jobDetailNoRoute, style: TextStyle(color: jdc.panelDim, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // ── Content Section ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(JdcRadius.sheet),
                  topRight: Radius.circular(JdcRadius.sheet),
                ),
                boxShadow: jdc.shadowSheet,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Keep the historical job ID and date visible above the route.
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: jdc.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _serviceDateTimeSummary(),
                            style: TextStyle(fontSize: 12, color: jdc.muted),
                          ),
                        ),
                        Text(
                          OrderCodeFormatter.formatByServiceType(
                            b.id,
                            serviceType: b.serviceType,
                          ),
                          style: TextStyle(fontSize: 11, color: jdc.muted, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: JdcSpacing.md),

                    // ── Origin / Destination ──
                    _buildAddressRow(
                      icon: Icons.circle,
                      iconColor: jdc.cta,
                      iconSize: 12,
                      text: b.pickupAddress ?? l10n.jobDetailPickupFallback,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Container(width: 2, height: 20, color: jdc.line),
                    ),
                    _buildAddressRow(
                      icon: Icons.circle,
                      iconColor: jdc.danger,
                      iconSize: 12,
                      text: b.destinationAddress ?? l10n.jobDetailDestFallback,
                    ),
                    const SizedBox(height: JdcSpacing.lg),

                    // ── Info Chips Row ──
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: jdc.paper,
                        borderRadius: BorderRadius.circular(JdcRadius.small),
                        border: Border.all(color: jdc.line),
                      ),
                      child: Row(
                        children: [
                          _buildInfoChip(paymentLabel, Icons.payment),
                          _chipDivider(),
                          _buildInfoChip(serviceLabel, Icons.local_shipping),
                          _chipDivider(),
                          _buildInfoChip('${_displayDistance().toStringAsFixed(2)} km', Icons.route),
                          _chipDivider(),
                          _buildInfoChip(_tripDuration(), Icons.timer),
                        ],
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.xl),

                    // ── Net Earnings ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(JdcSpacing.xl),
                      decoration: BoxDecoration(
                        gradient: jdc.hero3,
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                        boxShadow: jdc.shadowBrandLg,
                      ),
                      child: Column(
                        children: [
                          Text(l10n.jobDetailNetEarnings, style: TextStyle(color: jdc.panelDim, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            l10n.driverJobBaht(netEarnings.ceil().toString()),
                            style: TextStyle(
                              color: jdc.onPanel,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontVariations: const [FontVariation('wght', 700)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.xl),

                    // ── Earnings Breakdown ──
                    _sectionCard(
                      title: l10n.jobDetailEarningsBreakdown,
                      children: [
                        _earningsRow(l10n.jobDetailTripFare, l10n.driverJobBaht(totalCollect.ceil().toString()), jdc.text, isBold: true),
                        if (_couponDiscount > 0)
                          _earningsRow(
                            hideCouponBreakdown
                                ? l10n.jobDetailCouponDiscountGeneric
                                : (_couponCode != null && _couponCode!.isNotEmpty
                                    ? l10n.jobDetailCouponDiscountCode(_couponCode!)
                                    : l10n.jobDetailCouponDiscountGeneric),
                            l10n.driverJobBahtNeg(_couponDiscount.ceil().toString()),
                            jdc.successInk,
                          ),
                        _earningsRow(l10n.jobDetailPlatformFee, l10n.driverJobBahtNeg(commission.ceil().toString()), jdc.dangerInk),
                        const Divider(height: 20),
                        _earningsRow(l10n.jobDetailNetEarnings, l10n.driverJobBaht(netEarnings.ceil().toString()), jdc.cta, isBold: true),
                        if (isFood) ...[
                          const SizedBox(height: 8),
                          _earningsRow(l10n.jobDetailFoodCost, l10n.driverJobBaht(b.price.ceil().toString()), jdc.muted),
                          _earningsRow(l10n.jobDetailDeliveryFee, l10n.driverJobBaht((b.deliveryFee ?? 0).ceil().toString()), jdc.muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: JdcSpacing.lg),

                    // ── Cash Collection ──
                    if ((b.paymentMethod ?? 'cash') == 'cash')
                      _sectionCard(
                        title: l10n.jobDetailCashCollection,
                        children: [
                          _earningsRow(l10n.jobDetailCollectFromCustomer, l10n.driverJobBaht(totalCollect.ceil().toString()), jdc.text, isBold: true),
                          if (_couponDiscount > 0)
                            _earningsRow(
                              hideCouponBreakdown
                                  ? l10n.jobDetailCouponDiscountGeneric
                                  : (_couponCode != null &&
                                          _couponCode!.isNotEmpty
                                      ? l10n.jobDetailCouponDiscountCode(_couponCode!)
                                      : l10n.jobDetailCouponDiscountGeneric),
                              l10n.driverJobBahtNeg(_couponDiscount.ceil().toString()),
                              jdc.successInk,
                            ),
                          if (isFood) ...[
                            const SizedBox(height: 8),
                            _earningsRow(l10n.jobDetailFoodCost, l10n.driverJobBaht(b.price.ceil().toString()), jdc.muted),
                            _earningsRow(l10n.jobDetailDeliveryFee, l10n.driverJobBaht((b.deliveryFee ?? 0).ceil().toString()), jdc.muted),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({required IconData icon, required Color iconColor, required double iconSize, required String text}) {
    final jdc = JdcColors.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: jdc.text,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 500)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    final jdc = JdcColors.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: jdc.muted),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: jdc.text,
              fontWeight: FontWeight.w600,
              fontVariations: const [FontVariation('wght', 600)],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _chipDivider() {
    final jdc = JdcColors.of(context);
    return Container(width: 1, height: 30, color: jdc.line);
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    final jdc = JdcColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.paper,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: jdc.text,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
          const SizedBox(height: JdcSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _earningsRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              fontVariations: [FontVariation('wght', isBold ? 600 : 400)],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontVariations: [FontVariation('wght', isBold ? 700 : 500)],
            ),
          ),
        ],
      ),
    );
  }
}
