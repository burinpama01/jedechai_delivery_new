import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intl/intl.dart';
import '../../../common/models/booking.dart';
import '../../../common/config/env_config.dart';
import '../../../common/services/supabase_service.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _setupMap();
    _loadCouponUsage();
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
        infoWindow: InfoWindow(title: b.pickupAddress ?? 'จุดรับ'),
      ),
      Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(b.destLat, b.destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: b.destinationAddress ?? 'จุดส่ง'),
      ),
    ]);
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final b = widget.booking;
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
            color: const Color(0xFF1E88E5),
            width: 5,
            points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
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
            color: const Color(0xFF1E88E5),
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
        return '${mins ~/ 60} ชม. ${mins % 60} น.';
      }
      return '$mins นาที';
    }
    if (b.startedAt != null && b.completedAt != null) {
      final dur = b.completedAt!.difference(b.startedAt!).abs();
      if (dur.inHours > 0) return '${dur.inHours} ชม. ${dur.inMinutes % 60} น.';
      return '${dur.inMinutes} นาที';
    }
    if (b.assignedAt != null && b.completedAt != null) {
      final dur = b.completedAt!.difference(b.assignedAt!).abs();
      if (dur.inHours > 0) return '${dur.inHours} ชม. ${dur.inMinutes % 60} น.';
      return '${dur.inMinutes} นาที';
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
    final colorScheme = Theme.of(context).colorScheme;
    final b = widget.booking;
    final isFood = b.serviceType == 'food';
    final grossCollect = isFood ? b.price + (b.deliveryFee ?? 0) : b.price;
    final totalCollect = (grossCollect - _couponDiscount) < 0 ? 0 : (grossCollect - _couponDiscount);
    final commission = b.appEarnings ?? (totalCollect * 0.20);
    final netEarnings = b.driverEarnings ?? (totalCollect - commission);
    final paymentLabel = (b.paymentMethod ?? 'cash') == 'cash' ? 'เงินสด' : b.paymentMethod ?? '-';
    final serviceLabel = isFood
        ? 'สั่งอาหาร'
        : b.serviceType == 'ride'
            ? 'เรียกรถ'
            : 'ส่งพัสดุ';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('รายละเอียดการให้บริการ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // ── Map Section ──
          if (_hasValidCoordinates)
            SizedBox(
              height: 180,
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
              height: 120,
              color: const Color(0xFF1A1A2E),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_outlined, color: Colors.white24, size: 40),
                    SizedBox(height: 8),
                    Text('ไม่มีข้อมูลเส้นทาง', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // ── Content Section ──
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Date & Order ID ──
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _serviceDateTimeSummary(),
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          OrderCodeFormatter.formatByServiceType(
                            b.id,
                            serviceType: b.serviceType,
                          ),
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Origin / Destination ──
                    _buildAddressRow(
                      icon: Icons.circle,
                      iconColor: AppTheme.accentBlue,
                      iconSize: 12,
                      text: b.pickupAddress ?? 'จุดรับ',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Container(width: 2, height: 20, color: Colors.grey[300]),
                    ),
                    _buildAddressRow(
                      icon: Icons.circle,
                      iconColor: Colors.red,
                      iconSize: 12,
                      text: b.destinationAddress ?? 'จุดส่ง',
                    ),
                    const SizedBox(height: 16),

                    // ── Info Chips Row ──
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
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
                    const SizedBox(height: 20),

                    // ── Net Earnings ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.accentBlue, AppTheme.accentBlue.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentBlue.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text('ยอดรายได้สุทธิ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            '฿ ${netEarnings.ceil()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Earnings Breakdown ──
                    _sectionCard(
                      title: 'รายละเอียดรายได้',
                      children: [
                        _earningsRow('ค่ารอบ', '฿ ${totalCollect.ceil()}', colorScheme.onSurface, isBold: true),
                        if (_couponDiscount > 0)
                          _earningsRow(
                            _couponCode != null && _couponCode!.isNotEmpty
                                ? 'ส่วนลดคูปอง ($_couponCode)'
                                : 'ส่วนลดคูปอง',
                            '-฿ ${_couponDiscount.ceil()}',
                            Colors.green.shade600,
                          ),
                        _earningsRow('ค่าคอมมิชชั่น', '-฿ ${commission.ceil()}', Colors.red.shade400),
                        const Divider(height: 20),
                        _earningsRow('ยอดรายได้สุทธิ', '฿ ${netEarnings.ceil()}', AppTheme.accentBlue, isBold: true),
                        if (isFood) ...[
                          const SizedBox(height: 8),
                          _earningsRow('  ค่าอาหาร', '฿ ${b.price.ceil()}', colorScheme.onSurfaceVariant),
                          _earningsRow('  ค่าส่ง', '฿ ${(b.deliveryFee ?? 0).ceil()}', colorScheme.onSurfaceVariant),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Cash Collection ──
                    if (paymentLabel == 'เงินสด')
                      _sectionCard(
                        title: 'รายการชำระเงินสด',
                        children: [
                          _earningsRow('ยอดที่ต้องเก็บจากลูกค้า', '฿ ${totalCollect.ceil()}', colorScheme.onSurface, isBold: true),
                          if (_couponDiscount > 0)
                            _earningsRow(
                              _couponCode != null && _couponCode!.isNotEmpty
                                  ? 'ส่วนลดคูปอง ($_couponCode)'
                                  : 'ส่วนลดคูปอง',
                              '-฿ ${_couponDiscount.ceil()}',
                              Colors.green.shade600,
                            ),
                          if (isFood) ...[
                            const SizedBox(height: 8),
                            _earningsRow('  ค่าอาหาร', '฿ ${b.price.ceil()}', colorScheme.onSurfaceVariant),
                            _earningsRow('  ค่าส่ง', '฿ ${(b.deliveryFee ?? 0).ceil()}', colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurface, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _chipDivider() {
    return Container(width: 1, height: 30, color: Colors.grey[200]);
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 12),
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
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 14, color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}
