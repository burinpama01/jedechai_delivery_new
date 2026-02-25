import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../theme/app_theme.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/fare_adjustment_service.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/notification_sender.dart';
import '../../../../common/config/env_config.dart';
import '../../../../common/widgets/location_disclosure_dialog.dart';
import '../services/waiting_for_driver_screen.dart';
import '../services/saved_addresses_screen.dart';
import '../../../../common/models/saved_address.dart';

/// Ride Home Screen
///
/// Main screen for ride service with Google Maps integration
/// UI inspired by Grab/Bolt style
class RideHomeScreen extends StatefulWidget {
  const RideHomeScreen({super.key});

  @override
  State<RideHomeScreen> createState() => _RideHomeScreenState();
}

class _RideHomeScreenState extends State<RideHomeScreen> {
  GoogleMapController? _mapController;
  final PolylinePoints _polylinePoints = PolylinePoints();
  List<LatLng> polylineCoordinates = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  Position? _currentLocation;
  LatLng? _selectedDestination;
  bool _isLoading = false;
  String _selectedAddress = '';
  double _estimatedPrice = 0.0;
  double _estimatedDistance = 0.0;
  int _selectedVehicleIndex = -1;
  String _paymentMethod = 'cash';

  final TextEditingController _destinationController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Online driver counts per vehicle type
  Map<String, int> _onlineDriverCounts = {'มอเตอร์ไซค์': 0, 'รถยนต์': 0};
  double _driverSearchRadiusKm = 30.0;
  RideFarPickupConfig _rideFarPickupConfig = const RideFarPickupConfig(
    thresholdKm: 3,
    motorcycleRatePerKm: 5,
    carRatePerKm: 7,
  );
  double _estimatedDriverToPickupKm = 0.0;
  double _estimatedPickupSurcharge = 0.0;

  // Vehicle types with rate keys for service_rates table
  final List<Map<String, dynamic>> _vehicleTypes = [
    {
      'name': 'มอเตอร์ไซค์',
      'icon': Icons.two_wheeler,
      'rateKey': 'ride_motorcycle',
      'desc': 'เร็ว ประหยัด'
    },
    {
      'name': 'รถยนต์',
      'icon': Icons.directions_car,
      'rateKey': 'ride_car',
      'desc': 'สะดวกสบาย'
    },
  ];

  // Ride rates loaded from DB (keyed by service_type)
  Map<String, Map<String, num>> _rideRates = {};

