import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/services.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/services/chat_service.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/utils/address_formatter.dart';
import '../../../../common/utils/app_time.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/widgets/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cancellation_screen.dart';
import 'customer_ride_status_screen.dart';
import '../../customer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/utils/role_amount_calculator.dart';

/// Customer Order Detail Screen
///
/// Read-only view of order details for customers
class CustomerOrderDetailScreen extends StatefulWidget {
  final Booking booking;

  const CustomerOrderDetailScreen({
    super.key,
    required this.booking,
  });

  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoadingItems = true;
  Map<String, dynamic>? _driverInfo;
  bool _isLoadingDriver = false;
  Map<String, dynamic>? _couponUsage;
  StreamSubscription? _bookingStatusSubscription;
  bool _dialogShown = false;
  Booking? _currentBooking;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    // If already completed or cancelled, don't show dialogs again
    if (['completed', 'cancelled']
        .contains(widget.booking.status.toLowerCase())) {
      _dialogShown = true;
    }
    _fetchOrderItems();
    _fetchCouponUsage();
    _fetchDriverInfo();
    _setupBookingStatusListener();
  }

  @override
  void dispose() {
    _bookingStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrderItems() async {
    try {
      final bookingService = BookingService();
      final response = await bookingService.getBookingItems(widget.booking.id);

      if (mounted) {
        setState(() {
          _orderItems = response;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error fetching order items: $e');
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
        });
      }
    }
  }

  Future<void> _fetchCouponUsage() async {
    try {
      final usage = await SupabaseService.client
          .from('coupon_usages')
          .select('coupon_id, discount_amount')
          .eq('booking_id', widget.booking.id)
          .maybeSingle();

      if (usage == null) {
        if (mounted) setState(() => _couponUsage = null);
        return;
      }

      String? couponCode;
      final couponId = usage['coupon_id'] as String?;
      if (couponId != null && couponId.isNotEmpty) {
        final coupon = await SupabaseService.client
            .from('coupons')
            .select('code, is_system_coupon')
            .eq('id', couponId)
            .maybeSingle();
        couponCode = coupon?['code'] as String?;
        if (mounted) {
          setState(() {
            _couponUsage = {
              ...usage,
              'coupon_code': couponCode,
              'is_system_coupon': coupon?['is_system_coupon'] as bool? ?? false,
            };
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _couponUsage = {
            ...usage,
            'coupon_code': couponCode,
            'is_system_coupon': false,
          };
        });
      }
    } catch (e) {
      debugLog('❌ Error fetching coupon usage: $e');
    }
  }

  Future<void> _fetchDriverInfo() async {
    final currentStatus = _currentBooking?.status ?? widget.booking.status;
    final currentDriverId =
        _currentBooking?.driverId ?? widget.booking.driverId;

    debugLog(
        '🔍 _fetchDriverInfo called - Status: $currentStatus, DriverId: $currentDriverId');

    // Only fetch driver info if order has been accepted by driver
    if (![
      'accepted',
      'driver_accepted',
      'arrived',
      'arrived_at_merchant',
      'ready_for_pickup',
      'picking_up_order',
      'in_transit'
    ].contains(currentStatus)) {
      debugLog('⚠️ Status not in allowed list for driver info');
      return;
    }

    if (currentDriverId == null) {
      debugLog('⚠️ Driver ID is null');
      return;
    }

    try {
      setState(() {
        _isLoadingDriver = true;
      });

      final response = await SupabaseService.client.from('profiles').select('''
            id,
            full_name,
            phone_number,
            avatar_url,
            license_plate
          ''').eq('id', currentDriverId).single();

      if (mounted) {
        setState(() {
          _driverInfo = response;
          _isLoadingDriver = false;
        });
        debugLog(
            '✅ Driver info fetched successfully: ${response['full_name']}');
      }
    } catch (e) {
      debugLog('❌ Error fetching driver info: $e');
      if (mounted) {
        setState(() {
          _isLoadingDriver = false;
        });
      }
    }
  }

  void _setupBookingStatusListener() {
    debugLog(
        '🔔 Setting up booking status listener for booking: ${widget.booking.id}');

    _bookingStatusSubscription = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.booking.id)
        .listen((data) {
          if (data.isEmpty || !mounted) return;

          final bookingData = data.first;
          final newStatus = bookingData['status'] as String? ?? '';
          final oldStatus = _currentBooking?.status;

          // Skip rebuild if nothing changed
          if (newStatus == oldStatus &&
              _currentBooking?.driverId == bookingData['driver_id']) {
            return;
          }

          debugLog('📡 Booking status update: $oldStatus -> $newStatus');

          // Update current booking
          setState(() {
            _currentBooking = Booking.fromJson(bookingData);
          });

          // Refresh driver info if driver is assigned
          if ([
            'accepted',
            'driver_accepted',
            'arrived',
            'arrived_at_merchant',
            'ready_for_pickup',
            'picking_up_order',
            'in_transit'
          ].contains(newStatus)) {
            _fetchDriverInfo();
          }

          // Show completion dialog when order is completed
          if (newStatus == 'completed' &&
              oldStatus != 'completed' &&
              !_dialogShown) {
            _dialogShown = true;
            debugLog('🎉 Order completed - showing completion dialog');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showCompletionDialog();
              }
            });
          }

          // Show cancelled dialog when merchant rejects order
          if (newStatus == 'cancelled' &&
              oldStatus != 'cancelled' &&
              !_dialogShown) {
            _dialogShown = true;
            debugLog('❌ Order cancelled - showing cancellation dialog');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showCancelledByMerchantDialog();
              }
            });
          }
        }, onError: (Object error) {
          // ไม่มี onError สตรีมที่ล้มเหลวจะกลายเป็น unhandled error ทั้งแอป
          // (เช่นตอน session หลุดหรือเน็ตหาย) หน้าจอยังใช้ข้อมูลเดิมต่อได้
          debugLog('❌ Booking status stream error: $error');
        });
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final currentStatus = _currentBooking?.status ?? widget.booking.status;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: jdc.surface,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44, height: 64,
                    alignment: Alignment.center,
                    child: Icon(Icons.chevron_left,
                        size: 21, color: jdc.text),
                  ),
                ),
                // Order code + date
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        OrderCodeFormatter.format(widget.booking.id),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: jdc.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatDateTime(widget.booking.createdAt),
                        style:
                            TextStyle(fontSize: 12, color: jdc.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusBadgeBg(jdc, currentStatus),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _getStatusText(currentStatus),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _statusBadgeInk(jdc, currentStatus),
                    ),
                  ),
                ),
                // Cancel button (only for cancellable statuses)
                if (_canCancelOrder()) ...[
                  GestureDetector(
                    onTap: _showCancelOrderDialog,
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: jdc.dangerSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: jdc.dangerLine),
                      ),
                      child: Text(
                        l10n.orderDetailCancel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: jdc.dangerInk,
                        ),
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfoCard(),
            const SizedBox(height: 14),
            _buildLocationCard(),
            if (_driverInfo != null && _shouldShowDriverInfo()) ...[
              const SizedBox(height: 14),
              _buildDriverInfoCard(),
            ],
            if (_orderItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildOrderItemsCard(),
            ],
            const SizedBox(height: 14),
            _buildPricingCard(),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: jdc.surface,
          border: Border(top: BorderSide(color: jdc.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Help button
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpScreen()),
                ),
                child: Container(
                  width: 118, height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: jdc.line),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.b1orderDetailHelp,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: jdc.text),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Reorder button
              Expanded(
                child: GestureDetector(
                  onTap: _reorder,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: jdc.cta,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: jdc.shadowBrand,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.b1orderDetailReorder,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: jdc.onCta),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getServiceColor(widget.booking.serviceType),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getServiceIcon(widget.booking.serviceType),
                  size: 20,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getServiceTypeText(context, widget.booking.serviceType),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.orderDetailOrderId(
                          OrderCodeFormatter.format(widget.booking.id)),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.access_time,
                  size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              // ข้อความ "สั่งเมื่อ <วันเวลา>" ยาวเกินกรอบบนจอ 360 ถ้าไม่ยืดตามที่ว่าง
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.orderDetailOrderedAt(
                      _formatDateTime(widget.booking.createdAt)),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.orderDetailLocationTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Pickup location (if available)
          if (widget.booking.pickupAddress != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pin_drop,
                    size: 16,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.orderDetailPickup,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatAddress(widget.booking.pickupAddress),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 16,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.orderDetailDestination,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAddress(widget.booking.destinationAddress),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _shouldShowDriverInfo() {
    final currentStatus = _currentBooking?.status ?? widget.booking.status;
    final shouldShow = [
      'accepted',
      'driver_accepted',
      'arrived',
      'arrived_at_merchant',
      'ready_for_pickup',
      'picking_up_order',
      'in_transit',
      'completed'
    ].contains(currentStatus);
    debugLog(
        '🔍 _shouldShowDriverInfo - Status: $currentStatus, ShouldShow: $shouldShow, _driverInfo: ${_driverInfo != null}');
    return shouldShow;
  }

  Widget _buildDriverInfoCard() {
    if (_driverInfo == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.orderDetailDriverTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 12),
          if (_isLoadingDriver)
            Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Column(
              children: [
                // Top row: Avatar + Driver Info
                Row(
                  children: [
                    // Driver Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: JdcColors.of(context).infoInk.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _driverInfo!['avatar_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: AppNetworkImage(
                                imageUrl:
                                    _driverInfo!['avatar_url']?.toString(),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                backgroundColor:
                                    JdcColors.of(context).infoInk.withValues(alpha: 0.1),
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: JdcColors.of(context).infoInk,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Driver Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverInfo!['full_name'] ??
                                AppLocalizations.of(context)!
                                    .orderDetailDriverUnnamed,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (_driverInfo!['phone_number'] != null) ...[
                            Row(
                              children: [
                                Icon(Icons.phone,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _driverInfo!['phone_number'],
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (_driverInfo!['license_plate'] != null) ...[
                            Row(
                              children: [
                                Icon(Icons.directions_car,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _driverInfo!['license_plate'],
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),

                // Bottom row: Action Buttons
                Row(
                  children: [
                    // Track Driver Button
                    Expanded(
                      child: Material(
                        color: JdcColors.of(context).infoInk,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomerRideStatusScreen(
                                  booking: widget.booking,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on,
                                    color: JdcColors.of(context).surface, size: 18),
                                SizedBox(width: 6),
                                Text(
                                    AppLocalizations.of(context)!
                                        .orderDetailTrack,
                                    style: TextStyle(
                                        color: JdcColors.of(context).surface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_driverInfo!['phone_number'] != null) ...[
                      SizedBox(width: 8),
                      // Message Button
                      Expanded(
                        child: Material(
                          color: JdcColors.of(context).infoInk,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openChat(),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble,
                                      color: JdcColors.of(context).surface, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                      AppLocalizations.of(context)!
                                          .orderDetailChat,
                                      style: TextStyle(
                                          color: JdcColors.of(context).surface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Call Button
                      Expanded(
                        child: Material(
                          color: JdcColors.of(context).cta,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final phone =
                                  _driverInfo!['phone_number'] as String;
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!
                                                .orderDetailCannotCall(phone))),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone,
                                      color: JdcColors.of(context).surface, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                      AppLocalizations.of(context)!
                                          .orderDetailCall,
                                      style: TextStyle(
                                          color: JdcColors.of(context).surface,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.orderDetailItemsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingItems)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_orderItems.isEmpty)
            Text(
              AppLocalizations.of(context)!.orderDetailNoItems,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._orderItems.map((item) => Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: JdcColors.of(context).brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.restaurant,
                          color: JdcColors.of(context).brand,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['menu_item']?['name'] ??
                                  item['item_name'] ??
                                  AppLocalizations.of(context)!
                                      .orderDetailItemUnnamed,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (item['quantity'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.of(context)!
                                    .orderDetailQuantity(
                                        item['quantity'].toString()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            // ค้นหาช่วงบรรทัดที่มีการเช็ค if (item['options'] != null ...)
// แล้วแทนที่ด้วย Block นี้ครับ:

                            if (item['options'] != null &&
                                item['options'] is List &&
                                (item['options'] as List).isNotEmpty) ...[
                              SizedBox(height: 4),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: JdcColors.of(context).brand
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppLocalizations.of(context)!
                                          .orderDetailOptionsLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: JdcColors.of(context).brand,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    ...(item['options'] as List).map((option) {
                                      // 🛠️ Logic แกะข้อมูล: รองรับทั้งแบบ String และ JSON Map
                                      String optionName = '';

                                      if (option is Map) {
                                        // กรณีเป็น Object: {"name": "เส้นเล็ก", "price": 0}
                                        optionName = option['name'] ??
                                            option['item_name'] ??
                                            AppLocalizations.of(context)!
                                                .orderDetailOptionDefault;

                                        // (เสริม) ถ้าอยากโชว์ราคาเพิ่ม
                                        // final price = (option['price'] as num?)?.toDouble() ?? 0.0;
                                        // if (price > 0) optionName += ' (+฿$price)';
                                      } else {
                                        // กรณีเป็น String ธรรมดา
                                        optionName = option.toString();
                                      }

                                      return Padding(
                                        padding: EdgeInsets.only(top: 1),
                                        child: Text(
                                          '• $optionName',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: JdcColors.of(context).brand
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item['price'] != null)
                        Text(
                          RoleAmountCalculator.formatBahtCeil(((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1)),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  String _formatAddress(dynamic address) {
    return formatAddressValue(
      address,
      unknownLabel: AppLocalizations.of(context)!.orderDetailAddressUnknown,
      currentLocationLabel:
          AppLocalizations.of(context)!.orderDetailAddressCurrent,
    );
  }

  double _calculateTotalPrice() {
    final booking = _currentBooking ?? widget.booking;
    final couponDiscount =
        (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;

    if (booking.serviceType == 'food') {
      // Food: booking.price = ค่าอาหาร (subtotal รวม options แล้ว)
      // booking.deliveryFee = ค่าจัดส่ง
      // booking_items.price = effective unit price (base + options) — ใช้ booking.price สำหรับ total เพราะแม่นยำกว่า
      final deliveryFee = booking.deliveryFee ?? 0.0;
      final total = booking.price + deliveryFee - couponDiscount;
      return total < 0 ? 0 : total;
    }

    // Ride / Parcel: ใช้ราคาจาก booking โดยตรง
    final total = booking.price - couponDiscount;
    return total < 0 ? 0 : total;
  }

  Widget _buildPricingCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final booking = _currentBooking ?? widget.booking;
    final couponDiscount =
        (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final couponCode = _couponUsage?['coupon_code'] as String?;

    final hideCouponBreakdown =
        (_couponUsage?['is_system_coupon'] as bool?) ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.orderDetailPriceTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (booking.serviceType == 'food') ...[
            // Food items list (if available)
            if (_orderItems.isNotEmpty) ...[
              ..._orderItems.map((item) {
                final itemPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
                final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                final itemTotal = itemPrice * quantity;
                final itemName = item['name'] ??
                    item['item_name'] ??
                    item['menu_item']?['name'] ??
                    AppLocalizations.of(context)!.orderDetailItemUnnamed;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '$itemName x$quantity',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '฿${RoleAmountCalculator.ceilBaht(itemTotal)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
            ],

            // Food cost summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.orderDetailFoodCost,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                Text(
                  '฿${RoleAmountCalculator.ceilBaht(booking.price)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            // Delivery fee
            if (booking.deliveryFee != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.orderDetailDeliveryFee,
                    style:
                        TextStyle(fontSize: 14, color: colorScheme.onSurface),
                  ),
                  Text(
                    '฿${RoleAmountCalculator.ceilBaht(booking.deliveryFee!)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],

            if (couponDiscount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hideCouponBreakdown
                        ? AppLocalizations.of(context)!
                            .orderDetailCouponDiscount
                        : (couponCode != null && couponCode.isNotEmpty
                            ? AppLocalizations.of(context)!
                                .orderDetailCouponDiscountCode(couponCode)
                            : AppLocalizations.of(context)!
                                .orderDetailCouponDiscount),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.secondary,
                    ),
                  ),
                  Text(
                    '-฿${RoleAmountCalculator.ceilBaht(couponDiscount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],

            // Distance
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.orderDetailDistance,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                Text(
                  AppLocalizations.of(context)!.orderDetailDistanceKm(
                      booking.distanceKm.toStringAsFixed(1)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            const Divider(),
          ] else if (booking.serviceType != 'food') ...[
            // Non-food orders show single price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getServiceTypeText(context, booking.serviceType),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '฿${RoleAmountCalculator.ceilBaht(booking.price)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (couponDiscount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hideCouponBreakdown
                        ? AppLocalizations.of(context)!
                            .orderDetailCouponDiscount
                        : (couponCode != null && couponCode.isNotEmpty
                            ? AppLocalizations.of(context)!
                                .orderDetailCouponDiscountCode(couponCode)
                            : AppLocalizations.of(context)!
                                .orderDetailCouponDiscount),
                    style:
                        TextStyle(fontSize: 14, color: colorScheme.secondary),
                  ),
                  Text(
                    '-฿${RoleAmountCalculator.ceilBaht(couponDiscount)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            const Divider(),
          ],

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.orderDetailTotal,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '฿${RoleAmountCalculator.ceilBaht(_calculateTotalPrice())}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: JdcColors.of(context).cta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return AppTime.formatBangkokDateTime(dateTime);
  }

  String _getServiceTypeText(BuildContext context, String serviceType) {
    final l10n = AppLocalizations.of(context)!;
    switch (serviceType) {
      case 'ride':
        return l10n.orderDetailServiceRide;
      case 'food':
        return l10n.orderDetailServiceFood;
      case 'parcel':
        return l10n.orderDetailServiceParcel;
      default:
        return serviceType;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return JdcColors.of(context).infoInk;
      case 'food':
        return JdcColors.of(context).brand;
      case 'parcel':
        return JdcColors.of(context).cta;
      default:
        return JdcColors.of(context).muted;
    }
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return Icons.directions_car;
      case 'food':
        return Icons.restaurant;
      case 'parcel':
        return Icons.local_shipping;
      default:
        return Icons.help_outline;
    }
  }

  /// สั่งซ้ำ: เปิดหน้าร้านเดิมให้ลูกค้าเลือกเมนูใหม่
  /// (ถ้าออเดอร์ไม่มีร้าน เช่น งานส่งพัสดุ จะแจ้งว่าสั่งซ้ำไม่ได้)
  void _reorder() {
    final booking = _currentBooking ?? widget.booking;
    final merchantId = booking.merchantId;
    final l10n = AppLocalizations.of(context)!;
    if (merchantId == null || merchantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.b1orderDetailReorderUnavailable)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantDetailScreen(
          merchantId: merchantId,
          merchantName: (booking.pickupAddress?.isNotEmpty ?? false)
              ? booking.pickupAddress!
              : l10n.foodSvcRestaurantFallback,
        ),
      ),
    );
  }

  /// สีพื้นป้ายสถานะ: สำเร็จ = เขียว, ยกเลิก = แดง, กำลังดำเนินการ = โทนแบรนด์
  Color _statusBadgeBg(JdcColors jdc, String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return jdc.successSoft;
      case 'cancelled':
        return jdc.dangerSoft;
      default:
        return jdc.brandSoft;
    }
  }

  Color _statusBadgeInk(JdcColors jdc, String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return jdc.successInk;
      case 'cancelled':
        return jdc.dangerInk;
      default:
        return jdc.brandOnSoft;
    }
  }

  String _getStatusText(String status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status.toLowerCase()) {
      case 'pending':
        return l10n.orderDetailStatusPending;
      case 'pending_merchant':
        return l10n.orderDetailStatusPendingMerchant;
      case 'preparing':
        return l10n.orderDetailStatusPreparing;
      case 'ready_for_pickup':
        return l10n.orderDetailStatusReady;
      case 'driver_accepted':
        return l10n.orderDetailStatusDriverAccepted;
      case 'accepted':
      case 'confirmed':
        return l10n.orderDetailStatusConfirmed;
      case 'arrived':
      case 'arrived_at_merchant':
        return l10n.orderDetailStatusArrived;
      case 'picking_up_order':
        return l10n.orderDetailStatusPickingUp;
      case 'in_transit':
        return l10n.orderDetailStatusInTransit;
      case 'completed':
        return l10n.orderDetailStatusCompleted;
      case 'cancelled':
        return l10n.orderDetailStatusCancelled;
      default:
        return status;
    }
  }

  void _showCancelledByMerchantDialog() {
    final booking = _currentBooking ?? widget.booking;
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
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JdcColors.of(context).dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel, color: JdcColors.of(context).danger, size: 48),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.orderDetailCancelledTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: JdcColors.of(context).danger,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.orderDetailCancelledBody,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long,
                      color: colorScheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.orderDetailOrderNumber,
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.orderDetailCancelledRetry,
              style:
                  TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => CustomerMainScreen()),
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
              child: Text(AppLocalizations.of(context)!.orderDetailUnderstood,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openChat() async {
    final booking = _currentBooking ?? widget.booking;
    final customerId = AuthService.userId;
    if (customerId == null || booking.driverId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.orderDetailChatError)),
        );
      }
      return;
    }

    try {
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
            builder: (context) => ChatScreen(
              chatRoomId: room.id,
              otherPartyName: _driverInfo?['full_name'] ??
                  AppLocalizations.of(context)!.orderDetailDriverDefault,
              bookingId: booking.id,
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
                  Text(AppLocalizations.of(context)!.orderDetailChatError)),
        );
      }
    }
  }

  void _showCompletionDialog() {
    final booking = _currentBooking ?? widget.booking;
    final bookingId = booking.id;
    final isFood = booking.serviceType == 'food';
    final couponDiscount =
        (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final couponCode = _couponUsage?['coupon_code'] as String?;
    final foodCost = booking.price;
    final deliveryFee = booking.deliveryFee ?? 0.0;
    final grossAmount = isFood ? foodCost + deliveryFee : booking.price;
    final totalAmount =
        (grossAmount - couponDiscount) < 0 ? 0 : (grossAmount - couponDiscount);
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: JdcColors.of(context).cta.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  color: JdcColors.of(context).cta, size: 48),
            ),
            SizedBox(height: 16),
            Text(
              isFood
                  ? AppLocalizations.of(context)!.orderDetailCompletedFood
                  : AppLocalizations.of(context)!.orderDetailCompletedRide,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: JdcColors.of(context).cta),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.orderDetailThankYou,
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              // Order ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long,
                        color: colorScheme.onPrimaryContainer, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.orderDetailOrderNumber,
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              // Total Price with food breakdown
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      JdcColors.of(context).cta,
                      JdcColors.of(context).cta.withValues(alpha: 0.8)
                    ],
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
                            Text(
                                AppLocalizations.of(context)!
                                    .orderDetailTotalAmount,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: JdcColors.of(context).panelDim,
                                    fontWeight: FontWeight.w500)),
                            if (isFood)
                              Text(
                                  AppLocalizations.of(context)!
                                      .orderDetailIncludingDelivery,
                                  style: TextStyle(
                                      fontSize: 12, color: JdcColors.of(context).panelDim)),
                          ],
                        ),
                        Text(
                          '฿${RoleAmountCalculator.ceilBaht(totalAmount)}',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: JdcColors.of(context).surface),
                        ),
                      ],
                    ),
                    if (isFood) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: JdcColors.of(context).surface.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                    AppLocalizations.of(context)!
                                        .orderDetailFoodCost,
                                    style: TextStyle(
                                        fontSize: 11, color: JdcColors.of(context).panelDim)),
                                Text('฿${RoleAmountCalculator.ceilBaht(foodCost)}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: JdcColors.of(context).surface)),
                              ],
                            ),
                            Container(
                                width: 1, height: 24, color: JdcColors.of(context).panelLine),
                            Column(
                              children: [
                                Text(
                                    AppLocalizations.of(context)!
                                        .orderDetailDeliveryFee,
                                    style: TextStyle(
                                        fontSize: 11, color: JdcColors.of(context).panelDim)),
                                Text('฿${RoleAmountCalculator.ceilBaht(deliveryFee)}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: JdcColors.of(context).surface)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (couponDiscount > 0) ...[
                      SizedBox(height: 8),
                      Text(
                        couponCode != null && couponCode.isNotEmpty
                            ? AppLocalizations.of(context)!
                                .orderDetailCouponUsed(couponCode,
                                    RoleAmountCalculator.ceilBaht(couponDiscount).toString())
                            : AppLocalizations.of(context)!
                                .orderDetailCouponUsedNoCode(
                                    RoleAmountCalculator.ceilBaht(couponDiscount).toString()),
                        style: TextStyle(
                          fontSize: 12,
                          color: JdcColors.of(context).surface,
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
                Navigator.of(context).pop(); // ปิด dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => CustomerMainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: JdcColors.of(context).cta,
                foregroundColor: JdcColors.of(context).surface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                AppLocalizations.of(context)!.orderDetailUnderstood,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if order can be cancelled based on current status
  bool _canCancelOrder() {
    final currentStatus = _currentBooking?.status ?? widget.booking.status;

    // Orders that can be cancelled
    final cancellableStatuses = [
      'pending', // Waiting for driver
      'pending_merchant', // Food order waiting for merchant
      'confirmed', // Driver confirmed but not started
    ];

    return cancellableStatuses.contains(currentStatus);
  }

  /// Show cancel order — navigate to CancellationScreen for reason selection
  void _showCancelOrderDialog() {
    final booking = _currentBooking ?? widget.booking;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CancellationScreen(booking: booking),
      ),
    ).then((cancelled) {
      if (cancelled == true && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  /// Cancel the order
  // ignore: unused_element
  Future<void> _cancelOrder() async {
    try {
      final bookingService = BookingService();

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onInverseSurface),
                ),
              ),
              SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.orderDetailCancelling),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      await bookingService.cancelBooking(
        widget.booking.id,
        reason: 'Customer cancelled order',
      );

      if (mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.orderDetailCancelSuccess),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );

        // Navigate back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugLog('❌ Error cancelling order: $e');

      if (mounted) {
        // Hide loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .orderDetailCancelError(e.toString())),
            backgroundColor: JdcColors.of(context).danger,
          ),
        );
      }
    }
  }
}
