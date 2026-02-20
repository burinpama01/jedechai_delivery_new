import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/utils/order_code_formatter.dart';

/// Merchant Order Detail Screen
/// 
/// Shows detailed order information with accept/decline actions
class MerchantOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const MerchantOrderDetailScreen({
    super.key,
    required this.order,
  });

  @override
  State<MerchantOrderDetailScreen> createState() => _MerchantOrderDetailScreenState();
}

class _MerchantOrderDetailScreenState extends State<MerchantOrderDetailScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _orderItems = [];
  String? _error;
  StreamSubscription<List<Map<String, dynamic>>>? _orderStatusSubscription;
  bool _dialogShown = false;
  Timer? _autoRefreshTimer;
  Map<String, dynamic>? _currentOrder;
  double _effectiveGpRate = 0.10; // default, will be loaded dynamically
  String? _driverName;
  String? _driverPhone;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _fetchOrderItems();
    _fetchGpRate();
    _fetchDriverInfo();
    _setupOrderStatusListener();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _orderStatusSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    debugLog('⏱️ Starting auto-refresh every 2 seconds for order: ${widget.order['id']}');
    
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      try {
        // Fetch latest order data
        final response = await Supabase.instance.client
            .from('bookings')
            .select()
            .eq('id', widget.order['id'])
            .single();
        
        if (mounted) {
          final newStatus = response['status'] as String? ?? '';
          final oldStatus = _currentOrder?['status'] as String? ?? '';
          
          setState(() {
            _currentOrder = response;
          });
          debugLog('🔄 Auto-refreshed order status: $newStatus (previous: $oldStatus)');
          
          // Check if status changed to picking_up_order and show dialog
          if (newStatus == 'picking_up_order' && oldStatus != 'picking_up_order' && !_dialogShown) {
            _dialogShown = true;
            debugLog('💰 [AUTO-REFRESH] Status changed to picking_up_order - showing completion dialog');
            debugLog('💰 [AUTO-REFRESH] Setting _dialogShown to true');
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                debugLog('💰 [AUTO-REFRESH] Calling _showCompletionDialog()');
                _showCompletionDialog();
              } else {
                debugLog('⚠️ [AUTO-REFRESH] Widget not mounted, cannot show dialog');
              }
            });
          }
        }
      } catch (e) {
        debugLog('❌ Auto-refresh error: $e');
      }
    });
  }

  void _setupOrderStatusListener() {
    debugLog('🔔 Setting up order status listener for order: ${widget.order['id']}');
    debugLog('🔔 Initial _dialogShown flag: $_dialogShown');
    
    _orderStatusSubscription = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', widget.order['id'])
        .listen((data) {
      if (data.isEmpty || !mounted) {
        debugLog('⚠️ Listener: data is empty or widget not mounted');
        return;
      }
      
      final order = data.first;
      final status = order['status'] as String? ?? '';
      
      debugLog('📊 Order status update: $status');
      debugLog('📊 Current _dialogShown flag: $_dialogShown');
      
      // Update current order state
      setState(() {
        _currentOrder = order;
      });
      
      // Show completion dialog when driver picks up order
      if (status == 'picking_up_order') {
        debugLog('🔍 Status is picking_up_order, checking _dialogShown flag...');
        if (!_dialogShown) {
          _dialogShown = true;
          debugLog('💰 Driver picked up order - showing completion dialog');
          debugLog('💰 Setting _dialogShown to true');
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              debugLog('💰 Calling _showCompletionDialog()');
              _showCompletionDialog();
            } else {
              debugLog('⚠️ Widget not mounted, cannot show dialog');
            }
          });
        } else {
          debugLog('⚠️ Dialog already shown (_dialogShown = true), skipping');
        }
      }
    });
  }

  Future<void> _fetchGpRate() async {
    try {
      final merchantId = AuthService.userId;
      if (merchantId == null) return;

      // Try merchant's custom GP rate first
      double? customGp;
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('gp_rate')
            .eq('id', merchantId)
            .maybeSingle();
        customGp = (profile?['gp_rate'] as num?)?.toDouble();
      } catch (_) {}

      if (customGp != null && customGp > 0) {
        if (mounted) setState(() => _effectiveGpRate = customGp!);
        debugLog('💰 GP rate from merchant profile: ${(customGp * 100).toStringAsFixed(0)}%');
        return;
      }

      // Fallback to system default
      final configService = SystemConfigService();
      await configService.fetchSettings();
      final systemGp = configService.merchantGpRate;
      if (mounted) setState(() => _effectiveGpRate = systemGp);
      debugLog('💰 GP rate from system config: ${(systemGp * 100).toStringAsFixed(0)}%');
    } catch (e) {
      debugLog('⚠️ Error loading GP rate, using default: $e');
    }
  }

  Future<void> _fetchDriverInfo() async {
    final driverId = (_currentOrder ?? widget.order)['driver_id'] as String?;
    if (driverId == null || driverId.isEmpty) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', driverId)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _driverName = profile['full_name'] as String?;
          _driverPhone = profile['phone_number'] as String?;
        });
      }
    } catch (e) {
      debugLog('⚠️ Error fetching driver info: $e');
    }
  }

  Future<void> _callDriver() async {
    if (_driverPhone == null || _driverPhone!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบเบอร์โทรคนขับ')),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$_driverPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugLog('❌ Error calling driver: $e');
    }
  }

  Future<void> _fetchOrderItems() async {
    try {
      setState(() {
        _error = null;
      });

      debugLog('🔍 Fetching order items for booking: ${widget.order['id']}');
      
      // booking_items table already has 'name' and 'price' columns
      final response = await Supabase.instance.client
          .from('booking_items')
          .select('*')
          .eq('booking_id', widget.order['id']);

      debugLog('📋 Order items response: $response');
      
      setState(() {
        _orderItems = List<Map<String, dynamic>>.from(response);
      });
      
      debugLog('🍽️ Loaded ${_orderItems.length} order items');
    } catch (e) {
      debugLog('❌ Error fetching order items: $e');
      setState(() {
        _error = 'ไม่สามารถโหลดรายการอาหาร: $e';
      });
    }
  }

  Future<void> _acceptOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'preparing',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.order['id'])
          .inFilter('status', ['pending_merchant', 'pending'])
          .select();

      if (result.isEmpty) {
        throw Exception('Order already taken or not available');
      }

      if (mounted) {
        // Update current order state to reflect the change
        setState(() {
          _currentOrder = result.first;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ออเดอร์ได้รับการยืนยันแล้ว!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Don't pop - stay on this screen to see status updates
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: const Text('รับออเดอร์ไม่สำเร็จ'),
            content: Text('ไม่สามารถรับออเดอร์ได้: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _declineOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.order['id'])
          .inFilter('status', ['pending_merchant', 'pending'])
          .select();

      if (result.isEmpty) {
        throw Exception('Order already taken or not available');
      }

      // Send notification to customer about rejection
      final customerId = widget.order['customer_id'] as String?;
      if (customerId != null && customerId.isNotEmpty) {
        debugLog('📤 Sending rejection notification to customer: $customerId');
        await NotificationSender.sendToUser(
          userId: customerId,
          title: '❌ ร้านค้าปฏิเสธออเดอร์',
          body: 'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ออเดอร์ถูกปฏิเสธแล้ว'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: const Text('ปฏิเสธออเดอร์ไม่สำเร็จ'),
            content: Text('ไม่สามารถปฏิเสธออเดอร์ได้: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markFoodReady() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await Supabase.instance.client
          .from('bookings')
          .update({
            'status': 'ready_for_pickup',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.order['id'])
          .inFilter('status', ['preparing', 'driver_accepted', 'arrived_at_merchant', 'matched', 'accepted', 'arrived'])
          .select();

      if (result.isEmpty) {
        throw Exception('ไม่สามารถอัพเดตสถานะได้');
      }

      if (mounted) {
        // Update current order state to reflect the change
        setState(() {
          _currentOrder = result.first;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อาหารพร้อมแล้ว! รอคนขับมารับ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Don't pop - stay on this screen to see status updates
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: const Text('อัพเดตสถานะไม่สำเร็จ'),
            content: Text('ไม่สามารถอัพเดตสถานะได้: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'ไม่ระบุ';
    String raw;
    if (address is String) {
      if (address.contains('Instance of') || address.contains('AddressPlacemark')) {
        return 'ตำแหน่งตามหมุดปักของลูกค้า';
      }
      raw = address;
    } else {
      raw = address.toString();
    }
    // ตัดที่อยู่ยาวให้สั้นลง: เอาส่วนหลัก ตัดชื่อประเทศ/รหัสไปรษณีย์ที่ซ้ำกัน
    final parts = raw.split(',').map((p) => p.trim()).toList();
    // ถ้ามีหลายส่วน เอาแค่ 2-3 ส่วนแรก
    if (parts.length > 3) {
      return parts.take(3).join(', ');
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder ?? widget.order;
    final status = order['status'] as String? ?? '';
    final driverId = order['driver_id'] as String?;
    final price = order['price'] is int 
        ? (order['price'] as int).toDouble()
        : (order['price'] as num?)?.toDouble() ?? 0.0;
    final distanceKm = order['distance_km'] is int
        ? (order['distance_km'] as int).toDouble()
        : (order['distance_km'] as num?)?.toDouble() ?? 0.0;
    final gpAmount = price * _effectiveGpRate;
    final merchantReceives = price - gpAmount;
    final createdAt = DateTime.parse(order['created_at'] as String).toLocal();
    final scheduledAtStr = order['scheduled_at'] as String?;
    final scheduledAt = scheduledAtStr != null ? DateTime.tryParse(scheduledAtStr)?.toLocal() : null;
    final notes = order['notes'] as String? ?? '';
    final paymentMethod = order['payment_method'] as String? ?? 'cash';
    final hasDriver = driverId != null && driverId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'ออเดอร์ ${OrderCodeFormatter.formatByServiceType(order['id']?.toString(), serviceType: order['service_type']?.toString())}',
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStatusText(status),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                            Icon(Icons.receipt_long_outlined, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 8),
                            Text('ข้อมูลออเดอร์', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          'รหัสออเดอร์',
                          OrderCodeFormatter.formatByServiceType(
                            order['id']?.toString(),
                            serviceType: order['service_type']?.toString(),
                          ),
                        ),
                        _buildInfoRow('เวลาสั่ง', _formatDateTime(createdAt)),
                        _buildInfoRow('ชำระเงิน', paymentMethod == 'cash' ? 'เงินสด' : 'โอนเงิน'),
                        _buildInfoRow('ระยะทาง', '${distanceKm.toStringAsFixed(1)} กม.'),
                        if (scheduledAt != null)
                          _buildInfoRow('นัดหมาย', _formatDateTime(scheduledAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                            Icon(Icons.monetization_on_outlined, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 8),
                            Text('รายละเอียดราคา', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ยอดขาย', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                            Text('฿${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('หัก GP (${(_effectiveGpRate * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 13, color: Colors.red[400])),
                            Text('-฿${gpAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.red[400])),
                          ],
                        ),
                        const Divider(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ยอดรับจริง', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[800])),
                              Text('฿${merchantReceives.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[800])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                            Icon(Icons.location_on_outlined, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 8),
                            Text('ที่อยู่จัดส่ง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatAddress(order['destination_address']),
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ),
                        if (notes.isNotEmpty && !notes.startsWith('สั่งอาหารจาก')) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[300]!, width: 1.5),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 22, color: Colors.amber[800]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('หมายเหตุจากลูกค้า', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.amber[900])),
                                      const SizedBox(height: 4),
                                      Text(notes, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.amber[900])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Order Items Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                            Icon(
                              Icons.restaurant_menu_outlined,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'รายการอาหาร',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_orderItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ไม่พบรายการอาหาร',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
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
                                  child: Center(
                                    child: Text(
                                      '${item['quantity'] ?? 1}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentOrange,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? item['item_name'] ?? item['menu_item']?['name'] ?? 'ไม่ระบุชื่อ',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      if (item['quantity'] != null && item['quantity'] != 1) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'จำนวน: ${item['quantity']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
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
                                Text(
                                  '฿${(((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1)).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (status == 'pending_merchant' || status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _declineOrder,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text(
                              'ปฏิเสธออเดอร์',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _acceptOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'รับออเดอร์',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (status == 'preparing' && driverId == null) ...[
                    // Waiting for driver to accept
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            color: Colors.orange[700],
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'รอคนขับรับงาน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'กรุณารอคนขับรับงานก่อน\nจึงจะสามารถกดอาหารพร้อมได้',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasDriver && (status == 'driver_accepted' || status == 'arrived_at_merchant' || status == 'preparing' || status == 'matched' || status == 'accepted' || status == 'arrived')) ...[
                    // ปุ่มโทรหาคนขับ
                    if (_driverName != null || _driverPhone != null) ...[                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.blue[200],
                              child: const Icon(Icons.delivery_dining, size: 20, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_driverName ?? 'คนขับ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (_driverPhone != null)
                                    Text(_driverPhone!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            if (_driverPhone != null)
                              Material(
                                color: Colors.green,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _callDriver,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(Icons.phone, size: 20, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'driver_accepted' ||
                        status == 'arrived_at_merchant' ||
                        status == 'matched' ||
                        status == 'preparing' ||
                        status == 'accepted' ||
                        status == 'arrived') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _markFoodReady,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'อาหารพร้อม',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[600],
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'สถานะ: ${_getStatusText(status)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_merchant':
        return Colors.red; // New Order
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.teal;
      case 'driver_accepted':
      case 'matched':
      case 'arrived_at_merchant':
      case 'completed':
        return Colors.green; // Success/Active
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_outlined;
      case 'pending_merchant':
        return Icons.pending_outlined;
      case 'preparing':
        return Icons.restaurant_outlined;
      case 'driver_accepted':
        return Icons.delivery_dining;
      case 'arrived_at_merchant':
        return Icons.store;
      case 'ready_for_pickup':
        return Icons.check_circle_outline;
      case 'picking_up_order':
        return Icons.shopping_bag;
      case 'in_transit':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'pending_merchant':
        return 'รอการยืนยัน';
      case 'preparing':
        return 'กำลังเตรียมอาหาร';
      case 'driver_accepted':
        return 'คนขับรับงานแล้ว';
      case 'arrived_at_merchant':
        return 'คนขับถึงร้านแล้ว';
      case 'ready_for_pickup':
        return 'อาหารพร้อมส่ง';
      case 'picking_up_order':
        return 'คนขับกำลังรับออเดอร์';
      case 'in_transit':
        return 'กำลังส่งอาหาร';
      case 'cancelled':
        return 'ถูกปฏิเสธ';
      case 'completed':
        return 'เสร็จสิ้น';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  void _showCompletionDialog() {
    final order = _currentOrder ?? widget.order;
    final customerName = order['customer_name'] as String? ?? 'ลูกค้า';
    final price = order['price'] is int 
        ? (order['price'] as int).toDouble()
        : (order['price'] as num?)?.toDouble() ?? 0.0;
    final bookingId = order['id'].toString();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.accentOrange,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '✅ ออเดอร์สำเร็จ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentOrange,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'คนขับได้รับอาหารและกำลังเดินทางไปส่งลูกค้า',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Order ID Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'หมายเลขออเดอร์',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            OrderCodeFormatter.formatByServiceType(
                              bookingId,
                              serviceType: order['service_type']?.toString(),
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Customer Name Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ชื่อลูกค้า',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            customerName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Menu Items Section
              if (_orderItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: Colors.purple[700],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'รายการอาหาร',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._orderItems.map((item) {
                        final itemName = item['name'] as String? ?? item['item_name'] as String? ?? 'ไม่ระบุ';
                        final quantity = item['quantity'] as int? ?? 1;
                        final itemPrice = item['price'] is int 
                            ? (item['price'] as int).toDouble()
                            : (item['price'] as num?)?.toDouble() ?? 0.0;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${quantity}x',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Text(
                                '฿${itemPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              
              // Total Price Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accentOrange, AppTheme.accentOrange.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentOrange.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ยอดรับจริง',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'หลังหัก GP ${(_effectiveGpRate * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '฿${(price - (price * _effectiveGpRate)).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
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
                Navigator.of(context).pop(); // ปิด order_detail_screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
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
}