  // Constants
  static String get _googleApiKey => EnvConfig.googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDriverSearchRadius();
    _checkOnlineDrivers();
    _loadRideRates();
    _loadRideFarPickupConfig();
  }

  Future<void> _loadRideFarPickupConfig() async {
    try {
      final config = await FareAdjustmentService.loadRideFarPickupConfig();
      if (!mounted) return;
      setState(() {
        _rideFarPickupConfig = config;
      });

      if (_estimatedDistance > 0 && _selectedVehicleIndex >= 0) {
        await _recalculateEstimatedFareWithNearestDriver();
      }
    } catch (e) {
      debugLog('⚠️ Could not load ride far pickup config: $e');
    }
  }

  Future<void> _loadDriverSearchRadius() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      _driverSearchRadiusKm = configService.customerToDriverRadiusKm;
      debugLog(
          '📡 Driver search radius = ${_driverSearchRadiusKm.toStringAsFixed(1)} km');
    } catch (e) {
      _driverSearchRadiusKm = 30.0;
      debugLog('⚠️ ใช้รัศมีค้นหาคนขับเริ่มต้น 30 กม.: $e');
    }
    if (mounted) {
      await _checkOnlineDrivers();
    }
  }

  bool _isWithinDriverSearchRadius(
      double driverLat, double driverLng, double originLat, double originLng) {
    final km =
        Geolocator.distanceBetween(originLat, originLng, driverLat, driverLng) /
            1000;
    return km <= _driverSearchRadiusKm;
  }

  Future<void> _loadRideRates() async {
    try {
      final response = await SupabaseService.client
          .from('service_rates')
          .select('service_type, base_price, base_distance, price_per_km')
          .like('service_type', 'ride%');
      for (final r in response) {
        _rideRates[r['service_type'] as String] = {
          'base_price': r['base_price'] as num,
          'base_distance': r['base_distance'] as num,
          'price_per_km': r['price_per_km'] as num,
        };
      }
      debugLog('📊 Loaded ride rates: ${_rideRates.keys.join(', ')}');
      // Recalculate price if distance already known
      if (_estimatedDistance > 0 && _selectedVehicleIndex >= 0) {
        await _recalculateEstimatedFareWithNearestDriver();
      }
    } catch (e) {
      debugLog('⚠️ Could not load ride rates: $e');
    }
  }

  Future<void> _recalculateEstimatedFareWithNearestDriver() async {
    if (_selectedVehicleIndex < 0 || _currentLocation == null) return;

    final basePrice = _calculatePrice(_estimatedDistance);
    final vehicleName = _vehicleTypes[_selectedVehicleIndex]['name'] as String;

    try {
      final nearestDriverDistanceKm =
          await FareAdjustmentService.findNearestOnlineDriverDistanceKm(
        pickupLat: _currentLocation!.latitude,
        pickupLng: _currentLocation!.longitude,
        vehicleType: vehicleName,
      );

      final surcharge = nearestDriverDistanceKm == null
          ? 0.0
          : FareAdjustmentService.calculateRideFarPickupSurcharge(
              driverToPickupDistanceKm: nearestDriverDistanceKm,
              vehicleType: vehicleName,
              config: _rideFarPickupConfig,
            );

      if (!mounted) return;
      setState(() {
        _estimatedDriverToPickupKm = nearestDriverDistanceKm ?? 0.0;
        _estimatedPickupSurcharge = surcharge;
        _estimatedPrice = basePrice + surcharge;
      });
    } catch (e) {
      debugLog('⚠️ Could not estimate nearest driver surcharge: $e');
      if (!mounted) return;
      setState(() {
        _estimatedDriverToPickupKm = 0.0;
        _estimatedPickupSurcharge = 0.0;
        _estimatedPrice = basePrice;
      });
    }
  }

  // Map English vehicle_type values to Thai display names
  String _normalizeVehicleType(String? vt) {
    if (vt == null || vt.isEmpty) return '';
    final lower = vt.toLowerCase();
    if (lower == 'motorcycle' || vt == 'มอเตอร์ไซค์') return 'มอเตอร์ไซค์';
    if (lower == 'car' || vt == 'รถยนต์') return 'รถยนต์';
    if (vt.contains('มอเตอร์') ||
        lower.contains('moto') ||
        lower.contains('bike')) return 'มอเตอร์ไซค์';
    if (vt.contains('รถยนต์') ||
        lower.contains('car') ||
        lower.contains('sedan')) return 'รถยนต์';
    return vt;
  }

  Future<void> _checkOnlineDrivers() async {
    final counts = <String, int>{'มอเตอร์ไซค์': 0, 'รถยนต์': 0};

    try {
      // Step 1: Get online driver IDs from driver_locations (within radius)
      final locResponse = await SupabaseService.client
          .from('driver_locations')
          .select('driver_id, location_lat, location_lng, is_available')
          .eq('is_online', true)
          .eq('is_available', true);

      final nearbyOnlineDriverIds = <String>[];
      for (final row in (locResponse as List)) {
        final driverId = row['driver_id'] as String?;
        if (driverId == null || driverId.isEmpty) continue;

        final lat = (row['location_lat'] as num?)?.toDouble();
        final lng = (row['location_lng'] as num?)?.toDouble();
        if (_currentLocation != null && lat != null && lng != null) {
          if (_isWithinDriverSearchRadius(lat, lng, _currentLocation!.latitude,
              _currentLocation!.longitude)) {
            nearbyOnlineDriverIds.add(driverId);
          }
        } else if (_currentLocation == null) {
          nearbyOnlineDriverIds.add(driverId);
        }
      }

      if (nearbyOnlineDriverIds.isNotEmpty) {
        // Step 2: Get vehicle types for nearby online drivers from profiles
        final profileResponse = await SupabaseService.client
            .from('profiles')
            .select('vehicle_type')
            .inFilter('id', nearbyOnlineDriverIds);

        for (final row in profileResponse) {
          final vt = _normalizeVehicleType(row['vehicle_type'] as String?);
          if (counts.containsKey(vt)) {
            counts[vt] = (counts[vt] ?? 0) + 1;
          }
        }
      }

      // Fallback: if no driver_locations rows, check online drivers directly
      if (counts.values.every((v) => v == 0)) {
        final fallback = await SupabaseService.client
            .from('profiles')
            .select('vehicle_type')
            .eq('role', 'driver')
            .eq('approval_status', 'approved')
            .eq('is_online', true);
        for (final row in fallback) {
          final vt = _normalizeVehicleType(row['vehicle_type'] as String?);
          if (counts.containsKey(vt)) {
            counts[vt] = (counts[vt] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugLog('❌ Error checking online drivers: $e');
      // Fallback: show online approved drivers so button isn't permanently disabled
      try {
        final fallback = await SupabaseService.client
            .from('profiles')
            .select('vehicle_type')
            .eq('role', 'driver')
            .eq('approval_status', 'approved')
            .eq('is_online', true);
        for (final row in fallback) {
          final vt = _normalizeVehicleType(row['vehicle_type'] as String?);
          if (counts.containsKey(vt)) {
            counts[vt] = (counts[vt] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _onlineDriverCounts = counts);
    debugLog('🚗 Online drivers: $counts');
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Please enable location services', Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) return;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Location permissions are denied', Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Location permissions are permanently denied', Colors.red);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = position;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }

      _addCurrentLocationMarker();
      _checkOnlineDrivers();
    } catch (e) {
      _showMessage('Error getting location: $e', Colors.red);
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentLocation == null) return;

    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position:
              LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  void _addDestinationMarker(LatLng destination) {
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: InfoWindow(
              title:
                  _selectedAddress.isEmpty ? 'Destination' : _selectedAddress),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  Future<void> _getPolyline() async {
    if (_currentLocation == null || _selectedDestination == null) return;

    try {
      // Use Google Directions API for real routing
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_currentLocation!.latitude},${_currentLocation!.longitude}'
        '&destination=${_selectedDestination!.latitude},${_selectedDestination!.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final routes = data['routes'] as List;
        final route = routes[0] as Map<String, dynamic>;
        final legs = route['legs'] as List?;

        if (legs == null || legs.isEmpty) {
          throw Exception('No legs found in route');
        }

        final leg = legs[0] as Map<String, dynamic>;
        final distanceValue = leg['distance']?['value'] as int?;
        final durationValue = leg['duration']?['value'] as int?;

        if (distanceValue == null || durationValue == null) {
          throw Exception('Missing distance or duration in route data');
        }

        // Get real distance from API
        final realDistance = distanceValue / 1000; // Convert meters to km
        // final realDuration = durationValue / 60; // Convert seconds to minutes (unused)

        // Decode polyline
        final encodedPolyline = route['overview_polyline']['points'];
        final points = _polylinePoints.decodePolyline(encodedPolyline);

        setState(() {
          polylineCoordinates.clear();
          for (var point in points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }

          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              color: AppTheme.primaryGreen,
              width: 5,
              points: polylineCoordinates,
            ),
          );

          // Use real distance for price calculation
          _estimatedDistance = realDistance;
        });
        await _recalculateEstimatedFareWithNearestDriver();
      } else {
        // Fallback to straight line if API fails
        _getStraightLineRoute();
      }
    } catch (e) {
      debugLog('Error getting directions: $e');
      // Fallback to straight line
      _getStraightLineRoute();
    }
  }

  void _getStraightLineRoute() {
    if (_currentLocation == null || _selectedDestination == null) return;

    setState(() {
      polylineCoordinates.clear();

      // Add direct line from current location to destination
      polylineCoordinates
          .add(LatLng(_currentLocation!.latitude, _currentLocation!.longitude));
      polylineCoordinates.add(LatLng(
          _selectedDestination!.latitude, _selectedDestination!.longitude));

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: AppTheme.primaryGreen,
          width: 5,
          points: polylineCoordinates,
        ),
      );

      // Calculate straight-line distance as fallback
      _estimatedDistance = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _selectedDestination!.latitude,
        _selectedDestination!.longitude,
      );
    });
    _recalculateEstimatedFareWithNearestDriver();
  }

  double _calculateDistance(
      double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) /
        1000; // Convert to km
  }

  double _calculatePrice(double distanceInKm) {
    // Use per-vehicle-type rates from DB if available
    if (_selectedVehicleIndex >= 0) {
      final rateKey = _vehicleTypes[_selectedVehicleIndex]['rateKey'] as String;
      final rate = _rideRates[rateKey];
      if (rate != null) {
        final basePrice = rate['base_price']!.toDouble();
        final baseDist = rate['base_distance']!.toDouble();
        final perKm = rate['price_per_km']!.toDouble();
        if (distanceInKm <= baseDist) return basePrice;
        return basePrice + ((distanceInKm - baseDist) * perKm);
      }
    }
    // Fallback hardcoded rates
    const double baseFare = 25.0;
    const double perKmCharge = 8.0;
    return baseFare + (distanceInKm * perKmCharge);
  }

  void _showPaymentMethodSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('เลือกวิธีชำระเงิน',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildPaymentOption(
                    ctx, 'cash', 'เงินสด', Icons.payments_outlined),
                const SizedBox(height: 8),
                _buildPaymentOption(
                    ctx, 'transfer', 'โอนเงิน', Icons.account_balance),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOption(
      BuildContext ctx, String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() => _paymentMethod = value);
        Navigator.of(ctx).pop();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey[600]),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryGreen : colorScheme.onSurface,
                )),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppTheme.primaryGreen, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _callDriver() async {
    if (_currentLocation == null || _selectedDestination == null) {
      _showMessage('กรุณาเลือกจุดหมายปลายทาง', Colors.orange);
      return;
    }
    if (_selectedVehicleIndex < 0) {
      _showMessage('กรุณาเลือกประเภทรถก่อนเรียก', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        _showMessage('กรุณาเข้าสู่ระบบ', Colors.red);
        return;
      }

      final vehicleName = _vehicleTypes[_selectedVehicleIndex]['name'];
      debugLog('🚗 Creating booking...');
      debugLog(
          '   └─ Origin: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');
      debugLog(
          '   └─ Destination: ${_selectedDestination!.latitude}, ${_selectedDestination!.longitude}');
      debugLog('   └─ Distance: $_estimatedDistance km');
      debugLog('   └─ Price: ฿$_estimatedPrice');
      debugLog('   └─ Driver→Pickup: ${_estimatedDriverToPickupKm.toStringAsFixed(2)} km');
      debugLog('   └─ Pickup surcharge: ฿${_estimatedPickupSurcharge.toStringAsFixed(2)}');
      debugLog('   └─ Vehicle: $vehicleName');

      final noteLines = <String>['ประเภทรถ: $vehicleName'];
      if (_estimatedPickupSurcharge > 0) {
        noteLines.add(
          'เพิ่มระยะคนขับ→จุดรับ ${_estimatedDriverToPickupKm.toStringAsFixed(2)} กม. (+฿${_estimatedPickupSurcharge.toStringAsFixed(2)})',
        );
      }

      final response = await SupabaseService.client
          .from('bookings')
          .insert({
            'customer_id': currentUser.id,
            'service_type': 'ride',
            'vehicle_type': vehicleName,
            'origin_lat': _currentLocation!.latitude,
            'origin_lng': _currentLocation!.longitude,
            'pickup_address': 'ตำแหน่งปัจจุบัน',
            'dest_lat': _selectedDestination!.latitude,
            'dest_lng': _selectedDestination!.longitude,
            'destination_address': _selectedAddress,
            'distance_km': _estimatedDistance,
            'price': _estimatedPrice,
            'status': 'pending',
            'payment_method': _paymentMethod,
            'notes': noteLines.join(' | '),
          })
          .select()
          .single();

      debugLog('✅ Booking created successfully: ${response['id']}');

      final booking = Booking.fromJson(response);

      _showMessage('กำลังค้นหาคนขับ...', AppTheme.primaryGreen);

      // Send notification to matching vehicle type drivers only
      await _notifyDriversAboutNewRide(booking, vehicleName);

      // Navigate to waiting screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => WaitingForDriverScreen(booking: booking),
        ),
      );
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Send notification to drivers with matching vehicle type
  Future<void> _notifyDriversAboutNewRide(
      Booking booking, String vehicleType) async {
    try {
      debugLog(
          '📢 Notifying $vehicleType drivers about new ride: ${booking.id}');

      final nearbyLocations = await SupabaseService.client
          .from('driver_locations')
          .select('driver_id, location_lat, location_lng')
          .eq('is_online', true)
          .eq('is_available', true);

      final nearbyDriverIds = <String>[];
      for (final row in nearbyLocations) {
        final driverId = row['driver_id'] as String?;
        final lat = (row['location_lat'] as num?)?.toDouble();
        final lng = (row['location_lng'] as num?)?.toDouble();
        if (driverId == null || lat == null || lng == null) continue;

        if (_isWithinDriverSearchRadius(
            lat, lng, booking.originLat, booking.originLng)) {
          nearbyDriverIds.add(driverId);
        }
      }

      if (nearbyDriverIds.isEmpty) {
        debugLog(
            '⚠️ No nearby online drivers within ${_driverSearchRadiusKm.toStringAsFixed(0)} km');
        return;
      }

      // Get nearby online drivers with matching vehicle type
      final driversResponse = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, fcm_token, vehicle_type')
          .inFilter('id', nearbyDriverIds)
          .not('fcm_token', 'is', null);

      // Filter by vehicle type (normalize both sides)
      final matchingDrivers = driversResponse.where((d) {
        final driverVt = _normalizeVehicleType(d['vehicle_type'] as String?);
        return driverVt == vehicleType;
      }).toList();

      debugLog(
          '👤 Found ${driversResponse.length} online drivers, ${matchingDrivers.length} match $vehicleType');

      if (matchingDrivers.isEmpty) {
        debugLog('⚠️ No matching $vehicleType drivers found');
        return;
      }

      // Send notification to each matching driver
      int successCount = 0;
      for (final driver in matchingDrivers) {
        final driverId = driver['id'] as String;
        final driverToken = driver['fcm_token'] as String?;

        if (driverToken != null && driverToken.isNotEmpty) {
          final success = await NotificationSender.sendNotification(
            targetUserId: driverId,
            title: '🚗 งานใหม่! รับส่งผู้โดยสาร',
            body:
                'มีคนเรียกรถจาก ${booking.pickupAddress ?? 'จุดเริ่มต้น'} ไป ${booking.destinationAddress ?? 'จุดหมาย'} - ราคา ฿${booking.price}',
            data: {
              'type': 'new_ride_request',
              'booking_id': booking.id,
              'customer_id': booking.customerId,
              'pickup_address': booking.pickupAddress ?? '',
              'destination_address': booking.destinationAddress ?? '',
              'price': booking.price.toString(),
              'distance_km': booking.distanceKm.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );

          if (success) {
            successCount++;
            debugLog('✅ Notified driver: ${driver['full_name'] ?? 'Unknown'}');
          } else {
            debugLog(
                '❌ Failed to notify driver: ${driver['full_name'] ?? 'Unknown'}');
          }
        } else {
          debugLog(
              '⚠️ Driver ${driver['full_name'] ?? 'Unknown'} has no FCM token');
        }
      }

      debugLog(
          '📊 Ride notification summary: $successCount/${driversResponse.length} drivers notified');
    } catch (e) {
      debugLog('❌ Error notifying drivers: $e');
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _getCurrentLocation();
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedDestination = location;
      _selectedAddress =
          'Selected Location (${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)})';
      _destinationController.text = _selectedAddress;
    });

    _addDestinationMarker(location);
    _getPolyline();
  }

  Future<void> _pickSavedAddress() async {
    final result = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(pickMode: true),
      ),
    );
    if (result != null) {
      final location = LatLng(result.latitude, result.longitude);
      setState(() {
        _selectedDestination = location;
        _selectedAddress = '${result.name} — ${result.address}';
        _destinationController.text = _selectedAddress;
      });
      _addDestinationMarker(location);
      _getPolyline();
    }
  }

  void _onVehicleChanged(int index) {
    setState(() {
      _selectedVehicleIndex = index;
    });
    if (_estimatedDistance > 0) {
      _recalculateEstimatedFareWithNearestDriver();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // Google Map — full screen
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation != null
                  ? LatLng(
                      _currentLocation!.latitude, _currentLocation!.longitude)
                  : const LatLng(13.7563, 100.5018),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onTap: _onMapTap,
            padding: const EdgeInsets.only(bottom: 280),
          ),

          // Top bar — back + title
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _buildCircleButton(
                    Icons.arrow_back, () => Navigator.of(context).pop()),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.local_taxi,
                            color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 8),
                        Text('เรียกรถ',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildCircleButton(Icons.my_location, _getCurrentLocation),
              ],
            ),
          ),

          // Search card
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  // Pickup
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _currentLocation != null
                              ? 'ตำแหน่งปัจจุบัน'
                              : 'กำลังหาตำแหน่ง...',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                        width: 2, height: 20, color: Colors.grey[300]),
                  ),
                  // Destination
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          decoration: InputDecoration(
                            hintText: 'ไปไหน? แตะแผนที่เพื่อเลือก',
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            suffixIcon: _selectedAddress.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _destinationController.clear();
                                      setState(() {
                                        _selectedDestination = null;
                                        _selectedAddress = '';
                                        _estimatedPrice = 0.0;
                                        _estimatedDistance = 0.0;
                                        _polylines.clear();
                                        _markers.removeWhere((m) =>
                                            m.markerId.value == 'destination');
                                      });
                                    },
                                    child: Icon(Icons.close,
                                        size: 18, color: Colors.grey[400]),
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(
                                maxHeight: 20, maxWidth: 20),
                          ),
                          style: const TextStyle(fontSize: 14),
                          readOnly: true,
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickSavedAddress,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bookmark_outline,
                              size: 20, color: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom panel — vehicle selection + book button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, -4)),
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),

                      // Vehicle type selector
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _vehicleTypes.length,
                          itemBuilder: (context, index) {
                            final v = _vehicleTypes[index];
                            final isSelected = _selectedVehicleIndex == index;
                            final vehicleName = v['name'] as String;
                            final onlineCount =
                                _onlineDriverCounts[vehicleName] ?? 0;
                            final isAvailable = onlineCount > 0;
                            return GestureDetector(
                              onTap: isAvailable
                                  ? () => _onVehicleChanged(index)
                                  : () {
                                      _showMessage(
                                          'ไม่มี$vehicleNameออนไลน์ในขณะนี้',
                                          Colors.orange);
                                    },
                              child: Opacity(
                                opacity: isAvailable ? 1.0 : 0.45,
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: !isAvailable
                                        ? Colors.grey[100]
                                        : isSelected
                                            ? AppTheme.primaryGreen
                                                .withValues(alpha: 0.1)
                                            : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: !isAvailable
                                          ? Colors.grey[300]!
                                          : isSelected
                                              ? AppTheme.primaryGreen
                                              : Colors.grey[200]!,
                                      width: isSelected && isAvailable ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(v['icon'] as IconData,
                                          size: 24,
                                          color: !isAvailable
                                              ? Colors.grey[400]
                                              : isSelected
                                                  ? AppTheme.primaryGreen
                                                  : Colors.grey[500]),
                                      const SizedBox(height: 4),
                                      Text(vehicleName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                isSelected && isAvailable
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color: !isAvailable
                                                ? Colors.grey[400]
                                                : isSelected
                                                    ? AppTheme.primaryGreen
                                                    : Colors.grey[600],
                                          )),
                                      const SizedBox(height: 2),
                                      Text(
                                        onlineCount > 0
                                            ? 'ออนไลน์ $onlineCount คน'
                                            : 'ไม่มีคนขับ',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: onlineCount > 0
                                              ? Colors.green
                                              : Colors.red[300],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Distance + Price
                      if (_estimatedDistance > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.route,
                                  size: 18, color: Colors.grey[500]),
                              const SizedBox(width: 8),
                              Text(
                                  '${_estimatedDistance.toStringAsFixed(1)} กม.',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant)),
                              const Spacer(),
                              Text('฿${_estimatedPrice.ceil()}',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGreen)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Payment method
                      GestureDetector(
                        onTap: _showPaymentMethodSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _paymentMethod == 'cash'
                                    ? Icons.payments_outlined
                                    : Icons.account_balance,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _paymentMethod == 'cash' ? 'เงินสด' : 'โอนเงิน',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                              const Spacer(),
                              Icon(Icons.chevron_right,
                                  size: 20, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Book button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isLoading ||
                                  _selectedDestination == null ||
                                  _selectedVehicleIndex < 0)
                              ? null
                              : _callDriver,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : Text(
                                  _selectedDestination == null
                                      ? 'เลือกจุดหมายปลายทาง'
                                      : _selectedVehicleIndex < 0
                                          ? 'กรุณาเลือกประเภทรถ'
                                          : 'เรียกรถ — ฿${_estimatedPrice.ceil()}',
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 22, color: colorScheme.onSurface),
      ),
    );
  }
}
