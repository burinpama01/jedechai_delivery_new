import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../common/services/auth_service.dart';

/// Merchant Orders Screen
/// 
/// Displays incoming food orders for merchants with Parallel Flow
/// Features: Shop open/close toggle, order management, driver status
class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  bool _isShopOpen = false;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  Stream<List<Map<String, dynamic>>>? _ordersStream;
  SharedPreferences? _prefs;
  Set<String> _completedOrderIds = {}; // Track completed orders
  bool _showHistory = false; // Toggle between active and history

  @override
  void initState() {
    super.initState();
    _initializePrefs();
    _fetchShopStatus();
    _setupOrdersStream();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSavedShopStatus();
  }

  Future<void> _loadSavedShopStatus() async {
    if (_prefs != null) {
      final savedStatus = _prefs!.getBool('shop_open') ?? false;
      if (mounted) {
        setState(() {
          _isShopOpen = savedStatus;
        });
      }
    }
  }

  Future<void> _saveShopStatus(bool status) async {
    if (_prefs != null) {
      await _prefs!.setBool('shop_open', status);
      print('💾 Shop status saved: $status');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setupOrdersStream() {
    final merchantId = AuthService.userId;
    if (merchantId == null) {
      setState(() {
        _isLoading = false;
        _error = 'ไม่พบข้อมูลผู้ใช้';
      });
      return;
    }

    print('🏪 Setting up orders stream for merchant: $merchantId');

    _ordersStream = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('service_type', 'food')
        .order('created_at', ascending: false)
        .map((data) {
          print('📊 Raw merchant orders data: ${data.length} items');
          
          // Filter by merchant_id in the map function
          final merchantOrders = data.where((item) {
            final itemMerchantId = item['merchant_id'];
            return itemMerchantId != null && itemMerchantId.toString() == merchantId.toString();
          }).toList();
          
          // Filter based on whether we're showing active or history
          final filteredOrders = merchantOrders.where((item) {
            final status = item['status'] as String? ?? '';
            final bookingId = item['id'] as String;
            
            // Check if order was picked up by driver (only for active orders)
            if (!_showHistory && status != 'completed' && status != 'cancelled') {
              _checkDriverPickupStatus(item, bookingId);
            }
            
            if (_showHistory) {
              // Show completed and cancelled orders for history
              return status == 'completed' || status == 'cancelled';
            } else {
              // Show only active orders for main view (exclude orders that have been taken by drivers)
              return status != 'completed' && status != 'cancelled' && status != 'matched' && status != 'driver_accepted' && status != 'traveling_to_merchant' && status != 'arrived_at_merchant' && status != 'picking_up_order' && status != 'in_transit';
            }
          }).toList();
          
          print('📋 Filtered orders (${_showHistory ? "history" : "active"}): ${filteredOrders.length} items');
          return filteredOrders;
        });
    
    print('✅ Stream setup complete');
    
    // Add periodic refresh as fallback for stream issues
    _setupPeriodicRefresh();
  }

  void _setupPeriodicRefresh() {
    // Refresh every 5 seconds as backup for stream issues (increased from 3)
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_showHistory) {
        print('🔄 Periodic refresh - setting up stream again');
        _setupOrdersStream();
        _setupPeriodicRefresh(); // Schedule next refresh
      }
    });
  }

  Future<void> _fetchShopStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select('shop_status')
          .eq('id', userId)
          .single();

      if (mounted) {
        final serverStatus = response['shop_status'] ?? false;
        setState(() {
          _isShopOpen = serverStatus;
          _isLoading = false;
        });
        
        // Save server status to local storage
        await _saveShopStatus(serverStatus);
        print('🔄 Shop status synced from server: $serverStatus');
      }
    } catch (e) {
      print('❌ Error fetching shop status: $e');
      // If server fails, use local saved status
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleShopStatus(bool value) async {
    try {
      setState(() {
        _isShopOpen = value;
      });

      // Save to local storage
      await _saveShopStatus(value);

      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      await Supabase.instance.client
          .from('profiles')
          .update({'shop_status': value})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'เปิดร้านแล้ว' : 'ปิดร้านแล้ว'),
            backgroundColor: value ? AppTheme.accentOrange : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isShopOpen = !value;
        });
        // Revert saved status
        await _saveShopStatus(!value);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเปลี่ยนสถานะร้าน: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveOrderStatus(String bookingId, String status) async {
    if (_prefs != null) {
      await _prefs!.setString('order_status_$bookingId', status);
      await _prefs!.setString('order_updated_$bookingId', DateTime.now().toIso8601String());
      print('💾 Order status saved: $bookingId -> $status');
    }
  }

  Future<String?> _getSavedOrderStatus(String bookingId) async {
    if (_prefs != null) {
      return _prefs!.getString('order_status_$bookingId');
    }
    return null;
  }

  String? _getSavedOrderStatusSync(String bookingId) {
    // Synchronous version for UI building
    if (_prefs != null) {
      return _prefs!.getString('order_status_$bookingId');
    }
    return null;
  }

  Future<void> _clearOrderStatus(String bookingId) async {
    if (_prefs != null) {
      await _prefs!.remove('order_status_$bookingId');
      await _prefs!.remove('order_updated_$bookingId');
      print('🗑️ Order status cleared: $bookingId');
    }
  }

  void _checkDriverPickupStatus(Map<String, dynamic> item, String bookingId) {
    try {
      final status = item['status'] as String? ?? '';
      
      // Check if driver picked up the order (status changed to picking_up_order)
      if (status == 'picking_up_order') {
        // Only show notification if we haven't shown it before for this order
        if (!_completedOrderIds.contains(bookingId)) {
          print('💰 Driver picked up order: $bookingId - showing payment dialog');
          _completedOrderIds.add(bookingId);
          
          if (mounted) {
            // Show payment success notification
            _showPaymentSuccessDialog(item);
          }
        } else {
          print('🔄 Dialog already shown for order: $bookingId - skipping');
        }
      }
    } catch (e) {
      print('❌ Error in _checkDriverPickupStatus: $e');
      // Don't crash the app, just log the error
    }
  }

  void _showPaymentSuccessDialog(Map<String, dynamic> order) {
    final bookingId = order['id'] as String;
    final customerName = order['customer_name'] as String? ?? 'ลูกค้า';
    final price = order['price'] as num? ?? 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('รับเงินสำเร็จ!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.money,
                    color: Colors.green[600],
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '฿${price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'จากคุณ $customerName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'คนขับได้รับออเดอร์และกำลังนำส่งให้ลูกค้าแล้ว',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ร้านค้าสามารถรับออเดอร์ใหม่ได้ทันที',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset to accept new orders
              _resetForNewOrders();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'รับออเดอร์ใหม่',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  void _resetForNewOrders() {
    if (mounted) {
      print('🔄 Resetting for new orders - clearing completedOrderIds');
      
      setState(() {
        // Clear any pending order statuses
        _completedOrderIds.clear();
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('พร้อมรับออเดอร์ใหม่!'),
          backgroundColor: AppTheme.accentOrange,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Add delay to prevent immediate re-trigger
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print('🔄 Reset complete - refreshing stream');
          _setupOrdersStream();
        }
      });
    }
  }

  Future<void> _acceptOrder(String bookingId) async {
    try {
      print('🏪 Merchant accepting order: $bookingId');
      
      // Save pending status immediately
      await _saveOrderStatus(bookingId, 'preparing');
      
      // Get current booking to check status
      final bookingData = await Supabase.instance.client
          .from('bookings')
          .select('status')
          .eq('id', bookingId)
          .single();

      if (bookingData == null) {
        _showErrorSnackBar('Order not found');
        await _clearOrderStatus(bookingId);
        return;
      }

      final currentStatus = bookingData['status'] as String;
      String newStatus;
      
      // Parallel Flow Logic
      if (currentStatus == 'pending') {
        newStatus = 'preparing'; // Merchant accepts first
      } else if (currentStatus == 'driver_accepted') {
        newStatus = 'matched'; // Driver already accepted
      } else if (currentStatus == 'arrived_at_merchant') {
        newStatus = 'ready_for_pickup'; // Driver arrived, merchant marks food ready
      } else {
        _showErrorSnackBar('Order not available for acceptance');
        await _clearOrderStatus(bookingId);
        return;
      }

      print('🔄 Updating order status from $currentStatus to $newStatus');

      // Update booking with parallel flow logic
      final result = await Supabase.instance.client
          .from('bookings')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('status', currentStatus)
          .select();

      print('✅ Order accepted successfully: $result');

      if (result.isEmpty) {
        _showErrorSnackBar('Order already taken or not available');
        await _clearOrderStatus(bookingId);
        return;
      }

      // Update saved status with confirmed status
      await _saveOrderStatus(bookingId, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ออเดอร์ได้รับการยืนยันแล้ว!'),
            backgroundColor: const Color(0xFF10B981), // Green
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Force UI refresh
        setState(() {
          print('🔄 UI refreshed after accepting order');
        });
      }
    } catch (e) {
      print('❌ Failed to accept order: $e');
      await _clearOrderStatus(bookingId);
      _showErrorSnackBar('Cannot accept order: ${e.toString()}');
    }
  }

  Future<void> _markFoodReady(String bookingId) async {
    try {
      // Save pending status immediately
      await _saveOrderStatus(bookingId, 'ready_for_pickup');
      
      final result = await Supabase.instance.client
          .from('bookings')
          .update({'status': 'ready_for_pickup'})
          .eq('id', bookingId)
          .inFilter('status', ['matched', 'preparing'])
          .select();

      if (result.isEmpty) {
        _showErrorSnackBar('Order not available for marking ready');
        await _clearOrderStatus(bookingId);
        return;
      }

      _showSuccessSnackBar('Food marked as ready for pickup');
    } catch (e) {
      print('❌ Failed to mark food ready: $e');
      await _clearOrderStatus(bookingId);
      _showErrorSnackBar('Failed to mark food ready: $e');
    }
  }

  Future<void> _finishOrder(String bookingId) async {
    try {
      final result = await Supabase.instance.client
          .from('bookings')
          .update({'status': 'completed'})
          .eq('id', bookingId)
          .inFilter('status', ['ready_for_pickup', 'in_transit'])
          .select();

      if (result.isEmpty) {
        _showErrorSnackBar('Order not available for finishing');
        return;
      }

      _showSuccessSnackBar('Order completed successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to finish order: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getDriverStatus(String status, Map<String, dynamic> booking) {
    if (status == 'pending') {
      return 'Driver: Waiting...';
    } else if (status == 'driver_accepted' || status == 'matched') {
      final driverName = booking['driver_name'] ?? 'Driver';
      return 'Driver: $driverName is coming';
    } else if (status == 'in_transit') {
      final driverName = booking['driver_name'] ?? 'Driver';
      return 'Driver: $driverName at restaurant';
    } else {
      return 'Driver: Waiting...';
    }
  }

  String _getRestaurantStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting for confirmation';
      case 'preparing':
      case 'driver_accepted':
        return 'Cooking';
      case 'matched':
        return 'Cooking';
      case 'ready_for_pickup':
        return 'Food Ready';
      case 'in_transit':
        return 'Food Ready';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_showHistory ? 'ประวัติออเดอร์' : 'ออเดอร์'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          // Toggle between active and history
          IconButton(
            icon: Icon(_showHistory ? Icons.list : Icons.history),
            onPressed: _toggleView,
            tooltip: _showHistory ? 'ดูออเดอร์ที่กำลังดำเนินการ' : 'ดูประวัติออเดอร์',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchShopStatus,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchShopStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Status Card
          _buildShopStatusCard(),
          const SizedBox(height: 24),
          
          // Orders Section
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _ordersStream,
            builder: (context, snapshot) {
              try {
                print('🔄 Merchant Stream Debug:');
                print('👤 Merchant ID: ${AuthService.userId}');
                print('📊 Orders Count: ${snapshot.data?.length ?? 0}');
                print('🔍 Stream Error: ${snapshot.error}');
                print('🔗 Connection State: ${snapshot.connectionState}');

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('🚨 Stream Error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Stream Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _setupOrdersStream();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data ?? [];
                print('📊 Orders count in merchant UI: ${orders.length}');

                if (orders.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
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
                            color: AppTheme.accentOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.restaurant_outlined,
                            size: 64,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'ไม่มีออเดอร์ใหม่',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isShopOpen ? 'ออเดอร์ใหม่จะปรากฏที่นี่ทันที' : 'เปิดร้านเพื่อรับออเดอร์',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: orders.map((order) {
                    print('🎨 Building order card for: ${order['id']}');
                    return _buildOrderCard(order);
                  }).toList(),
                );
              } catch (e) {
                print('❌ Error in StreamBuilder: $e');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _setupOrdersStream();
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isShopOpen
              ? [
                  AppTheme.accentOrange,
                  AppTheme.accentOrange.withOpacity(0.8),
                ]
              : [
                  Colors.grey,
                  Colors.grey.withOpacity(0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isShopOpen ? AppTheme.accentOrange : Colors.grey).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isShopOpen ? Icons.store : Icons.store_mall_directory,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'สถานะร้าน',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _isShopOpen,
                onChanged: _toggleShopStatus,
                activeColor: Colors.white,
                inactiveThumbColor: Colors.grey[300],
                activeTrackColor: Colors.white.withOpacity(0.5),
                inactiveTrackColor: Colors.white.withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isShopOpen ? 'ร้านเปิด' : 'ร้านปิด',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isShopOpen
                ? 'ลูกค้าสามารถสั่งอาหารได้'
                : 'ร้านปิดให้บริการชั่วคราว',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String;
    final price = order['price'] is int 
        ? (order['price'] as int).toDouble()
        : order['price'] as double;
    final createdAt = DateTime.parse(order['created_at'] as String);
    
    print('🎨 Building order card for: ${order['id']}');
    print('🎨 Order price: $price (type: ${price.runtimeType})');
    print('🎨 Order data keys: ${order.keys.toList()}');
    print('🎨 Pickup address: ${order['pickup_address']}');
    print('🎨 Destination address: ${order['destination_address']}');
    
    // Check if we have saved status that might be newer
    final savedStatus = _getSavedOrderStatusSync(order['id']);
    final displayStatus = savedStatus ?? status;
    
    print('🎨 Order status - Stream: $status, Saved: $savedStatus, Display: $displayStatus');

    final orderCard = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(displayStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusText(displayStatus),
                    style: TextStyle(
                      color: _getStatusColor(displayStatus),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '฿${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Order ID and Time
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  'ออเดอร์ #${order['id'].toString().substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  _getTimeAgo(DateTime.now().difference(createdAt)),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Pickup Address
            if (order['pickup_address'] != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.store_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'รับที่: ${order['pickup_address']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            
            // Destination Address
            if (order['destination_address'] != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ส่งที่: ${order['destination_address']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Action buttons
            _buildActionButtons(order, displayStatus),
          ],
        ),
      ),
    );
    
    print('🎨 Order card built successfully for: ${order['id']}');
    return orderCard;
  }

  Widget _buildActionButtons(Map<String, dynamic> order, String status) {
    switch (status) {
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _acceptOrder(order['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'รับออเดอร์',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'preparing':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _markFoodReady(order['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'อาหารพร้อม',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'driver_accepted':
        return Container(
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
                Icons.person,
                color: Colors.blue[600],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับรับงานแล้ว',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กำลังประกอบอาหาร',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'matched':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _markFoodReady(order['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'อาหารพร้อม',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'traveling_to_merchant':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.directions_car,
                color: Colors.indigo[600],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับกำลังเดินทางมาที่ร้าน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กรุณาเตรียมอาหารให้พร้อม',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.indigo[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'arrived_at_merchant':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _markFoodReady(order['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'อาหารพร้อม',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'picking_up_order':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.lime[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.lime[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.delivery_dining,
                color: Colors.lime[600],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับกำลังรับออเดอร์',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.lime[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กำลังนำส่งให้ลูกค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.lime[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'in_transit':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.cyan[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.local_shipping,
                color: Colors.cyan[600],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'กำลังนำส่งอาหาร',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ออเดอร์กำลังเดินทางถึงลูกค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.cyan[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'ready_for_pickup':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            children: [
              Icon(
                Icons.delivery_dining,
                color: Colors.green[600],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับมารับออเดอร์แล้ว',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ออเดอร์นี้เสร็จสิ้นสำหรับร้านค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'driver_accepted':
        return 'คนขับรับแล้ว';
      case 'preparing':
        return 'กำลังประกอบ';
      case 'matched':
        return 'จับคู่แล้ว';
      case 'ready_for_pickup':
        return 'อาหารพร้อม';
      case 'traveling_to_merchant':
        return 'คนขับกำลังเดินทาง';
      case 'arrived_at_merchant':
        return 'คนขับถึงร้านแล้ว';
      case 'picking_up_order':
        return 'คนขับรับออเดอร์แล้ว';
      case 'in_transit':
        return 'กำลังนำส่ง';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'driver_accepted':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'matched':
        return Colors.green;
      case 'ready_for_pickup':
        return Colors.teal;
      case 'traveling_to_merchant':
        return Colors.indigo;
      case 'arrived_at_merchant':
        return Colors.amber;
      case 'picking_up_order':
        return Colors.lime;
      case 'in_transit':
        return Colors.cyan;
      case 'completed':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (duration.inMinutes < 60) {
      return 'เมื่อ ${duration.inMinutes} นาทีที่แล้ว';
    } else if (duration.inHours < 24) {
      return 'เมื่อ ${duration.inHours} ชั่วโมงที่แล้ว';
    } else {
      return 'เมื่อ ${duration.inDays} วันที่แล้ว';
    }
  }

  String _formatTimeAgo(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'Just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} mins ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} hours ago';
    } else {
      return '${duration.inDays} days ago';
    }
  }

  void _toggleView() {
    setState(() {
      _showHistory = !_showHistory;
    });
    // Re-setup stream with new filter
    _setupOrdersStream();
  }
}
