import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/booking_service.dart';
import '../../../common/services/chat_service.dart';
import '../../../common/services/merchant_order_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/services/merchant_food_config_service.dart';
import '../../../common/models/booking.dart';
import '../../../common/utils/driver_amount_calculator.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/widgets/chat_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/utils/role_amount_calculator.dart';

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
  State<MerchantOrderDetailScreen> createState() =>
      _MerchantOrderDetailScreenState();
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
  String? _customerName;
  String? _customerPhone;
  // สร้างแบบ lazy: หน้าจอ render ได้โดยไม่ต้องมี Supabase instance (widget test)
  late final MerchantOrderService _merchantOrderService = MerchantOrderService();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;

    if (widget.loadRemoteData) {
      // loader อ้าง AppLocalizations.of(context) ในเส้นทาง error
      // จึงต้องรอให้ initState จบก่อน ไม่งั้นชน assertion ของ Flutter
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchOrderItems();
      });
      _fetchGpRate();
      _fetchDriverInfo();
      _fetchCustomerInfo();
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
    debugLog(
        '⏱️ Starting auto-refresh every 2 seconds for order: ${widget.order['id']}');

    _autoRefreshTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
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
            // Preserve enriched customer data across raw booking refreshes
            _currentOrder = {
              ...Map<String, dynamic>.from(response),
              if (_customerName != null) 'customer_name': _customerName,
              if (_customerPhone != null) 'customer_phone': _customerPhone,
            };
          });
          debugLog(
              '🔄 Auto-refreshed order status: $newStatus (previous: $oldStatus)');

          // Check if status changed to picking_up_order and show dialog
          if (newStatus == 'picking_up_order' &&
              oldStatus != 'picking_up_order' &&
              !_dialogShown) {
            _dialogShown = true;
            debugLog(
                '💰 [AUTO-REFRESH] Status changed to picking_up_order - showing completion dialog');
            debugLog('💰 [AUTO-REFRESH] Setting _dialogShown to true');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                debugLog('💰 [AUTO-REFRESH] Calling _showCompletionDialog()');
                _showCompletionDialog();
              } else {
                debugLog(
                    '⚠️ [AUTO-REFRESH] Widget not mounted, cannot show dialog');
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
    debugLog(
        '🔔 Setting up order status listener for order: ${widget.order['id']}');
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

          // Update current order state, preserving enriched customer data
          setState(() {
            _currentOrder = {
              ...Map<String, dynamic>.from(order),
              if (_customerName != null) 'customer_name': _customerName,
              if (_customerPhone != null) 'customer_phone': _customerPhone,
            };
          });

          // Show completion dialog when driver picks up order
          if (status == 'picking_up_order') {
            debugLog(
                '🔍 Status is picking_up_order, checking _dialogShown flag...');
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
              debugLog(
                  '⚠️ Dialog already shown (_dialogShown = true), skipping');
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

  Future<void> _fetchCustomerInfo() async {
    final customerId = (_currentOrder ?? widget.order)['customer_id'] as String?;
    if (customerId == null || customerId.isEmpty) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', customerId)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _customerName = profile['full_name'] as String?;
          _customerPhone = profile['phone_number'] as String?;
        });
      }
    } catch (e) {
      debugLog('⚠️ Error fetching customer info: $e');
    }
  }

  Future<void> _callDriver() async {
    if (_driverPhone == null || _driverPhone!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .orderDetailDriverPhoneNotFound)),
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
        _error = AppLocalizations.of(context)!
            .orderDetailLoadItemsError(e.toString());
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
        setState(() {
          _currentOrder = {
            ...Map<String, dynamic>.from(result.first),
            if (_customerName != null) 'customer_name': _customerName,
            if (_customerPhone != null) 'customer_phone': _customerPhone,
          };
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.orderDetailAccepted),
            backgroundColor: JdcColors.of(context).successFill,
            duration: const Duration(seconds: 2),
          ),
        );

        unawaited(BookingService().notifyDriversAboutNewBooking(
          Booking.fromJson(Map<String, dynamic>.from(result.first)),
        ));
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.error_outline,
                color: JdcColors.of(ctx).danger, size: 48),
            title: Text(AppLocalizations.of(context)!.orderDetailAcceptFailed),
            content: Text(AppLocalizations.of(context)!
                .orderDetailAcceptError(e.toString())),
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
            backgroundColor: JdcColors.of(context).danger,
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
            icon: Icon(Icons.error_outline,
                color: JdcColors.of(ctx).danger, size: 48),
            title: Text(AppLocalizations.of(context)!.orderDetailDeclineFailed),
            content: Text(AppLocalizations.of(context)!
                .orderDetailDeclineError(e.toString())),
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

  Future<void> _openCustomerChat() async {
    final order = _currentOrder ?? widget.order;
    final bookingId = order['id']?.toString();
    final customerId = order['customer_id']?.toString();
    final merchantId = AuthService.userId ?? order['merchant_id']?.toString();

    if (bookingId == null ||
        bookingId.isEmpty ||
        customerId == null ||
        customerId.isEmpty ||
        merchantId == null ||
        merchantId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderDetailChatError),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
      return;
    }

    final chatService = ChatService();
    final room = await chatService.getOrCreateMerchantOrderChatRoom(
      bookingId: bookingId,
      customerId: customerId,
      merchantId: merchantId,
    );

    if (!mounted) return;
    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.orderDetailChatError),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId: bookingId,
          chatRoomId: room.id,
          otherPartyName:
              AppLocalizations.of(context)!.orderDetailCustomerDefault,
          roomType: 'merchant_order',
        ),
      ),
    );
  }

  Future<void> _markFoodReady() async {
    final statusUpdateFailed =
        AppLocalizations.of(context)!.orderDetailStatusUpdateFailed;
    final foodReadyText = AppLocalizations.of(context)!.orderDetailFoodReady;
    const pendingDriverArrivalText = 'บันทึกอาหารพร้อมแล้ว รอคนขับถึงร้าน';

    setState(() {
      _isLoading = true;
    });

    try {
      final merchantId = AuthService.userId;
      final bookingId = widget.order['id']?.toString();
      if (merchantId == null || bookingId == null || bookingId.isEmpty) {
        throw Exception(statusUpdateFailed);
      }

      final result = await _merchantOrderService.markFoodReady(
        bookingId: bookingId,
        merchantId: merchantId,
      );
      if (!result.success) {
        throw Exception(result.errorMessage ?? statusUpdateFailed);
      }

      if (mounted) {
        setState(() {
          if (result.booking != null) {
            _currentOrder = {
              ...Map<String, dynamic>.from(result.booking!),
              if (_customerName != null) 'customer_name': _customerName,
              if (_customerPhone != null) 'customer_phone': _customerPhone,
            };
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.pendingDriverArrival
                ? pendingDriverArrivalText
                : foodReadyText),
            backgroundColor: JdcColors.of(context).successFill,
            duration: const Duration(seconds: 2),
          ),
        );
        // Don't pop - stay on this screen to see status updates
      }

      if (!result.pendingDriverArrival && result.booking != null) {
        await BookingService()
            .notifyDriversAboutNewBooking(Booking.fromJson(result.booking!));
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.error_outline,
                color: JdcColors.of(ctx).danger, size: 48),
            title: Text(AppLocalizations.of(context)!.orderDetailUpdateFailed),
            content: Text(AppLocalizations.of(context)!
                .orderDetailUpdateError(e.toString())),
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
    if (address == null)
      return AppLocalizations.of(context)!.orderDetailAddressNotSpecified;
    String raw;
    if (address is String) {
      if (address.contains('Instance of') ||
          address.contains('AddressPlacemark')) {
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
    final scheduledAt = scheduledAtStr != null
        ? DateTime.tryParse(scheduledAtStr)?.toLocal()
        : null;
    final notes = order['notes'] as String? ?? '';
    final paymentMethod = order['payment_method'] as String? ?? 'cash';
    final hasDriver = driverId != null && driverId.isNotEmpty;
    final jdc = JdcColors.of(context);
    final tones = _statusTones(jdc, status);

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.orderDetailTitle(
              OrderCodeFormatter.formatByServiceType(order['id']?.toString(),
                  serviceType: order['service_type']?.toString())),
        ),
        actions: [
          IconButton(
            tooltip: 'แชทกับลูกค้า',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openCustomerChat,
          ),
        ],
        backgroundColor: jdc.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: jdc.text,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(jdc.brand),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: JdcSpacing.lg),
              child: JdcContentFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card — โทนตามสถานะแบบ artboard
                    // (ออเดอร์ใหม่ = brand-soft เน้นทอง)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(JdcSpacing.lg),
                      decoration: BoxDecoration(
                        color: tones.bg,
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                        border: Border.all(color: tones.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: jdc.surface,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                            ),
                            child: Icon(
                              _getStatusIcon(status),
                              color: tones.fg,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: JdcSpacing.md),
                          Expanded(
                            child: Text(
                              _getStatusText(status),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: _jt(
                                  fontSize: 17, color: tones.fg, weight: 700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.lg),

                    // Customer Info Card
                    if (_customerName != null || _customerPhone != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(JdcSpacing.lg),
                        margin: const EdgeInsets.only(bottom: JdcSpacing.lg),
                        decoration: BoxDecoration(
                          color: jdc.infoSoft,
                          borderRadius: BorderRadius.circular(JdcRadius.card),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: jdc.surface,
                              child: Icon(Icons.person,
                                  color: jdc.infoInk, size: 22),
                            ),
                            const SizedBox(width: JdcSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_customerName != null)
                                    Text(_customerName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _jt(
                                            fontSize: 15,
                                            color: jdc.infoInk,
                                            weight: 600)),
                                  if (_customerPhone != null)
                                    Text(_customerPhone!,
                                        style: _jt(
                                            fontSize: 13,
                                            color: jdc.muted)),
                                ],
                              ),
                            ),
                            if (_customerPhone != null)
                              Material(
                                color: jdc.successFill,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: () async {
                                    final uri = Uri.parse('tel:$_customerPhone');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(Icons.phone,
                                        size: 18, color: jdc.onCta),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                  // Order Info Card
                  _surfaceCard(
                    jdc,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardTitle(jdc, Icons.receipt_long_outlined,
                            AppLocalizations.of(context)!.orderDetailOrderInfo),
                        const SizedBox(height: JdcSpacing.lg),
                        _buildInfoRow(
                          AppLocalizations.of(context)!.orderDetailOrderCode,
                          OrderCodeFormatter.formatByServiceType(
                            order['id']?.toString(),
                            serviceType: order['service_type']?.toString(),
                          ),
                        ),
                        _buildInfoRow(
                            AppLocalizations.of(context)!.orderDetailOrderTime,
                            _formatDateTime(createdAt)),
                        _buildInfoRow(
                            AppLocalizations.of(context)!.orderDetailPayment,
                            paymentMethod == 'cash'
                                ? AppLocalizations.of(context)!
                                    .orderDetailPaymentCash
                                : AppLocalizations.of(context)!
                                    .orderDetailPaymentTransfer),
                        _buildInfoRow(
                            AppLocalizations.of(context)!
                                .orderDetailDistanceLabel,
                            AppLocalizations.of(context)!.orderDetailDistanceKm(
                                distanceKm.toStringAsFixed(1))),
                        if (scheduledAt != null)
                          _buildInfoRow(
                              AppLocalizations.of(context)!
                                  .orderDetailScheduled,
                              _formatDateTime(scheduledAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: JdcSpacing.lg),

                  // Financial Breakdown Card
                  _surfaceCard(
                    jdc,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardTitle(
                            jdc,
                            Icons.monetization_on_outlined,
                            AppLocalizations.of(context)!
                                .orderDetailPriceBreakdown),
                        const SizedBox(height: JdcSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                AppLocalizations.of(context)!
                                    .orderDetailSalesAmount,
                                style: _jt(
                                    fontSize: 13, color: jdc.muted)),
                            Text(
                                RoleAmountCalculator.formatBahtCeil(price),
                                style: _jt(
                                    fontSize: 13,
                                    color: jdc.text,
                                    weight: 600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                AppLocalizations.of(context)!
                                    .orderDetailGpDeduction(
                                        (_effectiveGpRate * 100)
                                            .toStringAsFixed(0)),
                                style: _jt(
                                    fontSize: 13, color: jdc.danger)),
                            Text(
                                '-฿${RoleAmountCalculator.formatMoney(gpAmount)}',
                                style: _jt(
                                    fontSize: 13, color: jdc.danger)),
                          ],
                        ),
                        Divider(
                          height: JdcSpacing.lg,
                          thickness: 1,
                          color: jdc.line,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(
                              child: Text(
                                  AppLocalizations.of(context)!
                                      .orderDetailNetReceived,
                                  style: _jt(
                                      fontSize: 14,
                                      color: jdc.text,
                                      weight: 700)),
                            ),
                            Text(
                              '฿${RoleAmountCalculator.formatMoney(merchantReceives)}',
                              style: _jt(
                                  fontSize: 20,
                                  color: jdc.text,
                                  weight: 700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 15,
                                color: jdc.muted),
                            const SizedBox(width: JdcSpacing.sm),
                            Expanded(
                              child: Text(
                                'โอนเข้ากระเป๋าร้านหลังส่งสำเร็จ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    _jt(fontSize: 12, color: jdc.muted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: JdcSpacing.lg),

                  // Address Card
                  _surfaceCard(
                    jdc,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardTitle(
                            jdc,
                            Icons.location_on_outlined,
                            AppLocalizations.of(context)!
                                .orderDetailDeliveryAddress),
                        const SizedBox(height: JdcSpacing.lg),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(JdcSpacing.md),
                          decoration: BoxDecoration(
                            color: jdc.sunken,
                            borderRadius:
                                BorderRadius.circular(JdcRadius.small),
                          ),
                          child: Text(
                            _formatAddress(order['destination_address']),
                            style: _jt(fontSize: 14, color: jdc.text),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (notes.isNotEmpty &&
                            !notes.startsWith('สั่งอาหารจาก')) ...[
                          const SizedBox(height: JdcSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(JdcSpacing.md),
                            decoration: BoxDecoration(
                              color: jdc.infoSoft,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 20, color: jdc.infoInk),
                                const SizedBox(width: JdcSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          AppLocalizations.of(context)!
                                              .orderDetailCustomerNote,
                                          style: _jt(
                                              fontSize: 12,
                                              color: jdc.infoInk,
                                              weight: 700)),
                                      const SizedBox(height: 4),
                                      Text(notes,
                                          style: _jt(
                                              fontSize: 14,
                                              color: jdc.infoInk,
                                              weight: 600)),
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
                  const SizedBox(height: JdcSpacing.lg),

                  // Order Items Card
                  _surfaceCard(
                    jdc,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardTitle(
                            jdc,
                            Icons.restaurant_menu_outlined,
                            AppLocalizations.of(context)!
                                .orderDetailFoodItems),
                        const SizedBox(height: JdcSpacing.lg),
                        if (_error != null)
                          Container(
                            padding: const EdgeInsets.all(JdcSpacing.md),
                            decoration: BoxDecoration(
                              color: jdc.dangerSoft,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                              border: Border.all(color: jdc.dangerLine),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: jdc.danger, size: 20),
                                const SizedBox(width: JdcSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: _jt(
                                        fontSize: 14, color: jdc.dangerInk),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_orderItems.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(JdcSpacing.md),
                            decoration: BoxDecoration(
                              color: jdc.sunken,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.orderDetailNoItems,
                              style: _jt(fontSize: 14, color: jdc.muted),
                            ),
                          )
                        else
                          ..._orderItems.map((item) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: JdcSpacing.md),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: jdc.sunken,
                                        borderRadius: BorderRadius.circular(
                                            JdcRadius.small),
                                      ),
                                      child: Text(
                                        '${item['quantity'] ?? 1}',
                                        style: _jt(
                                            fontSize: 13,
                                            color: jdc.text,
                                            weight: 700),
                                      ),
                                    ),
                                    const SizedBox(width: JdcSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'] ??
                                                item['item_name'] ??
                                                item['menu_item']?['name'] ??
                                                AppLocalizations.of(context)!
                                                    .orderDetailItemUnnamed,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: _jt(
                                                fontSize: 14,
                                                color: jdc.text,
                                                weight: 700),
                                          ),
                                          if (item['quantity'] != null &&
                                              item['quantity'] != 1) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              AppLocalizations.of(context)!
                                                  .orderDetailQuantity(
                                                      item['quantity']
                                                          .toString()),
                                              style: _jt(
                                                  fontSize: 12,
                                                  color: jdc.muted),
                                            ),
                                          ],
                                          if (_parseItemOptions(item)
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _parseItemOptions(item)
                                                  .map((option) {
                                                // แกะข้อมูล option: รองรับทั้ง String และ JSON Map
                                                if (option is Map) {
                                                  return (option['name'] ??
                                                          option[
                                                              'item_name'] ??
                                                          AppLocalizations.of(
                                                                  context)!
                                                              .orderDetailOptionDefault)
                                                      .toString();
                                                }
                                                return option.toString();
                                              }).join(' · '),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: _jt(
                                                  fontSize: 12,
                                                  color: jdc.muted),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: JdcSpacing.sm),
                                    Text(
                                      RoleAmountCalculator.formatBahtCeil(
                                          ((item['price'] as num?)
                                                      ?.toDouble() ??
                                                  0.0) *
                                              ((item['quantity'] as num?)
                                                      ?.toInt() ??
                                                  1)),
                                      style: _jt(
                                          fontSize: 13,
                                          color: jdc.text,
                                          weight: 700),
                                    ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                  const SizedBox(height: JdcSpacing.xxl),

                  // Action Buttons
                  if (status == 'pending_merchant' || status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _declineOrder,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: jdc.danger,
                              minimumSize:
                                  Size.fromHeight(JdcTouch.button),
                              padding: const EdgeInsets.symmetric(
                                  vertical: JdcSpacing.lg),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(JdcRadius.card),
                              ),
                              side: BorderSide(color: jdc.dangerLine),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!
                                  .orderDetailDeclineBtn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _jt(
                                  fontSize: 15,
                                  color: jdc.danger,
                                  weight: 700),
                            ),
                          ),
                        ),
                        const SizedBox(width: JdcSpacing.md),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _acceptOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: jdc.cta,
                              foregroundColor: jdc.onCta,
                              minimumSize:
                                  Size.fromHeight(JdcTouch.button),
                              padding: const EdgeInsets.symmetric(
                                  vertical: JdcSpacing.lg),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(JdcRadius.card),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              jdc.onCta),
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!
                                        .orderDetailAcceptBtn,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _jt(
                                        fontSize: 16,
                                        color: jdc.onCta,
                                        weight: 700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (status == 'preparing' && driverId == null) ...[
                    // Waiting for driver to accept
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(JdcSpacing.xl),
                      decoration: BoxDecoration(
                        color: jdc.brandSoft,
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                        border: Border.all(color: jdc.brandLine),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            color: jdc.brandOnSoft,
                            size: 32,
                          ),
                          const SizedBox(height: JdcSpacing.md),
                          Text(
                            AppLocalizations.of(context)!
                                .orderDetailWaitingDriver,
                            textAlign: TextAlign.center,
                            style: _jt(
                                fontSize: 16,
                                color: jdc.brandOnSoft,
                                weight: 700),
                          ),
                          const SizedBox(height: JdcSpacing.sm),
                          Text(
                            AppLocalizations.of(context)!
                                .orderDetailWaitingDriverDesc,
                            textAlign: TextAlign.center,
                            style: _jt(fontSize: 14, color: jdc.muted),
                          ),
                        ],
                      ),
                    ),
                  ] else if (hasDriver &&
                      (status == 'driver_accepted' ||
                          status == 'arrived_at_merchant' ||
                          status == 'preparing' ||
                          status == 'matched' ||
                          status == 'accepted' ||
                          status == 'arrived')) ...[
                    // ปุ่มโทรหาคนขับ
                    if (_driverName != null || _driverPhone != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: JdcSpacing.md),
                        padding: const EdgeInsets.symmetric(
                            horizontal: JdcSpacing.lg,
                            vertical: JdcSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: jdc.infoSoft,
                          borderRadius: BorderRadius.circular(JdcRadius.card),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: jdc.surface,
                              child: Icon(Icons.delivery_dining,
                                  size: 20, color: jdc.infoInk),
                            ),
                            const SizedBox(width: JdcSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      _driverName ??
                                          AppLocalizations.of(context)!
                                              .merchantDriverDefault,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _jt(
                                          fontSize: 14,
                                          color: jdc.infoInk,
                                          weight: 600)),
                                  if (_driverPhone != null)
                                    Text(
                                      _driverPhone!,
                                      style:
                                          _jt(fontSize: 12, color: jdc.muted),
                                    ),
                                ],
                              ),
                            ),
                            if (_driverPhone != null)
                              Material(
                                color: jdc.successFill,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  onTap: _callDriver,
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Icon(Icons.phone,
                                        size: 20, color: jdc.onCta),
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
                            backgroundColor: jdc.successFill,
                            foregroundColor: jdc.onCta,
                            minimumSize: Size.fromHeight(JdcTouch.button),
                            padding: const EdgeInsets.symmetric(
                                vertical: JdcSpacing.lg),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.card),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        jdc.onCta),
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context)!
                                      .orderDetailFoodReadyBtn,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _jt(
                                      fontSize: 16,
                                      color: jdc.onCta,
                                      weight: 700),
                                ),
                        ),
                      ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(JdcSpacing.xl),
                      decoration: BoxDecoration(
                        color: jdc.sunken,
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: jdc.muted,
                            size: 24,
                          ),
                          const SizedBox(height: JdcSpacing.sm),
                          Text(
                            AppLocalizations.of(context)!
                                .orderDetailStatusLabel(_getStatusText(status)),
                            textAlign: TextAlign.center,
                            style: _jt(fontSize: 14, color: jdc.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                ],
              ),
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

  /// โทนสีตามสถานะออเดอร์ — artboard: ออเดอร์ใหม่/กำลังเตรียมเน้นทอง,
  /// พร้อมส่ง/เสร็จเขียว, ยกเลิกแดง
  ({Color bg, Color fg, Color border}) _statusTones(
      JdcColors jdc, String status) {
    switch (status) {
      case 'completed':
      case 'ready':
      case 'food_ready':
        return (
          bg: jdc.successSoft,
          fg: jdc.successInk,
          border: jdc.successLine,
        );
      case 'cancelled':
        return (
          bg: jdc.dangerSoft,
          fg: jdc.dangerInk,
          border: jdc.dangerLine,
        );
      case 'pending':
      case 'pending_merchant':
      case 'confirmed':
      case 'preparing':
      case 'accepted':
        return (
          bg: jdc.brandSoft,
          fg: jdc.brandOnSoft,
          border: jdc.brandLine,
        );
      default:
        return (bg: jdc.infoSoft, fg: jdc.infoInk, border: jdc.line);
    }
  }

  /// การ์ดพื้น surface ขอบ line เงา card ตามระบบดีไซน์
  Widget _surfaceCard(JdcColors jdc, {required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: JdcSpacing.lg),
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: child,
    );
  }

  /// หัวการ์ด: ไอคอนในกล่อง sunken + ชื่อหัวข้อ
  Widget _cardTitle(JdcColors jdc, IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: jdc.sunken,
            borderRadius: BorderRadius.circular(JdcRadius.small),
          ),
          child: Icon(icon, size: 18, color: jdc.cta),
        ),
        const SizedBox(width: JdcSpacing.md),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _jt(fontSize: 15, color: jdc.text, weight: 700),
          ),
        ),
      ],
    );
  }

  /// TextStyle พร้อม fontVariations คู่ fontWeight (Noto Sans Thai variable)
  TextStyle _jt({
    double? fontSize,
    Color? color,
    double weight = 400,
    double? height,
    double? letterSpacing,
  }) {
    const weightMap = <int, FontWeight>{
      400: FontWeight.w400,
      500: FontWeight.w500,
      600: FontWeight.w600,
      700: FontWeight.w700,
      800: FontWeight.w800,
      900: FontWeight.w900,
    };
    return TextStyle(
      fontSize: fontSize,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: weightMap[weight.round()] ?? FontWeight.w400,
      fontVariations: [FontVariation('wght', weight)],
    );
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
    final customerName = _customerName ??
        order['customer_name'] as String? ??
        l10n.orderDetailCustomerDefault;
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
                color: JdcColors.of(context).successSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: JdcColors.of(context).successInk,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.orderDetailCompletionTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: JdcColors.of(context).successInk,
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
                  color: JdcColors.of(context).infoSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: JdcColors.of(context).line),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: JdcColors.of(context).infoInk,
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
                              color: JdcColors.of(context).infoInk,
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
                  color: JdcColors.of(context).brandSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: JdcColors.of(context).brandLine),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: JdcColors.of(context).cta,
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
                              color: JdcColors.of(context).cta,
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
                    color: JdcColors.of(context).successSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: JdcColors.of(context).successLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: JdcColors.of(context).successInk,
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
                        final itemName = item['name'] as String? ??
                            item['item_name'] as String? ??
                            l10n.orderDetailItemNotSpecified;
                        final quantity = item['quantity'] as int? ?? 1;
                        final itemPrice = item['price'] is int
                            ? (item['price'] as int).toDouble()
                            : (item['price'] as num?)?.toDouble() ?? 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: JdcColors.of(context).successSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${quantity}x',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: JdcColors.of(context).successInk,
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
                                RoleAmountCalculator.formatBahtCeil(itemPrice),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: JdcColors.of(context).successInk,
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
                    colors: [
                      JdcColors.of(context).brand,
                      JdcColors.of(context).brandHi
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: JdcColors.of(context).brand.withValues(alpha: 0.3),
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
                            color: JdcColors.of(context).panel.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.orderDetailCompletionAfterGP(
                              (_effectiveGpRate * 100).toStringAsFixed(0)),
                          style: TextStyle(
                            fontSize: 12,
                            color: JdcColors.of(context).panel.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '฿${RoleAmountCalculator.formatMoney(_foodSettlement(order).merchantReceives)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: JdcColors.of(context).onCta,
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
                backgroundColor: JdcColors.of(context).cta,
                foregroundColor: JdcColors.of(context).onCta,
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
