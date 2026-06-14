import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/laundry_order_customer_mapper.dart';

class LaundryService {
  LaundryService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchLaundryMerchants() async {
    final response = await _client
        .from('profiles')
        .select(
          'id, full_name, shop_address, latitude, longitude, shop_photo_url, '
          'custom_delivery_fee, custom_base_fare, custom_base_distance, custom_per_km, '
          'laundry_quote_sound_enabled, laundry_quote_sound_key',
        )
        .eq('role', 'merchant')
        .eq('approval_status', 'approved')
        .contains('merchant_service_types', ['laundry']).order('full_name');

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, double>> fetchLaundryDeliveryRate() async {
    final rows = await _client
        .from('service_rates')
        .select('base_price, base_distance, price_per_km')
        .eq('service_type', 'laundry')
        .limit(1);
    final row = (rows as List).isNotEmpty
        ? Map<String, dynamic>.from(rows.first as Map)
        : <String, dynamic>{};

    return {
      'base_price': (row['base_price'] as num?)?.toDouble() ?? 20.0,
      'base_distance': (row['base_distance'] as num?)?.toDouble() ?? 0.0,
      'price_per_km': (row['price_per_km'] as num?)?.toDouble() ?? 5.0,
    };
  }

  Future<Map<String, dynamic>> fetchMerchantLaundrySettings() async {
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      throw StateError('unauthenticated');
    }

    final response = await _client
        .from('profiles')
        .select('laundry_quote_expiry_minutes, laundry_quote_sound_enabled')
        .eq('id', merchantId)
        .maybeSingle();
    final row = response == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(response);

    return {
      'laundry_quote_expiry_minutes':
          (row['laundry_quote_expiry_minutes'] as num?)?.toInt() ?? 60,
      'laundry_quote_sound_enabled':
          (row['laundry_quote_sound_enabled'] as bool?) ?? true,
    };
  }

  Future<void> saveMerchantLaundrySettings({
    required int quoteExpiryMinutes,
    required bool quoteSoundEnabled,
  }) async {
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      throw StateError('unauthenticated');
    }
    final expiry = quoteExpiryMinutes < 5
        ? 5
        : quoteExpiryMinutes > 1440
            ? 1440
            : quoteExpiryMinutes;

