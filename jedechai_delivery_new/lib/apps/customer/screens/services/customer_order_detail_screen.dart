import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/services.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/services/chat_service.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/widgets/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_ride_status_screen.dart';
import '../../customer.dart';

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
  State<CustomerOrderDetailScreen> createState() => _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoadingItems = true;
  Map<String, dynamic>? _driverInfo;
  bool _isLoadingDriver = false;
  Map<String, dynamic>? _couponUsage;
  Timer? _autoRefreshTimer;
  StreamSubscription? _bookingStatusSubscription;
  bool _dialogShown = false;
  Booking? _currentBooking;

  @override
  void initState() {
    super.initState();
    _currentBooking = widget.booking;
    // If already completed or cancelled, don't show dialogs again
    if (['completed', 'cancelled'].contains(widget.booking.status.toLowerCase())) {
      _dialogShown = true;
    }
    _fetchOrderItems();
    _fetchCouponUsage();
    _fetchDriverInfo();
    _startAutoRefresh();
    _setupBookingStatusListener();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
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
            .select('code')
            .eq('id', couponId)
            .maybeSingle();
        couponCode = coupon?['code'] as String?;
      }

      if (mounted) {
        setState(() {
          _couponUsage = {
            ...usage,
            'coupon_code': couponCode,
          };
        });
      }
    } catch (e) {
      debugLog('❌ Error fetching coupon usage: $e');
    }
  }

  Future<void> _fetchDriverInfo() async {
    final currentStatus = _currentBooking?.status ?? widget.booking.status;
    final currentDriverId = _currentBooking?.driverId ?? widget.booking.driverId;
    
    debugLog('🔍 _fetchDriverInfo called - Status: $currentStatus, DriverId: $currentDriverId');
    
    // Only fetch driver info if order has been accepted by driver
    if (!['accepted', 'driver_accepted', 'arrived', 'arrived_at_merchant', 'ready_for_pickup', 'picking_up_order', 'in_transit'].contains(currentStatus)) {
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

      final response = await SupabaseService.client
          .from('profiles')
          .select('''
            id,
            full_name,
            phone_number,
            avatar_url,
            license_plate
          ''')
          .eq('id', currentDriverId)
          .single();

      if (mounted) {
        setState(() {
          _driverInfo = response;
          _isLoadingDriver = false;
        });
        debugLog('✅ Driver info fetched successfully: ${response['full_name']}');
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
    debugLog('🔔 Setting up booking status listener for booking: ${widget.booking.id}');
    
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
      if (newStatus == oldStatus && _currentBooking?.driverId == bookingData['driver_id']) {
        return;
      }
      
      debugLog('📡 Booking status update: $oldStatus -> $newStatus');
      
      // Update current booking
      setState(() {
        _currentBooking = Booking.fromJson(bookingData);
      });
      
      // Refresh driver info if driver is assigned
      if (['accepted', 'driver_accepted', 'arrived', 'arrived_at_merchant', 'ready_for_pickup', 'picking_up_order', 'in_transit'].contains(newStatus)) {
        _fetchDriverInfo();
      }
      
      // Show completion dialog when order is completed
      if (newStatus == 'completed' && oldStatus != 'completed' && !_dialogShown) {
        _dialogShown = true;
        debugLog('🎉 Order completed - showing completion dialog');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCompletionDialog();
          }
        });
      }
      
      // Show cancelled dialog when merchant rejects order
      if (newStatus == 'cancelled' && oldStatus != 'cancelled' && !_dialogShown) {
        _dialogShown = true;
        debugLog('❌ Order cancelled - showing cancellation dialog');
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCancelledByMerchantDialog();
          }
        });
      }
    });
  }

  void _startAutoRefresh() {
    // Fallback safety-net timer (realtime stream is the primary mechanism)
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (!mounted) return;
      
      try {
        final response = await SupabaseService.client
            .from('bookings')
            .select()
            .eq('id', widget.booking.id)
            .single();
        
        final newStatus = response['status'] as String?;
        final oldStatus = _currentBooking?.status;
        
        // Only update if status actually changed
        if (newStatus != null && newStatus != oldStatus) {
          if (!mounted) return;
          setState(() {
            _currentBooking = Booking.fromJson(response);
          });
          
          debugLog('🔄 [Fallback] Status changed: $oldStatus -> $newStatus');
          
          if (newStatus == 'completed' && !_dialogShown) {
            _dialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showCompletionDialog();
            });
          }
          if (newStatus == 'cancelled' && !_dialogShown) {
            _dialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showCancelledByMerchantDialog();
            });
          }
          
          // Refresh driver info if needed
          if (['accepted', 'driver_accepted', 'arrived', 'arrived_at_merchant', 'ready_for_pickup', 'picking_up_order', 'in_transit'].contains(newStatus)) {
            await _fetchDriverInfo();
          }
        }
      } catch (e) {
        debugLog('❌ Fallback refresh error: $e');
      }
    });
    
    debugLog('✅ Fallback refresh started (60s interval - order detail)');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'รายละเอียดออเดอร์',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Cancel order button (only show for cancellable statuses)
          if (_canCancelOrder())
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _showCancelOrderDialog,
                icon: Icon(Icons.cancel, size: 16, color: colorScheme.error),
                label: Text(
                  'ยกเลิก',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          Builder(
            builder: (context) {
              final currentStatus = _currentBooking?.status ?? widget.booking.status;
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(currentStatus),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(currentStatus),
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderInfoCard(),
            const SizedBox(height: 16),
            _buildLocationCard(),
            if (_driverInfo != null && _shouldShowDriverInfo()) ...[
              const SizedBox(height: 16),
              _buildDriverInfoCard(),
            ],
            if (_orderItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildOrderItemsCard(),
            ],
            const SizedBox(height: 16),
            _buildPricingCard(),
          ],
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
                      _getServiceTypeText(widget.booking.serviceType),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'ออเดอร์ ${OrderCodeFormatter.format(widget.booking.id)}',
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
              Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'สั่งเมื่อ: ${_formatDateTime(widget.booking.createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
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
            'สถานที่',
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
                    color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
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
                        'จุดรับ',
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
                      'จุดหมายปลายทาง',
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
    final shouldShow = ['accepted', 'driver_accepted', 'arrived', 'arrived_at_merchant', 'ready_for_pickup', 'picking_up_order', 'in_transit', 'completed'].contains(currentStatus);
    debugLog('🔍 _shouldShowDriverInfo - Status: $currentStatus, ShouldShow: $shouldShow, _driverInfo: ${_driverInfo != null}');
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
            'ข้อมูลคนขับ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          
          if (_isLoadingDriver)
            const Center(
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
                        color: AppTheme.accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _driverInfo!['avatar_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: AppNetworkImage(
                                imageUrl: _driverInfo!['avatar_url']?.toString(),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                backgroundColor: AppTheme.accentBlue.withValues(alpha: 0.1),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: AppTheme.accentBlue,
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
                            _driverInfo!['full_name'] ?? 'ไม่ระบุชื่อ',
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
                                Icon(Icons.phone, size: 14, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _driverInfo!['phone_number'],
                                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
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
                                Icon(Icons.directions_car, size: 14, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _driverInfo!['license_plate'],
                                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
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
                const SizedBox(height: 12),
                
                // Bottom row: Action Buttons
                Row(
                  children: [
                    // Track Driver Button
                    Expanded(
                      child: Material(
                        color: AppTheme.accentBlue,
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
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_on, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('ติดตาม', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_driverInfo!['phone_number'] != null) ...[
                      const SizedBox(width: 8),
                      // Message Button
                      Expanded(
                        child: Material(
                          color: AppTheme.accentBlue,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openChat(),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text('แชท', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Call Button
                      Expanded(
                        child: Material(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final phone = _driverInfo!['phone_number'] as String;
                              final uri = Uri.parse('tel:$phone');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('ไม่สามารถโทรไปที่ $phone ได้')),
                                  );
                                }
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone, color: Colors.white, size: 18),
                                  SizedBox(width: 6),
                                  Text('โทร', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
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
            'รายการอาหาร',
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
              'ไม่พบรายการอาหาร',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._orderItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: AppTheme.accentOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['menu_item']?['name'] ?? item['item_name'] ?? 'ไม่ระบุชื่อ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (item['quantity'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'จำนวน: ${item['quantity']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        // ค้นหาช่วงบรรทัดที่มีการเช็ค if (item['options'] != null ...)
// แล้วแทนที่ด้วย Block นี้ครับ:

if (item['options'] != null && item['options'] is List && (item['options'] as List).isNotEmpty) ...[
  const SizedBox(height: 4),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.accentOrange.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เพิ่มเติม:',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.accentOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        ...(item['options'] as List).map((option) {
          // 🛠️ Logic แกะข้อมูล: รองรับทั้งแบบ String และ JSON Map
          String optionName = '';
          
          if (option is Map) {
            // กรณีเป็น Object: {"name": "เส้นเล็ก", "price": 0}
            optionName = option['name'] ?? option['item_name'] ?? 'ตัวเลือก';
            
            // (เสริม) ถ้าอยากโชว์ราคาเพิ่ม
            // final price = (option['price'] as num?)?.toDouble() ?? 0.0;
            // if (price > 0) optionName += ' (+฿$price)';
          } else {
            // กรณีเป็น String ธรรมดา
            optionName = option.toString();
          }

          return Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              '• $optionName',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.accentOrange.withValues(alpha: 0.8),
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
                      '฿${item['price']}',
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
    if (address == null) {
      return 'ไม่ระบุที่อยู่';
    }
    
    // Handle Map/JSON object addresses
    if (address is Map) {
      try {
        final parts = <String>[];
        
        // Try different field names for address components
        if (address['address'] != null && address['address'].toString().isNotEmpty) {
          parts.add(address['address'].toString());
        } else if (address['street'] != null && address['street'].toString().isNotEmpty) {
          parts.add(address['street'].toString());
        }
        
        if (address['subLocality'] != null && address['subLocality'].toString().isNotEmpty) {
          parts.add(address['subLocality'].toString());
        }
        
        if (address['locality'] != null && address['locality'].toString().isNotEmpty) {
          parts.add(address['locality'].toString());
        }
        
        if (address['administrativeArea'] != null && address['administrativeArea'].toString().isNotEmpty) {
          parts.add(address['administrativeArea'].toString());
        }
        
        if (address['country'] != null && address['country'].toString().isNotEmpty) {
          parts.add(address['country'].toString());
        }
        
        return parts.isNotEmpty ? parts.join(', ') : 'ไม่ระบุที่อยู่';
      } catch (e) {
        debugLog('❌ Error parsing address map: $e');
      }
    }
    
    // Handle string addresses
    if (address is String) {
      try {
        // Clean up coordinate-only patterns like "ตำแหน่ง: 19.16282, 100.84155"
        final coordPattern = RegExp(r'ตำแหน่ง:\s*[\d.]+,\s*[\d.]+');
        if (coordPattern.hasMatch(address)) {
          final cleaned = address.replaceAll(coordPattern, '').replaceAll(RegExp(r'\s*[—\-]\s*$'), '').trim();
          if (cleaned.isNotEmpty) return cleaned;
          return 'ตำแหน่งปัจจุบัน';
        }
        
        // Try to parse as JSON if it looks like JSON
        if (address.trim().startsWith('{') && address.trim().endsWith('}')) {
          final addressMap = Map<String, dynamic>.from(
            Uri.splitQueryString(address.replaceAll('{', '').replaceAll('}', '').replaceAll(',', '&'))
          );
          
          final parts = <String>[];
          if (addressMap['address']?.isNotEmpty == true) {
            parts.add(addressMap['address']!);
          }
          if (addressMap['street']?.isNotEmpty == true) {
            parts.add(addressMap['street']!);
          }
          
          return parts.isNotEmpty ? parts.join(', ') : address;
        }
        
        // Check if it's an "Instance of" string
        if (address.contains('Instance of')) {
          return 'ไม่ระบุที่อยู่';
        }
        
        // Return regular string
        return address;
      } catch (e) {
        debugLog('❌ Error parsing address string: $e');
        return address;
      }
    }
    
    // Handle AddressPlacemark objects
    if (address.toString().contains('AddressPlacemark')) {
      return 'ไม่ระบุที่อยู่';
    }
    
    // Fallback
    return address.toString();
  }

  double _calculateTotalPrice() {
    final booking = _currentBooking ?? widget.booking;
    final couponDiscount = (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
    
    if (booking.serviceType == 'food') {
      // Food: booking.price = ค่าอาหาร (subtotal รวม options แล้ว)
      // booking.deliveryFee = ค่าจัดส่ง
      // ใช้ booking.price เสมอ เพราะ booking_items เก็บ base price ไม่รวม options
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
    final couponDiscount = (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final couponCode = _couponUsage?['coupon_code'] as String?;

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
            'รายละเอียดราคา',
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
                final itemName = item['name'] ?? item['item_name'] ?? item['menu_item']?['name'] ?? 'ไม่ระบุชื่อ';
                
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
                        '฿${itemTotal.ceil()}',
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
                  'ค่าอาหาร',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                Text(
                  '฿${booking.price.ceil()}',
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
                    'ค่าจัดส่ง',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                  ),
                  Text(
                    '฿${booking.deliveryFee!.ceil()}',
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
                    couponCode != null && couponCode.isNotEmpty
                        ? 'ส่วนลดคูปอง ($couponCode)'
                        : 'ส่วนลดคูปอง',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.secondary,
                    ),
                  ),
                  Text(
                    '-฿${couponDiscount.ceil()}',
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
                  'ระยะทาง',
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                ),
                Text(
                  '${booking.distanceKm.toStringAsFixed(1)} กม.',
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
                  _getServiceTypeText(booking.serviceType),
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '฿${booking.price.ceil()}',
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
                    couponCode != null && couponCode.isNotEmpty
                        ? 'ส่วนลดคูปอง ($couponCode)'
                        : 'ส่วนลดคูปอง',
                    style: TextStyle(fontSize: 14, color: colorScheme.secondary),
                  ),
                  Text(
                    '-฿${couponDiscount.ceil()}',
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
                'รวมทั้งหมด',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '฿${_calculateTotalPrice().ceil()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getServiceTypeText(String serviceType) {
    switch (serviceType) {
      case 'ride':
        return 'บริการรถส่ง';
      case 'food':
        return 'สั่งอาหาร';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return serviceType;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return AppTheme.accentBlue;
      case 'food':
        return AppTheme.accentOrange;
      case 'parcel':
        return AppTheme.primaryGreen;
      default:
        return Colors.grey;
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_merchant':
        return Colors.amber;
      case 'preparing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.purple;
      case 'driver_accepted':
        return Colors.indigo;
      case 'accepted':
      case 'confirmed':
        return Colors.blue;
      case 'arrived':
        return Colors.teal;
      case 'in_transit':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'pending_merchant':
        return 'รอร้านค้ายืนยัน';
      case 'preparing':
        return 'กำลังเตรียมอาหาร';
      case 'ready_for_pickup':
        return 'อาหารพร้อมรับ';
      case 'driver_accepted':
        return 'คนขับรับออเดอร์แล้ว';
      case 'accepted':
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'arrived':
      case 'arrived_at_merchant':
        return 'ถึงจุดรับแล้ว';
      case 'picking_up_order':
        return 'กำลังรับอาหาร';
      case 'in_transit':
        return 'กำลังจัดส่ง';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้',
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
                  Icon(Icons.receipt_long, color: colorScheme.onSurfaceVariant, size: 20),
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
              'กรุณาลองสั่งใหม่อีกครั้ง หรือเลือกร้านอื่น',
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
                  MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
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

  Future<void> _openChat() async {
    final booking = _currentBooking ?? widget.booking;
    final customerId = AuthService.userId;
    if (customerId == null || booking.driverId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปิดแชทได้')),
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
              otherPartyName: _driverInfo?['full_name'] ?? 'คนขับ',
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
          const SnackBar(content: Text('ไม่สามารถเปิดแชทได้')),
        );
      }
    }
  }

  void _showCompletionDialog() {
    final booking = _currentBooking ?? widget.booking;
    final bookingId = booking.id;
    final isFood = booking.serviceType == 'food';
    final couponDiscount = (_couponUsage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final couponCode = _couponUsage?['coupon_code'] as String?;
    final foodCost = booking.price;
    final deliveryFee = booking.deliveryFee ?? 0.0;
    final grossAmount = isFood ? foodCost + deliveryFee : booking.price;
    final totalAmount = (grossAmount - couponDiscount) < 0 ? 0 : (grossAmount - couponDiscount);
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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: colorScheme.onPrimaryContainer, size: 20),
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
              const SizedBox(height: 12),
              // Total Price with food breakdown
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
                Navigator.of(context).pop(); // ปิด dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'เข้าใจแล้ว',
                style: TextStyle(
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
      'pending',           // Waiting for driver
      'pending_merchant',  // Food order waiting for merchant
      'confirmed',         // Driver confirmed but not started
    ];
    
    return cancellableStatuses.contains(currentStatus);
  }

  /// Show cancel order confirmation dialog
  void _showCancelOrderDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'ยืนยันการยกเลิกออเดอร์',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'คุณต้องการยกเลิกออเดอร์นี้ใช่หรือไม่?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'หมายเหตุ: ไม่สามารถยกเลิกออเดอร์ที่กำลังดำเนินการได้',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'ไม่ยกเลิก',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelOrder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
  }

  /// Cancel the order
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
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onInverseSurface),
                ),
              ),
              SizedBox(width: 12),
              Text('กำลังยกเลิกออเดอร์...'),
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
            content: const Text('ออเดอร์ถูกยกเลิกเรียบร้อยแล้ว'),
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
            content: Text('ไม่สามารถยกเลิกออเดอร์ได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
