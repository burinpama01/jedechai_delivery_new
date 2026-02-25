import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/profile_service.dart';
import '../../../common/services/supabase_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/services/booking_service.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/services/chat_service.dart';
import '../../../common/widgets/chat_screen.dart';
import '../../../common/services/merchant_food_config_service.dart';
import '../../../common/models/booking.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../theme/app_theme.dart';
import '../../../common/config/env_config.dart';
import '../../customer/screens/services/support_tickets_screen.dart';
import 'driver_main_screen.dart';
import 'driver_job_detail_screen.dart';

/// Driver Navigation Screen
/// 
/// Real-time navigation and status management for drivers
class DriverNavigationScreen extends StatefulWidget {
  final String bookingId;

  const DriverNavigationScreen({
    super.key,
    required this.bookingId,
  });

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen>
    with TickerProviderStateMixin {
  // Map controllers
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  
  // Location
  Position? _currentPosition;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  
  // Booking data
  Booking? _booking;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  String? _lastKnownStatus;
  bool _isInfoPanelCollapsed = false;
  
  // Customer info
  // ignore: unused_field
  Map<String, dynamic>? _customerProfile;
  String _customerName = 'ลูกค้า';
  String _customerPhone = 'ไม่ระบุ';
  double _couponDiscount = 0.0;
  String? _couponCode;
  double _merchantSystemRatePreview = 0.10;
  double _merchantDriverRatePreview = 0.0;
  
  // Merchant info (for food orders)
  String _merchantName = '';
  String _merchantPhone = '';
  
  // Animation
  late AnimationController _pulseController;
  // ignore: unused_field
  late Animation<double> _pulseAnimation;
  Timer? _autoRefreshTimer;
  Timer? _locationUpdateTimer;
  DateTime? _lastLocationUpdate;
  StreamSubscription<Position>? _positionStreamSub;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingStreamSub;
  
  // Constants
  static String get _googleApiKey => EnvConfig.googleMapsApiKey;
  static const double kAllowedRadiusMeters = 100.0; // Geofencing radius
  final PolylinePoints _polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    
    debugLog('🧭 DriverNavigationScreen initialized with bookingId: ${widget.bookingId}');
    
    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
    // Initialize
    _initializeScreen();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _locationUpdateTimer?.cancel();

    final positionSub = _positionStreamSub;
    _positionStreamSub = null;
    if (positionSub != null) {
      unawaited(positionSub.cancel());
    }

    final bookingSub = _bookingStreamSub;
    _bookingStreamSub = null;
    if (bookingSub != null) {
      unawaited(bookingSub.cancel());
    }

    _mapController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCouponUsageForBooking(String bookingId) async {
    try {
      final usage = await SupabaseService.client
          .from('coupon_usages')
          .select('discount_amount, coupon_id')
          .eq('booking_id', bookingId)
          .maybeSingle();

      double discount = 0.0;
      String? couponCode;

      if (usage != null) {
        discount = (usage['discount_amount'] as num?)?.toDouble() ?? 0.0;

        final couponId = usage['coupon_id'] as String?;
        if (couponId != null && couponId.isNotEmpty) {
          final coupon = await SupabaseService.client
              .from('coupons')
              .select('code')
              .eq('id', couponId)
              .maybeSingle();
          couponCode = coupon?['code'] as String?;
        }
      }

      if (mounted) {
        setState(() {
          _couponDiscount = discount;
          _couponCode = couponCode;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading coupon usage in driver navigation: $e');
    }
  }

  double _grossCollectAmount(Booking booking) {
    return booking.serviceType == 'food'
        ? booking.price + (booking.deliveryFee ?? 0)
        : booking.price;
  }

  double _netCollectAmount(Booking booking) {
    final total = _grossCollectAmount(booking) - _couponDiscount;
    return total < 0 ? 0 : total;
  }

  Future<void> _loadMerchantFinancePreview() async {
    final booking = _booking;
    if (booking == null || booking.serviceType != 'food') return;

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
        defaultMerchantSystemRate: configService.merchantGpRate,
        defaultMerchantDriverRate: 0.0,
        defaultDeliverySystemRate: configService.platformFeeRate,
      );

      if (!mounted) return;
      setState(() {
        _merchantSystemRatePreview = config.merchantGpSystemRate;
        _merchantDriverRatePreview = config.merchantGpDriverRate;
      });

      debugLog('💡 Merchant finance preview loaded: ${config.summary}');
    } catch (e) {
      debugLog('⚠️ Failed to load merchant finance preview: $e');
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      await _refreshStatus();
    });
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted || _currentPosition == null) return;
      await _updateDriverLocation();
    });
    debugLog('✅ Started real-time location updates (every 10 seconds)');
  }

  Future<void> _updateDriverLocation() async {
    if (_currentPosition == null) {
      debugLog('⚠️ Cannot update driver location - current position is null');
      return;
    }

    // Throttle: Only update if at least 10 seconds have passed since last update
    if (_lastLocationUpdate != null) {
      final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
      if (timeSinceLastUpdate.inSeconds < 10) {
        return;
      }
    }

    try {
      final driverId = AuthService.userId;
      if (driverId == null) {
        debugLog('⚠️ Cannot update driver location - driver ID is null');
        return;
      }

      await SupabaseService.client
          .from('profiles')
          .update({
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
            'is_online': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', driverId);

      // Also update driver_locations table (admin map reads from here)
      final existing = await SupabaseService.client
          .from('driver_locations')
          .select('driver_id')
          .eq('driver_id', driverId)
          .maybeSingle();
      
      if (existing != null) {
        await SupabaseService.client
            .from('driver_locations')
            .update({
              'location_lat': _currentPosition!.latitude,
              'location_lng': _currentPosition!.longitude,
              'is_online': true,
              'is_available': false,
              'current_booking_id': widget.bookingId,
            })
            .eq('driver_id', driverId);
      } else {
        await SupabaseService.client
            .from('driver_locations')
            .insert({
              'driver_id': driverId,
              'location_lat': _currentPosition!.latitude,
              'location_lng': _currentPosition!.longitude,
              'is_online': true,
              'is_available': false,
              'current_booking_id': widget.bookingId,
            });
      }

      _lastLocationUpdate = DateTime.now();
      debugLog('📍 Driver location updated: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } catch (e) {
      debugLog('❌ Error updating driver location: $e');
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final response = await SupabaseService.client
          .from('bookings')
          .select('status')
          .eq('id', widget.bookingId)
          .single();

      final refreshedStatus = response['status'] as String?;
      if (refreshedStatus != null && refreshedStatus != _lastKnownStatus) {
        _lastKnownStatus = refreshedStatus;
        await _fetchBookingDetails();
        _updateMapRoute();

        if (refreshedStatus == 'completed') {
          _showCompletionDialog();
        }
      }
    } catch (e) {
      debugLog('❌ Auto refresh status error: $e');
    }
  }

  Future<void> _initializeScreen() async {
    debugLog('🧭 Initializing DriverNavigationScreen...');
    try {
      await _getCurrentLocation();
      await _fetchBookingDetails();
      await _setupRealtimeUpdates();
      debugLog('✅ DriverNavigationScreen initialization complete');
    } catch (e) {
      debugLog('❌ DriverNavigationScreen initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // แสดง Prominent Disclosure ก่อนขอ permission จากระบบ (Google Play Policy)
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) return;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugLog('⚠️ Location permission denied');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('กรุณาอนุญาตการเข้าถึงตำแหน่งเพื่อใช้งานฟีเจอร์นี้'),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugLog('⚠️ Location permission denied forever');
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(
                Icons.location_off,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              title: const Text('ไม่สามารถเข้าถึงตำแหน่ง'),
              content: const Text('กรุณาเปิดการเข้าถึงตำแหน่งในการตั้งค่าของเครื่อง เพื่อใช้งานแอปได้ตามปกติ'),
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
        return;
      }
      
      debugLog('📍 Getting current location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugLog('✅ Location obtained: ${position.latitude}, ${position.longitude}');
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      
      // Listen for location updates
      await _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _updateMapRoute();
        }
      }, onError: (error) {
        debugLog('❌ Location stream error: $error');
      });
      
      // Start periodic location updates to Supabase for real-time tracking
      _startLocationUpdates();
    } catch (e) {
      debugLog('❌ Error getting location: $e');
      // Still try to initialize map without current position
      if (mounted && _pickupLocation != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _mapController != null) {
            _addInitialMarkers();
          }
        });
      }
    }
  }

  Future<void> _fetchBookingDetails() async {
    try {
      debugLog('🔍 Fetching booking details for: ${widget.bookingId}');
      
      // Fetch booking details
      final response = await SupabaseService.client
          .from('bookings')
          .select()
          .eq('id', widget.bookingId)
          .single();
      
      debugLog('📋 Booking response: $response');
      
      _booking = Booking.fromJson(response);
      _lastKnownStatus = _booking?.status;
      await _loadCouponUsageForBooking(widget.bookingId);
      await _loadMerchantFinancePreview();
      
      // Fetch customer profile separately
      if (_booking?.customerId != null) {
        await _fetchCustomerProfile(_booking!.customerId);
      }
      await _fetchMerchantProfile();
      
      debugLog('✅ Booking fetched: ${_booking?.serviceType} - ${_booking?.status}');
      debugLog('📋 Booking details:');
      debugLog('   └─ ID: ${_booking?.id}');
      debugLog('   └─ Status: ${_booking?.status}');
      debugLog('   └─ Driver ID: ${_booking?.driverId}');
      debugLog('   └─ Service Type: ${_booking?.serviceType}');
      debugLog('   └─ Price: ${_booking?.price}');
      
      // Check if booking is cancelled
      if (_booking?.status == 'cancelled') {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showCancellationDialog();
        }
        return;
      }
      
      // Extract locations
      if (_booking != null) {
        _pickupLocation = LatLng(_booking!.originLat, _booking!.originLng);
        debugLog('📍 Pickup location: ${_booking!.originLat}, ${_booking!.originLng}');
        _destinationLocation = LatLng(_booking!.destLat, _booking!.destLng);
        debugLog('📍 Destination location: ${_booking!.destLat}, ${_booking!.destLng}');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Initialize map after a delay to ensure map controller is ready
      // Also wait for current position if not available yet
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _mapController != null) {
          if (_currentPosition == null) {
            // Wait a bit more for location
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted && _mapController != null) {
                _initializeMap();
              }
            });
          } else {
            _initializeMap();
          }
        }
      });
    } catch (e) {
      debugLog('❌ Error fetching booking: $e');
      debugLog('❌ Error stack trace: ${StackTrace.current}');
      
      // Try fetching without join as fallback
      try {
        final fallbackResponse = await SupabaseService.client
            .from('bookings')
            .select()
            .eq('id', widget.bookingId)
            .single();
        
        _booking = Booking.fromJson(fallbackResponse);
        await _loadCouponUsageForBooking(widget.bookingId);
        await _loadMerchantFinancePreview();
        
        // Extract locations
        if (_booking != null) {
          _pickupLocation = LatLng(_booking!.originLat, _booking!.originLng);
          _destinationLocation = LatLng(_booking!.destLat, _booking!.destLng);
        }
        
        // Fetch customer profile separately
        if (_booking?.customerId != null) {
          await _fetchCustomerProfile(_booking!.customerId);
        }
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        
        if (_mapController != null) {
          _initializeMap();
        }
      } catch (fallbackError) {
        debugLog('❌ Fallback fetch also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  Future<void> _fetchCustomerProfile(String customerId) async {
    try {
      debugLog('🔍 Fetching customer profile for: $customerId');
      final profileService = ProfileService();
      final profile = await profileService.getProfileById(customerId);
      
      if (profile != null) {
        _customerProfile = profile;
        _customerName = profile['full_name'] ?? 'ลูกค้า';
        _customerPhone = profile['phone_number'] ?? 'ไม่ระบุ';
        debugLog('✅ Customer profile fetched: $_customerName, $_customerPhone');
        
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugLog('❌ Error fetching customer profile: $e');
    }
  }

  Future<void> _fetchMerchantProfile() async {
    if (_booking == null || _booking!.serviceType != 'food') return;
    final merchantId = _booking!.merchantId;
    if (merchantId == null || merchantId.isEmpty) return;
    try {
      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', merchantId)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _merchantName = profile['full_name'] ?? 'ร้านค้า';
          _merchantPhone = profile['phone_number'] ?? '';
        });
      }
    } catch (e) {
      debugLog('⚠️ Error fetching merchant profile: $e');
    }
  }

  Future<void> _callMerchant() async {
    if (_merchantPhone.isEmpty) {
      _showErrorSnackBar('ไม่พบเบอร์โทรร้านค้า');
      return;
    }
    final uri = Uri.parse('tel:$_merchantPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackBar('ไม่สามารถโทรออกได้');
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโทร');
    }
  }

  Future<void> _openSupportChat() async {
    if (_booking == null) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportTicketsScreen(bookingId: _booking!.id),
      ),
    );
  }

  Future<void> _cancelJob() async {
    if (_booking == null) return;

    String? selectedReason;
    final reasons = [
      'ลูกค้าไม่รับสาย/ติดต่อไม่ได้',
      'ร้านค้าปิด/ไม่พร้อมให้บริการ',
      'ระยะทางไกลเกินไป',
      'เกิดเหตุฉุกเฉินส่วนตัว',
      'สภาพอากาศไม่ดี/ถนนไม่สะดวก',
      'อื่นๆ',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: colorScheme.error, size: 24),
                  const SizedBox(width: 8),
                  const Text('ยกเลิกงาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'กรุณาเลือกเหตุผลในการยกเลิก:',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason, style: const TextStyle(fontSize: 13)),
                    value: reason,
                    groupValue: selectedReason,
                    dense: true,
                    activeColor: colorScheme.error,
                    onChanged: (val) => setDialogState(() => selectedReason = val),
                  )),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'การยกเลิกงานบ่อยอาจส่งผลต่อคะแนนของคุณ',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('กลับ'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                  ),
                  child: const Text('ยืนยันยกเลิก'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedReason == null) return;

    try {
      setState(() => _isUpdatingStatus = true);

      await SupabaseService.client.from('bookings').update({
        'status': 'cancelled',
        'cancel_reason': selectedReason,
        'cancelled_by': 'driver',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _booking!.id);

      // Notify customer
      if (_booking!.customerId.isNotEmpty) {
        await NotificationSender.sendNotification(
          targetUserId: _booking!.customerId,
          title: '❌ คนขับยกเลิกงาน',
          body: 'เหตุผล: $selectedReason',
          data: {
            'type': 'booking_cancelled',
            'booking_id': _booking!.id,
          },
        );
      }

      if (mounted) {
        _showSuccessSnackBar('ยกเลิกงานเรียบร้อยแล้ว');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DriverMainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugLog('❌ Error cancelling job: $e');
      if (mounted) {
        _showErrorSnackBar('ไม่สามารถยกเลิกงาน: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _setupRealtimeUpdates() async {
    debugLog('📡 Setting up real-time updates for booking: ${widget.bookingId}');
    
    // Use proper stream with execute()
    try {
      await _bookingStreamSub?.cancel();
      _bookingStreamSub = SupabaseService.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', widget.bookingId)
          .execute()
          .listen((data) {
            debugLog('📡 Stream update received: ${data.length} items');
            if (data.isNotEmpty && mounted) {
              final updatedBooking = Booking.fromJson(data.first);
              debugLog('📡 Booking updated from stream: ${updatedBooking.status}');
              
              setState(() {
                _booking = updatedBooking;
              });

              _loadCouponUsageForBooking(updatedBooking.id);
              _loadMerchantFinancePreview();
              
              // Update locations if changed
              _pickupLocation = LatLng(updatedBooking.originLat, updatedBooking.originLng);
              _destinationLocation = LatLng(updatedBooking.destLat, updatedBooking.destLng);
              
              _updateMapForStatus();
              
              // Handle completion
              if (updatedBooking.status == 'completed') {
                _showCompletionDialog();
              }
              
              // Handle cancellation
              if (updatedBooking.status == 'cancelled') {
                _showCancellationDialog();
              }
            }
          }, onError: (error) {
            debugLog('❌ Stream error: $error');
          });
    } catch (e) {
      debugLog('❌ Error setting up stream: $e');
    }
  }

  /// Initialize map with markers and route immediately
  void _initializeMap() {
    if (_booking == null || _mapController == null) {
      debugLog('⚠️ Cannot initialize map - booking: ${_booking != null}, mapController: ${_mapController != null}');
      return;
    }
    
    debugLog('🗺️ Initializing map with booking status: ${_booking!.status}');
    debugLog('📍 Pickup location: $_pickupLocation');
    debugLog('📍 Destination location: $_destinationLocation');
    debugLog('📍 Current position: $_currentPosition');
    
    // Always show pickup and destination markers first
    _addInitialMarkers();
    
    // Draw route based on status
    _updateMapForStatus();
  }
  
  /// Add initial markers (pickup and destination)
  void _addInitialMarkers() {
    if (_pickupLocation == null && _destinationLocation == null) {
      debugLog('⚠️ No locations available for markers');
      // Still try to show driver location if available
      if (_currentPosition != null) {
        setState(() {
          _markers.clear();
          _markers.add(Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ));
        });
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15,
            ),
          ),
        );
      }
      return;
    }
    
    debugLog('📍 Adding markers - Pickup: $_pickupLocation, Destination: $_destinationLocation');
    
    setState(() {
      _markers.clear();
      
      // Add driver marker if current position is available
      if (_currentPosition != null) {
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ));
        debugLog('📍 Added driver marker');
      }
      
      // Add pickup marker
      if (_pickupLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'จุดรับ',
            snippet: _booking?.pickupAddress ?? 'ตำแหน่งรับ',
          ),
        ));
        debugLog('📍 Added pickup marker at ${_pickupLocation!.latitude}, ${_pickupLocation!.longitude}');
      }
      
      // Add destination marker
      if (_destinationLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'จุดหมาย',
            snippet: _booking?.destinationAddress ?? 'จุดหมายปลายทาง',
          ),
        ));
        debugLog('📍 Added destination marker at ${_destinationLocation!.latitude}, ${_destinationLocation!.longitude}');
      }
    });
    
    debugLog('📍 Total markers: ${_markers.length}');
    
    // Auto-zoom to fit all markers
    _zoomToFitMarkers();
  }
  
  /// Zoom map to fit all markers
  void _zoomToFitMarkers() {
    if (_markers.isEmpty || _mapController == null) return;
    
    try {
      final positions = _markers.map((marker) => marker.position).toList();
      if (positions.length < 2) {
        // If only one marker, just center on it
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: positions.first, zoom: 15),
          ),
        );
        return;
      }
      
      final bounds = _calculateBounds(positions);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      debugLog('❌ Error zooming to fit markers: $e');
    }
  }
  
  void _updateMapForStatus() {
    if (_booking == null || _mapController == null) return;
    
    debugLog('🗺️ Updating map for status: ${_booking!.status}');
    
    switch (_booking!.status) {
      case 'accepted':        // Ride - going to pickup
      case 'driver_accepted': // Food - going to merchant
        if (_currentPosition != null && _pickupLocation != null) {
          _drawRouteToPickup();
        } else {
          _addInitialMarkers();
        }
        break;
      case 'arrived':
      case 'arrived_at_merchant': // Food - at merchant
      case 'ready_for_pickup':    // Food - waiting for food
      case 'picking_up_order':    // Food - picking up
        _focusOnPickup();
        break;
      case 'in_transit':
        if (_currentPosition != null && _destinationLocation != null) {
          _drawRouteToDestination();
        } else if (_pickupLocation != null && _destinationLocation != null) {
          _drawRouteToDestination();
        } else {
          _addInitialMarkers();
        }
        break;
      case 'completed':
        // Handle completion
        break;
      default:
        // For any other status, just show markers
        _addInitialMarkers();
        break;
    }
  }

  Future<void> _drawRouteToPickup() async {
    if (_currentPosition == null || _pickupLocation == null) {
      debugLog('⚠️ Cannot draw route - CurrentPosition: ${_currentPosition != null}, PickupLocation: ${_pickupLocation != null}');
      // Still show markers even without route
      _addInitialMarkers();
      return;
    }
    
    debugLog('🗺️ Drawing route to pickup location');
    debugLog('   └─ From: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    debugLog('   └─ To: ${_pickupLocation!.latitude}, ${_pickupLocation!.longitude}');
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&destination=${_pickupLocation!.latitude},${_pickupLocation!.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );

      debugLog('🌐 Requesting directions from Google Maps API...');
      final response = await http.get(url);
      final data = json.decode(response.body);
      
      debugLog('📡 Directions API response status: ${data['status']}');

      if (data['status'] == 'OK' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final routes = data['routes'] as List;
        final route = routes[0] as Map<String, dynamic>;
        final encodedPolyline = route['overview_polyline']?['points'] as String?;
        
        if (encodedPolyline == null) {
          debugLog('❌ No polyline points found');
          _addInitialMarkers(); // Fallback to markers only
          return;
        }
        
        debugLog('✅ Polyline encoded: ${encodedPolyline.substring(0, 50)}...');
        final points = _polylinePoints.decodePolyline(encodedPolyline);
        debugLog('✅ Decoded ${points.length} points');
        
        if (mounted) {
          setState(() {
            _polylines.clear();
            _markers.clear();
            
            // Add driver marker
            _markers.add(Marker(
              markerId: const MarkerId('driver'),
              position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ));
            
            // Add pickup marker
            _markers.add(Marker(
              markerId: const MarkerId('pickup'),
              position: _pickupLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(
                title: 'Pickup',
                snippet: _booking?.pickupAddress ?? 'Pickup Location',
              ),
            ));
            
            // Add destination marker if available
            if (_destinationLocation != null) {
              _markers.add(Marker(
                markerId: const MarkerId('destination'),
                position: _destinationLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: 'Destination',
                  snippet: _booking?.destinationAddress ?? 'Destination',
                ),
              ));
            }
            
            // Add polyline
            _polylines.add(Polyline(
              polylineId: const PolylineId('route_to_pickup'),
              color: AppTheme.accentBlue,
              width: 5,
              points: points.map((point) => LatLng(point.latitude, point.longitude)).toList(),
            ));
            
            debugLog('✅ Route drawn: ${_polylines.length} polylines, ${_markers.length} markers');
          });
          
          // Move camera to show route
          final routePoints = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
          final bounds = _calculateBounds(routePoints);
          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
          debugLog('✅ Camera moved to show route');
        }
      } else {
        debugLog('❌ Directions API error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        _addInitialMarkers(); // Fallback to markers only
      }
    } catch (e) {
      debugLog('❌ Error drawing route to pickup: $e');
      debugLog('❌ Error stack trace: ${StackTrace.current}');
      _addInitialMarkers(); // Fallback to markers only
    }
  }

  Future<void> _focusOnPickup() async {
    if (_pickupLocation == null) return;
    
    debugLog('🗺️ Focusing on pickup location');
    
    setState(() {
      _polylines.clear();
      _markers.clear();
      
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup: ${_booking?.pickupAddress ?? 'Location'}'),
      ));
    });
    
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _pickupLocation!, zoom: 17),
    ));
  }

  Future<void> _drawRouteToDestination() async {
    if (_destinationLocation == null) return;
    
    // Use current driver position if available, otherwise fallback to pickup
    final originLat = _currentPosition?.latitude ?? _pickupLocation?.latitude;
    final originLng = _currentPosition?.longitude ?? _pickupLocation?.longitude;
    if (originLat == null || originLng == null) return;
    
    debugLog('🗺️ Drawing route to destination from driver position');
    
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$originLat,$originLng'
        '&destination=${_destinationLocation!.latitude},${_destinationLocation!.longitude}'
        '&mode=driving'
        '&key=$_googleApiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final routes = data['routes'] as List;
        final route = routes[0] as Map<String, dynamic>;
        final encodedPolyline = route['overview_polyline']?['points'] as String?;
        
        if (encodedPolyline == null) {
          debugLog('❌ No polyline points found');
          return;
        }
        
        final points = _polylinePoints.decodePolyline(encodedPolyline);
        
        setState(() {
          _polylines.clear();
          _markers.clear();
          
          // Add driver marker
          if (_currentPosition != null) {
            _markers.add(Marker(
              markerId: const MarkerId('driver'),
              position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'ตำแหน่งคนขับ'),
            ));
          }
          
          // Add destination marker
          _markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'จุดหมาย: ${_booking?.destinationAddress ?? 'ตำแหน่ง'}'),
          ));
          
          // Add polyline
          _polylines.add(Polyline(
            polylineId: const PolylineId('route_to_destination'),
            color: AppTheme.accentBlue,
            width: 5,
            points: points.map((point) => LatLng(point.latitude, point.longitude)).toList(),
          ));
        });
        
        // Move camera to show route
        final allPoints = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
        if (_currentPosition != null) {
          allPoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
        }
        final bounds = _calculateBounds(allPoints);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
      }
    } catch (e) {
      debugLog('❌ Error drawing route to destination: $e');
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  DateTime? _lastRouteDrawTime;

  void _updateMapRoute() {
    if (_currentPosition == null || _booking == null) return;

    // Throttle route redraws: at most once every 30 seconds
    if (_lastRouteDrawTime != null) {
      final diff = DateTime.now().difference(_lastRouteDrawTime!);
      if (diff.inSeconds < 30) {
        // Just update driver marker position without redrawing route
        setState(() {
          _markers.removeWhere((m) => m.markerId.value == 'driver');
          _markers.add(
            Marker(
              markerId: const MarkerId('driver'),
              position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
            ),
          );
        });
        return;
      }
    }
    _lastRouteDrawTime = DateTime.now();

    // Determine target based on status
    LatLng targetLocation;
    String targetLabel;
    BitmapDescriptor targetIcon;
    
    if (_booking!.status == 'in_transit') {
      if (_destinationLocation == null) return;
      targetLocation = _destinationLocation!;
      targetLabel = 'จุดหมาย';
      targetIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else {
      if (_pickupLocation == null) return;
      targetLocation = _pickupLocation!;
      targetLabel = 'จุดรับ';
      targetIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }

    // Update markers immediately (don't clear polylines — keep old route visible until new one arrives)
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
        ),
      );
      _markers.add(
        Marker(
          markerId: MarkerId(targetLabel.toLowerCase().replaceAll(' ', '_')),
          position: targetLocation,
          icon: targetIcon,
          infoWindow: InfoWindow(title: targetLabel),
        ),
      );
      // Also keep destination marker visible when going to pickup
      if (_booking!.status != 'in_transit' && _destinationLocation != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'จุดหมาย: ${_booking?.destinationAddress ?? ''}'),
          ),
        );
      }
    });

    // Draw route asynchronously (polylines update when API responds)
    _drawRoute(targetLocation);
  }

  Future<void> _drawRoute(LatLng destination) async {
    if (_currentPosition == null) {
      debugLog('⚠️ Cannot draw route - current position is null');
      return;
    }

    final origin = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
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
                  color: AppTheme.accentBlue,
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
            color: AppTheme.accentBlue,
            width: 5,
            points: [origin, destination],
          ),
        );
      });
      debugLog('⚠️ Drew fallback straight line');
    }
  }

  Future<void> _updateJobStatus(String newStatus) async {
    if (_isUpdatingStatus || _booking == null) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      debugLog('🔄 Updating status from ${_booking!.status} to: $newStatus');
      debugLog('📋 Booking ID: ${widget.bookingId}');
      debugLog('👤 Driver ID: ${AuthService.userId}');
      
      // Add timestamp for debugging
      final timestamp = DateTime.now().toIso8601String();
      debugLog('🕐 Update timestamp: $timestamp');
      
      // Prepare update data
      final updateData = {
        'status': newStatus,
        'updated_at': timestamp,
      };
      
      // Add driver_id if not already set
      if (_booking!.driverId == null || _booking!.driverId!.isEmpty) {
        final driverId = AuthService.userId;
        if (driverId != null) {
          updateData['driver_id'] = driverId;
          debugLog('👤 Adding driver_id: $driverId');
        } else {
          debugLog('❌ Driver ID is null - cannot update');
          if (mounted) {
            _showErrorSnackBar('ไม่พบข้อมูลคนขับ กรุณาออกจากระบบและเข้าสู่ระบบใหม่');
          }
          return;
        }
      }
      
      debugLog('📤 Update data: $updateData');
      
      debugLog('🔍 DEBUG: About to call BookingService.updateBookingStatus');
      debugLog('   └─ This should trigger commission deduction for completed jobs');
      
      // Use BookingService to ensure commission deduction works
      final bookingService = BookingService();
      await bookingService.updateBookingStatus(widget.bookingId, newStatus);
      
      // Save trip tracking data when completing
      if (newStatus == 'completed') {
        try {
          final tripData = <String, dynamic>{};
          // Compute trip duration from started_at (or assigned_at) to now
          final startTime = _booking!.startedAt ?? _booking!.assignedAt;
          if (startTime != null) {
            final durationMin = DateTime.now().difference(startTime).inMinutes;
            tripData['trip_duration_minutes'] = durationMin;
          }
          tripData['completed_at'] = DateTime.now().toIso8601String();
          // actual_distance_km = estimated distance (can be improved with GPS tracking)
          tripData['actual_distance_km'] = _booking!.distanceKm;
          
          if (tripData.isNotEmpty) {
            await SupabaseService.client
                .from('bookings')
                .update(tripData)
                .eq('id', widget.bookingId);
            debugLog('📊 Trip data saved: $tripData');
          }
        } catch (e) {
          debugLog('⚠️ Error saving trip data (non-blocking): $e');
        }
      }
      
      // Fetch updated booking data
      final result = await SupabaseService.client
          .from('bookings')
          .select()
          .eq('id', widget.bookingId);
      
      debugLog('✅ Status update result: $result');
      
      if (result.isNotEmpty) {
        setState(() {
          _booking = Booking.fromJson(result[0]);
        });
        
        // Send notification to customer about status change
        await _notifyCustomerStatusUpdate(result[0], newStatus);
        
        // If driver arrived at merchant, also notify merchant
        if (newStatus == 'arrived_at_merchant' && _booking!.serviceType == 'food') {
          await _notifyMerchantDriverArrived(result[0]);
        }
        
        if (mounted) {
          _showSuccessSnackBar('อัพเดตสถานะเรียบร้อยแล้ว');
          
          // Show merchant payment dialog when picking up food
          if (newStatus == 'picking_up_order' && _booking!.serviceType == 'food') {
            _showMerchantPaymentDialog();
          }
          
          // Launch Google Maps Navigation when starting trip
          if (newStatus == 'in_transit') {
            _launchGoogleMapsNavigation();
          }
          
          // Handle completion
          if (newStatus == 'completed') {
            _showCompletionDialog();
          }
        }
      } else {
        throw Exception('No data returned from update operation');
      }
    } catch (e) {
      debugLog('❌ Error updating status: $e');
      debugLog('❌ Error type: ${e.runtimeType}');
      debugLog('❌ Error details: ${e.toString()}');
      debugLog('❌ Stack trace: ${StackTrace.current}');
      
      // Try to get more specific error info
      if (e.toString().contains('permission_denied')) {
        debugLog('❌ Permission denied - check RLS policies');
        if (mounted) {
          _showErrorSnackBar('ไม่มีสิทธิ์ กรุณาตรวจสอบสิทธิ์บัญชีของคุณ');
        }
      } else if (e.toString().contains('no rows')) {
        debugLog('❌ No rows found - booking may not exist');
        if (mounted) {
          _showErrorSnackBar('ไม่พบการจอง กรุณารีเฟรชและลองใหม่');
        }
      } else if (e.toString().contains('foreign_key')) {
        debugLog('❌ Foreign key constraint - driver_id may be invalid');
        if (mounted) {
          _showErrorSnackBar('ข้อมูลคนขับไม่ถูกต้อง กรุณาออกจากระบบและเข้าสู่ระบบใหม่');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('ไม่สามารถอัพเดตสถานะ: ${e.toString()}');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  /// เปิด Google Maps Navigation ไปยังจุดหมายที่เหมาะสมตามสถานะ
  Future<void> _launchGoogleMapsNavigation() async {
    if (_booking == null) return;

    // กำหนดจุดหมายตามสถานะปัจจุบัน
    final double destLat;
    final double destLng;
    final status = _booking!.status;
    
    // ถ้ายังไม่ถึงจุดรับ → นำทางไปจุดรับ (origin)
    // ถ้าถึงจุดรับแล้ว / กำลังส่ง → นำทางไปจุดส่ง (destination)
    final goingToPickup = ['accepted', 'driver_accepted', 'matched', 'preparing', 'arrived_at_merchant', 'arrived'].contains(status);
    if (goingToPickup) {
      destLat = _booking!.originLat;
      destLng = _booking!.originLng;
    } else {
      destLat = _booking!.destLat;
      destLng = _booking!.destLng;
    }

    debugLog('🧭 Launching Google Maps Navigation to: $destLat, $destLng');

    // google.navigation: เปิดโหมดนำทางโดยตรง
    final googleNavUri = Uri.parse(
      'google.navigation:q=$destLat,$destLng&mode=d',
    );

    // fallback: เปิด Google Maps ปกติ
    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri);
        debugLog('✅ Google Maps Navigation launched');
      } else if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
        debugLog('✅ Google Maps (web) launched as fallback');
      } else {
        debugLog('❌ Cannot launch Google Maps');
        if (mounted) {
          _showErrorSnackBar('ไม่สามารถเปิด Google Maps ได้');
        }
      }
    } catch (e) {
      debugLog('❌ Error launching Google Maps: $e');
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาดในการเปิดแผนที่นำทาง');
      }
    }
  }

  String _getActionButtonText() {
    final status = _booking?.status ?? 'unknown';
    final serviceType = _booking?.serviceType ?? 'ride';
    debugLog('🎯 Getting action button text for status: $status, service: $serviceType');
    
    if (serviceType == 'food') {
      switch (status) {
        case 'accepted':
        case 'driver_accepted':
          return 'ถึงร้านแล้ว';
        case 'arrived_at_merchant':
          return 'รออาหารพร้อม';
        case 'ready_for_pickup':
          return 'รับอาหาร';
        case 'picking_up_order':
          return 'เริ่มส่งอาหาร';
        case 'in_transit':
          return 'ส่งอาหารเสร็จสิ้น';
        default:
          return 'อัพเดตสถานะ';
      }
    } else if (serviceType == 'parcel') {
      switch (status) {
        case 'accepted':
        case 'driver_accepted':
          return 'ถึงจุดรับพัสดุแล้ว';
        case 'arrived':
          return 'รับพัสดุ เริ่มส่ง';
        case 'in_transit':
          return 'ส่งพัสดุเสร็จสิ้น';
        default:
          return 'อัพเดตสถานะ';
      }
    } else {
      // Ride
      switch (status) {
        case 'accepted':
        case 'driver_accepted':
          return 'ถึงจุดรับลูกค้าแล้ว';
        case 'arrived':
          return 'รับผู้โดยสาร เริ่มเดินทาง';
        case 'in_transit':
          return 'ส่งผู้โดยสารเสร็จสิ้น';
        default:
          return 'อัพเดตสถานะ';
      }
    }
  }

  // ignore: unused_element
  Color _getActionButtonColor() {
    final colorScheme = Theme.of(context).colorScheme;
    switch (_booking?.status) {
      case 'accepted': // Ride - driver accepted, going to pickup
        return AppTheme.accentBlue;
      case 'driver_accepted': // Food - going to merchant
        return colorScheme.tertiary;
      case 'arrived_at_merchant': // Food - at merchant, waiting for food
        return colorScheme.outline; // Disabled state
      case 'arrived': // Ride - arrived at pickup
        return colorScheme.tertiary;
      case 'ready_for_pickup': // Ride - ready to pickup customer
        return colorScheme.primary;
      case 'picking_up_order': // Food - picked up order
        return colorScheme.secondary;
      case 'in_transit':
        return colorScheme.error;
      default:
        return colorScheme.outline;
    }
  }

  Future<void> _handleActionPress() async {
    if (_isUpdatingStatus || _booking == null) {
      debugLog('⚠️ Cannot handle action - isUpdating: $_isUpdatingStatus, booking: ${_booking != null}');
      return;
    }
    
    debugLog('🎯 Handling action press - Current status: ${_booking!.status}');
    
    String newStatus;
    bool requiresProximityCheck = false;
    
    final serviceType = _booking!.serviceType;
    
    // ═══════════════════════════════════════════════
    // Status flow แยกตาม serviceType
    // ═══════════════════════════════════════════════
    // RIDE:   accepted/driver_accepted → arrived → in_transit → completed
    // PARCEL: accepted/driver_accepted → arrived → in_transit → completed
    // FOOD:   driver_accepted/accepted → arrived_at_merchant → (wait) → ready_for_pickup → picking_up_order → in_transit → completed
    // ═══════════════════════════════════════════════
    
    if (serviceType == 'food') {
      // ─── Food flow ───
      switch (_booking!.status) {
        case 'accepted':
        case 'driver_accepted':
          newStatus = 'arrived_at_merchant';
          requiresProximityCheck = true;
          break;
        case 'arrived_at_merchant':
          // Disabled: merchant must mark food ready first
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('กรุณารอร้านค้ากดอาหารพร้อมก่อน'),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        case 'ready_for_pickup':
          newStatus = 'picking_up_order';
          requiresProximityCheck = true;
          break;
        case 'picking_up_order':
          newStatus = 'in_transit';
          break;
        case 'in_transit':
          newStatus = 'completed';
          requiresProximityCheck = true;
          break;
        default:
          debugLog('⚠️ Unknown food status: ${_booking!.status}');
          _showErrorSnackBar('สถานะไม่ถูกต้อง: ${_booking!.status}');
          return;
      }
    } else {
      // ─── Ride / Parcel flow ───
      switch (_booking!.status) {
        case 'accepted':
        case 'driver_accepted':
          newStatus = 'arrived';
          requiresProximityCheck = true;
          break;
        case 'arrived':
          newStatus = 'in_transit'; // Start trip immediately
          break;
        case 'in_transit':
          newStatus = 'completed';
          requiresProximityCheck = true;
          break;
        default:
          debugLog('⚠️ Unknown ride/parcel status: ${_booking!.status}');
          _showErrorSnackBar('สถานะไม่ถูกต้อง: ${_booking!.status}');
          return;
      }
    }
    
    // Perform proximity check if required
    if (requiresProximityCheck) {
      final isWithinRange = await _checkProximity();
      if (!isWithinRange) {
        return; // Don't proceed if not within range
      }
    }
    
    debugLog('🔄 Updating status from ${_booking!.status} to $newStatus');
    _updateJobStatus(newStatus);
  }

  Future<bool> _checkProximity() async {
    try {
      debugLog('📍 Checking proximity to target location...');
      
      // Get current driver position
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugLog('📍 Driver current position: ${currentPosition.latitude}, ${currentPosition.longitude}');
      
      // Determine target location based on service type and status
      double targetLat;
      double targetLng;
      String locationName;
      
      final status = _booking!.status;
      final serviceType = _booking!.serviceType;

      if (status == 'in_transit') {
        // ALL service types - check distance to destination (customer) before completing
        targetLat = _booking!.destLat;
        targetLng = _booking!.destLng;
        locationName = 'จุดหมายลูกค้า';
        debugLog('📍 Target: Customer destination (${targetLat}, ${targetLng})');
      } else if (serviceType == 'food' && status == 'driver_accepted') {
        // Food - check distance to merchant (origin) when arriving
        targetLat = _booking!.originLat;
        targetLng = _booking!.originLng;
        locationName = 'ร้านค้า';
        debugLog('📍 Target: Merchant location (${targetLat}, ${targetLng})');
      } else if (serviceType == 'food' && status == 'ready_for_pickup') {
        // Food - check distance to merchant (origin) when picking up order
        targetLat = _booking!.originLat;
        targetLng = _booking!.originLng;
        locationName = 'ร้านค้า';
        debugLog('📍 Target: Merchant location for pickup (${targetLat}, ${targetLng})');
      } else if (serviceType == 'ride' && status == 'accepted') {
        // Ride - check distance to pickup location (origin)
        targetLat = _booking!.originLat;
        targetLng = _booking!.originLng;
        locationName = 'จุดรับผู้โดยสาร';
        debugLog('📍 Target: Pickup location (${targetLat}, ${targetLng})');
      } else if (serviceType == 'parcel' && (status == 'accepted' || status == 'driver_accepted')) {
        // Parcel - check distance to pickup (origin)
        targetLat = _booking!.originLat;
        targetLng = _booking!.originLng;
        locationName = 'จุดรับพัสดุ';
        debugLog('📍 Target: Parcel pickup location (${targetLat}, ${targetLng})');
      } else if (serviceType == 'parcel' && status == 'ready_for_pickup') {
        // Parcel - check distance to pickup (origin) before starting delivery
        targetLat = _booking!.originLat;
        targetLng = _booking!.originLng;
        locationName = 'จุดรับพัสดุ';
        debugLog('📍 Target: Parcel pickup for delivery (${targetLat}, ${targetLng})');
      } else {
        debugLog('⚠️ Unexpected service type or status for proximity check');
        return true; // Allow if not a case we're checking
      }
      
      // Calculate distance using Geolocator
      final distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLat,
        targetLng,
      );
      
      debugLog('📏 Distance to $locationName: ${distanceInMeters.toStringAsFixed(1)}m (allowed: ${kAllowedRadiusMeters}m)');
      
      if (distanceInMeters <= kAllowedRadiusMeters) {
        debugLog('✅ Driver is within allowed radius');
        return true;
      } else {
        debugLog('❌ Driver is too far from $locationName');
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(
                Icons.location_searching,
                color: Theme.of(context).colorScheme.tertiary,
                size: 48,
              ),
              title: const Text('อยู่ไกลเกินไป'),
              content: Text(
                'กรุณาเข้าใกล้จุดหมายมากขึ้น\n\n'
                'ระยะทางปัจจุบัน: ${distanceInMeters.toStringAsFixed(0)} เมตร\n'
                'ระยะทางที่อนุญาต: ${kAllowedRadiusMeters.toStringAsFixed(0)} เมตร',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ตกลง'),
                ),
              ],
            ),
          );
        }
        return false;
      }
    } catch (e) {
      debugLog('❌ Error checking proximity: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถตรวจสอบตำแหน่ง: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // Allow action to proceed if we can't verify location (fail-safe)
      return true;
    }
  }

  /// เปิดแชทกับลูกค้า
  Future<void> _openChat() async {
    if (_booking == null) return;
    final driverId = AuthService.userId;
    if (driverId == null || _booking!.customerId.isEmpty) {
      _showErrorSnackBar('ไม่สามารถเปิดแชทได้');
      return;
    }

    try {
      final chatService = ChatService();
      final room = await chatService.getOrCreateBookingChatRoom(
        bookingId: _booking!.id,
        customerId: _booking!.customerId,
        driverId: driverId,
      );
      if (room != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: _booking!.id,
              chatRoomId: room.id,
              otherPartyName: _customerName,
              roomType: 'booking',
            ),
          ),
        );
      } else {
        _showErrorSnackBar('ไม่สามารถเปิดห้องแชทได้');
      }
    } catch (e) {
      debugLog('❌ Error opening chat: $e');
      _showErrorSnackBar('เกิดข้อผิดพลาดในการเปิดแชท');
    }
  }

  /// แสดงรายการอาหารที่ลูกค้าสั่ง
  Future<void> _showOrderItemsDialog() async {
    if (_booking == null) return;
    try {
      final items = await SupabaseService.client
          .from('booking_items')
          .select('*')
          .eq('booking_id', _booking!.id);

      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;

      final orderItems = List<Map<String, dynamic>>.from(items);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.restaurant_menu, color: colorScheme.tertiary, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('รายการอาหาร', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: orderItems.isEmpty
              ? const Text('ไม่พบรายการอาหาร', style: TextStyle(fontSize: 16))
              : SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: orderItems.map((item) {
                        final name = item['name'] ?? item['item_name'] ?? 'ไม่ระบุ';
                        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                        final price = (item['price'] as num?)?.toDouble() ?? 0;
                        final options = item['options'];
                        final selectedOptions = item['selected_options'];
                        final specialInstructions = item['special_instructions'] as String?;

                        // Parse options from either 'options' or 'selected_options'
                        final List<Map<String, dynamic>> parsedOptions = [];
                        final rawOpts = selectedOptions ?? options;
                        if (rawOpts != null && rawOpts is List) {
                          for (final opt in rawOpts) {
                            if (opt is Map) {
                              parsedOptions.add(Map<String, dynamic>.from(opt));
                            } else if (opt is String) {
                              parsedOptions.add({'name': opt});
                            }
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colorScheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('x$qty', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.tertiary, fontSize: 15)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                                  Text('฿${(price * qty).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.tertiary, fontSize: 16)),
                                ],
                              ),
                              if (parsedOptions.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ตัวเลือก:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
                                      const SizedBox(height: 4),
                                      ...parsedOptions.map((opt) {
                                        final optName = opt['name']?.toString() ?? '';
                                        final optPrice = (opt['price'] as num?)?.toDouble() ?? 0;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 2),
                                          child: Row(
                                            children: [
                                              Text('  • ', style: TextStyle(color: colorScheme.tertiary, fontSize: 14)),
                                              Expanded(child: Text(optName, style: TextStyle(fontSize: 14, color: colorScheme.onSurface))),
                                              if (optPrice > 0)
                                                Text('+฿${optPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: colorScheme.tertiary, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                              if (specialInstructions != null && specialInstructions.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.note_alt_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(specialInstructions, style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic))),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ปิด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugLog('❌ Error fetching order items: $e');
      _showErrorSnackBar('ไม่สามารถโหลดรายการอาหาร');
    }
  }

  /// โทรหาลูกค้า
  Future<void> _callCustomer() async {
    if (_customerPhone == 'ไม่ระบุ' || _customerPhone.isEmpty) {
      _showErrorSnackBar('ไม่พบเบอร์โทรลูกค้า');
      return;
    }
    final uri = Uri.parse('tel:$_customerPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackBar('ไม่สามารถโทรออกได้');
      }
    } catch (e) {
      _showErrorSnackBar('เกิดข้อผิดพลาดในการโทร');
    }
  }

  /// ข้อความสถานะปัจจุบันสำหรับแถบสถานะ (แยกตาม serviceType)
  String _getStatusBarText() {
    final status = _booking?.status ?? 'unknown';
    final serviceType = _booking?.serviceType ?? 'ride';
    switch (status) {
      case 'accepted':
      case 'driver_accepted':
        if (serviceType == 'food') return 'กำลังไปร้านอาหาร';
        if (serviceType == 'parcel') return 'กำลังไปรับพัสดุ';
        return 'กำลังไปรับผู้โดยสาร';
      case 'arrived_at_merchant':
        if (serviceType == 'food') return 'ถึงร้านแล้ว รออาหาร';
        return 'ถึงจุดรับแล้ว';
      case 'arrived':
        if (serviceType == 'food') return 'ถึงร้านแล้ว';
        if (serviceType == 'parcel') return 'ถึงจุดรับพัสดุแล้ว';
        return 'ถึงจุดรับลูกค้าแล้ว';
      case 'ready_for_pickup':
        if (serviceType == 'food') return 'อาหารพร้อมแล้ว';
        if (serviceType == 'parcel') return 'พร้อมส่งพัสดุ';
        return 'พร้อมรับผู้โดยสาร';
      case 'picking_up_order':
        if (serviceType == 'food') return 'รับอาหารแล้ว';
        return 'รับของแล้ว';
      case 'in_transit':
        if (serviceType == 'food') return 'กำลังส่งอาหาร...';
        if (serviceType == 'parcel') return 'กำลังส่งพัสดุ...';
        return 'กำลังเดินทาง...';
      case 'completed':
        return 'ส่งเสร็จแล้ว';
      default:
        return 'กำลังดำเนินการ';
    }
  }

  /// ไอคอนสถานะปัจจุบัน
  IconData _getStatusIcon() {
    final status = _booking?.status ?? 'unknown';
    switch (status) {
      case 'accepted':
      case 'driver_accepted':
        return Icons.directions_car_rounded;
      case 'arrived_at_merchant':
      case 'arrived':
        return Icons.location_on_rounded;
      case 'ready_for_pickup':
      case 'picking_up_order':
        return Icons.inventory_2_rounded;
      case 'in_transit':
        return Icons.delivery_dining_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  /// สีของปุ่ม action หลัก
  Color _getMainActionColor() {
    final colorScheme = Theme.of(context).colorScheme;
    final status = _booking?.status ?? 'unknown';
    switch (status) {
      case 'accepted':
      case 'driver_accepted':
        return AppTheme.accentBlue;
      case 'arrived_at_merchant':
        return colorScheme.outline; // Food only: disabled waiting for merchant
      case 'arrived':
        return colorScheme.tertiary; // Ride/parcel: start trip
      case 'ready_for_pickup':
        return colorScheme.secondary; // Food only: pick up order
      case 'picking_up_order':
        return colorScheme.secondary;
      case 'in_transit':
        return colorScheme.error;
      default:
        return AppTheme.accentBlue;
    }
  }

  /// ไอคอนของปุ่ม action หลัก
  IconData _getMainActionIcon() {
    final status = _booking?.status ?? 'unknown';
    final serviceType = _booking?.serviceType ?? 'ride';
    switch (status) {
      case 'accepted':
      case 'driver_accepted':
        return Icons.location_on_rounded;
      case 'arrived_at_merchant':
        return Icons.hourglass_top_rounded; // Food: waiting
      case 'arrived':
        if (serviceType == 'ride') return Icons.directions_car_rounded;
        return Icons.inventory_2_rounded;
      case 'ready_for_pickup':
        return Icons.shopping_bag_rounded; // Food: pick up
      case 'picking_up_order':
        return Icons.delivery_dining_rounded;
      case 'in_transit':
        return Icons.flag_rounded;
      default:
        return Icons.update_rounded;
    }
  }

  /// ชื่อประเภทบริการ
  String _getServiceTypeName() {
    switch (_booking?.serviceType) {
      case 'food':
        return 'สั่งอาหาร';
      case 'ride':
        return 'เรียกรถ';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return 'บริการ';
    }
  }

  /// ไอคอนประเภทบริการ
  IconData _getServiceTypeIcon() {
    switch (_booking?.serviceType) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'ride':
        return Icons.local_taxi_rounded;
      case 'parcel':
        return Icons.inventory_2_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  Future<bool> _onBackPressed() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ออกจากหน้านำทาง?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('คุณยังมีงานอยู่ งานจะยังคงดำเนินต่อไป'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('อยู่ต่อ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'ย้อนกลับ',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading || _booking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('กำลังโหลด...'),
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: colorScheme.onPrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
          ),
        ),
      );
    }

    final booking = _booking!;
    final distanceText = booking.distanceKm > 0
        ? '${booking.distanceKm.toStringAsFixed(1)} km'
        : '—';
    final showMerchantCallButton = booking.serviceType == 'food' &&
        _merchantPhone.isNotEmpty &&
        !['picking_up_order', 'in_transit', 'completed', 'cancelled']
            .contains(booking.status);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _onBackPressed();
        if (shouldPop && mounted) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const DriverMainScreen()),
            (route) => false,
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('งานที่กำลังดำเนินการ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(OrderCodeFormatter.format(booking.id), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          // ปุ่มโทรหาลูกค้า
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.phone, size: 22),
              onPressed: _callCustomer,
              tooltip: 'โทรหาลูกค้า',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ===== แผนที่ =====
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _initializeMap();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : (_pickupLocation ?? const LatLng(13.7563, 100.5018)),
                    zoom: 14,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  padding: const EdgeInsets.only(bottom: 60),
                ),
                // ปุ่ม Zoom + My Location (ขวาบน)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    children: [
                      _buildMapButton(Icons.my_location, () {
                        if (_currentPosition != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                zoom: 16,
                              ),
                            ),
                          );
                        }
                      }),
                      const SizedBox(height: 8),
                      _buildMapButton(Icons.zoom_out_map, _zoomToFitMarkers),
                    ],
                  ),
                ),
                // ปุ่ม Zoom +/- (ขวาล่าง)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      _buildMapButton(Icons.add, () {
                        _mapController?.animateCamera(CameraUpdate.zoomIn());
                      }),
                      const SizedBox(height: 4),
                      _buildMapButton(Icons.remove, () {
                        _mapController?.animateCamera(CameraUpdate.zoomOut());
                      }),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 72,
                  top: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFloatingInfoChip(
                          _getServiceTypeIcon(),
                          'ประเภท',
                          _getServiceTypeName(),
                          AppTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFloatingInfoChip(
                          Icons.route_rounded,
                          'ระยะทาง',
                          distanceText,
                          colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== Bottom Panel =====
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity == null) return;
              if (details.primaryVelocity! > 120) {
                setState(() => _isInfoPanelCollapsed = true);
              } else if (details.primaryVelocity! < -120) {
                setState(() => _isInfoPanelCollapsed = false);
              }
            },
            child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 56,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() {
                              _isInfoPanelCollapsed = !_isInfoPanelCollapsed;
                            }),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                _isInfoPanelCollapsed
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ─── แถบสถานะ + นำทาง + โทร ───
                    Row(
                      children: [
                        // Status text
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(_getStatusIcon(), size: 18, color: AppTheme.accentBlue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _getStatusBarText(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ปุ่มนำทาง Google Maps
                        _buildActionCircleButton(
                          Icons.navigation_rounded,
                          colorScheme.secondary,
                          _launchGoogleMapsNavigation,
                          tooltip: 'นำทาง',
                        ),
                        const SizedBox(width: 6),
                        // ปุ่มแชท
                        _buildActionCircleButton(
                          Icons.chat_rounded,
                          colorScheme.tertiary,
                          _openChat,
                          tooltip: 'แชทกับลูกค้า',
                        ),
                        const SizedBox(width: 6),
                        // ปุ่มโทร
                        _buildActionCircleButton(
                          Icons.phone_rounded,
                          AppTheme.accentBlue,
                          _callCustomer,
                          tooltip: 'โทรหาลูกค้า',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isUpdatingStatus ? null : _handleActionPress,
                        icon: _isUpdatingStatus
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Icon(_getMainActionIcon(), size: 22),
                        label: Text(
                          _getActionButtonText(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getMainActionColor(),
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    if (_isInfoPanelCollapsed) ...[
                      const SizedBox(height: 2),
                    ] else ...[
                    // ─── ปุ่มดูรายการอาหาร (เฉพาะ food) ───
                    if (booking.serviceType == 'food') ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: _showOrderItemsDialog,
                          icon: Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: colorScheme.tertiary,
                          ),
                          label: Text('ดูรายการอาหาร', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.tertiary.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // ─── ข้อมูลลูกค้า ───
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: colorScheme.primary.withValues(alpha: 0.24),
                            child: Icon(Icons.person, size: 18, color: colorScheme.onPrimary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _customerName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _customerPhone,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onPrimaryContainer
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Mini call button
                          InkWell(
                            onTap: _callCustomer,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.phone,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ─── ร้านค้า (เฉพาะ food) ───
                    if (booking.serviceType == 'food' && _merchantName.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.secondary.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  colorScheme.secondary.withValues(alpha: 0.24),
                              child: Icon(
                                Icons.store,
                                size: 18,
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _merchantName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_merchantPhone.isNotEmpty)
                                    Text(
                                      _merchantPhone,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSecondaryContainer
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (showMerchantCallButton)
                              InkWell(
                                onTap: _callMerchant,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.phone,
                                    size: 16,
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ─── การ์ดการเงิน ───
                    _buildFinancialCard(booking),
                    const SizedBox(height: 10),

                    // ─── ปุ่ม Support Chat + ยกเลิกงาน ───
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openSupportChat,
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: const Text('แจ้งปัญหา', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(
                                color: colorScheme.primary.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUpdatingStatus ? null : _cancelJob,
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('ยกเลิกงาน', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.error,
                              side: BorderSide(
                                color: colorScheme.error.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    ),
    );
  }

  /// ปุ่มกลมบนแผนที่ (my location, zoom, etc.)
  Widget _buildMapButton(IconData icon, VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: colorScheme.onSurface),
        ),
      ),
    );
  }

  /// ปุ่มกลมสำหรับ action (นำทาง, โทร)
  Widget _buildActionCircleButton(IconData icon, Color color, VoidCallback onPressed, {String? tooltip}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 1,
      shape: const CircleBorder(),
      color: color,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: colorScheme.onPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingInfoChip(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: colorScheme.onPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.accentBlue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showCancellationDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.cancel,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: const Text('งานถูกยกเลิก'),
        content: const Text('รายการนี้ถูกยกเลิกแล้ว ระบบจะพากลับหน้าหลักคนขับ'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DriverMainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('กลับหน้าหลัก'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyCustomerStatusUpdate(Map<String, dynamic> booking, String newStatus) async {
    try {
      final customerId = booking['customer_id'] as String?;
      if (customerId == null || customerId.isEmpty) return;

      final statusText = _getStatusTextForCustomer(newStatus);
      await NotificationSender.sendNotification(
        targetUserId: customerId,
        title: 'อัปเดตสถานะงาน',
        body: statusText,
        data: {
          'type': 'booking_status_update',
          'booking_id': booking['id']?.toString() ?? '',
          'status': newStatus,
        },
      );
    } catch (e) {
      debugLog('⚠️ Failed to notify customer status update: $e');
    }
  }

  Future<void> _notifyMerchantDriverArrived(Map<String, dynamic> booking) async {
    try {
      final merchantId = booking['merchant_id'] as String?;
      if (merchantId == null || merchantId.isEmpty) return;

      await NotificationSender.sendNotification(
        targetUserId: merchantId,
        title: 'คนขับถึงร้านแล้ว',
        body: 'คนขับมาถึงร้านแล้ว กรุณาเตรียมส่งมอบอาหาร',
        data: {
          'type': 'driver_arrived_merchant',
          'booking_id': booking['id']?.toString() ?? '',
        },
      );
    } catch (e) {
      debugLog('⚠️ Failed to notify merchant driver arrival: $e');
    }
  }

  String _getStatusTextForCustomer(String status) {
    switch (status) {
      case 'accepted':
        return 'คนขับรับงานแล้ว';
      case 'arrived':
      case 'arrived_at_merchant':
        return 'คนขับถึงจุดรับแล้ว';
      case 'picking_up_order':
        return 'คนขับรับอาหารแล้ว กำลังจัดส่ง';
      case 'in_transit':
        return 'คนขับกำลังเดินทางมาหาคุณ';
      case 'completed':
        return 'งานเสร็จสมบูรณ์แล้ว';
      case 'cancelled':
        return 'งานถูกยกเลิก';
      default:
        return 'สถานะงานอัปเดตเป็น $status';
    }
  }

  void _showErrorSnackBar(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: colorScheme.onError, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showMerchantPaymentDialog() {
    if (_booking == null || !mounted) return;
    final colorScheme = Theme.of(context).colorScheme;
    
    final foodPrice = _booking!.price;
    final merchantChargeRate =
        (_merchantSystemRatePreview + _merchantDriverRatePreview)
            .clamp(0.0, 1.0)
            .toDouble();
    final serviceFee = foodPrice * merchantChargeRate;
    final merchantReceives = foodPrice - serviceFee;

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
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.payments, color: AppTheme.accentBlue, size: 48),
            ),
            const SizedBox(height: 12),
            const Text(
              '💰 จ่ายเงินร้านค้าสำเร็จ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'รับอาหารจากร้านค้าเรียบร้อย\nกรุณาส่งอาหารให้ลูกค้าต่อ',
              style: TextStyle(fontSize: 15, color: colorScheme.onSurface, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.35)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ยอดขาย', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                      Text('฿${foodPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'หักร้าน (${(merchantChargeRate * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(fontSize: 13, color: colorScheme.error),
                      ),
                      Text('-฿${serviceFee.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: colorScheme.error)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('จ่ายร้านค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                      Text('฿${merchantReceives.toStringAsFixed(0)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delivery_dining),
              label: const Text('ส่งอาหารให้ลูกค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    if (_booking == null) return;

    final booking = _booking!;
    final isFood = booking.serviceType == 'food';
    final foodPrice = booking.price;
    final deliveryFee = booking.deliveryFee ?? 0;
    final totalCollect = _netCollectAmount(booking);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('🎉 งานเสร็จสมบูรณ์!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: AppTheme.accentBlue,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'ส่งสำเร็จแล้ว!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('เก็บเงินลูกค้า', '฿${totalCollect.ceil()}', colorScheme.onSurface, isBold: true),
                    if (isFood) ...[
                      const SizedBox(height: 4),
                      _buildSummaryRow('  ค่าอาหาร', '฿${foodPrice.ceil()}', colorScheme.tertiary),
                      _buildSummaryRow('  ค่าส่ง', '฿${deliveryFee.ceil()}', colorScheme.primary),
                    ],
                    if (_couponDiscount > 0) ...[
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        _couponCode != null && _couponCode!.isNotEmpty
                            ? '  ส่วนลดคูปอง ($_couponCode)'
                            : '  ส่วนลดคูปอง',
                        '-฿${_couponDiscount.ceil()}',
                        colorScheme.secondary,
                      ),
                    ],
                    const Divider(height: 16),
                    _buildSummaryRow(
                      'รายได้สุทธิ',
                      '฿${(booking.driverEarnings ?? booking.price).ceil()}',
                      AppTheme.accentBlue,
                      isBold: true,
                      fontSize: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => DriverJobDetailScreen(booking: booking),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      foregroundColor: colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('ดูรายละเอียด'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const DriverMainScreen()),
                        (route) => false,
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('กลับหน้าหลัก'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialCard(Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFood = booking.serviceType == 'food';
    final foodPrice = booking.price;
    final deliveryFee = booking.deliveryFee ?? 0;
    final totalCollect = _netCollectAmount(booking);
    final merchantChargeRate =
        (_merchantSystemRatePreview + _merchantDriverRatePreview)
            .clamp(0.0, 1.0)
            .toDouble();
    final serviceFee = isFood ? foodPrice * merchantChargeRate : 0.0;
    final payToMerchant = isFood ? foodPrice - serviceFee : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // เก็บเงินลูกค้า (ตัวใหญ่)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.payments, color: colorScheme.secondary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'เก็บเงินลูกค้า',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Text(
                '฿${totalCollect.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
          if (isFood) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMiniInfo(
                    'ค่าอาหาร',
                    '฿${foodPrice.toStringAsFixed(0)}',
                    colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniInfo(
                    'ค่าส่ง',
                    '฿${deliveryFee.toStringAsFixed(0)}',
                    colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.secondary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, color: colorScheme.tertiary, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'จ่ายร้านค้า',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '฿${payToMerchant.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Mini info widget
  Widget _buildMiniInfo(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  /// สร้างแถวสรุปรายได้สำหรับ completion dialog
  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 13 : 12,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

}
