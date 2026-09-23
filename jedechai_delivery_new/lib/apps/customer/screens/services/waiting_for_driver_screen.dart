import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/profile_service.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/services/chat_service.dart';
import '../../../../common/services/admin_line_notification_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/utils/role_amount_calculator.dart';
import '../../../../common/widgets/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../customer_home_screen.dart';
import '../customer_main_screen.dart';
import 'customer_ride_status_screen.dart';

/// Waiting for Driver/Restaurant Screen - Real-time Updates
///
/// Shows real-time updates when driver accepts and updates booking status
/// Also handles food orders waiting for restaurant acceptance
class WaitingForDriverScreen extends StatefulWidget {
  final Booking booking;

  const WaitingForDriverScreen({
    super.key,
    required this.booking,
  });

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseAnimationController;
  late final Animation<double> _pulseAnimation;

  StreamSubscription<List<Map<String, dynamic>>>? _bookingStreamSubscription;
  Timer? _retryTimer;
  Timer? _rideTimeoutTimer;
  bool _isHandlingPriceAdjustment = false;
  bool _isHandlingRideTimeout = false;
  late double _initialQuotedPrice;
  double _couponDiscount = 0;
  static const Duration _rideMatchTimeout = Duration(minutes: 5);

  bool _isDriverFound = false;
  String _driverName = '';
  String _driverPhone = '';

  // Food service specific
  bool get _isFoodService => widget.booking.serviceType == 'food';

  @override
  void initState() {
    super.initState();

    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(
            parent: _pulseAnimationController, curve: Curves.easeInOut));

    _pulseAnimationController.repeat();
    _initialQuotedPrice = widget.booking.price;

