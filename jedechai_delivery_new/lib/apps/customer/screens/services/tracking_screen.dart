import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/config/env_config.dart';
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
  StreamSubscription? _driverLocationSubscription;
  String? _trackedDriverId;
  bool _didInitialDriverCamera = false;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  static String get _googleApiKey => EnvConfig.googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _listenToBookingUpdates();
    if (_booking.driverId != null) {
      _listenToDriverLocation(_booking.driverId!);
    }
    _fetchRoute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupMarkers();
  }

  void _setupMarkers() {
    _markers.removeWhere(
        (m) => m.markerId.value == 'origin' || m.markerId.value == 'destination');
    _markers.add(Marker(
      markerId: const MarkerId('origin'),
      position: LatLng(_booking.originLat, _booking.originLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
          title: AppLocalizations.of(context)!.trackPickup,
          snippet: _booking.pickupAddress ?? ''),
    ));
    _markers.add(Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(_booking.destLat, _booking.destLng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
          title: AppLocalizations.of(context)!.trackDestination,
          snippet: _booking.destinationAddress ?? ''),
    ));
  }

  Future<void> _fetchRoute() async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_booking.originLat},${_booking.originLng}'
        '&destination=${_booking.destLat},${_booking.destLng}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );
      final response = await http.get(url);
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
        final encoded = (data['routes'][0] as Map)['overview_polyline']
            ?['points'] as String?;
        if (encoded != null && encoded.isNotEmpty) {
          final points = _decodePolyline(encoded);
          final routeColor = JdcColors.of(context).route;
          setState(() {
            _polylines.clear();
            _polylines.add(Polyline(
              polylineId: const PolylineId('route'),
              color: routeColor,
              width: 5,
              points: points,
            ));
          });
          return;
        }
      }
      // Fallback: dashed straight line
      _drawFallbackLine();
    } catch (e) {
      debugLog('TrackingScreen: route fetch error: $e');
      _drawFallbackLine();
    }
  }

  void _drawFallbackLine() {
    if (!mounted) return;
    final fallbackColor = JdcColors.of(context).muted;
    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        color: fallbackColor,
        width: 3,
        patterns: [PatternItem.dash(12), PatternItem.gap(6)],
        points: [
          LatLng(_booking.originLat, _booking.originLng),
          LatLng(_booking.destLat, _booking.destLng),
        ],
      ));
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);
      lat += dlat;
      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result0 & 1) != 0 ? ~(result0 >> 1) : (result0 >> 1);
      lng += dlng;
      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  void _listenToBookingUpdates() {
    try {
      _bookingSubscription = Supabase.instance.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', _booking.id)
          .listen((data) {
        if (data.isNotEmpty && mounted) {
          final updated = Booking.fromJson(data.first);
          setState(() => _booking = updated);
          if (updated.driverId != null &&
              updated.driverId != _trackedDriverId) {
            _listenToDriverLocation(updated.driverId!);
          }
        }
      }, onError: (Object error) {
        debugLog('Booking stream error: $error');
      });
    } catch (e) {
      debugLog('Error listening to booking updates: $e');
    }
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();
    _trackedDriverId = driverId;
    _didInitialDriverCamera = false;
    try {
      _driverLocationSubscription = Supabase.instance.client
          .from('driver_locations')
          .stream(primaryKey: ['id'])
          .eq('driver_id', driverId)
          .listen((data) {
        if (!mounted || data.isEmpty) return;
        final row = data.first;
        final lat = (row['location_lat'] as num?)?.toDouble();
        final lng = (row['location_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return;
        final driverPos = LatLng(lat, lng);
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'driver');
          _markers.add(Marker(
            markerId: const MarkerId('driver'),
            position: driverPos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
                title:
                    AppLocalizations.of(context)!.trackDriverFallback),
          ));
        });
        if (!_didInitialDriverCamera) {
          _didInitialDriverCamera = true;
          _mapController?.animateCamera(
              CameraUpdate.newLatLng(driverPos));
        }
      }, onError: (Object error) {
        debugLog('Driver location stream error: $error');
      });
    } catch (e) {
      debugLog('Error listening to driver location: $e');
    }
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
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
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController?.animateCamera(
                CameraUpdate.newLatLngBounds(
                  LatLngBounds(
                    southwest: LatLng(
                      _booking.originLat < _booking.destLat
                          ? _booking.originLat
                          : _booking.destLat,
                      _booking.originLng < _booking.destLng
                          ? _booking.originLng
                          : _booking.destLng,
                    ),
                    northeast: LatLng(
                      _booking.originLat > _booking.destLat
                          ? _booking.originLat
                          : _booking.destLat,
                      _booking.originLng > _booking.destLng
                          ? _booking.originLng
                          : _booking.destLng,
                    ),
                  ),
                  80,
                ),
              );
            },
          ),

          // ปุ่มกลับ (Wave 1.5 style)
          Positioned(
            top: MediaQuery.of(context).padding.top + JdcSpacing.sm,
            left: JdcSpacing.lg,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: jdc.shadowFloat,
              ),
              child: IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: jdc.text, size: 21),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
              ),
            ),
          ),

          // Order ID chip top right
          Positioned(
            top: MediaQuery.of(context).padding.top + JdcSpacing.sm,
            right: JdcSpacing.lg,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.circular(999),
                boxShadow: jdc.shadowFloat,
              ),
              child: Text(
                '#${OrderCodeFormatter.formatByServiceType(_booking.id, serviceType: _booking.serviceType)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: jdc.text),
              ),
            ),
          ),

          // Bottom sheet
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
    final jdc = JdcColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(JdcRadius.sheet)),
        boxShadow: jdc.shadowFloat,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: jdc.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: JdcSpacing.lg),
              _buildCurrentStatus(),
              const SizedBox(height: JdcSpacing.lg),
              _buildTimeline(),
              const SizedBox(height: JdcSpacing.lg),
              if (_booking.driverName != null) _buildDriverInfo(),
              const SizedBox(height: JdcSpacing.md),
              _buildAddressInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatus() {
    final jdc = JdcColors.of(context);
    final statusInfo = _getStatusInfo(_booking.status);
    final statusColor = statusInfo['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(JdcRadius.field),
      ),
      child: Row(
        children: [
          Icon(statusInfo['icon'] as IconData, color: jdc.onCta, size: 28),
          const SizedBox(width: JdcSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusInfo['title'] as String,
                    style: TextStyle(
                      color: jdc.onCta,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 2),
                Text(statusInfo['subtitle'] as String,
                    style: TextStyle(
                      color: jdc.onCta.withValues(alpha: 0.9),
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
    final jdc = JdcColors.of(context);
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
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive ? jdc.cta : jdc.line,
                    shape: BoxShape.circle,
                  ),
                  child: isActive
                      ? Icon(Icons.check, color: jdc.onCta, size: 14)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 30,
                    color: isActive ? jdc.cta : jdc.line,
                  ),
              ],
            ),
            const SizedBox(width: JdcSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                child: Text(step['label'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive ? jdc.text : jdc.muted,
                    )),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDriverInfo() {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.sunken,
        borderRadius: BorderRadius.circular(JdcRadius.small),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: jdc.brandSoft,
            radius: 22,
            child: Icon(Icons.person, color: jdc.brandOnSoft),
          ),
          const SizedBox(width: JdcSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _booking.driverName ??
                        AppLocalizations.of(context)!.trackDriverFallback,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: jdc.text,
                    )),
                if (_booking.driverVehicle != null)
                  Text(
                    _booking.driverVehicle!,
                    style: TextStyle(fontSize: 13, color: jdc.muted),
                  ),
              ],
            ),
          ),
          if (_booking.driverPhone != null)
            IconButton(
              icon: Icon(Icons.phone, color: jdc.cta),
              onPressed: () async {
                final uri =
                    Uri(scheme: 'tel', path: _booking.driverPhone!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .trackCallNotSupported)),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAddressInfo() {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.sunken,
        borderRadius: BorderRadius.circular(JdcRadius.small),
      ),
      child: Column(
        children: [
          _buildAddressRow(
            icon: Icons.circle,
            color: jdc.cta,
            label: AppLocalizations.of(context)!.trackPickup,
            address: _booking.pickupAddress ??
                AppLocalizations.of(context)!.trackNotSpecified,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 2, height: 20, color: jdc.line),
          ),
          _buildAddressRow(
            icon: Icons.location_on,
            color: jdc.danger,
            label: AppLocalizations.of(context)!.trackDestination,
            address: _booking.destinationAddress ??
                AppLocalizations.of(context)!.trackNotSpecified,
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
    final jdc = JdcColors.of(context);
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: JdcSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: jdc.muted)),
              Text(
                address,
                style: TextStyle(fontSize: 14, color: jdc.text),
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
    final jdc = JdcColors.of(context);
    switch (status) {
      case 'pending':
        return {
          'icon': Icons.hourglass_empty,
          'color': jdc.brand,
          'title': AppLocalizations.of(context)!.trackStatusPendingTitle,
          'subtitle': AppLocalizations.of(context)!.trackStatusPendingSub
        };
      case 'accepted':
      case 'assigned':
        return {
          'icon': Icons.delivery_dining,
          'color': jdc.infoInk,
          'title': AppLocalizations.of(context)!.trackStatusAcceptedTitle,
          'subtitle': AppLocalizations.of(context)!.trackStatusAcceptedSub
        };
      case 'picking_up':
      case 'arrived':
      case 'arrived_at_pickup':
        return {
          'icon': Icons.store,
          'color': jdc.infoInk,
          'title':
              AppLocalizations.of(context)!.trackStatusPickingUpTitle,
          'subtitle':
              AppLocalizations.of(context)!.trackStatusPickingUpSub
        };
      case 'preparing':
        return {
          'icon': Icons.restaurant,
          'color': jdc.brand,
          'title':
              AppLocalizations.of(context)!.trackStatusPreparingTitle,
          'subtitle':
              AppLocalizations.of(context)!.trackStatusPreparingSub
        };
      case 'in_transit':
      case 'delivering':
        return {
          'icon': Icons.local_shipping,
          'color': jdc.cta,
          'title': AppLocalizations.of(context)!.trackStatusInTransitTitle,
          'subtitle': AppLocalizations.of(context)!.trackStatusInTransitSub
        };
      case 'arrived_at_dropoff':
        return {
          'icon': Icons.pin_drop,
          'color': jdc.cta,
          'title': AppLocalizations.of(context)!.trackStatusArrivedTitle,
          'subtitle': AppLocalizations.of(context)!.trackStatusArrivedSub
        };
      case 'completed':
        return {
          'icon': Icons.check_circle,
          'color': jdc.successInk,
          'title':
              AppLocalizations.of(context)!.trackStatusCompletedTitle,
          'subtitle':
              AppLocalizations.of(context)!.trackStatusCompletedSub
        };
      case 'cancelled':
        return {
          'icon': Icons.cancel,
          'color': jdc.danger,
          'title':
              AppLocalizations.of(context)!.trackStatusCancelledTitle,
          'subtitle':
              AppLocalizations.of(context)!.trackStatusCancelledSub
        };
      default:
        return {
          'icon': Icons.info,
          'color': jdc.dim,
          'title': AppLocalizations.of(context)!.trackStatusUnknownTitle,
          'subtitle': status,
        };
    }
  }

  List<Map<String, dynamic>> _getTimelineSteps() {
    final statusOrder = [
      'pending',
      'accepted',
      'picking_up',
      'in_transit',
      'completed'
    ];
    final l10n = AppLocalizations.of(context)!;
    final labels = {
      'pending': l10n.trackTimelineCreated,
      'accepted': l10n.trackTimelineAccepted,
      'picking_up': l10n.trackTimelinePickingUp,
      'in_transit': l10n.trackTimelineInTransit,
      'completed': l10n.trackTimelineCompleted,
    };

    int currentIndex = statusOrder.indexOf(_booking.status);
    if (currentIndex == -1) {
      switch (_booking.status) {
        case 'assigned':
        case 'matched':
          currentIndex = 1;
        case 'preparing':
          currentIndex = 1;
        case 'arrived':
        case 'arrived_at_pickup':
        case 'picking_up_order':
        case 'arrived_at_merchant':
          currentIndex = 2;
        case 'delivering':
        case 'arrived_at_dropoff':
          currentIndex = 3;
        case 'cancelled':
          currentIndex = -1;
        case 'pending_merchant':
          currentIndex = 0;
        default:
          currentIndex = 0;
      }
    }

    return List.generate(
        statusOrder.length,
        (i) => {
              'label': labels[statusOrder[i]]!,
              'active': i <= currentIndex,
            });
  }
}
