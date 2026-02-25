import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../common/services/services.dart';
import '../../../common/models/models.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import '../../../common/services/driver_foreground_service.dart';
import '../../customer/screens/auth/login_screen.dart';
import 'driver_navigation_screen.dart';
import 'profile/driver_profile_screen.dart';

/// Driver Dashboard Screen
///
/// Real-time job feed for drivers
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with WidgetsBindingObserver {
  final user = AuthService.currentUser;
  final ProfileService _profileService = ProfileService();
  // ignore: unused_field
  String? _userRole;
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  bool _isOnline = true; // Online/Offline toggle state
  bool _isRefreshing = false; // Manual refresh state
  List<Booking> _availableJobs = [];
  Stream<List<Booking>>? _jobsStream;
  Timer? _autoRefreshTimer;
  List<Booking> _previousJobs = []; // Track previous jobs for notification

  // Earnings tracking
  double _todayEarnings = 0.0;
  // ignore: unused_field
  double _totalEarnings = 0.0;
  int _todayCompletedJobs = 0;
  bool _isAcceptingJob = false;
  Map<String, double> _couponDiscountByBookingId = {};
  StreamSubscription<Position>? _driverLocationSub;
  DateTime? _lastLocationSyncAt;
  double _driverOrderDetectionRadiusKm = 20.0;
  double? _driverLat;
  double? _driverLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DriverForegroundService.init();
    _loadDriverOrderDetectionRadius();
    _loadDriverProfile();
    _loadUserRole();
    _loadEarningsData(); // Load earnings data
    _setupJobStream();
    _startAutoRefresh();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _isWithinDriverOrderRadius(Map<String, dynamic> bookingJson) {
    if (_driverLat == null || _driverLng == null) {
      return false;
    }

    final originLat = _toDouble(bookingJson['origin_lat']) ??
        _toDouble(bookingJson['originLat']);
    final originLng = _toDouble(bookingJson['origin_lng']) ??
        _toDouble(bookingJson['originLng']);
    if (originLat == null || originLng == null) {
      return false;
    }

    final distanceKm = Geolocator.distanceBetween(
          _driverLat!,
          _driverLng!,
          originLat,
          originLng,
        ) /
        1000;

    return distanceKm <= _driverOrderDetectionRadiusKm;
  }

  Future<void> _loadDriverOrderDetectionRadius() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      _driverOrderDetectionRadiusKm = configService.driverToOrderRadiusKm;
      debugLog(
        '📡 Driver order radius = ${_driverOrderDetectionRadiusKm.toStringAsFixed(1)} km',
      );
      if (mounted) {
        await _manualRefresh();
      }
    } catch (e) {
      _driverOrderDetectionRadiusKm = 20.0;
      debugLog('⚠️ ใช้รัศมีรับงานเริ่มต้น 20 กม.: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _driverLocationSub?.cancel();
    // ไม่ set offline อัตโนมัติ — คนขับต้องกดปุ่มออฟไลน์เอง
    // ยกเว้นกรณี app ถูกปิดจริง (handled by didChangeAppLifecycleState)
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App ถูกปิดหรือไปอยู่ background — ไม่ set offline (เพื่อให้คนขับยังออนไลน์อยู่)
      debugLog('📱 App lifecycle: $state — keeping online status');
    } else if (state == AppLifecycleState.resumed) {
      // กลับมา foreground — ใช้ addPostFrameCallback เพื่อรอ widget tree rebuild ก่อน
      debugLog('📱 App resumed — refreshing status');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_isOnline) {
          unawaited(_updateOnlineStatusInDB(true));
          unawaited(_startDriverLocationTracking(fromResume: true));
          unawaited(DriverForegroundService.start());
        } else {
          unawaited(_stopDriverLocationTracking());
          unawaited(DriverForegroundService.stop());
        }
      });
    }
  }

  bool _truthyDbFlag(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 't';
    }
    return false;
  }

  String _normalizeVehicleType(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final raw = value.trim();
    final lower = raw.toLowerCase();

    if (raw.contains('มอเตอร์') ||
        lower == 'motorcycle' ||
        lower.contains('moto') ||
        lower.contains('bike')) {
      return 'motorcycle';
    }
    if (raw.contains('รถยนต์') ||
        lower == 'car' ||
        lower.contains('car') ||
        lower.contains('sedan')) {
      return 'car';
    }
    return lower;
  }

  String _displayVehicleType(String? value) {
    final normalized = _normalizeVehicleType(value);
    switch (normalized) {
      case 'motorcycle':
        return 'มอเตอร์ไซค์';
      case 'car':
        return 'รถยนต์';
      default:
        return value ?? '';
    }
  }

  Future<bool> _ensureLocationPermission({bool fromResume = false}) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugLog('⚠️ Location service is disabled');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // แสดง Prominent Disclosure ก่อนขอ permission จากระบบ (Google Play Policy)
        // ข้าม disclosure เมื่อกลับมาจาก background (ป้องกัน stale context crash)
        if (!fromResume && mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) {
            debugLog('⚠️ User declined location disclosure');
            return false;
          }
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugLog('⚠️ Location permission is not granted: $permission');
        return false;
      }

      return true;
    } catch (e) {
      debugLog('❌ Failed to check location permission: $e');
      return false;
    }
  }

  Future<void> _startDriverLocationTracking({bool fromResume = false}) async {
    if (!_isOnline) return;

    await _stopDriverLocationTracking();

    final permissionGranted =
        await _ensureLocationPermission(fromResume: fromResume);
    if (!permissionGranted) return;

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _syncDriverLiveLocation(currentPosition, force: true);
    } catch (e) {
      debugLog('⚠️ Cannot fetch initial driver location: $e');
    }

    _driverLocationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(
      (position) {
        if (!_isOnline) return;
        unawaited(_syncDriverLiveLocation(position));
      },
      onError: (error) {
        debugLog('❌ Driver location stream error: $error');
      },
    );

    debugLog('✅ Driver location tracking started');
  }

  Future<void> _stopDriverLocationTracking() async {
    await _driverLocationSub?.cancel();
    _driverLocationSub = null;
    _lastLocationSyncAt = null;
  }

  Future<void> _syncDriverLiveLocation(
    Position position, {
    bool force = false,
  }) async {
    if (!_isOnline) return;

    if (!force && _lastLocationSyncAt != null) {
      final diff = DateTime.now().difference(_lastLocationSyncAt!);
      if (diff.inSeconds < 10) return;
    }

    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      await SupabaseService.client.from('profiles').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'is_online': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      final existing = await SupabaseService.client
          .from('driver_locations')
          .select('driver_id')
          .eq('driver_id', userId)
          .maybeSingle();

      final locationData = {
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'is_online': true,
        'is_available': true,
        'current_booking_id': null,
      };

      if (existing != null) {
        await SupabaseService.client
            .from('driver_locations')
            .update(locationData)
            .eq('driver_id', userId);
      } else {
        await SupabaseService.client.from('driver_locations').insert({
          'driver_id': userId,
          ...locationData,
        });
      }

      _lastLocationSyncAt = DateTime.now();
      _driverLat = position.latitude;
      _driverLng = position.longitude;
      debugLog(
        '📍 Driver live location synced: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugLog('❌ Failed syncing driver live location: $e');
    }
  }

  Future<void> _loadDriverProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();
      final persistedOnline = profile == null
          ? _isOnline
          : (profile.containsKey('is_online')
              ? _truthyDbFlag(profile['is_online'])
              : _isOnline);

      if (mounted) {
        setState(() {
          _driverProfile = profile;
          _isOnline = persistedOnline;
          _driverLat = _toDouble(profile?['latitude']);
          _driverLng = _toDouble(profile?['longitude']);
        });
      }

      await _updateOnlineStatusInDB(_isOnline);
      if (_isOnline) {
        await _startDriverLocationTracking();
        unawaited(DriverForegroundService.start());
      } else {
        await _stopDriverLocationTracking();
        unawaited(DriverForegroundService.stop());
      }

      _setupJobStream();
    } catch (e) {
      debugLog('❌ Error loading driver profile: $e');
    }
  }

  Future<void> _updateOnlineStatusInDB(bool isOnline) async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        debugLog('❌ Cannot update online status — userId is null');
        return;
      }

      debugLog('🔄 Updating online status to: $isOnline for user: $userId');

      // Update profiles table
      await SupabaseService.client.from('profiles').update({
        'is_online': isOnline,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', userId);
      debugLog('  ✅ profiles.is_online = $isOnline');

      // Also update driver_locations table (admin reads from here)
      final existing = await SupabaseService.client
          .from('driver_locations')
          .select('driver_id')
          .eq('driver_id', userId)
          .maybeSingle();

      if (existing != null) {
        await SupabaseService.client.from('driver_locations').update({
          'is_online': isOnline,
          'is_available': isOnline,
          'current_booking_id': null,
        }).eq('driver_id', userId);
      } else {
        await SupabaseService.client.from('driver_locations').insert({
          'driver_id': userId,
          'is_online': isOnline,
          'is_available': isOnline,
          'location_lat': _driverProfile?['latitude'] ?? 0,
          'location_lng': _driverProfile?['longitude'] ?? 0,
          'current_booking_id': null,
        });
      }
      debugLog('  ✅ driver_locations.is_online = $isOnline');

      // Verify the update was saved
      final verify = await SupabaseService.client
          .from('profiles')
          .select('is_online')
          .eq('id', userId)
          .maybeSingle();
      final savedValue = verify?['is_online'];
      if (savedValue != isOnline) {
        debugLog(
            '⚠️ Verification failed! DB has is_online=$savedValue, expected $isOnline');
        debugLog(
            '   This may be caused by missing RLS UPDATE policy on profiles table');
      } else {
        debugLog('✅ Online status verified in DB: $isOnline');
      }
    } catch (e) {
      debugLog('❌ Error updating online status: $e');
      debugLog(
          '   Hint: Run migration 20240226_fix_profiles_driver_locations_rls.sql');
    }
  }

  Future<void> _loadEarningsData() async {
    try {
      final driverId = AuthService.userId;
      if (driverId == null) return;

      // Get today's date range
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      // Fetch completed bookings for earnings
      final response = await SupabaseService.client
          .from('bookings')
          .select('driver_earnings, created_at')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      double todayEarnings = 0.0;
      double totalEarnings = 0.0;

      for (final booking in response) {
        final earnings =
            (booking['driver_earnings'] as num?)?.toDouble() ?? 0.0;
        final createdAt = DateTime.parse(booking['created_at']);

        totalEarnings += earnings;

        if (createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd)) {
          todayEarnings += earnings;
        }
      }

      // Count today's completed jobs
      int todayCompleted = 0;
      for (final booking in response) {
        final createdAt = DateTime.parse(booking['created_at']);
        if (createdAt.isAfter(todayStart) && createdAt.isBefore(todayEnd)) {
          todayCompleted++;
        }
      }

      if (mounted) {
        setState(() {
          _todayEarnings = todayEarnings;
          _totalEarnings = totalEarnings;
          _todayCompletedJobs = todayCompleted;
        });
      }

      debugLog('💰 Driver earnings loaded:');
      debugLog('   └─ Today: ฿${todayEarnings.toStringAsFixed(2)}');
      debugLog('   └─ Total: ฿${totalEarnings.toStringAsFixed(2)}');
    } catch (e) {
      debugLog('❌ Error loading earnings data: $e');
    }
  }

  void _setupJobStream() {
    debugLog('🔄 Setting up real-time job stream...');
    debugLog('🔄 Listening for INSERT and UPDATE events on bookings table...');

    _jobsStream = SupabaseService.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .inFilter('status', [
          'pending', // Ride requests waiting for driver
          'pending_merchant', // Food orders waiting for merchant
          'preparing', // Food orders being prepared
          'matched', // Food orders matched with driver
          'ready_for_pickup', // Food orders ready for pickup
          'accepted', // Ride accepted by driver
          'driver_accepted', // Food accepted by driver
          'arrived', // Driver at pickup location
          'arrived_at_merchant', // Driver at merchant location
          'picking_up_order', // Driver picking up food
          'in_transit' // Driver delivering
        ])
        .order('created_at', ascending: false)
        .execute()
        .map((data) {
          debugLog('📡 ===== STREAM UPDATE RECEIVED =====');
          debugLog('🔍 Raw stream data received: ${data.length} items');
          debugLog('🔍 Timestamp: ${DateTime.now().toIso8601String()}');

          // Debug all items first
          for (var item in data) {
            debugLog(
                '🔍 Raw item: ${item['id']} - Service: ${item['service_type']} - Status: ${item['status']} - Driver: ${item['driver_id']}');
          }

          // Filter for available jobs (both ride and food)
          final driverId = AuthService.userId;
          final myVehicleType =
              _normalizeVehicleType(_driverProfile?['vehicle_type'] as String?);
          debugLog('👤 Driver ID: $driverId, Vehicle: $myVehicleType');

          final availableJobs = data.where((item) {
            // Include ride, food, and parcel services
            final isValidService = item['service_type'] == 'food' ||
                item['service_type'] == 'ride' ||
                item['service_type'] == 'parcel';
            final status = item['status'] as String?;
            final itemDriverId = item['driver_id'] as String?;

            // Exclude cancelled and completed bookings
            if (status == 'cancelled' || status == 'completed') {
              return false;
            }

            // Show jobs that are:
            // 1. Available jobs (pending rides matching vehicle type, pending_merchant/preparing/matched/ready_for_pickup food without driver)
            // 2. Jobs assigned to this driver (any active status)
            // 3. Exclude cancelled and completed bookings
            bool isPendingRide = status == 'pending' &&
                item['service_type'] == 'ride' &&
                itemDriverId == null;
            // Filter ride jobs by vehicle type — only show rides matching this driver's vehicle
            if (isPendingRide && myVehicleType.isNotEmpty) {
              final jobVehicle =
                  _normalizeVehicleType(item['vehicle_type'] as String?);
              if (jobVehicle.isNotEmpty && jobVehicle != myVehicleType) {
                isPendingRide = false;
              }
            }
            final isPendingParcel = status == 'pending' &&
                item['service_type'] == 'parcel' &&
                itemDriverId == null;
            final isAvailableFood = (status == 'pending_merchant' ||
                    status == 'preparing' ||
                    status == 'matched' ||
                    status == 'ready_for_pickup') &&
                item['service_type'] == 'food' &&
                itemDriverId == null;
            final isAssignedToThisDriver =
                itemDriverId?.toString() == driverId?.toString();
            final isUnassignedAvailableJob =
                isPendingRide || isPendingParcel || isAvailableFood;
            final isWithinRadius =
                !isUnassignedAvailableJob || _isWithinDriverOrderRadius(item);

            // When offline: only show jobs already assigned to this driver
            // When online: show all available + assigned jobs
            final shouldShow = isValidService &&
                (_isOnline
                    ? ((isUnassignedAvailableJob && isWithinRadius) ||
                        isAssignedToThisDriver)
                    : isAssignedToThisDriver);

            debugLog(
                '🔍 Job: ${item['id']} - Service: ${item['service_type']} - Status: $status - VehicleType: ${item['vehicle_type']} - ShouldShow: $shouldShow');

            return shouldShow;
          }).toList();

          final jobs =
              availableJobs.map((item) => Booking.fromJson(item)).toList();
          debugLog('📊 Real-time jobs received: ${jobs.length}');
          for (var job in jobs) {
            debugLog(
                '📋 Job: ${job.id} - ${job.serviceType} - ${job.status} - ${job.price}');
          }

          // Update _availableJobs for UI stat cards and check for new jobs
          if (mounted) {
            setState(() {
              _availableJobs = jobs;
            });

            // Load coupon discounts for displayed jobs
            _loadCouponDiscountsForJobs(jobs);

            // Check for new jobs and send notifications
            _checkForNewJobs(jobs);
          }

          return jobs;
        });

    debugLog('✅ Job stream setup complete');
  }

  /// Start auto-refresh timer (10 seconds) - fallback for when realtime stream disconnects
  void _startAutoRefresh() {
    debugLog('🕐 Starting auto-refresh fallback timer (10 seconds)...');

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isRefreshing) {
        _manualRefresh();
      }
    });
  }

  /// Check for new jobs and send notification
  void _checkForNewJobs(List<Booking> currentJobs) {
    if (_previousJobs.isEmpty) {
      // First time loading, set baseline
      _previousJobs = List.from(currentJobs);
      return;
    }

    // Find new jobs (jobs that weren't in previous list)
    final newJobs = currentJobs.where((currentJob) {
      return !_previousJobs
          .any((previousJob) => previousJob.id == currentJob.id);
    }).toList();

    if (newJobs.isNotEmpty && mounted) {
      debugLog('🔔 Found ${newJobs.length} new job(s)');

      for (final newJob in newJobs) {
        _sendNewJobNotification(newJob);
      }

      // Update previous jobs list
      _previousJobs = List.from(currentJobs);
    }
  }

  /// Send notification for new job
  void _sendNewJobNotification(Booking job) {
    debugLog('📢 Sending notification for new job: ${job.id}');

    // Show local notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '🚨 งานใหม่! ${_getJobTypeText(job.serviceType)} - ${_getJobStatusText(job.status)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'ดูงาน',
          textColor: Colors.white,
          onPressed: () {
            // Scroll to top or refresh
            _manualRefresh();
          },
        ),
      ),
    );

    // You could also add sound/vibration here
    debugLog(
        '🔔 New job notification sent: ${job.serviceType} - ${job.status}');
  }

  /// Get job type text in Thai
  String _getJobTypeText(String? serviceType) {
    switch (serviceType) {
      case 'food':
        return 'ส่งอาหาร';
      case 'ride':
        return 'รับส่งผู้โดยสาร';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return 'งานทั่วไป';
    }
  }

  /// Get job status text in Thai
  String _getJobStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'รอคนขับ';
      case 'pending_merchant':
        return 'รอร้านค้ารับ';
      case 'preparing':
        return 'กำลังทำอาหาร';
      case 'matched':
        return 'จับคู่แล้ว';
      case 'ready_for_pickup':
        return 'อาหารพร้อม';
      case 'accepted':
        return 'รับงานแล้ว';
      case 'driver_accepted':
        return 'คนขับรับแล้ว';
      default:
        return status ?? 'ไม่ทราบสถานะ';
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      debugLog('🔄 Manual refresh started...');

      // Refresh jobs stream
      _setupJobStream();

      // Refresh earnings data
      await _loadEarningsData();

      // Small delay to show loading state
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugLog('❌ Manual refresh error: $e');

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadUserRole() async {
    try {
      if (mounted) {
        setState(() {
          _userRole = 'driver';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptJob(String bookingId) async {
    if (_isAcceptingJob) return;

    // Block accepting when offline
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเปิดสถานะออนไลน์ก่อนรับงาน'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isAcceptingJob = true);
    try {
      final driverId = AuthService.userId;
      if (driverId == null) {
        _showErrorDialog('ไม่พบข้อมูลผู้ใช้', 'กรุณาเข้าสู่ระบบใหม่');
        if (mounted) setState(() => _isAcceptingJob = false);
        return;
      }

      debugLog('🚗 Driver accepting job: $bookingId');
      debugLog('👤 Driver ID: $driverId');

      // Use BookingService to accept the job (includes wallet check)
      final bookingService = BookingService();
      await bookingService.acceptBooking(bookingId);

      // Send FCM notifications to customer and merchant
      try {
        final bookingData = await SupabaseService.client
            .from('bookings')
            .select()
            .eq('id', bookingId)
            .single();
        await _notifyCustomerDriverAccepted(bookingData);
        if (bookingData['service_type'] == 'food' &&
            bookingData['merchant_id'] != null) {
          await _notifyMerchantDriverAccepted(bookingData);
        }
      } catch (e) {
        debugLog('⚠️ Failed to send accept notifications: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รับงานแล้ว! กำลังนำทาง...'),
            backgroundColor: Color(0xFF3B82F6),
            duration: Duration(seconds: 2),
          ),
        );

        debugLog(
            '🧭 Navigating to DriverNavigationScreen with bookingId: $bookingId');

        try {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  DriverNavigationScreen(bookingId: bookingId),
            ),
          );
          debugLog('✅ Navigation to DriverNavigationScreen successful');
        } catch (e) {
          debugLog('❌ Navigation error: $e');
          _showErrorDialog(
              'เกิดข้อผิดพลาด', 'ไม่สามารถเปิดหน้านำทางได้: ${e.toString()}');
        }
      }
    } catch (e) {
      debugLog('❌ Failed to accept job: $e');

      // Handle specific wallet balance error
      if (e.toString().contains('ยอดเงินในกระเป๋าไม่พอ')) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.account_balance_wallet,
                  color: Colors.orange, size: 48),
              title: const Text('ยอดเงินไม่เพียงพอ'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('ปิด'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DriverProfileScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('เติมเงิน'),
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorDialog('ไม่สามารถรับงานได้', e.toString());
      }
    } finally {
      if (mounted) setState(() => _isAcceptingJob = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('แดชบอร์ดคนขับ'),
        backgroundColor: const Color(0xFF1E3A8A), // Deep blue
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: InkWell(
              onTap: _toggleOnlineStatus,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOnline
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _isOnline
                        ? Colors.greenAccent.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isOnline ? Icons.toggle_on : Icons.toggle_off,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () async {
              // Navigate to driver profile screen
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DriverProfileScreen(),
                ),
              );

              if (mounted) {
                await _loadDriverProfile();
              }
            },
            tooltip: 'โปรไฟล์',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)), // Blue
              ),
            )
          : RefreshIndicator(
              onRefresh: _manualRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCompactDriverHeader(),
                    const SizedBox(height: 14),

                    // Job Feed Section
                    Row(
                      children: [
                        Text(
                          'รายการงาน',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isRefreshing ? 'กำลังรีเฟรช...' : 'เรียลไทม์',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildJobFeed(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCompactDriverHeader() {
    final driverName = _driverProfile?['full_name'] ?? 'คนขับ';
    final vehicle = _displayVehicleType(_driverProfile?['vehicle_type'] as String?);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.work_outline, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  if (mounted) {
                    await _loadDriverProfile();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'งานรอรับ',
                  '${_availableJobs.length}',
                  Icons.pending_actions,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickStat(
                  'เสร็จวันนี้',
                  '$_todayCompletedJobs',
                  Icons.check_circle,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickStat(
                  'รายได้วันนี้',
                  '฿${_todayEarnings.toStringAsFixed(0)}',
                  Icons.payments,
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleOnlineStatus() {
    if (!mounted) return;

    setState(() {
      _isOnline = !_isOnline;
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline ? 'คุณออนไลน์แล้ว' : 'คุณออฟไลน์แล้ว'),
        backgroundColor: _isOnline ? Colors.green : Colors.grey,
        duration: const Duration(seconds: 2),
      ),
    );

    // Save online status to database
    _updateOnlineStatusInDB(_isOnline);

    if (_isOnline) {
      unawaited(_startDriverLocationTracking());
      unawaited(DriverForegroundService.start());
    } else {
      unawaited(_stopDriverLocationTracking());
      unawaited(DriverForegroundService.stop());
    }

    // Refresh job stream to apply online/offline filter immediately
    _setupJobStream();

    debugLog('🔧 Online status changed to: $_isOnline');
  }

  Widget _buildJobFeed() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<Booking>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugLog('❌ Stream error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            _availableJobs.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)), // Blue
            ),
          );
        }

        // Use _availableJobs if available (from manual refresh), otherwise use stream data
        final jobs =
            _availableJobs.isNotEmpty ? _availableJobs : (snapshot.data ?? []);
        debugLog(
            '📊 Jobs count in UI: ${jobs.length} (from ${_availableJobs.isNotEmpty ? "manual refresh" : "stream"})');

        if (jobs.isEmpty) {
          final isOfflineEmpty = !_isOnline;
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isOfflineEmpty
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOfflineEmpty ? Icons.wifi_off : Icons.work_outline,
                    size: 64,
                    color:
                        isOfflineEmpty ? Colors.grey : const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isOfflineEmpty ? 'คุณอยู่ในโหมดออฟไลน์' : 'ไม่มีงานใหม่',
                  style: TextStyle(
                    fontSize: 20,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOfflineEmpty
                      ? 'เปิดสถานะออนไลน์เพื่อรับงานใหม่'
                      : 'งานใหม่จะปรากฏที่นี่ทันที',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isRefreshing ? null : _manualRefresh,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('รีเฟรช'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6), // Blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: jobs.map((job) => _buildJobCard(job)).toList(),
        );
      },
    );
  }

  Widget _buildJobCard(Booking job) {
    final colorScheme = Theme.of(context).colorScheme;
    // Calculate time elapsed
    final now = DateTime.now();
    final jobTime = job.createdAt;
    final difference = now.difference(jobTime);
    final timeAgo = _formatTimeAgo(difference);

    // Get service icon and color
    final serviceIcon = _getServiceIcon(job.serviceType);
    final serviceColor = _getServiceColor(job.serviceType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Header
            Row(
              children: [
                // Service Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    serviceIcon,
                    color: serviceColor,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),

                // Center: Service Name with Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getJobTypeText(job.serviceType),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: serviceColor,
                        ),
                      ),
                      Text(
                        _getServiceLabel(job.serviceType),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: Time elapsed
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (job.scheduledAt != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.scheduledAt!.isAfter(DateTime.now())
                            ? 'งานนัดเวลา: รับได้ตั้งแต่ ${_formatScheduledDateTime(job.scheduledAt!)}'
                            : 'งานนัดเวลา: ${_formatScheduledDateTime(job.scheduledAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Row 2: Financial Details
            _buildFinancialSummary(job),

            const SizedBox(height: 10),

            // Row 3: Route Details (Step-like UI)
            Column(
              children: [
                // Start Point
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.serviceType == 'food' ? 'ร้านอาหาร' : 'จุดรับ',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            job.serviceType == 'food'
                                ? (job.pickupAddress ?? 'ตำแหน่งร้านอาหาร')
                                : (job.pickupAddress ?? 'ตำแหน่งปัจจุบัน'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Vertical Line
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 2,
                    height: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                ),

                // End Point
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.serviceType == 'food'
                                ? 'ตำแหน่งลูกค้า'
                                : 'จุดหมาย',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            job.destinationAddress ?? 'จุดหมายปลายทาง',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 4: Accept Button or Status
            _buildActionButtons(job),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Booking job) {
    debugLog(
        '🎯 Building action buttons for job: ${job.id} - Status: ${job.status}');
    final isScheduledLocked =
        job.scheduledAt != null && job.scheduledAt!.isAfter(DateTime.now());

    switch (job.status) {
      case 'pending':
        // Show for ride and parcel requests
        if (job.serviceType != 'ride' && job.serviceType != 'parcel') {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isAcceptingJob || isScheduledLocked)
                ? null
                : () => _acceptJob(job.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isScheduledLocked
                  ? 'รับได้เวลา ${_formatScheduledDateTime(job.scheduledAt!)}'
                  : (job.serviceType == 'parcel'
                      ? 'รับงานส่งพัสดุ'
                      : 'รับงานนี้'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'preparing':
        // Only show for food orders
        if (job.serviceType != 'food') {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (_isAcceptingJob || isScheduledLocked)
                ? null
                : () => _acceptJob(job.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              isScheduledLocked
                  ? 'รับได้เวลา ${_formatScheduledDateTime(job.scheduledAt!)}'
                  : 'รับออเดอร์อาหาร',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      case 'matched':
      case 'accepted':
      case 'driver_accepted':
      case 'ready_for_pickup':
      case 'traveling_to_merchant':
      case 'arrived_at_merchant':
      case 'picking_up_order':
      case 'in_transit':
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.blue[600],
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'งานที่ยังไม่เสร็จ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'กำลังดำเนินการ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _navigateToPickup(job.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6), // Blue
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ไปยังหน้านำทาง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _navigateToPickup(String bookingId) async {
    try {
      debugLog('🧭 Navigating to pickup for booking: $bookingId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กำลังไปยังหน้านำทาง...'),
          backgroundColor: const Color(0xFF10B981), // Green
          duration: const Duration(seconds: 2),
        ),
      );

      try {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => DriverNavigationScreen(bookingId: bookingId),
          ),
        );
        debugLog('✅ Navigation to DriverNavigationScreen successful');
      } catch (e) {
        debugLog('❌ Navigation error: $e');
        _showErrorDialog(
            'เกิดข้อผิดพลาด', 'ไม่สามารถเปิดหน้านำทางได้: ${e.toString()}');
      }
    } catch (e) {
      debugLog('❌ Failed to navigate to pickup: $e');
      _showErrorDialog('เกิดข้อผิดพลาด', 'ไม่สามารถนำทางได้: ${e.toString()}');
    }
  }

  // Helper methods
  String _getServiceLabel(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'food':
        return 'ส่งอาหาร';
      case 'ride':
        return 'รับส่งผู้โดยสาร';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return 'งานทั่วไป';
    }
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} นาทีที่แล้ว';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} ชั่วโมงที่แล้ว';
    } else {
      return '${duration.inDays} วันที่แล้ว';
    }
  }

  String _formatScheduledDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return Icons.motorcycle;
      case 'delivery':
      case 'parcel':
        return Icons.local_shipping;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.directions_car;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return Colors.blue;
      case 'delivery':
      case 'parcel':
        return Colors.orange;
      case 'food':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  /// Send notification to customer when driver accepts their order
  Future<void> _notifyCustomerDriverAccepted(
      Map<String, dynamic> booking) async {
    try {
      final customerId = booking['customer_id'] as String?;
      final serviceType = booking['service_type'] as String? ?? 'ride';

      if (customerId == null || customerId.isEmpty) {
        debugLog('❌ No customer ID found in booking');
        return;
      }

      debugLog('📤 Sending notification to customer: $customerId');
      debugLog('🚗 Service type: $serviceType');

      // Get driver profile for notification
      final driverProfile = await _getDriverProfile();

      // Prepare notification content based on service type
      String title;
      String body;

      switch (serviceType.toLowerCase()) {
        case 'food':
          title = '🍔 คนขับรับออเดอร์แล้ว!';
          body = driverProfile != null
              ? 'คนขับ ${driverProfile['full_name'] ?? 'กำลังมา'} กำลังมารับอาหารของคุณ'
              : 'คนขับกำลังมารับอาหารของคุณ';
          break;
        case 'delivery':
        case 'parcel':
          title = '📦 คนขับรับพัสดุแล้ว!';
          body = driverProfile != null
              ? 'คนขับ ${driverProfile['full_name'] ?? 'กำลังมา'} กำลังมารับพัสดุของคุณ'
              : 'คนขับกำลังมารับพัสดุของคุณ';
          break;
        case 'ride':
        case 'taxi':
        default:
          title = '🚗 คนขับรับทริปแล้ว!';
          body = driverProfile != null
              ? 'คนขับ ${driverProfile['full_name'] ?? 'กำลังมา'} กำลังมารับคุณ'
              : 'คนขับกำลังมารับคุณ';
          break;
      }

      // Send notification
      final success = await NotificationSender.sendNotification(
        targetUserId: customerId,
        title: title,
        body: body,
        data: {
          'type': 'driver_accepted',
          'booking_id': booking['id'] as String,
          'driver_id': booking['driver_id'] as String,
          'service_type': serviceType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        debugLog('✅ Notification sent to customer successfully');
      } else {
        debugLog('❌ Failed to send notification to customer');
      }
    } catch (e) {
      debugLog('❌ Error sending notification to customer: $e');
    }
  }

  /// Send notification to merchant when driver accepts food order
  Future<void> _notifyMerchantDriverAccepted(
      Map<String, dynamic> booking) async {
    try {
      final merchantId = booking['merchant_id'] as String?;

      if (merchantId == null || merchantId.isEmpty) {
        debugLog('❌ No merchant ID found in food booking');
        return;
      }

      debugLog('📤 Sending notification to merchant: $merchantId');
      debugLog('🍔 Food order accepted by driver');

      // Get driver profile for notification
      final driverProfile = await _getDriverProfile();

      // Send notification to merchant
      final orderCode = OrderCodeFormatter.formatByServiceType(
        booking['id']?.toString(),
        serviceType: booking['service_type']?.toString(),
      );
      final success = await NotificationSender.sendNotification(
        targetUserId: merchantId,
        title: '🚗 คนขับรับออเดอร์แล้ว!',
        body: driverProfile != null
            ? 'คนขับ ${driverProfile['full_name'] ?? 'กำลังมา'} กำลังมารับอาหารออเดอร์ $orderCode'
            : 'คนขับกำลังมารับอาหารออเดอร์ของคุณ',
        data: {
          'type': 'driver_accepted_food',
          'booking_id': booking['id'] as String,
          'driver_id': booking['driver_id'] as String,
          'merchant_id': merchantId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        debugLog('✅ Notification sent to merchant successfully');
      } else {
        debugLog('❌ Failed to send notification to merchant');
      }
    } catch (e) {
      debugLog('❌ Error sending notification to merchant: $e');
    }
  }

  /// Get current driver profile for notification
  Future<Map<String, dynamic>?> _getDriverProfile() async {
    try {
      final driverId = AuthService.userId;
      if (driverId == null) return null;

      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name, phone_number, license_plate')
          .eq('id', driverId)
          .single();

      return profile;
    } catch (e) {
      debugLog('❌ Error fetching driver profile: $e');
      return null;
    }
  }

  Future<void> _loadCouponDiscountsForJobs(List<Booking> jobs) async {
    if (jobs.isEmpty) return;
    try {
      final ids = jobs.map((j) => j.id).toList();
      final usageRows = await SupabaseService.client
          .from('coupon_usages')
          .select('booking_id, discount_amount')
          .inFilter('booking_id', ids);

      final map = <String, double>{};
      for (final row in usageRows) {
        final bid = row['booking_id'] as String?;
        if (bid == null) continue;
        map[bid] = (row['discount_amount'] as num?)?.toDouble() ?? 0.0;
      }
      if (mounted) {
        setState(() {
          _couponDiscountByBookingId = map;
        });
      }
    } catch (e) {
      debugLog('⚠️ Error loading coupon discounts for dashboard jobs: $e');
    }
  }

  /// สร้างส่วนแสดงรายละเอียดการเงินของงาน
  Widget _buildFinancialSummary(Booking job) {
    final colorScheme = Theme.of(context).colorScheme;
    final couponDiscount = _couponDiscountByBookingId[job.id] ?? 0.0;

    if (job.serviceType == 'food') {
      // Food: แสดง ค่าอาหาร + ค่าส่ง - คูปอง = เก็บลูกค้า
      final foodPrice = job.price;
      final deliveryFee = job.deliveryFee ?? 0;
      final gross = foodPrice + deliveryFee;
      final totalCollect =
          (gross - couponDiscount) < 0 ? 0.0 : (gross - couponDiscount);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Column(
          children: [
            // เก็บลูกค้า (ตัวใหญ่)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'เก็บเงินลูกค้า',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '฿${totalCollect.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // รายละเอียด
            Row(
              children: [
                Expanded(
                  child: _buildMiniDetail('ค่าอาหาร',
                      '฿${foodPrice.toStringAsFixed(0)}', Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniDetail('ค่าส่ง',
                      '฿${deliveryFee.toStringAsFixed(0)}', Colors.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniDetail('ระยะทาง',
                      '${job.distanceKm.toStringAsFixed(1)} กม.', Colors.grey),
                ),
              ],
            ),
            if (couponDiscount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.local_offer, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'ส่วนลดคูปอง -฿${couponDiscount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else {
      // Ride/Parcel: แสดง ค่าบริการ - คูปอง + ระยะทาง
      final netCollect =
          (job.price - couponDiscount) < 0 ? 0.0 : (job.price - couponDiscount);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เก็บเงินลูกค้า',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '฿${netCollect.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${job.distanceKm.toStringAsFixed(1)} กม.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (couponDiscount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.local_offer, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      'ส่วนลดคูปอง -฿${couponDiscount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }

  /// Mini detail widget สำหรับแสดงรายละเอียดย่อย
  Widget _buildMiniDetail(String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _logout() async {
    await SupabaseService.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }
}
