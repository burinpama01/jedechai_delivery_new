import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantOrderService {
  final SupabaseClient _client;

  MerchantOrderService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> watchOrders(String merchantId) {
    // RLS policy ensures only this merchant's rows are streamed server-side.
    // The client-side filter is a safety net for latency window edge cases.
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', merchantId)
        .map((rows) => rows
            .where((item) => item['service_type'] == 'food')
            .map(Map<String, dynamic>.from)
            .toList());
  }

  Future<List<Map<String, dynamic>>> fetchOrders(String merchantId) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('service_type', 'food')
        .eq('merchant_id', merchantId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> fetchShopStatus(String merchantId) async {
    final response = await _client
        .from('profiles')
        .select('shop_status, order_accept_mode, shop_auto_schedule_enabled')
        .eq('id', merchantId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> toggleShopStatus(
    String merchantId,
    bool isOpen, {
    required bool disableAutoSchedule,
  }) async {
    final updateData = {
      'shop_status': isOpen,
      'is_online': isOpen,
      if (disableAutoSchedule) 'shop_auto_schedule_enabled': false,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('profiles')
        .update(updateData)
        .eq('id', merchantId)
        .select('shop_status, shop_auto_schedule_enabled')
        .maybeSingle();

    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<MerchantAcceptOrderResult> acceptOrder(String bookingId) async {
    final bookingData = await _client
        .from('bookings')
        .select('status')
        .eq('id', bookingId)
        .single();

    final currentStatus = bookingData['status'] as String;
    final newStatus = nextAcceptedStatus(currentStatus);
    if (newStatus == null) {
      return MerchantAcceptOrderResult.unavailable(currentStatus);
    }

    final result = await _client
        .from('bookings')
        .update({
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', bookingId)
        .eq('status', currentStatus)
        .select();

    if (result.isEmpty) {
      return MerchantAcceptOrderResult.taken(currentStatus, newStatus);
    }

    return MerchantAcceptOrderResult.accepted(
      currentStatus: currentStatus,
      newStatus: newStatus,
      booking: Map<String, dynamic>.from(result.first),
    );
  }

  Future<MerchantFoodReadyResult> markFoodReady({
    required String bookingId,
    required String merchantId,
  }) async {
    final result = await _client.rpc(
      'mark_food_ready_guarded',
      params: {
        'p_booking_id': bookingId,
        'p_merchant_id': merchantId,
      },
    );

    if (result is Map && result['success'] != true) {
      return MerchantFoodReadyResult.failure(
        result['error']?.toString() ?? 'Order not available for marking ready',
      );
    }

    if (result is Map && result['pending_driver_arrival'] == true) {
      return MerchantFoodReadyResult.pendingDriverArrival();
    }

    final booking =
        await _client.from('bookings').select().eq('id', bookingId).single();

    return MerchantFoodReadyResult.ready(Map<String, dynamic>.from(booking));
  }

  Future<void> updateShopSchedule(
    String merchantId, {
    required String shopOpenTime,
    required String shopCloseTime,
    required List<dynamic> shopOpenDays,
    required String orderAcceptMode,
    required bool shopAutoScheduleEnabled,
  }) async {
    await _client.from('profiles').update({
      'shop_open_time': shopOpenTime,
      'shop_close_time': shopCloseTime,
      'shop_open_days': shopOpenDays,
      'order_accept_mode': orderAcceptMode,
      'shop_auto_schedule_enabled': shopAutoScheduleEnabled,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', merchantId);
  }

  Future<bool> finishOrder(String bookingId) async {
    final result = await _client
        .from('bookings')
        .update({'status': 'completed'})
        .eq('id', bookingId)
        .inFilter('status', ['ready_for_pickup', 'in_transit'])
        .select();

    return result.isNotEmpty;
  }

  static String? nextAcceptedStatus(String currentStatus) {
    if (currentStatus == 'pending' || currentStatus == 'pending_merchant') {
      return 'preparing';
    }
    if (currentStatus == 'driver_accepted') {
      return 'matched';
    }
    if (currentStatus == 'arrived_at_merchant') {
      return 'ready_for_pickup';
    }
    return null;
  }
}

class MerchantAcceptOrderResult {
  final bool accepted;
  final String currentStatus;
  final String? newStatus;
  final Map<String, dynamic>? booking;
  final String? errorCode;

  const MerchantAcceptOrderResult._({
    required this.accepted,
    required this.currentStatus,
    this.newStatus,
    this.booking,
    this.errorCode,
  });

  factory MerchantAcceptOrderResult.accepted({
    required String currentStatus,
    required String newStatus,
    required Map<String, dynamic> booking,
  }) {
    return MerchantAcceptOrderResult._(
      accepted: true,
      currentStatus: currentStatus,
      newStatus: newStatus,
      booking: booking,
    );
  }

  factory MerchantAcceptOrderResult.unavailable(String currentStatus) {
    return MerchantAcceptOrderResult._(
      accepted: false,
      currentStatus: currentStatus,
      errorCode: 'unavailable',
    );
  }

  factory MerchantAcceptOrderResult.taken(
    String currentStatus,
    String newStatus,
  ) {
    return MerchantAcceptOrderResult._(
      accepted: false,
      currentStatus: currentStatus,
      newStatus: newStatus,
      errorCode: 'taken',
    );
  }
}

class MerchantFoodReadyResult {
  final bool success;
  final bool pendingDriverArrival;
  final Map<String, dynamic>? booking;
  final String? errorMessage;

  const MerchantFoodReadyResult._({
    required this.success,
    required this.pendingDriverArrival,
    this.booking,
    this.errorMessage,
  });

  factory MerchantFoodReadyResult.ready(Map<String, dynamic> booking) {
    return MerchantFoodReadyResult._(
      success: true,
      pendingDriverArrival: false,
      booking: booking,
    );
  }

  factory MerchantFoodReadyResult.pendingDriverArrival() {
    return const MerchantFoodReadyResult._(
      success: true,
      pendingDriverArrival: true,
    );
  }

  factory MerchantFoodReadyResult.failure(String message) {
    return MerchantFoodReadyResult._(
      success: false,
      pendingDriverArrival: false,
      errorMessage: message,
    );
  }
}
