import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/config/env_config.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/chat_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/widgets/location_disclosure_dialog.dart';
import '../../../../common/widgets/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../customer_main_screen.dart';

/// Customer Ride Status Screen
/// 
/// Shows real-time ride status and driver location
class CustomerRideStatusScreen extends StatefulWidget {
  final Booking booking;

  const CustomerRideStatusScreen({
    super.key,
    required this.booking,
  });

  @override
  State<CustomerRideStatusScreen> createState() => _CustomerRideStatusScreenState();
}

class _CustomerRideStatusScreenState extends State<CustomerRideStatusScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final PolylinePoints _polylinePoints = PolylinePoints();
  Position? _currentPosition;
  // ignore: unused_field
  bool _isLoadingLocation = true;
  bool _hasLocationPermission = false;
  final BookingService _bookingService = BookingService();
  
  // Real-time booking state
  Booking? _currentBooking;
  // ignore: unused_field
  bool _isLoadingBooking = false;
  StreamSubscription? _bookingSubscription;
  StreamSubscription? _driverLocationSubscription;
  bool _hasShownCompletionDialog = false;
  bool _customerInitiatedCancel = false;
  Timer? _autoRefreshTimer;
  Position? _driverPosition;
  Map<String, dynamic>? _driverProfile;
  Map<String, dynamic>? _couponUsage;
  
  static String get _googleApiKey => EnvConfig.googleMapsApiKey;
  
  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    _loadCouponUsage(widget.booking.id);
    _checkLocationPermission();
    _setupRealtimeUpdates();
    _startAutoRefresh();
  }

  Future<void> _loadCouponUsage(String bookingId) async {
    try {
      final usage = await SupabaseService.client
          .from('coupon_usages')
          .select('discount_amount, coupon_id')
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (usage == null) {
        if (mounted) {
          setState(() {
            _couponUsage = null;
          });
        }
        return;
      }

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
          _couponUsage = {
            'discount_amount': usage['discount_amount'],
            'coupon_code': couponCode,
          };
        });
      }
    } catch (e) {
      debugLog('❌ Error loading coupon usage in customer ride status: $e');
    }
  }

  double _couponDiscountAmount() {
    return (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
  }

  String? _couponCode() {
    return _couponUsage?['coupon_code'] as String?;
  }

  double _calculateTotalAmount(Booking booking) {
    final couponDiscount = _couponDiscountAmount();
    final gross = booking.serviceType == 'food'
        ? booking.price + (booking.deliveryFee ?? 0.0)
        : booking.price;
    final total = gross - couponDiscount;
    return total < 0 ? 0 : total;
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      await _refreshStatus();
    });
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBooking() async {
    try {
      final response = await SupabaseService.client
          .from('bookings')
          .select()
          .eq('id', widget.booking.id)
          .single();

      final refreshed = Booking.fromJson(response);
      if (!mounted) return;
      setState(() {
        _currentBooking = refreshed;
      });
      await _loadCouponUsage(refreshed.id);
      _initializeMap();
      _drawRoute();
    } catch (e) {
      debugLog('❌ Auto refresh booking error: $e');
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final response = await SupabaseService.client
          .from('bookings')
          .select('status')
          .eq('id', widget.booking.id)
          .single();

      final refreshedStatus = response['status'] as String?;
      final currentStatus = _currentBooking?.status;

      if (refreshedStatus != null && refreshedStatus != currentStatus) {
        await _refreshBooking();

        if (refreshedStatus == 'completed') {
          _showCompletionDialog();
        }
        
        if (refreshedStatus == 'cancelled' && !_customerInitiatedCancel) {
          _showCancelledByMerchantDialog();
        }
      }
    } catch (e) {
      debugLog('❌ Auto refresh status error: $e');
    }
  }

  void _setupRealtimeUpdates() {
    debugLog('🔄 Setting up real-time updates for booking: ${widget.booking.id}');
    
    // Listen for booking status updates
    _bookingSubscription = SupabaseService.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.booking.id)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final updatedBooking = Booking.fromJson(data.first);
            debugLog('📡 Real-time update received: ${updatedBooking.status}');

            if (mounted) {
              setState(() {
                _currentBooking = updatedBooking;
              });

              _loadCouponUsage(updatedBooking.id);

              // Handle completed status
              if (updatedBooking.status == 'completed') {
                _showCompletionDialog();
              }
              
              // Handle cancelled status (merchant rejected, not customer-initiated)
              if (updatedBooking.status == 'cancelled' && !_customerInitiatedCancel) {
                _showCancelledByMerchantDialog();
              }
              
              // Setup driver location tracking when driver is assigned
              if (updatedBooking.driverId != null && _driverLocationSubscription == null) {
                _setupDriverLocationTracking(updatedBooking.driverId!);
                _fetchDriverProfile(updatedBooking.driverId!);
              }
            }
          }
        }, onError: (error) {
          debugLog('❌ Real-time update error: $error');
        });
    
    // Setup driver location tracking if driver is already assigned
    if (widget.booking.driverId != null) {
      _setupDriverLocationTracking(widget.booking.driverId!);
      _fetchDriverProfile(widget.booking.driverId!);
    }
  }

  void _setupDriverLocationTracking(String driverId) {
    debugLog('📍 Setting up driver location tracking for driver: $driverId');
    
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = SupabaseService.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty && mounted) {
            final profile = data.first;
            final lat = profile['latitude'] as double?;
            final lng = profile['longitude'] as double?;
            
            if (lat != null && lng != null) {
              debugLog('📡 Driver location update: $lat, $lng');
              
              setState(() {
                _driverPosition = Position(
                  latitude: lat,
                  longitude: lng,
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                );
              });
              
              _updateDriverMarker();
            }
          }
        }, onError: (error) {
          debugLog('❌ Driver location tracking error: $error');
        });
  }

  void _updateDriverMarker() {
    if (_driverPosition == null) return;
    
    setState(() {
      // Remove old driver marker if exists
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');
      
      // Add updated driver marker
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(_driverPosition!.latitude, _driverPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'คนขับ'),
        ),
      );
    });
    
    debugLog('✅ Driver marker updated on map');
    
    // Redraw route from driver position
    _drawRoute();
  }

  Future<void> _fetchDriverProfile(String driverId) async {
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('id, full_name, phone_number, avatar_url, vehicle_type, license_plate')
          .eq('id', driverId)
          .single();
      if (mounted) {
        setState(() {
          _driverProfile = response;
        });
        debugLog('✅ Driver profile fetched: ${response['full_name']}');
      }
    } catch (e) {
      debugLog('❌ Error fetching driver profile: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ไม่สามารถโทรไปที่ $phoneNumber ได้')),
        );
      }
    }
  }

  Future<void> _openChat() async {
    try {
      final booking = _currentBooking ?? widget.booking;
      final customerId = AuthService.userId;
      if (customerId == null || booking.driverId == null) return;
      final chatService = ChatService();
      final room = await chatService.getOrCreateBookingChatRoom(
        bookingId: booking.id,
        customerId: customerId,
        driverId: booking.driverId,
      );
      if (room != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: booking.id,
              chatRoomId: room.id,
              otherPartyName: _driverProfile?['full_name'] ?? 'คนขับ',
              roomType: 'booking',
            ),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดแชทได้')),
        );
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('กรุณาเปิดใช้งาน Location Service'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoadingLocation = false;
          _hasLocationPermission = false;
        });
        _initializeMap();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) {
            setState(() { _isLoadingLocation = false; _hasLocationPermission = false; });
            _initializeMap();
            return;
          }
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('กรุณาอนุญาตให้เข้าถึงตำแหน่ง'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() {
            _isLoadingLocation = false;
            _hasLocationPermission = false;
          });
          _initializeMap();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.location_off, color: Colors.red, size: 48),
              title: const Text('ไม่สามารถเข้าถึงตำแหน่ง'),
              content: const Text('กรุณาเปิดการเข้าถึงตำแหน่งในการตั้งค่าของเครื่อง'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ตกลง'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Geolocator.openAppSettings();
                  },
                  child: const Text('เปิดการตั้งค่า'),
                ),
              ],
            ),
          );
        }
        setState(() {
          _isLoadingLocation = false;
          _hasLocationPermission = false;
        });
        _initializeMap();
        return;
      }

      setState(() {
        _hasLocationPermission = true;
      });
      
      await _getCurrentLocation();
    } catch (e) {
      debugLog('❌ Error checking location permission: $e');
      setState(() {
        _isLoadingLocation = false;
        _hasLocationPermission = false;
      });
      _initializeMap();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        _initializeMap();
      }
    } catch (e) {
      debugLog('❌ Error getting current location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        _initializeMap();
      }
    }
  }

  void _initializeMap() {
    final booking = _currentBooking ?? widget.booking;
    final hasDriver = booking.driverId != null;

    setState(() {
      _markers.clear();
      // Don't clear polylines here - let _drawRoute handle it
    });

    // Add origin marker (merchant/pickup location)
    _markers.add(
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(booking.originLat, booking.originLng),
        infoWindow: InfoWindow(
          title: booking.serviceType == 'food'
              ? 'ร้านค้า: ${booking.pickupAddress ?? 'ร้านอาหาร'}'
              : 'จุดรับ: ${booking.pickupAddress ?? 'จุดรับ'}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // Add driver marker if driver position is available (priority over current location)
    if (_driverPosition != null && hasDriver) {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(_driverPosition!.latitude, _driverPosition!.longitude),
          infoWindow: const InfoWindow(title: 'คนขับ'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    } else if (_currentPosition != null) {
      // Show customer's own position if no driver yet
      _markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    // Add destination marker
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(booking.destLat, booking.destLng),
        infoWindow: InfoWindow(
          title: 'จุดหมาย: ${booking.destinationAddress ?? 'ปลายทาง'}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // Draw route
    _drawRoute();
    
    // Zoom to fit all markers
    if (_markers.isNotEmpty && _mapController != null) {
      _zoomToFitMarkers();
    }
  }

  Future<void> _drawRoute() async {
    LatLng origin;
    LatLng destination;

    final booking = _currentBooking ?? widget.booking;

    // Determine origin based on status and available positions
    if (_driverPosition != null && booking.driverId != null) {
      // Driver is assigned and we have their position - show route from driver
      origin = LatLng(_driverPosition!.latitude, _driverPosition!.longitude);
    } else if (_currentPosition != null) {
      origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      origin = LatLng(booking.originLat, booking.originLng);
    }

    // Destination depends on status
    // If driver is going to merchant (food), show route to merchant
    // If driver is delivering, show route to customer
    final driverGoingToMerchant = ['driver_accepted', 'matched', 'preparing'].contains(booking.status);
    if (booking.serviceType == 'food' && driverGoingToMerchant && _driverPosition != null) {
      destination = LatLng(booking.originLat, booking.originLng); // Route to merchant
    } else {
      destination = LatLng(booking.destLat, booking.destLng); // Route to customer
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );

      debugLog('🗺️ Requesting directions from Google Maps API...');
      debugLog('🗺️ Origin: ${origin.latitude}, ${origin.longitude}');
      debugLog('🗺️ Destination: ${destination.latitude}, ${destination.longitude}');
      
      final response = await http.get(url);
      final data = json.decode(response.body);

      debugLog('📡 Directions API response status: ${data['status']}');

      if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final routes = data['routes'] as List;
        final route = routes[0] as Map<String, dynamic>;
        final encodedPolyline = route['overview_polyline']?['points'] as String?;

        if (encodedPolyline != null) {
          final points = _polylinePoints.decodePolyline(encodedPolyline);
          final polylineCoordinates = points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          if (mounted) {
            setState(() {
              // Clear existing polylines first to prevent flickering
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: AppTheme.primaryGreen,
                  width: 5,
                  points: polylineCoordinates,
                ),
              );
            });
          }

          debugLog('✅ Route drawn successfully with ${polylineCoordinates.length} points');
        } else {
          debugLog('❌ No polyline points found in route');
          _drawStraightLine(origin, destination);
        }
      } else {
        debugLog('❌ Directions API error: ${data['status']}');
        _drawStraightLine(origin, destination);
      }
    } catch (e) {
      debugLog('❌ Error drawing route: $e');
      _drawStraightLine(origin, destination);
    }
  }

  void _drawStraightLine(LatLng origin, LatLng destination) {
    // Fallback: draw straight line if API fails
    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: AppTheme.primaryGreen,
            width: 5,
            points: [origin, destination],
          ),
        );
      });
      debugLog('⚠️ Drew fallback straight line');
    }
  }

  Future<void> _zoomToFitMarkers() async {
    if (_markers.isEmpty || _mapController == null) return;

    try {
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (var marker in _markers) {
        final lat = marker.position.latitude;
        final lng = marker.position.longitude;
        minLat = lat < minLat ? lat : minLat;
        maxLat = lat > maxLat ? lat : maxLat;
        minLng = lng < minLng ? lng : minLng;
        maxLng = lng > maxLng ? lng : maxLng;
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      debugLog('❌ Error zooming to fit markers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _currentBooking ?? widget.booking;
    final totalAmount = _calculateTotalAmount(booking);
    final couponDiscount = _couponDiscountAmount();
    final colorScheme = Theme.of(context).colorScheme;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
          (route) => false,
        );
      },
      child: Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        title: const Text('สถานะการเดินทาง'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
              (route) => false,
            );
          },
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Map Section
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(booking.destLat, booking.destLng),
                zoom: 15,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: _hasLocationPermission,
              onMapCreated: (controller) {
                _mapController = controller;
                // Wait a bit for map to be ready, then initialize
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    _initializeMap();
                    _zoomToFitMarkers();
                  }
                });
              },
            ),
          ),
          
          // Status Section
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Driver Info
                  if (booking.driverId != null) ...[
                    Text(
                      'ข้อมูลคนขับ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primaryGreen,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _driverProfile?['full_name'] ?? _getDriverStatusText(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _driverProfile?['vehicle_type'] ?? 'รถจักรยานยนต์',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (_driverProfile?['license_plate'] != null)
                                      Text(
                                        _driverProfile!['license_plate'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              // Call button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _driverProfile?['phone_number'] != null
                                      ? () => _makePhoneCall(_driverProfile!['phone_number'])
                                      : null,
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: const Text('โทร'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Chat button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _openChat(),
                                  icon: const Icon(Icons.chat, size: 18),
                                  label: const Text('แชท'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Trip Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        if (booking.serviceType == 'food') ...[
                          _buildInfoRow('ค่าอาหาร', '฿${booking.price.ceil()}'),
                          const SizedBox(height: 6),
                          _buildInfoRow('ค่าจัดส่ง', '฿${booking.deliveryFee?.ceil() ?? 0}'),
                          if (couponDiscount > 0) ...[
                            const SizedBox(height: 6),
                            _buildInfoRow(
                              _couponCode() != null && _couponCode()!.isNotEmpty
                                  ? 'ส่วนลดคูปอง (${_couponCode()!})'
                                  : 'ส่วนลดคูปอง',
                              '-฿${couponDiscount.ceil()}',
                            ),
                          ],
                          const SizedBox(height: 6),
                          _buildInfoRow('ระยะทาง', '${booking.distanceKm.toStringAsFixed(1)} กม.'),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('รวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(
                                '฿${totalAmount.ceil()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          _buildInfoRow('ระยะทาง', '${booking.distanceKm.toStringAsFixed(1)} กม.'),
                          if (couponDiscount > 0) ...[
                            const SizedBox(height: 6),
                            _buildInfoRow(
                              _couponCode() != null && _couponCode()!.isNotEmpty
                                  ? 'ส่วนลดคูปอง (${_couponCode()!})'
                                  : 'ส่วนลดคูปอง',
                              '-฿${couponDiscount.ceil()}',
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ค่าบริการ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                '฿${totalAmount.ceil()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: booking.status == 'completed' 
                          ? null 
                          : () {
                              _showCancelDialog();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: booking.status == 'completed' 
                            ? Colors.grey 
                            : Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        booking.status == 'completed' 
                            ? 'เดินทางเสร็จสิ้น'
                            : 'ยกเลิกการเดินทาง',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Color _getStatusColor() {
    final booking = _currentBooking ?? widget.booking;
    switch (booking.status) {
      case 'accepted':
      case 'driver_accepted':
        return Colors.blue;
      case 'arrived':
      case 'arrived_at_merchant':
        return Colors.orange;
      case 'ready_for_pickup':
        return Colors.green;
      case 'picking_up_order':
        return Colors.teal;
      case 'in_transit':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    final booking = _currentBooking ?? widget.booking;
    switch (booking.status) {
      case 'accepted':
        return 'คนขับรับงานแล้ว';
      case 'driver_accepted':
        return 'คนขับกำลังไปรับอาหาร';
      case 'arrived':
        return 'คนขับถึงจุดรับแล้ว';
      case 'arrived_at_merchant':
        return 'คนขับถึงร้านแล้ว';
      case 'ready_for_pickup':
        return 'อาหารพร้อม';
      case 'picking_up_order':
        return 'คนขับรับอาหารแล้ว';
      case 'in_transit':
        return 'กำลังเดินทาง';
      case 'completed':
        return 'เดินทางเสร็จสิ้น';
      default:
        return 'รอดำเนินการ';
    }
  }

  String _getDriverStatusText() {
    final booking = _currentBooking ?? widget.booking;
    switch (booking.status) {
      case 'accepted':
        return 'คนขับกำลังมารับ';
      case 'driver_accepted':
        return 'คนขับกำลังไปรับอาหาร';
      case 'arrived':
        return 'คนขับถึงจุดรับแล้ว';
      case 'arrived_at_merchant':
        return 'คนขับถึงร้านแล้ว รออาหาร';
      case 'ready_for_pickup':
        return 'อาหารพร้อม คนขับกำลังรับ';
      case 'picking_up_order':
        return 'คนขับรับอาหารแล้ว กำลังมาส่ง';
      case 'in_transit':
        return 'กำลังนำทางไปปลายทาง';
      case 'completed':
        return 'เดินทางเสร็จสิ้น';
      default:
        return 'รอคนขับ';
    }
  }

  void _showCancelledByMerchantDialog() {
    if (_hasShownCompletionDialog || !mounted) return;
    _hasShownCompletionDialog = true;
    _bookingSubscription?.cancel();
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'ร้านค้าปฏิเสธออเดอร์',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้\n\nกรุณาลองสั่งใหม่อีกครั้ง หรือเลือกร้านอื่น',
          style: TextStyle(fontSize: 15, color: colorScheme.onSurface, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => CustomerMainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('เข้าใจแล้ว', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    if (_hasShownCompletionDialog || !mounted) return;
    _hasShownCompletionDialog = true;
    _bookingSubscription?.cancel();

    final booking = _currentBooking ?? widget.booking;
    final isFood = booking.serviceType == 'food';
    final couponDiscount = _couponDiscountAmount();
    final couponCode = _couponCode();
    final foodCost = booking.price;
    final deliveryFee = booking.deliveryFee ?? 0.0;
    final grossAmount = isFood ? foodCost + deliveryFee : booking.price;
    final totalAmount = (grossAmount - couponDiscount) < 0 ? 0 : (grossAmount - couponDiscount);
    final bookingId = booking.id;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              isFood ? '🎉 จัดส่งสำเร็จแล้ว!' : '🎉 เดินทางเสร็จสิ้น!',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ขอบคุณที่ใช้บริการ',
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              // Order ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'หมายเลขออเดอร์',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          OrderCodeFormatter.formatByServiceType(
                            bookingId,
                            serviceType: booking.serviceType,
                          ),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Total Price
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ยอดเงินทั้งหมด', style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
                            if (isFood)
                              const Text('รวมค่าจัดส่ง', style: TextStyle(fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                        Text(
                          '฿${totalAmount.ceil()}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    if (isFood) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('ค่าอาหาร', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                Text('฿${foodCost.ceil()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            Container(width: 1, height: 24, color: Colors.white30),
                            Column(
                              children: [
                                const Text('ค่าจัดส่ง', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                Text('฿${deliveryFee.ceil()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (couponDiscount > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        couponCode != null && couponCode.isNotEmpty
                            ? 'ใช้คูปอง $couponCode ลด ฿${couponDiscount.ceil()}'
                            : 'ใช้คูปอง ลด ฿${couponDiscount.ceil()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => CustomerMainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('เข้าใจแล้ว', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    final booking = _currentBooking ?? widget.booking;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกการเดินทาง'),
        content: const Text('คุณต้องการยกเลิกการเดินทางนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _customerInitiatedCancel = true;
              try {
                await _bookingService.cancelBooking(booking.id);
                debugLog('✅ Booking cancelled successfully: ${booking.id}');
                
                if (mounted) {
                  // Clean up subscriptions first
                  _bookingSubscription?.cancel();
                  _autoRefreshTimer?.cancel();
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ยกเลิกการเดินทางสำเร็จ'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Add small delay to ensure SnackBar shows
                  await Future.delayed(const Duration(milliseconds: 500));
                  
                  // Navigate back to home screen
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => CustomerMainScreen()),
                      (route) => false,
                    );
                  }
                }
              } catch (e) {
                debugLog('❌ Error cancelling booking: $e');
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      title: const Text('ยกเลิกไม่สำเร็จ'),
                      content: Text('เกิดข้อผิดพลาดในการยกเลิก: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('ตกลง'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text(
              'ใช่',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
