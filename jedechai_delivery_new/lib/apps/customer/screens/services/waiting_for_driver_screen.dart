import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/profile_service.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/chat_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../common/widgets/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';
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
  late final AnimationController _radarAnimationController;
  late final AnimationController _pulseAnimationController;
  late final Animation<double> _radarAnimation;
  late final Animation<double> _pulseAnimation;
  
  StreamSubscription<List<Map<String, dynamic>>>? _bookingStreamSubscription;
  Timer? _autoRefreshTimer;
  String? _lastKnownStatus;
  String? _lastKnownDriverId;
  bool _isHandlingPriceAdjustment = false;
  late double _initialQuotedPrice;
  
  bool _isDriverFound = false;
  bool _isDriverAssigned = false;
  String _driverName = 'กำลังค้นหาคนขับ...';
  String _driverPhone = '';
  String _driverVehicle = '';
  int _estimatedTime = 5; // minutes
  
  // Food service specific
  bool get _isFoodService => widget.booking.serviceType == 'food';
  // ignore: unused_element
  bool get _isWaitingForRestaurant => widget.booking.status == 'pending_merchant';
  bool get _isRestaurantConfirmed => widget.booking.status == 'confirmed_merchant';

  @override
  void initState() {
    super.initState();
    
    _radarAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _radarAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _radarAnimationController, curve: Curves.linear)
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut)
    );
    
    _radarAnimationController.repeat();
    _pulseAnimationController.repeat();
    _initialQuotedPrice = widget.booking.price;
    
    // Listen to real-time booking updates
    _listenToBookingUpdates();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      await _refreshStatus();
    });
  }

  Future<void> _refreshStatus() async {
    try {
      final response = await SupabaseService.client
          .from('bookings')
          .select('status, driver_id')
          .eq('id', widget.booking.id)
          .single();

      final status = response['status'] as String?;
      final driverId = response['driver_id'] as String?;

      if (status != _lastKnownStatus || driverId != _lastKnownDriverId) {
        _lastKnownStatus = status;
        _lastKnownDriverId = driverId;

        if (status != null) {
          _handleBookingUpdate({
            'id': widget.booking.id,
            'status': status,
            'driver_id': driverId,
          });
        }
      }
    } catch (e) {
      debugLog('❌ Auto refresh status error: $e');
    }
  }

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
            title: const Text('ราคาอัปเดตใหม่'),
            content: Text(
              'ราคาถูกปรับใหม่เนื่องจากคนขับที่รับงานอยู่เกินระยะที่กำหนด\n\n'
              'ราคาเดิม: ฿${_initialQuotedPrice.toStringAsFixed(2)}\n'
              'ราคาใหม่: ฿${adjustedPrice.toStringAsFixed(2)}\n\n'
              'ต้องการดำเนินการต่อหรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('ยกเลิกงาน'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('ดำเนินการต่อ'),
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
      await SupabaseService.client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'notes': '${booking.notes ?? ''} | ลูกค้ายกเลิกหลังปรับราคาจากระยะคนขับ',
          })
          .eq('id', booking.id);
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
                content: Text('การเชื่อมต่อขัดข้อง กำลังลองใหม่...'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          Future.delayed(const Duration(seconds: 3), () {
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
            icon: const Icon(Icons.wifi_off, color: Colors.red, size: 48),
            title: const Text('เชื่อมต่อไม่สำเร็จ'),
            content: Text('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: ${e.toString()}'),
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
  }

  void _handleBookingUpdate(Map<String, dynamic> bookingData) {
    final status = bookingData['status'] as String?;
    final driverId = bookingData['driver_id'] as String?;

    debugLog('🔄 Booking status changed to: $status');
    debugLog('👤 Driver ID: $driverId');
    debugLog('Customer Stream Status: $status');
    debugLog('📋 Full booking data: $bookingData');

    _lastKnownStatus = status;
    _lastKnownDriverId = driverId;

    final hasDriver = driverId != null && driverId.toString().isNotEmpty;
    
    // Food service statuses that should navigate to status screen
    final foodActiveStatuses = ['preparing', 'matched', 'ready_for_pickup', 'picking_up_order', 'in_transit', 'arrived'];
    final isFoodActive = _isFoodService && status != null && foodActiveStatuses.contains(status);
    
    // Ride service accepted statuses
    final isAcceptedStatus = status == 'accepted' || status == 'matched';

    // Navigate to status screen if driver accepted (ride) or food order is active
    if ((isAcceptedStatus && hasDriver) || isFoodActive) {
      debugLog('✅ Order active! Status: $status, Driver ID: $driverId');

      if (hasDriver) {
        _fetchDriverInfo(driverId).then((driverInfo) {
          if (!mounted) return;

          if (driverInfo != null) {
            setState(() {
              _isDriverFound = true;
              _isDriverAssigned = true;
              _driverName = driverInfo['full_name'] ?? 'คนขับ';
              _driverPhone = driverInfo['phone'] ?? '';
              _driverVehicle = driverInfo['vehicle_type'] ?? 'รถจักรยานยนต์';
            });
          }

          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            final fullBooking = await _fetchFullBooking(bookingData['id'] as String);
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
        }).catchError((error) {
          debugLog('❌ Error fetching driver info: $error');
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            final fullBooking = await _fetchFullBooking(bookingData['id'] as String);
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
        });
      } else {
        // Food order active but no driver yet - still navigate to show status
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          final fullBooking = await _fetchFullBooking(bookingData['id'] as String);
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

    if (status == 'completed') {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => CustomerMainScreen()),
        (route) => false,
      );
      return;
    }

    if (status == 'cancelled') {
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
          content: const Text(
            'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้\n\nกรุณาลองสั่งใหม่อีกครั้ง หรือเลือกร้านอื่น',
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
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
    debugLog('🧹 Disposing WaitingForDriverScreen - canceling stream subscription');
    _bookingStreamSubscription?.cancel();
    _bookingStreamSubscription = null;
    _autoRefreshTimer?.cancel();
    _radarAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _isFoodService ? AppTheme.accentOrange : AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        title: Text(_isFoodService ? 'กำลังรอร้านค้า' : 'กำลังค้นหาคนขับ'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Status Section
              _buildStatusSection(),
              
              const SizedBox(height: 32),
              
              // Animation Section
              _buildAnimationSection(),
              
              const SizedBox(height: 32),
              
              // Driver Info Section
              if (_isDriverFound) _buildDriverInfoSection(),
              
              const Spacer(),
              
              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildStatusSection() {
    // final isWaiting = _isFoodService ? _isWaitingForRestaurant : !_isDriverFound;
    final isCompleted = _isFoodService ? _isRestaurantConfirmed : _isDriverFound;
    final primaryColor = _isFoodService ? AppTheme.accentOrange : AppTheme.primaryGreen;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : 
            _isFoodService ? Icons.restaurant : Icons.search,
            color: primaryColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            isCompleted 
                ? (_isFoodService ? 'ร้านค้ายืนยันคำสั่งซื้อ!' : 'พบคนขับแล้ว!')
                : (_isFoodService ? 'กำลังรอร้านค้า...' : 'กำลังค้นหาคนขับ...'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted 
                ? (_isFoodService ? 'ร้านค้ากำลังเตรียมอาหารของคุณ' : 'คนขับกำลังเดินทางมาหาคุณ')
                : 'ระบบเวลาโดยประมาณ $_estimatedTime นาที',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimationSection() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: (_isFoodService ? AppTheme.accentOrange : AppTheme.primaryGreen).withValues(alpha: 0.3), 
          width: 2
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar circles
          AnimatedBuilder(
            animation: _radarAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Positioned.fill(
                      child: Container(
                        margin: EdgeInsets.all(20.0 * (_radarAnimation.value + i * 0.3)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (_isFoodService ? AppTheme.accentOrange : AppTheme.primaryGreen).withValues(alpha: 0.3 - i * 0.1),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          
          // Center icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Icon(
                  _isFoodService ? Icons.restaurant : Icons.local_taxi,
                  color: _isFoodService ? AppTheme.accentOrange : AppTheme.primaryGreen,
                  size: 40,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoSection() {
    // For food service, show restaurant info instead of driver info
    if (_isFoodService && _isRestaurantConfirmed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: AppTheme.accentOrange,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ร้านค้ากำลังเตรียมอาหาร',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'โปรดรอสักครู่...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
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
    
    // Original driver info section for ride service
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      _driverName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _driverVehicle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isDriverAssigned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'มอบหมายแล้ว',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.phone, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                _driverPhone,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_isDriverAssigned)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showContactDialog,
              icon: const Icon(Icons.phone),
              label: const Text('ติดต่อคนขับ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _showCancelDialog,
            icon: const Icon(Icons.cancel, color: Colors.red),
            label: const Text(
              'ยกเลิกการจอง',
              style: TextStyle(color: Colors.red),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ติดต่อคนขับ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.green),
              title: const Text('โทรศัพท์'),
              subtitle: Text(_driverPhone),
              onTap: () {
                Navigator.of(context).pop();
                _makePhoneCall(_driverPhone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.blue),
              title: const Text('แชทกับคนขับ'),
              subtitle: const Text('ส่งข้อความในแอป'),
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
            child: const Text('ปิด'),
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
          SnackBar(content: Text('ไม่สามารถโทรไปที่ $phoneNumber ได้')),
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
          const SnackBar(content: Text('ไม่สามารถเปิดแชทได้')),
        );
      }
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกการจอง'),
        content: const Text('คุณแน่ใจว่าต้องการยกเลิกการจองนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                // Update booking status to cancelled in database
                await SupabaseService.client
                    .from('bookings')
                    .update({'status': 'cancelled'})
                    .eq('id', widget.booking.id);
                
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
                  Future.delayed(const Duration(milliseconds: 100), () {
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
                  });
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ข้อมูลการจอง'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'รหัสออเดอร์: ${OrderCodeFormatter.formatByServiceType(widget.booking.id, serviceType: widget.booking.serviceType)}',
            ),
            const SizedBox(height: 8),
            Text('ประเภท: ${widget.booking.serviceType}'),
            const SizedBox(height: 8),
            Text('ราคา: ฿${widget.booking.price.ceil()}'),
            const SizedBox(height: 8),
            Text('สถานะ: ${widget.booking.status}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
