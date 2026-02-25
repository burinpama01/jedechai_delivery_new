import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../utils/debug_logger.dart';

/// Tracking Screen
/// 
/// Shows real-time tracking of delivery with map and status timeline
class TrackingScreen extends StatefulWidget {
  final Booking booking;

  const TrackingScreen({super.key, required this.booking});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  GoogleMapController? _mapController;
  late Booking _booking;
  StreamSubscription? _bookingSubscription;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _setupMarkers();
    _listenToBookingUpdates();
  }

  void _setupMarkers() {
    _markers.clear();
    // จุดรับ
    _markers.add(Marker(
      markerId: const MarkerId('origin'),
      position: LatLng(_booking.originLat, _booking.originLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: 'จุดรับ', snippet: _booking.pickupAddress ?? ''),
    ));
    // จุดส่ง
    _markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(_booking.destLat, _booking.destLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'จุดส่ง', snippet: _booking.destinationAddress ?? ''),
    ));
  }

  void _listenToBookingUpdates() {
    try {
      _bookingSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', _booking.id)
          .listen((data) {
        if (data.isNotEmpty && mounted) {
          setState(() {
            _booking = Booking.fromJson(data.first);
          });
        }
      });
    } catch (e) {
      debugLog('Error listening to booking updates: $e');
    }
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          // แผนที่
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (_booking.originLat + _booking.destLat) / 2,
                (_booking.originLng + _booking.destLng) / 2,
              ),
              zoom: 13,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              // Fit bounds
              _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
                LatLngBounds(
                  southwest: LatLng(
                    _booking.originLat < _booking.destLat ? _booking.originLat : _booking.destLat,
                    _booking.originLng < _booking.destLng ? _booking.originLng : _booking.destLng,
                  ),
                  northeast: LatLng(
                    _booking.originLat > _booking.destLat ? _booking.originLat : _booking.destLat,
                    _booking.originLng > _booking.destLng ? _booking.originLng : _booking.destLng,
                  ),
                ),
                80,
              ));
            },
          ),

          // ปุ่มกลับ
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: CircleAvatar(
              backgroundColor: colorScheme.surface,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Bottom sheet — ข้อมูลสถานะ
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStatusPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // สถานะปัจจุบัน
              _buildCurrentStatus(),
              const SizedBox(height: 16),

              // Timeline
              _buildTimeline(),
              const SizedBox(height: 16),

              // ข้อมูลคนขับ
              if (_booking.driverName != null) _buildDriverInfo(),

              // ข้อมูลที่อยู่
              const SizedBox(height: 12),
              _buildAddressInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatus() {
    final colorScheme = Theme.of(context).colorScheme;
    final statusInfo = _getStatusInfo(_booking.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusInfo['color'] as Color, (statusInfo['color'] as Color).withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(statusInfo['icon'] as IconData, color: colorScheme.onPrimary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusInfo['title'] as String,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                Text(statusInfo['subtitle'] as String,
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.9),
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = _getTimelineSteps();
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isActive = step['active'] as bool;
        final isLast = i == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryGreen : colorScheme.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                  child: isActive
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2, height: 30,
                    color: isActive ? AppTheme.primaryGreen : colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Text(step['label'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    )),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDriverInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
            radius: 22,
            child: const Icon(Icons.person, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_booking.driverName ?? 'คนขับ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colorScheme.onSurface,
                    )),
                if (_booking.driverVehicle != null)
                  Text(
                    _booking.driverVehicle!,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (_booking.driverPhone != null)
            IconButton(
              icon: const Icon(Icons.phone, color: AppTheme.primaryGreen),
              onPressed: () {
                // TODO: launch phone call
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAddressInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildAddressRow(
            icon: Icons.circle,
            color: AppTheme.primaryGreen,
            label: 'จุดรับ',
            address: _booking.pickupAddress ?? 'ไม่ระบุ',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 2, height: 20, color: colorScheme.outlineVariant),
          ),
          _buildAddressRow(
            icon: Icons.location_on,
            color: Colors.red,
            label: 'จุดส่ง',
            address: _booking.destinationAddress ?? 'ไม่ระบุ',
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              Text(
                address,
                style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {'icon': Icons.hourglass_empty, 'color': Colors.orange, 'title': 'รอคนขับรับงาน', 'subtitle': 'กำลังค้นหาคนขับในพื้นที่ใกล้คุณ'};
      case 'accepted':
      case 'assigned':
        return {'icon': Icons.delivery_dining, 'color': AppTheme.accentBlue, 'title': 'คนขับรับงานแล้ว', 'subtitle': 'คนขับกำลังเดินทางมาหาคุณ'};
      case 'picking_up':
      case 'arrived_at_pickup':
        return {'icon': Icons.store, 'color': AppTheme.accentBlue, 'title': 'กำลังรับสินค้า', 'subtitle': 'คนขับถึงจุดรับแล้ว'};
      case 'preparing':
        return {'icon': Icons.restaurant, 'color': Colors.orange, 'title': 'ร้านกำลังเตรียม', 'subtitle': 'ร้านค้ากำลังเตรียมออเดอร์ของคุณ'};
      case 'in_transit':
      case 'delivering':
        return {'icon': Icons.local_shipping, 'color': AppTheme.primaryGreen, 'title': 'กำลังจัดส่ง', 'subtitle': 'คนขับกำลังเดินทางไปจุดส่ง'};
      case 'arrived_at_dropoff':
        return {'icon': Icons.pin_drop, 'color': AppTheme.primaryGreen, 'title': 'ถึงจุดส่งแล้ว', 'subtitle': 'คนขับถึงจุดหมายปลายทางแล้ว'};
      case 'completed':
        return {'icon': Icons.check_circle, 'color': AppTheme.primaryGreen, 'title': 'จัดส่งสำเร็จ', 'subtitle': 'ออเดอร์เสร็จสมบูรณ์'};
      case 'cancelled':
        return {'icon': Icons.cancel, 'color': Colors.red, 'title': 'ยกเลิกแล้ว', 'subtitle': 'ออเดอร์นี้ถูกยกเลิก'};
      default:
        final colorScheme = Theme.of(context).colorScheme;
        return {
          'icon': Icons.info,
          'color': colorScheme.outlineVariant,
          'title': 'ไม่ทราบสถานะ',
          'subtitle': status,
        };
    }
  }

  List<Map<String, dynamic>> _getTimelineSteps() {
    final statusOrder = ['pending', 'accepted', 'picking_up', 'in_transit', 'completed'];
    final labels = {
      'pending': 'สร้างออเดอร์แล้ว',
      'accepted': 'คนขับรับงาน',
      'picking_up': 'กำลังรับสินค้า',
      'in_transit': 'กำลังจัดส่ง',
      'completed': 'จัดส่งสำเร็จ',
    };

    int currentIndex = statusOrder.indexOf(_booking.status);
    if (currentIndex == -1) {
      // handle statuses not in the main flow
      if (_booking.status == 'assigned') currentIndex = 1;
      else if (_booking.status == 'preparing' || _booking.status == 'arrived_at_pickup') currentIndex = 2;
      else if (_booking.status == 'delivering' || _booking.status == 'arrived_at_dropoff') currentIndex = 3;
      else if (_booking.status == 'cancelled') currentIndex = -1;
      else currentIndex = 0;
    }

    return List.generate(statusOrder.length, (i) => {
      'label': labels[statusOrder[i]]!,
      'active': i <= currentIndex,
    });
  }
}