    await _client.from('profiles').update({
      'laundry_quote_expiry_minutes': expiry,
      'laundry_quote_sound_enabled': quoteSoundEnabled,
    }).eq('id', merchantId);
  }

  Future<List<Map<String, dynamic>>> fetchMerchantPackages(
    String merchantId,
  ) async {
    final response = await _client
        .from('laundry_packages')
        .select()
        .eq('merchant_id', merchantId)
        .eq('is_active', true)
        .order('sort_order')
        .order('name');

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMyMerchantPackages() async {
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      throw StateError('unauthenticated');
    }

    final response = await _client
        .from('laundry_packages')
        .select()
        .eq('merchant_id', merchantId)
        .order('sort_order')
        .order('name');

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> saveMerchantPackage({
    String? packageId,
    required String name,
    String? description,
    double? startingPrice,
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      throw StateError('unauthenticated');
    }

    final payload = <String, dynamic>{
      'merchant_id': merchantId,
      'name': name.trim(),
      'description': description?.trim(),
      'base_price': startingPrice,
      'sort_order': sortOrder,
      'is_active': isActive,
    };

    if (packageId == null || packageId.isEmpty) {
      await _client.from('laundry_packages').insert(payload);
      return;
    }

    await _client
        .from('laundry_packages')
        .update(payload)
        .eq('id', packageId)
        .eq('merchant_id', merchantId);
  }

  Future<void> disableMerchantPackage(String packageId) async {
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      throw StateError('unauthenticated');
    }

    await _client
        .from('laundry_packages')
        .update({'is_active': false})
        .eq('id', packageId)
        .eq('merchant_id', merchantId);
  }

  Future<Map<String, dynamic>> createQuoteRequest({
    required String merchantId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    List<Map<String, dynamic>> requestedItems = const [],
    List<String> attachmentUrls = const [],
    String? customerNote,
    String? packageId,
  }) async {
    return _rpc('create_laundry_quote_request', {
      'p_merchant_id': merchantId,
      'p_pickup_lat': pickupLat,
      'p_pickup_lng': pickupLng,
      'p_pickup_address': pickupAddress,
      'p_requested_items': requestedItems,
      'p_attachment_urls': attachmentUrls,
      'p_customer_note': customerNote,
      'p_package_id': packageId,
    });
  }

  Future<Map<String, dynamic>> sendMerchantQuote({
    required String laundryOrderId,
    required double laundryAmount,
    double deliveryFeeOutbound = 0,
    String? quoteMessage,
    int? quoteExpiresMinutes,
    double? platformGpRate,
  }) async {
    return _rpc('merchant_send_laundry_quote', {
      'p_laundry_order_id': laundryOrderId,
      'p_laundry_amount': laundryAmount,
      'p_quote_message': quoteMessage,
      'p_quote_expires_minutes': quoteExpiresMinutes,
      'p_delivery_fee_outbound': deliveryFeeOutbound,
      'p_platform_gp_rate': platformGpRate,
    });
  }

  Future<Map<String, dynamic>> acceptQuote({
    required String laundryOrderId,
    String paymentMethod = 'wallet',
    String pickupPresence = 'remote_pickup',
    String returnMode = 'delivery',
    String returnPaymentMethod = 'cash',
  }) async {
    return _rpc('customer_accept_laundry_quote', {
      'p_laundry_order_id': laundryOrderId,
      'p_payment_method': paymentMethod,
      'p_return_mode': returnMode,
      'p_return_payment_method': returnPaymentMethod,
      'p_pickup_presence': pickupPresence,
    });
  }

  Future<Map<String, dynamic>> createReturnBooking({
    required String laundryOrderId,
    double deliveryFeeReturn = 0,
    String? returnPaymentMethod,
  }) async {
    return _rpc('create_laundry_return_booking', {
      'p_laundry_order_id': laundryOrderId,
      'p_delivery_fee_return': deliveryFeeReturn,
      'p_return_payment_method': returnPaymentMethod,
    });
  }

  Future<Map<String, dynamic>> updateMerchantLaundryStatus({
    required String laundryOrderId,
    required String status,
  }) async {
    return _rpc('merchant_update_laundry_status', {
      'p_laundry_order_id': laundryOrderId,
      'p_status': status,
    });
  }

  Future<Map<String, dynamic>> confirmPickupWithEvidence({
    required String bookingId,
    required String evidenceUrl,
  }) async {
    return _rpc('driver_confirm_laundry_pickup', {
      'p_booking_id': bookingId,
      'p_evidence_url': evidenceUrl,
    });
  }

  Future<List<Map<String, dynamic>>> fetchMyLaundryOrders() async {
    final response = await _client
        .from('laundry_orders')
        .select(
            '*, outbound_booking:outbound_booking_id(*), return_booking:return_booking_id(*)')
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchQuoteMessages(
    String laundryOrderId,
  ) async {
    final response = await _client
        .from('laundry_quote_messages')
        .select('id, sender_id, sender_role, message_type, body, created_at')
        .eq('thread_id', laundryOrderId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> sendQuoteMessage({
    required String laundryOrderId,
    required String body,
  }) async {
    return _rpc('send_laundry_quote_message', {
      'p_laundry_order_id': laundryOrderId,
      'p_body': body,
      'p_message_type': 'text',
    });
  }

  Future<List<Map<String, dynamic>>> fetchMerchantLaundryOrders() async {
    final response = await _client
        .from('laundry_orders')
        .select()
        .order('created_at', ascending: false);

    var orders = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final customerIds = laundryOrderCustomerIds(orders);
    if (customerIds.isNotEmpty) {
      final customersResponse = await _client
          .from('profiles')
          .select('id, full_name, phone_number')
          .inFilter('id', customerIds);
      final customers = (customersResponse as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      orders = attachLaundryOrderCustomers(
        orders: orders,
        customers: customers,
      );
    }

    for (final order in orders) {
      order['_attachment_signed_urls'] =
          await _signedQuoteAttachmentUrls(order['attachment_urls']);
    }
    return orders;
  }

  Future<List<String>> _signedQuoteAttachmentUrls(dynamic rawPaths) async {
    final paths = rawPaths is List
        ? rawPaths.whereType<String>().where((path) => path.isNotEmpty).toList()
        : const <String>[];
    final signedUrls = <String>[];
    for (final path in paths) {
      try {
        final signedUrl = await _client.storage
            .from('laundry-quote-attachments')
            .createSignedUrl(path, 3600);
        signedUrls.add(signedUrl);
      } catch (_) {
        // Keep the order list usable even if one private attachment expires.
      }
    }
    return signedUrls;
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc(name, params: params);
    return result is Map<String, dynamic>
        ? result
        : Map<String, dynamic>.from(result as Map);
  }
}
