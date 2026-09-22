import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../theme/jdc_layout.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../../common/services/services.dart';
import '../../../common/models/models.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/services/driver_foreground_service.dart';
import '../../../common/utils/driver_job_visibility_policy.dart';
import '../../../common/utils/notification_payload_policy.dart';
import '../../../common/utils/app_time.dart';
import '../../../common/utils/role_amount_calculator.dart';
import '../../customer/screens/auth/login_screen.dart';
import 'driver_navigation_screen.dart';
import 'driver_service_type_settings.dart';
import 'driver_performance_screen.dart';
import 'driver_shift_screen.dart';
import 'profile/driver_profile_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Driver Dashboard Screen
///
/// Real-time job feed for drivers
class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final user = AuthService.currentUser;
  final ProfileService _profileService = ProfileService();
  // ignore: unused_field
  String? _userRole;
  Map<String, dynamic>? _driverProfile;
  bool _isLoading = true;
  bool _isOnline = true; // Online/Offline toggle state
  bool _isRefreshing = false; // Manual refresh state
  List<Booking> _availableJobs = [];
  StreamSubscription<List<Booking>>? _jobStreamSubscription;
  bool _jobStreamConnecting = false;
  Object? _jobStreamError;
  Timer? _autoRefreshTimer;
  Timer? _heartbeatTimer;
  List<Booking> _previousJobs = []; // Track previous jobs for notification
  final Set<String> _seenNotifiedJobIds = {};

  // Animation for online indicator pulse
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // Earnings tracking
  double _todayEarnings = 0.0;
  // ignore: unused_field
  double _totalEarnings = 0.0;
  int _todayCompletedJobs = 0;
  Map<String, double> _earningsByType = {};
  bool _isAcceptingJob = false;
  Map<String, double> _couponDiscountByBookingId = {};
  Map<String, String?> _couponCodeByBookingId = {};
  StreamSubscription<Position>? _driverLocationSub;
  DateTime? _lastLocationSyncAt;
  double _driverOrderDetectionRadiusKm = 20.0;
  double? _driverLat;
  double? _driverLng;

  bool _didCheckReferralWalletRewardDialog = false;
  List<String>? _acceptedServiceTypes; // null = accept all service types

  List<Booking> _scheduledJobs = [];
  bool _scheduledJobsLoading = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    WidgetsBinding.instance.addObserver(this);
    DriverForegroundService.init();
    _loadDriverOrderDetectionRadius();
    _loadDriverProfile();
    _loadUserRole();
    _loadEarningsData(); // Load earnings data
    _setupJobStream();
    _startAutoRefresh();
    _loadScheduledJobs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowReferralWalletRewardDialogIfAny();
    });
  }

  Future<void> _checkAndShowReferralWalletRewardDialogIfAny() async {
    if (!mounted) return;
    if (_didCheckReferralWalletRewardDialog) return;
    _didCheckReferralWalletRewardDialog = true;

    final userId = AuthService.userId;
    if (userId == null) return;

    final unread = await NotificationService.getUnreadByTypes(
      userId,
      const [
        'referral_wallet_reward_referee',
        'referral_wallet_reward_referrer',
      ],
      limit: 1,
    );
    if (!mounted) return;
    if (unread.isEmpty) return;

    final n = unread.first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title),
        content: Text(n.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.driverDashOk),
          ),
        ],
      ),
    );

    await NotificationService.markAsRead(n.id);
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
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _heartbeatTimer?.cancel();
    _driverLocationSub?.cancel();
    _jobStreamSubscription?.cancel();
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
          _startHeartbeat();
        } else {
          unawaited(_stopDriverLocationTracking());
          unawaited(DriverForegroundService.stop());
          _stopHeartbeat();
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
        return AppLocalizations.of(context)!.driverDashVehicleMotorcycle;
      case 'car':
        return AppLocalizations.of(context)!.driverDashVehicleCar;
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
        distanceFilter: 30,
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

  // Heartbeat: keeps last_heartbeat_at fresh so pg_cron can auto-offline stale drivers (ISSUE-042)
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!_isOnline) return;
      final userId = AuthService.userId;
      if (userId == null) return;
      try {
        await SupabaseService.client.from('driver_locations').update({
          'is_online': true,
          'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('driver_id', userId);
      } catch (e) {
        debugLog('⚠️ Heartbeat failed: $e');
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
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
      // Compute real availability: online AND no active assigned booking (ISSUE-041)
      final currentDriverId = AuthService.userId;
      final activeStatuses = const {
        'driver_accepted',
        'arrived_at_merchant',
        'picking_up_order',
        'in_transit',
        'arrived',
      };
      final hasActiveBooking = _availableJobs.any((j) =>
          j.driverId == currentDriverId && activeStatuses.contains(j.status));
      final isAvailable = _isOnline && !hasActiveBooking;

      // Update profiles — no device updated_at (ISSUE-046)
      await SupabaseService.client.from('profiles').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'is_online': true,
      }).eq('id', userId);

      // Upsert driver_locations in one round trip (ISSUE-043)
      await SupabaseService.client.from('driver_locations').upsert({
        'driver_id': userId,
        'location_lat': position.latitude,
        'location_lng': position.longitude,
        'is_online': true,
        'is_available': isAvailable,
        'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'driver_id');

      _lastLocationSyncAt = DateTime.now();
      final wasLocationNull = _driverLat == null;
      _driverLat = position.latitude;
      _driverLng = position.longitude;
      debugLog(
        '📍 Driver live location synced: ${position.latitude}, ${position.longitude} available=$isAvailable',
      );
      unawaited(_loadAvailableJobsFromRpc());
      // Rebuild stream on first GPS fix so jobs hidden by driverLocationMissing are re-evaluated (ISSUE-038)
      if (wasLocationNull && mounted) _setupJobStream();
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

      // Load accepted service types
      final rawServiceTypes = _driverProfile?['accepted_service_types'];
      if (rawServiceTypes is List) {
        setState(() {
          _acceptedServiceTypes = rawServiceTypes.cast<String>();
        });
      }

      await _updateOnlineStatusInDB(_isOnline);
      if (_isOnline) {
        await _startDriverLocationTracking();
        unawaited(DriverForegroundService.start());
        _startHeartbeat();
      } else {
        await _stopDriverLocationTracking();
        unawaited(DriverForegroundService.stop());
        _stopHeartbeat();
      }

      _setupJobStream();
    } catch (e) {
      debugLog('❌ Error loading driver profile: $e');
      // Safe default: show offline so driver knows tracking isn't active
      if (mounted) setState(() => _isOnline = false);
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

      // Update profiles table — let DB handle updated_at via DEFAULT/trigger
      await SupabaseService.client.from('profiles').update({
        'is_online': isOnline,
      }).eq('id', userId);
      debugLog('  ✅ profiles.is_online = $isOnline');

      // Use UPSERT only when real coordinates are available so we never write
      // a (0,0) ghost row. When coordinates are unknown, UPDATE the existing
      // row (or no-op if the row doesn't exist yet — GPS sync will create it).
      final lat =
          _driverLat ?? (_driverProfile?['latitude'] as num?)?.toDouble();
      final lng =
          _driverLng ?? (_driverProfile?['longitude'] as num?)?.toDouble();
      final hasRealCoords =
          lat != null && lng != null && !(lat == 0.0 && lng == 0.0);
      if (hasRealCoords) {
        await SupabaseService.client.from('driver_locations').upsert({
          'driver_id': userId,
          'is_online': isOnline,
          'is_available': isOnline,
          'location_lat': lat,
          'location_lng': lng,
          'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'driver_id');
      } else {
        await SupabaseService.client.from('driver_locations').update({
          'is_online': isOnline,
          'is_available': isOnline,
          'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('driver_id', userId);
      }
      debugLog('  ✅ driver_locations.is_online = $isOnline');
    } catch (e) {
      debugLog('❌ Error updating online status: $e');
    }
  }

  Future<void> _loadEarningsData() async {
    try {
      final driverId = AuthService.userId;
      if (driverId == null) return;

      final todayKey = AppTime.bangkokDateKey(DateTime.now());

      // Fetch completed bookings for earnings (include service_type for breakdown)
      final response = await SupabaseService.client
          .from('bookings')
          .select('driver_earnings, created_at, service_type')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      double todayEarnings = 0.0;
      double totalEarnings = 0.0;
      int todayCompleted = 0;
      final byType = <String, double>{};

      for (final booking in response) {
        final earnings =
            (booking['driver_earnings'] as num?)?.toDouble() ?? 0.0;
        final createdAt = AppTime.parseDbTimestamp(booking['created_at']);

        totalEarnings += earnings;

        if (AppTime.bangkokDateKey(createdAt) == todayKey) {
          todayEarnings += earnings;
          todayCompleted++;
          final type = booking['service_type'] as String? ?? 'other';
          byType[type] = (byType[type] ?? 0) + earnings;
        }
      }

      if (mounted) {
        setState(() {
          _todayEarnings = todayEarnings;
          _totalEarnings = totalEarnings;
          _todayCompletedJobs = todayCompleted;
          _earningsByType = byType;
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
    // Cancel old subscription before creating new one (ISSUE-039)
    _jobStreamSubscription?.cancel();
    _jobStreamSubscription = null;

    debugLog('🔄 Setting up real-time job stream...');
    if (mounted)
      setState(() {
        _jobStreamConnecting = true;
        _jobStreamError = null;
      });

    final stream = SupabaseService.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .inFilter('status', [
          'pending',
          'pending_merchant',
          'preparing',
          'matched',
          'ready_for_pickup',
          'accepted',
          'driver_accepted',
          'arrived',
          'arrived_at_merchant',
          'picking_up_order',
          'in_transit',
        ])
        .order('created_at', ascending: false)
        .execute()
        .map((data) {
          debugLog('📡 Stream update: ${data.length} items');
          final driverId = AuthService.userId;
          final myVehicleType =
              _normalizeVehicleType(_driverProfile?['vehicle_type'] as String?);

          final availableJobs = data.where((item) {
            final serviceType = item['service_type'] as String?;
            final status = item['status'] as String?;
            final itemDriverId = item['driver_id'] as String?;
            final isAssignedToThisDriver =
                itemDriverId?.toString() == driverId?.toString();
            final locationReady = _driverLat != null && _driverLng != null;
            final isWithinRadius =
                isAssignedToThisDriver || _isWithinDriverOrderRadius(item);
            final jobVehicle =
                _normalizeVehicleType(item['vehicle_type'] as String?);
            final visibility = DriverJobVisibilityPolicy.evaluate(
              serviceType: serviceType,
              status: status,
              driverId: itemDriverId,
              currentDriverId: driverId,
              isOnline: _isOnline,
              isWithinRadius: isWithinRadius,
              acceptedServiceTypes: _acceptedServiceTypes,
              locationReady: locationReady,
              jobVehicleType: jobVehicle,
              driverVehicleType: myVehicleType,
            );
            debugLog(
                '🔍 Job: ${item['id']} - $serviceType/$status - show:${visibility.visible} reason:${visibility.reason}');
            return visibility.visible;
          }).toList();

          return availableJobs.map((item) => Booking.fromJson(item)).toList();
        });

    _jobStreamSubscription = stream.listen(
      (jobs) {
        debugLog('📊 Real-time jobs: ${jobs.length}');
        if (mounted) {
          setState(() {
            _availableJobs = jobs;
            _jobStreamConnecting = false;
          });
          _loadCouponDiscountsForJobs(jobs);
          _checkForNewJobs(jobs);
        }
      },
      onError: (Object error) {
        debugLog('❌ Stream error: $error');
        if (mounted)
          setState(() {
            _jobStreamConnecting = false;
            _jobStreamError = error;
          });
      },
    );

    debugLog('✅ Job stream setup complete');
  }

  /// Load available jobs using get_nearby_bookings RPC (Postgres proximity filter)
  Future<void> _loadAvailableJobsFromRpc() async {
    if (_driverLat == null || _driverLng == null) return;
    if (!_isOnline) return;

    try {
      final params = <String, dynamic>{
        'p_driver_lat': _driverLat,
        'p_driver_lng': _driverLng,
        'p_radius_km': _driverOrderDetectionRadiusKm,
      };
      if (_acceptedServiceTypes != null) {
        params['p_service_types'] = _acceptedServiceTypes;
      }

      final result = await SupabaseService.client.rpc(
        'get_nearby_bookings',
        params: params,
      );

      final rpcJobs = (result as List)
          .map((item) => Booking.fromJson(item as Map<String, dynamic>))
          .toList();

      final driverId = AuthService.userId;
      final assignedJobs =
          _availableJobs.where((j) => j.driverId == driverId).toList();

      final seenIds = <String>{};
      final merged = <Booking>[];
      for (final j in [...rpcJobs, ...assignedJobs]) {
        if (seenIds.add(j.id)) merged.add(j);
      }

      if (mounted) {
        setState(() => _availableJobs = merged);
        _loadCouponDiscountsForJobs(merged);
        _checkForNewJobs(merged);
      }

      debugLog(
          '📡 RPC nearby jobs: ${rpcJobs.length}, assigned: ${assignedJobs.length}');
    } catch (e) {
      debugLog('❌ Error loading nearby jobs from RPC: $e');
    }
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
      final initialNewJobs = currentJobs
          .where((job) =>
              (job.driverId == null || job.driverId!.isEmpty) &&
              !_seenNotifiedJobIds.contains(job.id))
          .toList();
      for (final job in initialNewJobs) {
        _sendNewJobNotification(job);
      }
      _previousJobs = List.from(currentJobs);
      _seenNotifiedJobIds.addAll(initialNewJobs.map((job) => job.id));
      debugLog(
          '🔔 Initial visible jobs notified: ${initialNewJobs.length}, total visible: ${currentJobs.length}');
      return;
    }

    // Find new jobs (jobs that weren't in previous list)
    final newJobs = currentJobs.where((currentJob) {
      return !_seenNotifiedJobIds.contains(currentJob.id) &&
          !_previousJobs.any((previousJob) => previousJob.id == currentJob.id);
    }).toList();

    if (newJobs.isNotEmpty && mounted) {
      debugLog('🔔 Found ${newJobs.length} new job(s)');

      for (final newJob in newJobs) {
        _sendNewJobNotification(newJob);
      }
    }

    // Always update state so pruning runs even when no new jobs appear
    _previousJobs = List.from(currentJobs);
    final currentIds = currentJobs.map((job) => job.id).toSet();
    _seenNotifiedJobIds
      ..addAll(newJobs.map((job) => job.id))
      ..retainAll(currentIds);
  }

  /// Send notification for new job
  void _sendNewJobNotification(Booking job) {
    debugLog('📢 Sending notification for new job: ${job.id}');

    // Show local notification
    final jdc = context.jdc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.driverDashNewJob(
            _getJobTypeText(job.serviceType), _getJobStatusText(job.status))),
        backgroundColor: jdc.successFill,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.driverDashViewJob,
          textColor: jdc.onCta,
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
    final l10n = AppLocalizations.of(context)!;
    switch (serviceType) {
      case 'food':
        return l10n.driverDashJobFood;
      case 'ride':
        return l10n.driverDashJobRide;
      case 'parcel':
        return l10n.driverDashJobParcel;
      case 'laundry':
        return l10n.driverDashJobLaundry;
      default:
        return l10n.driverDashJobGeneral;
    }
  }

  /// Get job status text in Thai
  String _getJobStatusText(String? status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'pending':
        return l10n.driverDashStatusPending;
      case 'pending_merchant':
        return l10n.driverDashStatusPendingMerchant;
      case 'preparing':
        return l10n.driverDashStatusPreparing;
      case 'matched':
        return l10n.driverDashStatusMatched;
      case 'ready_for_pickup':
        return l10n.driverDashStatusReady;
      case 'accepted':
        return l10n.driverDashStatusAccepted;
      case 'driver_accepted':
        return l10n.driverDashStatusDriverAccepted;
      default:
        return status ?? l10n.driverDashStatusUnknown;
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

      // Load nearby jobs via RPC (proximity filter)
      await _loadAvailableJobsFromRpc();

      // Refresh earnings data
      await _loadEarningsData();

      // Refresh scheduled jobs
      await _loadScheduledJobs();

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
            content: Text(AppLocalizations.of(context)!
                .driverDashErrorGeneric(e.toString())),
            backgroundColor: context.jdc.danger,
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
        SnackBar(
          content: Text(AppLocalizations.of(context)!.driverDashMustOnline),
          backgroundColor: context.jdc.brandOnSoft,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isAcceptingJob = true);
    try {
      final driverId = AuthService.userId;
      if (driverId == null) {
        _showErrorDialog(AppLocalizations.of(context)!.driverDashNoUser,
            AppLocalizations.of(context)!.driverDashPleaseLogin);
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
        final notifRows = await SupabaseService.client
            .from('bookings')
            .select()
            .eq('id', bookingId)
            .limit(1);
        if (notifRows.isNotEmpty) {
          final bookingData = notifRows.first;
          await _notifyCustomerDriverAccepted(bookingData);
          if (bookingData['service_type'] == 'food' &&
              bookingData['merchant_id'] != null) {
            await _notifyMerchantDriverAccepted(bookingData);
          }
        }
      } catch (e) {
        debugLog('⚠️ Failed to send accept notifications: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.driverDashAccepted),
            backgroundColor: context.jdc.successFill,
            duration: const Duration(seconds: 2),
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
          _showErrorDialog(AppLocalizations.of(context)!.driverDashErrorTitle,
              AppLocalizations.of(context)!.driverDashNavError(e.toString()));
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
              icon: Icon(Icons.account_balance_wallet,
                  color: context.jdc.brandOnSoft, size: 48),
              title: Text(
                  AppLocalizations.of(context)!.driverDashInsufficientBalance),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(AppLocalizations.of(context)!.driverDashClose),
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
                  child: Text(AppLocalizations.of(context)!.driverDashTopUp),
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorDialog(
            AppLocalizations.of(context)!.driverDashCannotAccept, e.toString());
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
        icon: Icon(Icons.error_outline, color: context.jdc.danger, size: 48),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.driverDashOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = context.jdc;
    return Scaffold(
      backgroundColor: jdc.paper,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(jdc.cta),
              ),
            )
          : SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroHeader(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _manualRefresh,
                      color: jdc.cta,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: JdcContentFrame(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: JdcSpacing.lg,
                              bottom: JdcSpacing.xxl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildQuickActionRow(),
                                const SizedBox(height: JdcSpacing.lg),
                                _buildJobFeedHeader(),
                                const SizedBox(height: JdcSpacing.lg),
                                _buildJobFeed(),
                                _buildScheduledJobsSection(),
                              ],
                            ),
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

  /// หัวข้อ "รายการงาน" + chip สถานะเรียลไทม์/กำลังรีเฟรช
  Widget _buildJobFeedHeader() {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final refreshing = _isRefreshing || _jobStreamConnecting;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.driverDashJobList,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: JdcSpacing.sm, vertical: JdcSpacing.xs),
          decoration: BoxDecoration(
            color: refreshing ? jdc.infoSoft : jdc.successSoft,
            borderRadius: BorderRadius.circular(JdcRadius.small),
          ),
          child: Text(
            refreshing ? l10n.driverDashRefreshing : l10n.driverDashRealtime,
            style: textTheme.labelMedium
                ?.copyWith(color: refreshing ? jdc.infoInk : jdc.successInk),
          ),
        ),
      ],
    );
  }

  /// แถวปุ่มลัด: ผลงาน / กะงาน
  Widget _buildQuickActionRow() {
    final jdc = context.jdc;
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DriverPerformanceScreen()),
            ),
            icon: Icon(Icons.insights, size: 16, color: jdc.infoInk),
            label: Text(l10n.driverDashQuickPerf),
            style: OutlinedButton.styleFrom(
              foregroundColor: jdc.infoInk,
              side: BorderSide(color: jdc.line),
              padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.sm),
            ),
          ),
        ),
        const SizedBox(width: JdcSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverShiftScreen()),
            ),
            icon: Icon(Icons.schedule, size: 16, color: jdc.successInk),
            label: Text(l10n.driverDashQuickShift),
            style: OutlinedButton.styleFrom(
              foregroundColor: jdc.successInk,
              side: BorderSide(color: jdc.successLine),
              padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.sm),
            ),
          ),
        ),
      ],
    );
  }

  /// หัว hero2 เขียวเข้ม — avatar + ชื่อ + ปุ่ม action, สวิตช์ออนไลน์ และสถิติ 3 ช่อง
  Widget _buildHeroHeader() {
    final driverName = _driverProfile?['full_name'] ??
        AppLocalizations.of(context)!.driverDashDriverDefault;
    final vehicle =
        _displayVehicleType(_driverProfile?['vehicle_type'] as String?);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.xl),
      decoration: BoxDecoration(gradient: context.jdc.hero2),
      child: JdcContentFrame(
        padded: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildHeroAvatar(),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: context.jdc.onPanel),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.jdc.brandHi,
                          fontWeight: FontWeight.w600,
                          fontVariations: const [
                            FontVariation('wght', 600),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ..._heroActionButtons(),
              ],
            ),
            const SizedBox(height: JdcSpacing.lg),
            _buildOnlineSwitch(),
            const SizedBox(height: JdcSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildHeroStat(
                    '${_availableJobs.length}',
                    l10n.driverDashPendingJobs,
                  ),
                ),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                  child: _buildHeroStat(
                    '$_todayCompletedJobs',
                    l10n.driverDashCompletedToday,
                  ),
                ),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                  child: _buildHeroStat(
                    l10n.driverEarningsBaht(
                        RoleAmountCalculator.formatMoney(_todayEarnings)),
                    l10n.driverDashEarningsToday,
                  ),
                ),
              ],
            ),
            if (_earningsByType.isNotEmpty) ...[
              const SizedBox(height: JdcSpacing.md),
              _buildEarningsBreakdown(),
            ],
          ],
        ),
      ),
    );
  }

  /// Avatar มุมซ้ายบน — ใช้รูปโปรไฟล์จริงเมื่อมี avatar_url
  /// ถ้าไม่มีใช้โลโก้ระบบสีเทา
  Widget _buildHeroAvatar() {
    final jdc = context.jdc;
    final avatarUrl = _driverProfile?['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: jdc.panelSoft3,
        shape: BoxShape.circle,
        border: Border.all(color: jdc.panelLine),
      ),
      child: ClipOval(
        child: hasAvatar
            ? AppNetworkImage(
                imageUrl: avatarUrl,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                backgroundColor: jdc.panelSoft3,
              )
            // ไม่มีรูป: โลโก้ระบบสีเทา (มาตรฐานทุกช่องรูป ห้ามใช้ตัวย่อ)
            : GrayscaleLogoPlaceholder(
                width: 42,
                height: 42,
                padding: const EdgeInsets.all(4),
                backgroundColor: jdc.surface,
              ),
      ),
    );
  }

  /// ปุ่มบน hero: ตั้งค่าประเภทงาน / โปรไฟล์ / ออกจากระบบ
  List<Widget> _heroActionButtons() {
    final jdc = context.jdc;
    final l10n = AppLocalizations.of(context)!;

    Widget action(IconData icon, String tooltip, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(left: JdcSpacing.sm),
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(JdcRadius.field),
            child: Container(
              width: JdcTouch.minTarget,
              height: JdcTouch.minTarget,
              decoration: BoxDecoration(
                color: jdc.panelSoft2,
                borderRadius: BorderRadius.circular(JdcRadius.field),
                border: Border.all(color: jdc.panelLine),
              ),
              child: Icon(icon, size: 20, color: jdc.onPanel),
            ),
          ),
        ),
      );
    }

    return [
      // Service type settings button
      action(Icons.tune_rounded, l10n.driverDashServiceTypeSettings, () async {
        final updated = await showModalBottomSheet<List<String>?>(
          context: context,
          isScrollControlled: true,
          builder: (_) => DriverServiceTypeSettings(
            initialServiceTypes: _acceptedServiceTypes,
            driverId: AuthService.userId ?? '',
          ),
        );
        if (updated != null) {
          setState(
              () => _acceptedServiceTypes = updated.isEmpty ? null : updated);
        }
      }),
      // Profile button
      action(Icons.person, l10n.driverDashProfile, () async {
        // Navigate to driver profile screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const DriverProfileScreen(),
          ),
        );

        if (mounted) {
          await _loadDriverProfile();
        }
      }),
      // Logout button
      action(Icons.logout, l10n.driverDashLogout, _logout),
    ];
  }

  /// แผงสวิตช์ออนไลน์/ออฟไลน์ บนพื้น successPanel ขอบ successPanelLine
  Widget _buildOnlineSwitch() {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

    final String subtitle;
    if (!_isOnline) {
      subtitle = l10n.driverDashOfflineHint;
    } else if (_jobStreamConnecting) {
      subtitle = l10n.driverDashRefreshing;
    } else {
      subtitle = l10n.driverDashRealtime;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleOnlineStatus,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: JdcSpacing.lg, vertical: JdcSpacing.md),
          decoration: BoxDecoration(
            color: _isOnline ? jdc.successPanel : jdc.panelSoft,
            borderRadius: BorderRadius.circular(JdcRadius.card),
            border: Border.all(
                color: _isOnline ? jdc.successPanelLine : jdc.panelLine),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isOnline ? jdc.successDot : jdc.panelDim,
                              shape: BoxShape.circle,
                              boxShadow: _isOnline
                                  ? [
                                      BoxShadow(
                                        color: jdc.successDot.withValues(
                                            alpha: _pulseAnim.value * 0.8),
                                        blurRadius: 4 + _pulseAnim.value * 6,
                                        spreadRadius: _pulseAnim.value,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _isOnline
                                ? l10n.driverDashOnline
                                : l10n.driverDashOffline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium
                                ?.copyWith(color: jdc.onPanel),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: _isOnline ? jdc.successOnPanel : jdc.panelDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: JdcSpacing.md),
              // สวิตช์เลื่อนออนไลน์/ออฟไลน์
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 54,
                height: JdcSpacing.xxxl,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: _isOnline ? jdc.successFill : jdc.trackEmpty,
                  borderRadius: BorderRadius.circular(JdcRadius.chip),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment:
                      _isOnline ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration:
                        BoxDecoration(color: jdc.knob, shape: BoxShape.circle),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsBreakdown() {
    final l10n = AppLocalizations.of(context)!;
    final typeInfo = {
      'food': ('🍔', l10n.driverDashEarnBreakdownFood),
      'ride': ('🚗', l10n.driverDashEarnBreakdownRide),
      'parcel': ('📦', l10n.driverDashEarnBreakdownParcel),
    };
    final entries = _earningsByType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (i > 0) children.add(const SizedBox(width: JdcSpacing.lg));
      final info = typeInfo[e.key] ?? ('•', e.key);
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.$1, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: JdcSpacing.xs),
            Text(
              l10n.driverDashEarnBreakdownEntry(
                  info.$2, RoleAmountCalculator.formatMoney(e.value)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: context.jdc.panelDim,
                fontWeight: FontWeight.w500,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md, vertical: JdcSpacing.sm),
      decoration: BoxDecoration(
        color: context.jdc.panelSoft2,
        borderRadius: BorderRadius.circular(JdcRadius.small),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }

  /// ช่องสถิติบนพื้น panelSoft ใน hero
  Widget _buildHeroStat(String value, String label) {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.panelSoft,
        borderRadius: BorderRadius.circular(JdcRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.headlineSmall?.copyWith(color: jdc.onPanel),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(color: jdc.panelDim),
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
    final jdc = context.jdc;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isOnline
            ? AppLocalizations.of(context)!.driverDashNowOnline
            : AppLocalizations.of(context)!.driverDashNowOffline),
        backgroundColor: _isOnline ? jdc.successFill : jdc.dim,
        duration: const Duration(seconds: 2),
      ),
    );

    // Save online status to database
    _updateOnlineStatusInDB(_isOnline);

    if (_isOnline) {
      unawaited(_startDriverLocationTracking());
      unawaited(DriverForegroundService.start());
      _startHeartbeat();
    } else {
      unawaited(_stopDriverLocationTracking());
      unawaited(DriverForegroundService.stop());
      _stopHeartbeat();
    }

    // Refresh job stream to apply online/offline filter immediately
    _setupJobStream();

    debugLog('🔧 Online status changed to: $_isOnline');
  }

  Widget _buildJobFeed() {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    // Using state directly — subscription managed explicitly (ISSUE-039)
    if (_jobStreamError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(JdcSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: jdc.danger),
              const SizedBox(height: JdcSpacing.lg),
              Text(
                'Error: $_jobStreamError',
                style: textTheme.bodyLarge?.copyWith(color: jdc.danger),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_jobStreamConnecting && _availableJobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(JdcSpacing.xxxl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final jobs = _availableJobs;
    debugLog('📊 Jobs count in UI: ${jobs.length}');

    if (jobs.isEmpty) {
      final isOfflineEmpty = !_isOnline;
      return Container(
        padding: const EdgeInsets.all(JdcSpacing.xxxl),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
          boxShadow: jdc.shadowCard,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(JdcSpacing.xxl),
              decoration: BoxDecoration(
                color: isOfflineEmpty ? jdc.sunken : jdc.infoSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOfflineEmpty ? Icons.wifi_off : Icons.search_off_rounded,
                size: 64,
                color: jdc.muted,
              ),
            ),
            const SizedBox(height: JdcSpacing.sm + 2),
            Text(
              isOfflineEmpty
                  ? AppLocalizations.of(context)!.driverDashOfflineTitle
                  : AppLocalizations.of(context)!.driverDashNoJobs,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              isOfflineEmpty
                  ? AppLocalizations.of(context)!.driverDashOfflineHint
                  : AppLocalizations.of(context)!.driverDashNoJobsInRadius(
                      _driverOrderDetectionRadiusKm.toStringAsFixed(0)),
              style: textTheme.bodyMedium?.copyWith(color: jdc.muted),
              textAlign: TextAlign.center,
            ),
            if (!isOfflineEmpty && !_isRefreshing) ...[
              const SizedBox(height: JdcSpacing.xs + 2),
              Text(
                AppLocalizations.of(context)!.driverDashPullToRefresh,
                style:
                    textTheme.bodySmall?.copyWith(fontSize: 13, color: jdc.dim),
              ),
            ],
            const SizedBox(height: JdcSpacing.xl),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _manualRefresh,
              icon: _isRefreshing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(jdc.onCta),
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.driverDashRefresh),
            ),
          ],
        ),
      );
    }

    return Column(
      children: jobs.map((job) => _buildJobCard(job)).toList(),
    );
  }

  /// การ์ดงานใหม่ — ขอบ brand 2px เงา shadowBrandLg หัวการ์ดเป็นแถบ panel
  Widget _buildJobCard(Booking job) {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    // Calculate time elapsed
    final now = DateTime.now();
    final jobTime = job.createdAt;
    final difference = now.difference(jobTime);
    final timeAgo = _formatTimeAgo(difference);

    // Get service icon
    final serviceIcon = _getServiceIcon(job.serviceType);

    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.brand, width: 2),
        boxShadow: jdc.shadowBrandLg,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // แถบหัวการ์ด: ประเภทงาน + เวลาที่ผ่านมา
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: JdcSpacing.lg, vertical: JdcSpacing.md),
            color: jdc.panel,
            child: Row(
              children: [
                Icon(serviceIcon, size: 16, color: jdc.onPanel),
                const SizedBox(width: JdcSpacing.sm),
                Expanded(
                  child: Text(
                    _getJobTypeText(job.serviceType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium
                        ?.copyWith(fontSize: 13, color: jdc.onPanel),
                  ),
                ),
                Text(
                  timeAgo,
                  style: textTheme.titleMedium?.copyWith(color: jdc.brandHi),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(JdcSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // สรุปเงิน
                _buildFinancialSummary(job),
                const SizedBox(height: JdcSpacing.md),

                // แบนเนอร์งานนัดหมาย (ถ้ามี)
                if (job.scheduledAt != null) ...[
                  _buildScheduledBanner(job),
                  const SizedBox(height: JdcSpacing.md),
                ],

                // จุดรับ-จุดส่ง
                _buildRouteSummary(job),

                const SizedBox(height: JdcSpacing.lg),

                // ปุ่มรับงาน / สถานะ
                _buildActionButtons(job),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// แบนเนอร์แจ้งเวลานัดหมายของงาน (ถ้ามี)
  Widget _buildScheduledBanner(Booking job) {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md, vertical: JdcSpacing.sm),
      decoration: BoxDecoration(
        color: jdc.brandSoft,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.brandLine),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 18, color: jdc.brandOnSoft),
          const SizedBox(width: JdcSpacing.sm),
          Expanded(
            child: Text(
              job.scheduledAt!.isAfter(DateTime.now())
                  ? AppLocalizations.of(context)!.driverDashScheduledFrom(
                      _formatScheduledDateTime(job.scheduledAt!))
                  : AppLocalizations.of(context)!.driverDashScheduledAt(
                      _formatScheduledDateTime(job.scheduledAt!)),
              style: textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// ลิสต์จุดรับ-จุดส่ง — วงกลมขอบ cta / เส้น line / ปลายทางสี่เหลี่ยม panel
  Widget _buildRouteSummary(Booking job) {
    final l10n = AppLocalizations.of(context)!;
    final pickupLabel = job.serviceType == 'food'
        ? l10n.driverDashPickupRestaurant
        : l10n.driverDashPickupPoint;
    final destLabel = job.serviceType == 'food'
        ? l10n.driverDashDestCustomer
        : l10n.driverDashDestPoint;
    final pickupAddress = job.serviceType == 'food'
        ? (job.pickupAddress ?? l10n.driverDashPickupFoodFallback)
        : (job.pickupAddress ?? l10n.driverDashPickupRideFallback);
    final destAddress = job.destinationAddress ?? l10n.driverDashDestFallback;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // คอลัมน์หมุดจุดรับ-จุดส่ง
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: JdcSpacing.md,
                  height: JdcSpacing.md,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.jdc.cta, width: 3),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: context.jdc.line,
                    ),
                  ),
                ),
                Container(
                  width: JdcSpacing.md,
                  height: JdcSpacing.md,
                  decoration: BoxDecoration(
                    color: context.jdc.panel,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: JdcSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRouteStop(pickupLabel, pickupAddress),
                const SizedBox(height: JdcSpacing.sm),
                _buildRouteStop(destLabel, destAddress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// จุดแวะหนึ่งจุด (ป้ายกำกับ + ที่อยู่)
  Widget _buildRouteStop(String label, String address) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall,
        ),
        const SizedBox(height: 2),
        Text(
          address,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall,
        ),
      ],
    );
  }

  Widget _buildActionButtons(Booking job) {
    debugLog(
        '🎯 Building action buttons for job: ${job.id} - Status: ${job.status}');
    final isScheduledLocked =
        job.scheduledAt != null && job.scheduledAt!.isAfter(DateTime.now());
    final currentDriverId = AuthService.userId;
    final isMine = job.driverId != null &&
        job.driverId!.isNotEmpty &&
        job.driverId == currentDriverId;

    switch (job.status) {
      case 'pending':
        // Show for ride, parcel, and laundry delivery legs.
        if (job.serviceType != 'ride' &&
            job.serviceType != 'parcel' &&
            job.serviceType != 'laundry') {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isAcceptingJob || isScheduledLocked)
                ? null
                : () => _acceptJob(job.id),
            child: Text(
              isScheduledLocked
                  ? AppLocalizations.of(context)!.driverDashAcceptAt(
                      _formatScheduledDateTime(job.scheduledAt!))
                  : (job.serviceType == 'parcel'
                      ? AppLocalizations.of(context)!.driverDashAcceptParcel
                      : AppLocalizations.of(context)!.driverDashAcceptRide),
            ),
          ),
        );
      case 'preparing':
        // Only show for food orders
        if (job.serviceType != 'food') {
          return const SizedBox.shrink();
        }
        return _buildAcceptFoodButton(job, isScheduledLocked);
      case 'ready_for_pickup':
        // งานอาหาร "พร้อมรับ" ที่ broadcast อยู่ แต่คนขับคนนี้ยังไม่ได้รับงาน
        // (driver_id ว่าง หรือเป็นของคนอื่น) ต้องกด "รับงาน" ก่อน ไม่งั้นเข้าหน้า
        // nav แล้วกด "รับอาหาร" จะ error driver_mismatch (RPC เช็ค driver_id = ตัวเอง)
        if (!isMine && job.serviceType == 'food') {
          return _buildAcceptFoodButton(job, isScheduledLocked);
        }
        return _buildResumeNavCard(job);
      case 'matched':
      case 'accepted':
      case 'driver_accepted':
      case 'traveling_to_merchant':
      case 'arrived_at_merchant':
      case 'picking_up_order':
      case 'in_transit':
        return _buildResumeNavCard(job);
      default:
        return const SizedBox.shrink();
    }
  }

  /// ปุ่ม "รับงาน" สำหรับออเดอร์อาหารที่ยัง broadcast อยู่ (preparing / ready_for_pickup
  /// ที่ยังไม่มีคนขับ) — เรียก accept_booking ก่อนเข้าหน้า nav
  Widget _buildAcceptFoodButton(Booking job, bool isScheduledLocked) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isAcceptingJob || isScheduledLocked)
            ? null
            : () => _acceptJob(job.id),
        child: Text(
          isScheduledLocked
              ? AppLocalizations.of(context)!.driverDashAcceptAt(
                  _formatScheduledDateTime(job.scheduledAt!))
              : AppLocalizations.of(context)!.driverDashAcceptFood,
        ),
      ),
    );
  }

  /// การ์ด "งานที่ทำค้างอยู่" + ปุ่มไปหน้า nav — เฉพาะงานที่คนขับรับแล้ว
  Widget _buildResumeNavCard(Booking job) {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(JdcSpacing.lg),
          decoration: BoxDecoration(
            color: jdc.infoSoft,
            borderRadius: BorderRadius.circular(JdcRadius.small),
            border: Border.all(color: jdc.line),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: jdc.infoInk,
                size: 32,
              ),
              const SizedBox(height: JdcSpacing.sm),
              Text(
                AppLocalizations.of(context)!.driverDashIncompleteJob,
                style: textTheme.titleMedium?.copyWith(color: jdc.infoInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: JdcSpacing.xs),
              Text(
                AppLocalizations.of(context)!.driverDashInProgress,
                style: textTheme.bodyMedium?.copyWith(color: jdc.infoInk),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: JdcSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _navigateToPickup(job.id),
            child: Text(
              AppLocalizations.of(context)!.driverDashGoToNav,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToPickup(String bookingId) async {
    try {
      debugLog('🧭 Navigating to pickup for booking: $bookingId');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.driverDashNavigating),
          backgroundColor: context.jdc.successFill,
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
        _showErrorDialog(AppLocalizations.of(context)!.driverDashErrorTitle,
            AppLocalizations.of(context)!.driverDashNavError(e.toString()));
      }
    } catch (e) {
      debugLog('❌ Failed to navigate to pickup: $e');
      _showErrorDialog(AppLocalizations.of(context)!.driverDashErrorTitle,
          AppLocalizations.of(context)!.driverDashCannotNav(e.toString()));
    }
  }

  // Helper methods
  String _getServiceLabel(String serviceType) {
    final l10n = AppLocalizations.of(context)!;
    switch (serviceType.toLowerCase()) {
      case 'food':
        return l10n.driverDashJobFood;
      case 'ride':
        return l10n.driverDashJobRide;
      case 'parcel':
        return l10n.driverDashJobParcel;
      default:
        return l10n.driverDashJobGeneral;
    }
  }

  String _formatTimeAgo(Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    if (duration.inMinutes < 1) {
      return l10n.driverDashTimeJustNow;
    } else if (duration.inMinutes < 60) {
      return l10n.driverDashTimeMinutes(duration.inMinutes.toString());
    } else if (duration.inHours < 24) {
      return l10n.driverDashTimeHours(duration.inHours.toString());
    } else {
      return l10n.driverDashTimeDays(duration.inDays.toString());
    }
  }

  String _formatScheduledDateTime(DateTime dateTime) {
    return AppTime.formatBangkokDateTime(dateTime);
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

  /// สีตัวอักษร/ไอคอนประจำประเภทงาน (โทนเข้ม อ่านบนพื้นสว่างได้)
  Color _getServiceInkColor(String serviceType) {
    final jdc = context.jdc;
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return jdc.infoInk;
      case 'delivery':
      case 'parcel':
        return jdc.brandOnSoft;
      case 'food':
        return jdc.danger;
      default:
        return jdc.successInk;
    }
  }

  /// สีพื้นอ่อนประจำประเภทงาน (สำหรับวงกลมไอคอน)
  Color _getServiceSoftColor(String serviceType) {
    final jdc = context.jdc;
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return jdc.infoSoft;
      case 'delivery':
      case 'parcel':
        return jdc.brandSoft;
      case 'food':
        return jdc.dangerSoft;
      default:
        return jdc.successSoft;
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

      final l10n = AppLocalizations.of(context)!;
      switch (serviceType.toLowerCase()) {
        case 'food':
          title = l10n.driverDashNotifFoodTitle;
          body = driverProfile != null
              ? l10n.driverDashNotifFoodBody(driverProfile['full_name'] ?? '')
              : l10n.driverDashNotifFoodBodyDefault;
          break;
        case 'delivery':
        case 'parcel':
          title = l10n.driverDashNotifParcelTitle;
          body = driverProfile != null
              ? l10n.driverDashNotifParcelBody(driverProfile['full_name'] ?? '')
              : l10n.driverDashNotifParcelBodyDefault;
          break;
        case 'ride':
        case 'taxi':
        default:
          title = l10n.driverDashNotifRideTitle;
          body = driverProfile != null
              ? l10n.driverDashNotifRideBody(driverProfile['full_name'] ?? '')
              : l10n.driverDashNotifRideBodyDefault;
          break;
      }

      // Send notification
      final success = await NotificationSender.sendNotification(
        targetUserId: customerId,
        title: title,
        body: body,
        data: NotificationPayloadPolicy.buildBookingPayload(
          type: NotificationTypes.customerBookingDriverAssigned,
          recipientRole: NotificationRoles.customer,
          bookingId: booking['id'] as String,
          serviceType: serviceType,
          screen: serviceType == 'ride'
              ? NotificationRouteScreens.customerRideStatus
              : NotificationRouteScreens.customerOrder,
          extra: {
            'legacy_type': 'driver_accepted',
            'driver_id': booking['driver_id'] as String,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
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
      final l10n = AppLocalizations.of(context)!;
      final success = await NotificationSender.sendNotification(
        targetUserId: merchantId,
        title: l10n.driverDashNotifMerchantTitle,
        body: driverProfile != null
            ? l10n.driverDashNotifMerchantBody(
                driverProfile['full_name'] ?? '', orderCode)
            : l10n.driverDashNotifMerchantBodyDefault,
        data: NotificationPayloadPolicy.buildBookingPayload(
          type: NotificationTypes.merchantOrderAdminAction,
          recipientRole: NotificationRoles.merchant,
          bookingId: booking['id'] as String,
          serviceType: booking['service_type']?.toString() ?? 'food',
          screen: NotificationRouteScreens.merchantOrder,
          extra: {
            'legacy_type': 'driver_accepted_food',
            'driver_id': booking['driver_id'] as String,
            'merchant_id': merchantId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
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
          .select('booking_id, discount_amount, coupon_id')
          .inFilter('booking_id', ids);

      final map = <String, double>{};
      final couponIdByBookingId = <String, String?>{};
      for (final row in usageRows) {
        final bid = row['booking_id'] as String?;
        if (bid == null) continue;
        map[bid] = (row['discount_amount'] as num?)?.toDouble() ?? 0.0;
        couponIdByBookingId[bid] = row['coupon_id'] as String?;
      }

      final couponIds = couponIdByBookingId.values
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();
      final couponCodeById = <String, String>{};
      if (couponIds.isNotEmpty) {
        final couponRows = await SupabaseService.client
            .from('coupons')
            .select('id, code')
            .inFilter('id', couponIds);
        for (final r in couponRows) {
          final id = r['id'] as String?;
          final code = r['code'] as String?;
          if (id != null && code != null) {
            couponCodeById[id] = code;
          }
        }
      }

      final codeMap = <String, String?>{};
      for (final entry in couponIdByBookingId.entries) {
        final cid = entry.value;
        codeMap[entry.key] = cid != null ? couponCodeById[cid] : null;
      }

      if (mounted) {
        setState(() {
          _couponDiscountByBookingId = {
            ..._couponDiscountByBookingId,
            ...map,
          };
          _couponCodeByBookingId = {
            ..._couponCodeByBookingId,
            ...codeMap,
          };
        });
      }
    } catch (e) {
      debugLog('⚠️ Error loading coupon discounts for jobs: $e');
    }
  }

  /// สร้างส่วนแสดงรายละเอียดการเงินของงาน
  /// (จำนวนเงินใหญ่ทางซ้าย + chip ระยะทางทางขวา ตาม artboard)
  Widget _buildFinancialSummary(Booking job) {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final couponDiscount = _couponDiscountByBookingId[job.id] ?? 0.0;
    final couponCode = _couponCodeByBookingId[job.id];
    final normalizedCouponCode = couponCode?.trim().toUpperCase();
    final hideCouponBreakdown = Coupon.isSystemCouponCode(normalizedCouponCode);

    final isFood = job.serviceType == 'food';
    final foodPrice = job.price;
    final deliveryFee = job.deliveryFee ?? 0;
    final baseAmount = isFood ? (foodPrice + deliveryFee) : job.price;
    final collect =
        (baseAmount - couponDiscount) < 0 ? 0.0 : (baseAmount - couponDiscount);
    final distanceText =
        l10n.driverDashDistanceKm(job.distanceKm.toStringAsFixed(1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.driverDashCollectCustomer,
                      style: textTheme.bodySmall),
                  Text(
                    RoleAmountCalculator.formatBahtCeil(collect),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.displayLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: JdcSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: JdcSpacing.md, vertical: JdcSpacing.xs),
              decoration: BoxDecoration(
                color: jdc.sunken,
                borderRadius: BorderRadius.circular(JdcRadius.chip),
              ),
              child: Text(
                distanceText,
                style: textTheme.labelMedium,
              ),
            ),
          ],
        ),
        if (isFood) ...[
          const SizedBox(height: JdcSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildMiniDetail(
                  l10n.driverDashFoodCost,
                  RoleAmountCalculator.formatBahtCeil(foodPrice),
                ),
              ),
              const SizedBox(width: JdcSpacing.sm),
              Expanded(
                child: _buildMiniDetail(
                  l10n.driverDashDeliveryFee,
                  RoleAmountCalculator.formatBahtCeil(deliveryFee),
                ),
              ),
              const SizedBox(width: JdcSpacing.sm),
              Expanded(
                child: _buildMiniDetail(
                  l10n.driverDashDistance,
                  distanceText,
                ),
              ),
            ],
          ),
        ],
        if (couponDiscount > 0) ...[
          const SizedBox(height: JdcSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(Icons.local_offer, size: 14, color: jdc.successInk),
              const SizedBox(width: JdcSpacing.xs),
              Expanded(
                child: Text(
                  hideCouponBreakdown
                      ? AppLocalizations.of(context)!.driverDashCouponDiscount(
                          RoleAmountCalculator.ceilBaht(couponDiscount)
                              .toString())
                      : AppLocalizations.of(context)!
                          .driverDashCouponDiscountCode(
                              RoleAmountCalculator.ceilBaht(couponDiscount)
                                  .toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: textTheme.labelMedium?.copyWith(color: jdc.successInk),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Mini detail widget สำหรับแสดงรายละเอียดย่อย
  Widget _buildMiniDetail(String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: textTheme.titleSmall,
        ),
      ],
    );
  }

  Future<void> _loadScheduledJobs() async {
    if (!mounted) return;
    setState(() => _scheduledJobsLoading = true);
    try {
      final result = await SupabaseService.client
          .from('bookings')
          .select()
          .not('scheduled_at', 'is', null)
          .eq('status', 'pending')
          .isFilter('driver_id', null)
          .order('scheduled_at', ascending: true);

      final jobs = (result as List)
          .map((item) => Booking.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _scheduledJobs = jobs;
          _scheduledJobsLoading = false;
        });
      }
      await _loadCouponDiscountsForJobs(jobs);
      debugLog('📅 Scheduled jobs loaded: ${jobs.length}');
    } catch (e) {
      debugLog('❌ Error loading scheduled jobs: $e');
      if (mounted) {
        setState(() => _scheduledJobsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: context.jdc.danger),
        );
      }
    }
  }

  Widget _buildScheduledJobsSection() {
    final jdc = context.jdc;
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: JdcSpacing.xl),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.driverDashScheduledJobs,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: JdcSpacing.sm, vertical: JdcSpacing.xs),
              decoration: BoxDecoration(
                color: jdc.infoSoft,
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
              child: Text(
                '${_scheduledJobs.length}',
                style: textTheme.labelMedium?.copyWith(color: jdc.infoInk),
              ),
            ),
          ],
        ),
        const SizedBox(height: JdcSpacing.md),
        if (_scheduledJobsLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(JdcSpacing.xxl),
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(context.jdc.cta)),
            ),
          )
        else if (_scheduledJobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(JdcSpacing.xxl),
            decoration: BoxDecoration(
              color: jdc.surface,
              borderRadius: BorderRadius.circular(JdcRadius.card),
              border: Border.all(color: jdc.line),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available, size: 40, color: jdc.muted),
                const SizedBox(height: JdcSpacing.sm),
                Text(l10n.driverDashScheduledJobsEmpty,
                    style: textTheme.bodyMedium?.copyWith(color: jdc.muted)),
              ],
            ),
          )
        else
          ...List.generate(_scheduledJobs.length,
              (i) => _buildScheduledJobCard(_scheduledJobs[i])),
      ],
    );
  }

  Widget _buildScheduledJobCard(Booking job) {
    final jdc = context.jdc;
    final textTheme = Theme.of(context).textTheme;
    final serviceIcon = _getServiceIcon(job.serviceType);
    final serviceInk = _getServiceInkColor(job.serviceType);
    final serviceSoft = _getServiceSoftColor(job.serviceType);
    final scheduledAt = job.scheduledAt;
    final couponDiscount = _couponDiscountByBookingId[job.id] ?? 0.0;
    final displayAmount = RoleAmountCalculator.netDisplayTotalForService(
      serviceType: job.serviceType,
      price: job.price,
      deliveryFee: job.deliveryFee,
      couponDiscountAmount: couponDiscount,
    );

    String scheduledText = '-';
    if (scheduledAt != null) {
      final local = AppTime.toBangkok(scheduledAt);
      final l10n = AppLocalizations.of(context)!;
      // ชื่อเดือนย่อตาม locale (ไทย = ม.ค.…ธ.ค., อังกฤษ = Jan…Dec) —
      // index 0 เว้นว่างเพราะ DateTime.month เริ่มนับที่ 1
      final localizedMonths = [
        '',
        l10n.driverDashMonthJan,
        l10n.driverDashMonthFeb,
        l10n.driverDashMonthMar,
        l10n.driverDashMonthApr,
        l10n.driverDashMonthMay,
        l10n.driverDashMonthJun,
        l10n.driverDashMonthJul,
        l10n.driverDashMonthAug,
        l10n.driverDashMonthSep,
        l10n.driverDashMonthOct,
        l10n.driverDashMonthNov,
        l10n.driverDashMonthDec,
      ];
      final day = local.day;
      final month = localizedMonths[local.month];
      // ปี พ.ศ. (+543) ตามพฤติกรรมเดิม — known gap: โหมดอังกฤษยังแสดง พ.ศ.
      final year = local.year + 543;
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      scheduledText = l10n.driverDashScheduledTime(
          day.toString(), month, year.toString(), hour, minute);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.md),
      padding: const EdgeInsets.all(JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(JdcSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: serviceSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(serviceIcon, color: serviceInk, size: 18),
              ),
              const SizedBox(width: JdcSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getServiceLabel(job.serviceType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: jdc.infoInk),
                        const SizedBox(width: JdcSpacing.xs),
                        Expanded(
                          child: Text(
                            scheduledText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall
                                ?.copyWith(color: jdc.infoInk),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                RoleAmountCalculator.formatBahtCeil(displayAmount),
                style: textTheme.headlineSmall?.copyWith(color: jdc.successInk),
              ),
            ],
          ),
          if (job.pickupAddress != null) ...[
            const SizedBox(height: JdcSpacing.sm),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: jdc.muted),
                const SizedBox(width: JdcSpacing.xs),
                Expanded(
                  child: Text(
                    job.pickupAddress ?? '-',
                    style: textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