    // Listen to real-time booking updates
    _listenToBookingUpdates();
    _fetchCouponDiscount();
    if (!_isFoodService &&
        (widget.booking.status == 'pending' ||
            widget.booking.status == 'searching')) {
      _startRideTimeout();
    }
  }

  Future<void> _fetchCouponDiscount() async {
    try {
      final usage = await SupabaseService.client
          .from('coupon_usages')
          .select('discount_amount')
          .eq('booking_id', widget.booking.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _couponDiscount =
            (usage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
      });
    } catch (e) {
      debugLog('⚠️ Error fetching waiting coupon discount: $e');
    }
  }

  double get _displayAmount => RoleAmountCalculator.netDisplayTotalForService(
        serviceType: widget.booking.serviceType,
        price: widget.booking.price,
        deliveryFee: widget.booking.deliveryFee,
        couponDiscountAmount: _couponDiscount,
      );

  Future<bool> _confirmAdjustedPriceIfNeeded(Booking booking) async {
    if (booking.serviceType != 'ride') return true;
    if (_isHandlingPriceAdjustment) return false;

    final adjustedPrice = booking.price;
    if (adjustedPrice <= _initialQuotedPrice) {
      _initialQuotedPrice = adjustedPrice;
      return true;
    }

    _isHandlingPriceAdjustment = true;

    final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.waitingPriceUpdated),
            content: Text(
              AppLocalizations.of(context)!.waitingPriceAdjustedBody(
                  _initialQuotedPrice.toStringAsFixed(2),
                  adjustedPrice.toStringAsFixed(2)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppLocalizations.of(context)!.waitingCancelJob),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppLocalizations.of(context)!.waitingContinue),
              ),
            ],
          ),
        ) ??
        false;

    if (proceed) {
      _initialQuotedPrice = adjustedPrice;
      _isHandlingPriceAdjustment = false;
      return true;
    }

    try {
      await SupabaseService.client.from('bookings').update({
        'status': 'cancelled',
        'notes':
            '${booking.notes ?? ''} | customer_cancelled_after_price_adjustment',
      }).eq('id', booking.id);
    } catch (e) {
      debugLog('❌ Failed to cancel adjusted booking: $e');
    }

    _isHandlingPriceAdjustment = false;
    if (!mounted) return false;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
      (route) => false,
    );
    return false;
  }

  void _listenToBookingUpdates() {
    debugLog('🔍 Starting to listen for booking updates: ${widget.booking.id}');
    debugLog('🔍 Current booking status: ${widget.booking.status}');
    debugLog('🔍 Current driver_id: ${widget.booking.driverId}');

    _bookingStreamSubscription?.cancel();

    try {
      _bookingStreamSubscription = SupabaseService.client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('id', widget.booking.id)
          .listen(
            (data) {
              debugLog('📡 ===== STREAM UPDATE RECEIVED =====');
              debugLog('📡 Stream update received: ${data.length} items');
              debugLog('📡 Timestamp: ${DateTime.now().toIso8601String()}');

              if (data.isEmpty || !mounted) {
                debugLog('⚠️ Stream data is empty or widget not mounted');
                return;
              }

              final bookingData = data.first;
              _handleBookingUpdate(bookingData);
            },
            onError: (error) {
              debugLog('❌ Stream error: $error');
              debugLog('❌ Stream error type: ${error.runtimeType}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        AppLocalizations.of(context)!.waitingConnectionError),
                    backgroundColor: JdcColors.of(context).brand,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              _retryTimer?.cancel();
              _retryTimer = Timer(Duration(seconds: 3), () {
                if (mounted) {
                  debugLog('🔄 Retrying stream connection...');
                  _listenToBookingUpdates();
                }
              });
            },
            cancelOnError: false,
          );

      debugLog('✅ Stream subscription created successfully');
    } catch (e) {
      debugLog('❌ Failed to create stream subscription: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.wifi_off,
                color: JdcColors.of(context).danger, size: 48),
            title: Text(AppLocalizations.of(context)!.waitingConnectionFailed),
            content: Text(AppLocalizations.of(context)!
                .waitingCannotConnect(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(context)!.waitingOk),
              ),
            ],
          ),
        );
      }
    }
  }

  void _handleBookingUpdate(Map<String, dynamic> bookingData) {
    final status = bookingData['status'] as String?;
    final driverId = bookingData['driver_id'] as String?;
    final colorScheme = Theme.of(context).colorScheme;

    debugLog('🔄 Booking status changed to: $status');
    debugLog('👤 Driver ID: $driverId');
    debugLog('Customer Stream Status: $status');
    debugLog('📋 Full booking data: $bookingData');

    final hasDriver = driverId != null && driverId.toString().isNotEmpty;
    final isTerminalStatus = status == 'completed' || status == 'cancelled';

    // Food service statuses that should navigate to status screen
    final foodActiveStatuses = [
      'preparing',
      'matched',
      'driver_accepted',
      'ready_for_pickup',
      'picking_up_order',
      'in_transit',
      'arrived'
    ];
    final isFoodActive =
        _isFoodService && status != null && foodActiveStatuses.contains(status);

    // Ride service accepted statuses
    final isAcceptedStatus = status == 'accepted' || status == 'matched';

    // Navigate to status screen if driver accepted (ride) or food order is active
    if ((isAcceptedStatus && hasDriver) || isFoodActive) {
      _rideTimeoutTimer?.cancel();
      debugLog('✅ Order active! Status: $status, Driver ID: $driverId');

      if (hasDriver) {
        _fetchDriverInfo(driverId).then((driverInfo) {
          if (!mounted) return;

          if (driverInfo != null) {
            setState(() {
              _isDriverFound = true;
              _driverName = driverInfo['full_name'] ??
                  AppLocalizations.of(context)!.waitingDriverFallback;
              _driverPhone = driverInfo['phone'] ?? '';
            });
          }

          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            final fullBooking =
                await _fetchFullBooking(bookingData['id'] as String);
            if (!mounted || fullBooking == null) return;

            final canContinue =
                await _confirmAdjustedPriceIfNeeded(fullBooking);
            if (!mounted || !canContinue) return;

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => CustomerRideStatusScreen(
                  booking: fullBooking,
                ),
              ),
            );
          });
        }).catchError((error) {
          debugLog('❌ Error fetching driver info: $error');
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            final fullBooking =
                await _fetchFullBooking(bookingData['id'] as String);
            if (!mounted || fullBooking == null) return;

            final canContinue =
                await _confirmAdjustedPriceIfNeeded(fullBooking);
            if (!mounted || !canContinue) return;

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => CustomerRideStatusScreen(
                  booking: fullBooking,
                ),
              ),
            );
          });
        });
      } else {
        // Food order active but no driver yet - still navigate to show status
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          final fullBooking =
              await _fetchFullBooking(bookingData['id'] as String);
          if (!mounted || fullBooking == null) return;

          final canContinue = await _confirmAdjustedPriceIfNeeded(fullBooking);
          if (!mounted || !canContinue) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CustomerRideStatusScreen(
                booking: fullBooking,
              ),
            ),
          );
        });
      }
      return;
    }

    if (isTerminalStatus) {
      _rideTimeoutTimer?.cancel();
    }

    if (status == 'completed') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => CustomerMainScreen()),
        (route) => false,
      );
      return;
    }

    if (status == 'cancelled') {
      if (_isHandlingRideTimeout) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: JdcColors.of(context).dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cancel,
                    color: JdcColors.of(context).danger, size: 48),
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.waitingMerchantRejected,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: JdcColors.of(context).danger),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.waitingMerchantRejectedBody,
            style: TextStyle(
                fontSize: 15, color: colorScheme.onSurface, height: 1.5),
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => CustomerMainScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: JdcColors.of(context).danger,
                  foregroundColor: JdcColors.of(context).surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(AppLocalizations.of(context)!.waitingUnderstood,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _startRideTimeout() {
    _rideTimeoutTimer?.cancel();
    _rideTimeoutTimer = Timer(_rideMatchTimeout, _handleRideTimeout);
  }

  Future<void> _handleRideTimeout() async {
    final latestBooking = await _fetchFullBooking(widget.booking.id);
    if (latestBooking == null || !mounted) return;

    final stillWaiting = latestBooking.serviceType == 'ride' &&
        (latestBooking.status == 'pending' ||
            latestBooking.status == 'searching') &&
        (latestBooking.driverId == null || latestBooking.driverId!.isEmpty);

    if (!stillWaiting) return;

    _isHandlingRideTimeout = true;
    var didCancelBooking = false;
    try {
      final cancelledRows = await SupabaseService.client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'notes':
                '${latestBooking.notes ?? ''} | ride_timeout_no_driver_${DateTime.now().toIso8601String()}',
          })
          .eq('id', latestBooking.id)
          .inFilter('status', ['pending', 'searching'])
          .filter('driver_id', 'is', null)
          .select('id');
      didCancelBooking = cancelledRows.isNotEmpty;
    } catch (e) {
      debugLog('❌ Failed to cancel timed out ride: $e');
    }

    if (!mounted) return;
    if (!didCancelBooking) {
      _isHandlingRideTimeout = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.waitingNoDriverCancelFailed,
          ),
          backgroundColor: JdcColors.of(context).brand,
        ),
      );
      return;
    }

    try {
      await AdminLineNotificationService.notify(
        eventType: 'ride_timeout_no_driver',
        title: 'JDC: ride timeout no driver',
        message:
            'Ride booking ${latestBooking.id} timed out without driver assignment.',
        data: {
          'booking_id': latestBooking.id,
          'customer_id': latestBooking.customerId,
          'service_type': latestBooking.serviceType,
        },
      );
    } catch (e) {
      debugLog('❌ Failed to notify admin about ride timeout: $e');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(context)!.waitingNoDriverTitle),
        content: Text(
          AppLocalizations.of(context)!.waitingNoDriverBody,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _isHandlingRideTimeout = false;
                Navigator.of(ctx).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
                  (route) => false,
                );
              },
              child: Text(AppLocalizations.of(context)!.waitingBackToHome),
            ),
          ),
        ],
      ),
    );
  }

  Future<Booking?> _fetchFullBooking(String bookingId) async {
    try {
      final response = await SupabaseService.client
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();
      return Booking.fromJson(response);
    } catch (e) {
      debugLog('❌ Error fetching full booking: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchDriverInfo(String driverId) async {
    try {
      debugLog('🔍 Fetching driver info for ID: $driverId');

      final profileService = ProfileService();
      final response = await profileService.getProfileById(driverId);

      debugLog('✅ Driver info fetched: $response');
      return response;
    } catch (e) {
      debugLog('❌ Error fetching driver info: $e');
      return null;
    }
  }

  @override
  void dispose() {
    debugLog(
        '🧹 Disposing WaitingForDriverScreen - canceling stream subscription');
    _bookingStreamSubscription?.cancel();
    _bookingStreamSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _rideTimeoutTimer?.cancel();
    _rideTimeoutTimer = null;
    _pulseAnimationController.dispose();
    super.dispose();
  }

  // Wave 1.5 b1food: Customer-WaitingDriver artboard layout
  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final orderId = OrderCodeFormatter.formatByServiceType(
        widget.booking.id, serviceType: widget.booking.serviceType);
    final merchantName = widget.booking.merchantId ?? '';
    final totalAmount = widget.booking.price;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => CustomerMainScreen()),
          (route) => false,
        );
      },
      child: Scaffold(
        backgroundColor: jdc.paper,
        body: SafeArea(
          child: Column(
            children: [
              // Minimal header row: order ID + help
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#$orderId',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: jdc.muted),
                      ),
                    ),
                    TextButton(
                      onPressed: _showInfoDialog,
                      child: Text(l10n.waitingHelpLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: jdc.link)),
                    ),
                  ],
                ),
              ),
              // Center content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 22),
                        // Animated radar icon
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, _) {
                            return SizedBox(
                              width: 156,
                              height: 156,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: jdc.brandSoft,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: jdc.brandLine.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 74,
                                    height: 74,
                                    decoration: BoxDecoration(
                                      color: jdc.panel,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.directions_car_rounded, color: jdc.onPanel, size: 34),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        // Title + subtitle
                        Text(
                          _isDriverFound
                              ? l10n.waitingDriverFound
                              : l10n.waitingSearchingTitle,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: jdc.text),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDriverFound
                              ? l10n.waitingDriverComing
                              : l10n.waitingSearchingBody,
                          style: TextStyle(fontSize: 13, color: jdc.muted, height: 1.7),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        // Progress dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) {
                            final filled = _isDriverFound ? true : i == 0;
                            return Container(
                              width: 34,
                              height: 4,
                              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                              decoration: BoxDecoration(
                                color: filled ? jdc.brand : jdc.trackEmpty,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 22),
                        // Order info card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: jdc.surface,
                            border: Border.all(color: jdc.line),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: jdc.brandSoft,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: const GrayscaleLogoPlaceholder(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      merchantName.isNotEmpty ? merchantName : l10n.foodSvcRestaurantFallback,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jdc.text),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _isFoodService ? l10n.waitingForMerchantDots : l10n.waitingSearchingForDriver,
                                      style: TextStyle(fontSize: 12, color: jdc.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '฿${totalAmount.ceil()}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: jdc.text),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    if (_isDriverFound) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _showContactDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: jdc.cta,
                            foregroundColor: jdc.onCta,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.headset_mic_rounded, size: 18),
                          label: Text(l10n.waitingContactDriver, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _showCancelDialog,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: jdc.dangerLine),
                          foregroundColor: jdc.dangerInk,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(l10n.waitingCancelOrder, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.waitingCancelNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: jdc.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.waitingContactDriver),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  Icon(Icons.phone, color: JdcColors.of(context).successInk),
              title: Text(AppLocalizations.of(context)!.waitingPhoneCall),
              subtitle: Text(_driverPhone),
              onTap: () {
                Navigator.of(context).pop();
                _makePhoneCall(_driverPhone);
              },
            ),
            ListTile(
              leading: Icon(Icons.chat, color: JdcColors.of(context).infoInk),
              title: Text(AppLocalizations.of(context)!.waitingChatWithDriver),
              subtitle: Text(AppLocalizations.of(context)!.waitingChatInApp),
              onTap: () {
                Navigator.of(context).pop();
                _openChat();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.waitingClose),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .waitingCannotCall(phoneNumber))),
        );
      }
    }
  }

  Future<void> _openChat() async {
    try {
      final customerId = AuthService.userId;
      if (customerId == null) return;
      final chatService = ChatService();
      final room = await chatService.getOrCreateBookingChatRoom(
        bookingId: widget.booking.id,
        customerId: customerId,
        driverId: widget.booking.driverId,
      );
      if (room != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: widget.booking.id,
              chatRoomId: room.id,
              otherPartyName: _driverName,
              roomType: 'booking',
            ),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error opening chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.waitingCannotOpenChat)),
        );
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.waitingCancelBookingTitle),
        content: Text(AppLocalizations.of(context)!.waitingCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.waitingNo),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final bookingService = BookingService();
                await bookingService.cancelBooking(widget.booking.id,
                    reason: 'customer_cancelled_while_waiting');
                debugLog('✅ Booking cancelled: ${widget.booking.id}');

                // Navigate back to home
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => CustomerHomeScreen(),
                    ),
                  );
                }
              } catch (e) {
                debugLog('❌ Error cancelling booking: $e');
                if (mounted) {
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (mounted) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          icon: Icon(Icons.error_outline,
                              color: JdcColors.of(context).danger, size: 48),
                          title: Text(AppLocalizations.of(context)!
                              .waitingCancelFailed),
                          content: Text(AppLocalizations.of(context)!
                              .waitingCancelError(e.toString())),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child:
                                  Text(AppLocalizations.of(context)!.waitingOk),
                            ),
                          ],
                        ),
                      );
                    }
                  });
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: JdcColors.of(context).danger,
            ),
            child: Text(AppLocalizations.of(context)!.waitingCancel),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.waitingBookingInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.waitingOrderCode(
                  OrderCodeFormatter.formatByServiceType(widget.booking.id,
                      serviceType: widget.booking.serviceType)),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!
                .waitingType(widget.booking.serviceType)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!
                .waitingPrice(_displayAmount.ceil().toString())),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!
                .waitingStatus(widget.booking.status)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.waitingClose),
          ),
        ],
      ),
    );
  }
}
