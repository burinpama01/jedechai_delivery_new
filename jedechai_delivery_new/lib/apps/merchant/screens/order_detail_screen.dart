import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/services/merchant_food_config_service.dart';
import '../../../common/utils/driver_amount_calculator.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../l10n/app_localizations.dart';

/// Merchant Order Detail Screen
/// 
/// Shows detailed order information with accept/decline actions
class MerchantOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool loadRemoteData;
  final bool enableRealtimeListener;
  final bool enableAutoRefresh;

  const MerchantOrderDetailScreen({
    super.key,
    required this.order,
    this.loadRemoteData = true,
    this.enableRealtimeListener = true,
    this.enableAutoRefresh = true,
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
  double _merchantGpSystemRate = 0.10;
  double _merchantGpDriverRate = 0.0;
  double _deliverySystemRate = 0.02;
  String? _driverName;
  String? _driverPhone;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;

    if (widget.loadRemoteData) {
      _fetchOrderItems();
      _fetchGpRate();
      _fetchDriverInfo();
    }
    if (widget.enableRealtimeListener) {
      _setupOrderStatusListener();
    }
    if (widget.enableAutoRefresh) {
      _startAutoRefresh();
    }
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

  FoodOrderSettlement _foodSettlement(Map<String, dynamic> order) {
    final price = order['price'] is int
        ? (order['price'] as int).toDouble()
        : (order['price'] as num?)?.toDouble() ?? 0.0;
    final deliveryFee = order['delivery_fee'] is int
        ? (order['delivery_fee'] as int).toDouble()
        : (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    return DriverAmountCalculator.foodOrderSettlement(
      foodPrice: price,
      deliveryFee: deliveryFee,
      deliverySystemRate: _deliverySystemRate,
      merchantGpSystemRate: _merchantGpSystemRate,
      merchantGpDriverRate: _merchantGpDriverRate,
    );
  }

  Future<void> _fetchGpRate() async {
    try {
      final merchantId = AuthService.userId;
      if (merchantId == null) return;

      Map<String, dynamic>? merchantProfile;
      try {
        merchantProfile = await Supabase.instance.client
            .from('profiles')
            .select(
              'gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_base_fare, custom_base_distance, custom_per_km, custom_delivery_fee',
            )
            .eq('id', merchantId)
            .maybeSingle();
      } catch (_) {}

      final configService = SystemConfigService();
      await configService.fetchSettings();
      final config = MerchantFoodConfigService.resolve(
        merchantProfile: merchantProfile,
        defaultMerchantSystemRate: configService.merchantGpSystemRateDefault,
        defaultMerchantDriverRate: configService.merchantGpDriverRateDefault,
        defaultDeliverySystemRate: configService.platformFeeRate,
      );

      if (mounted) {
        setState(() {
          _merchantGpSystemRate = config.merchantGpSystemRate;
          _merchantGpDriverRate = config.merchantGpDriverRate;
          _effectiveGpRate = config.merchantGpTotalRate;
          _deliverySystemRate = config.deliverySystemRate;
        });
      }
      debugLog('💰 Merchant finance config loaded: ${config.summary}');
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
          SnackBar(content: Text(AppLocalizations.of(context)!.orderDetailDriverPhoneNotFound)),
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
        _error = AppLocalizations.of(context)!.orderDetailLoadItemsError(e.toString());
      });
    }
  }

  List<dynamic> _parseItemOptions(Map<String, dynamic> item) {
    dynamic rawOptions = item['selected_options'] ?? item['options'];
    if (rawOptions is String && rawOptions.trim().isNotEmpty) {
      try {
        rawOptions = jsonDecode(rawOptions);
      } catch (_) {
        rawOptions = [rawOptions];
      }
    }
    if (rawOptions is List) return rawOptions;
    return const [];
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
            content: Text(AppLocalizations.of(context)!.orderDetailAccepted),
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
            title: Text(AppLocalizations.of(context)!.orderDetailAcceptFailed),
            content: Text(AppLocalizations.of(context)!.orderDetailAcceptError(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(context)!.orderDetailOk),
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
          title: AppLocalizations.of(context)!.orderDetailNotifRejectTitle,
          body: AppLocalizations.of(context)!.orderDetailNotifRejectBody,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.orderDetailDeclined),
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
            title: Text(AppLocalizations.of(context)!.orderDetailDeclineFailed),
            content: Text(AppLocalizations.of(context)!.orderDetailDeclineError(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(context)!.orderDetailOk),
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
        throw Exception(AppLocalizations.of(context)!.orderDetailStatusUpdateFailed);
      }

      if (mounted) {
        // Update current order state to reflect the change
        setState(() {
          _currentOrder = result.first;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.orderDetailFoodReady),
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
            title: Text(AppLocalizations.of(context)!.orderDetailUpdateFailed),
            content: Text(AppLocalizations.of(context)!.orderDetailUpdateError(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(context)!.orderDetailOk),
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
    if (address == null) return AppLocalizations.of(context)!.orderDetailAddressNotSpecified;
    String raw;
    if (address is String) {
      if (address.contains('Instance of') || address.contains('AddressPlacemark')) {
        return AppLocalizations.of(context)!.orderDetailAddressPinLocation;
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
    final settlement = _foodSettlement(order);
    final gpAmount = settlement.merchantGP;
    final merchantReceives = settlement.merchantReceives;
    final createdAt = DateTime.parse(order['created_at'] as String).toLocal();
    final scheduledAtStr = order['scheduled_at'] as String?;
    final scheduledAt = scheduledAtStr != null ? DateTime.tryParse(scheduledAtStr)?.toLocal() : null;
    final notes = order['notes'] as String? ?? '';
    final paymentMethod = order['payment_method'] as String? ?? 'cash';
    final hasDriver = driverId != null && driverId.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.orderDetailTitle(OrderCodeFormatter.formatByServiceType(order['id']?.toString(), serviceType: order['service_type']?.toString())),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
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
                      color: colorScheme.surfaceContainer,
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
                            Icon(Icons.receipt_long_outlined,
                                color: colorScheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.orderDetailOrderInfo,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          AppLocalizations.of(context)!.orderDetailOrderCode,
                          OrderCodeFormatter.formatByServiceType(
                            order['id']?.toString(),
                            serviceType: order['service_type']?.toString(),
                          ),
                        ),
                        _buildInfoRow(AppLocalizations.of(context)!.orderDetailOrderTime, _formatDateTime(createdAt)),
                        _buildInfoRow(AppLocalizations.of(context)!.orderDetailPayment, paymentMethod == 'cash' ? AppLocalizations.of(context)!.orderDetailPaymentCash : AppLocalizations.of(context)!.orderDetailPaymentTransfer),
                        _buildInfoRow(AppLocalizations.of(context)!.orderDetailDistanceLabel, AppLocalizations.of(context)!.orderDetailDistanceKm(distanceKm.toStringAsFixed(1))),
                        if (scheduledAt != null)
                          _buildInfoRow(AppLocalizations.of(context)!.orderDetailScheduled, _formatDateTime(scheduledAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
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
                            Icon(Icons.monetization_on_outlined,
                                color: colorScheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.orderDetailPriceBreakdown,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)!.orderDetailSalesAmount,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant)),
                            Text('฿${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)!.orderDetailGpDeduction((_effectiveGpRate * 100).toStringAsFixed(0)), style: TextStyle(fontSize: 13, color: Colors.red[400])),
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
                              Text(AppLocalizations.of(context)!.orderDetailNetReceived, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[800])),
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
                      color: colorScheme.surfaceContainer,
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
                            Icon(Icons.location_on_outlined,
                                color: colorScheme.onSurfaceVariant, size: 20),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.orderDetailDeliveryAddress,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatAddress(order['destination_address']),
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
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
                                      Text(AppLocalizations.of(context)!.orderDetailCustomerNote, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.amber[900])),
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
                      color: colorScheme.surfaceContainer,
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
                              color: colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.orderDetailFoodItems,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
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
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.orderDetailNoItems,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
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
                                        item['name'] ?? item['item_name'] ?? item['menu_item']?['name'] ?? AppLocalizations.of(context)!.orderDetailItemUnnamed,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                      if (item['quantity'] != null && item['quantity'] != 1) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          AppLocalizations.of(context)!.orderDetailQuantity(item['quantity'].toString()),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      if (_parseItemOptions(item).isNotEmpty) ...[
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
                                                AppLocalizations.of(context)!.orderDetailOptions,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppTheme.accentOrange,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              ..._parseItemOptions(item).map((option) {
                                                // 🛠️ Logic แกะข้อมูล: รองรับทั้งแบบ String และ JSON Map
                                                String optionName = '';
                                                
                                                if (option is Map) {
                                                  // กรณีเป็น Object: {"name": "เส้นเล็ก", "price": 0}
                                                  optionName = option['name'] ?? option['item_name'] ?? AppLocalizations.of(context)!.orderDetailOptionDefault;
                                                  
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
                                              }),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '฿${(((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 1)).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          )),
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
                            child: Text(
                              AppLocalizations.of(context)!.orderDetailDeclineBtn,
                              style: const TextStyle(
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
                                : Text(
                                    AppLocalizations.of(context)!.orderDetailAcceptBtn,
                                    style: const TextStyle(
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
                            AppLocalizations.of(context)!.orderDetailWaitingDriver,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.orderDetailWaitingDriverDesc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
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
                                  Text(_driverName ?? AppLocalizations.of(context)!.merchantDriverDefault, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (_driverPhone != null)
                                    Text(
                                      _driverPhone!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
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
                              : Text(
                                  AppLocalizations.of(context)!.orderDetailFoodReadyBtn,
                                  style: const TextStyle(
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
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.orderDetailStatusLabel(_getStatusText(status)),
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
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
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
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
        return AppLocalizations.of(context)!.orderDetailStatusPending;
      case 'pending_merchant':
        return AppLocalizations.of(context)!.orderDetailStatusPending;
      case 'preparing':
        return AppLocalizations.of(context)!.orderDetailStatusPreparing;
      case 'driver_accepted':
        return AppLocalizations.of(context)!.orderDetailStatusDriverAccepted;
      case 'arrived_at_merchant':
        return AppLocalizations.of(context)!.orderDetailStatusArrivedMerchant;
      case 'ready_for_pickup':
        return AppLocalizations.of(context)!.orderDetailStatusReadyPickup;
      case 'picking_up_order':
        return AppLocalizations.of(context)!.orderDetailStatusPickingUp;
      case 'in_transit':
        return AppLocalizations.of(context)!.orderDetailStatusInTransit;
      case 'cancelled':
        return AppLocalizations.of(context)!.orderDetailStatusCancelled;
      case 'completed':
        return AppLocalizations.of(context)!.orderDetailStatusCompleted;
      default:
        return AppLocalizations.of(context)!.orderDetailStatusUnknown;
    }
  }

  void _showCompletionDialog() {
    final order = _currentOrder ?? widget.order;
    final l10n = AppLocalizations.of(context)!;
    final customerName = order['customer_name'] as String? ?? l10n.orderDetailCustomerDefault;
    final price = order['price'] is int 
        ? (order['price'] as int).toDouble()
        : (order['price'] as num?)?.toDouble() ?? 0.0;
    final bookingId = order['id'].toString();
    final colorScheme = Theme.of(context).colorScheme;
    
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
              l10n.orderDetailCompletionTitle,
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
              Text(
                l10n.orderDetailCompletionBody,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
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
                          Text(
                            l10n.orderDetailCompletionOrderNum,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
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
                          Text(
                            l10n.orderDetailCompletionCustomer,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
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
                          Text(
                            l10n.orderDetailFoodItems,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._orderItems.map((item) {
                        final itemName = item['name'] as String? ?? item['item_name'] as String? ?? l10n.orderDetailItemNotSpecified;
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
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
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
                      }),
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
                        Text(
                          l10n.orderDetailCompletionNetReceived,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.orderDetailCompletionAfterGP((_effectiveGpRate * 100).toStringAsFixed(0)),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '฿${_foodSettlement(order).merchantReceives.toStringAsFixed(0)}',
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
              child: Text(
                l10n.orderDetailCompletionOk,
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
}
