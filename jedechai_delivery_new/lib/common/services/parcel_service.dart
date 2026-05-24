import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/parcel_detail.dart';
import '../models/booking.dart';
import 'auth_service.dart';
import 'admin_line_notification_service.dart';
import 'booking_service.dart';
import '../utils/app_time.dart';

/// ParcelService - บริการจัดการพัสดุ
class ParcelService {
  final SupabaseClient _client = Supabase.instance.client;

  /// สร้าง Parcel Booking ใหม่ (atomic via RPC)
  Future<Booking?> createParcelBooking({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double distanceKm,
    required double price,
    required String pickupAddress,
    required String destinationAddress,
    required String senderName,
    required String senderPhone,
    required String recipientName,
    required String recipientPhone,
    required String parcelSize,
    String? description,
    double? estimatedWeightKg,
    String? parcelPhotoUrl,
    DateTime? scheduledAt,
    bool notifyDrivers = true,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) {
      debugLog('❌ User not authenticated');
      return null;
    }

    try {
      final notes =
          'พัสดุ: ${description ?? "-"}\nขนาด: $parcelSize\nผู้รับ: $recipientName $recipientPhone';

      final response = await _client.rpc('create_parcel_booking', params: {
        'p_origin_lat': originLat,
        'p_origin_lng': originLng,
        'p_dest_lat': destLat,
        'p_dest_lng': destLng,
        'p_distance_km': distanceKm,
        'p_price': price,
        'p_pickup_address': pickupAddress,
        'p_destination_address': destinationAddress,
        'p_notes': notes,
        'p_scheduled_at':
            scheduledAt == null ? null : AppTime.toDbIso(scheduledAt),
        'p_sender_name': senderName,
        'p_sender_phone': senderPhone,
        'p_recipient_name': recipientName,
        'p_recipient_phone': recipientPhone,
        'p_parcel_size': parcelSize,
        'p_description': description,
        'p_estimated_weight_kg': estimatedWeightKg,
        'p_parcel_photo_url': parcelPhotoUrl,
      });

      if (response == null) {
        debugLog('❌ create_parcel_booking RPC returned null');
        return null;
      }

      final booking = Booking.fromJson(response as Map<String, dynamic>);
      debugLog('✅ Parcel booking created atomically: ${booking.id}');

      if (notifyDrivers) {
        await notifyParcelBookingCreated(
          booking: booking,
          price: price,
          distanceKm: distanceKm,
          pickupAddress: pickupAddress,
          destinationAddress: destinationAddress,
          senderName: senderName,
          senderPhone: senderPhone,
          recipientName: recipientName,
          recipientPhone: recipientPhone,
          parcelSize: parcelSize,
          scheduledAt: scheduledAt,
        );
      }

      return booking;
    } catch (e) {
      debugLog('❌ Error creating parcel booking: $e');
      return null;
    }
  }

  Future<void> notifyParcelBookingCreated({
    required Booking booking,
    required double price,
    required double distanceKm,
    required String pickupAddress,
    required String destinationAddress,
    required String senderName,
    required String senderPhone,
    required String recipientName,
    required String recipientPhone,
    required String parcelSize,
    DateTime? scheduledAt,
  }) async {
    await AdminLineNotificationService.notify(
      eventType: 'parcel_order_new',
      title: 'JDC: มีออเดอร์ส่งพัสดุใหม่',
      message: 'พัสดุใหม่ ขนาด $parcelSize\n'
          'ราคา ฿${price.toStringAsFixed(0)} ระยะทาง ${distanceKm.toStringAsFixed(2)} กม.\n'
          'จาก $senderName → $recipientName',
      data: {
        'booking_id': booking.id,
        'price': price.toStringAsFixed(0),
        'distance_km': distanceKm.toStringAsFixed(2),
        'parcel_size': parcelSize,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'pickup': pickupAddress,
        'destination': destinationAddress,
        if (scheduledAt != null) 'scheduled_at': AppTime.toDbIso(scheduledAt),
      },
    );

    debugLog('📤 Sending new parcel booking notification to drivers...');
    await BookingService().notifyDriversAboutNewBooking(booking);
  }

  /// ดึงรายละเอียดพัสดุจาก booking_id
  Future<ParcelDetail?> getParcelDetail(String bookingId) async {
    try {
      final response = await _client
          .from('parcel_details')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (response == null) return null;
      return ParcelDetail.fromJson(response);
    } catch (e) {
      debugLog('❌ Error fetching parcel detail: $e');
      return null;
    }
  }

  /// คนขับ: อัปเดตรูปตอนรับของ (created → picked_up)
  Future<bool> updatePickupPhoto({
    required String bookingId,
    required String photoUrl,
  }) async {
    try {
      final existingAccepted = await _client
          .from('parcel_details')
          .select('id')
          .eq('booking_id', bookingId)
          .inFilter('parcel_status', ['picked_up', 'in_transit'])
          .limit(1);
      if ((existingAccepted as List).isNotEmpty) {
        debugLog('Pickup photo already accepted for booking: $bookingId');
        return true;
      }

      final result = await _client
          .from('parcel_details')
          .update({
            'pickup_photo_url': photoUrl,
            'parcel_status': 'picked_up',
          })
          .eq('booking_id', bookingId)
          .eq('parcel_status', 'created')
          .select('id');

      if ((result as List).isEmpty) {
        debugLog('⚠️ Pickup update skipped: not in created state ($bookingId)');
        return false;
      }

      debugLog('✅ Pickup photo updated for booking: $bookingId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating pickup photo: $e');
      return false;
    }
  }

  /// คนขับ: อัปเดตสถานะเป็น "กำลังส่ง" (picked_up → in_transit)
  Future<bool> updateInTransit(String bookingId) async {
    try {
      final existingInTransit = await _client
          .from('parcel_details')
          .select('id')
          .eq('booking_id', bookingId)
          .inFilter('parcel_status', ['in_transit', 'delivered'])
          .limit(1);
      if ((existingInTransit as List).isNotEmpty) {
        debugLog('Parcel already in transit: $bookingId');
        return true;
      }

      final result = await _client
          .from('parcel_details')
          .update({'parcel_status': 'in_transit'})
          .eq('booking_id', bookingId)
          .eq('parcel_status', 'picked_up')
          .select('id');

      if ((result as List).isEmpty) {
        debugLog('⚠️ In-transit update skipped: not in picked_up state ($bookingId)');
        return false;
      }

      debugLog('✅ Parcel in transit: $bookingId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating in_transit: $e');
      return false;
    }
  }

  /// คนขับ: อัปเดตรูปตอนส่งของ + ลายเซ็น (in_transit → delivered)
  Future<bool> updateDeliveryPhotos({
    required String bookingId,
    String? deliveryPhotoUrl,
    String? signaturePhotoUrl,
    String? deliveryNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'parcel_status': 'delivered',
      };

      if (deliveryPhotoUrl != null) {
        updateData['delivery_photo_url'] = deliveryPhotoUrl;
      }
      if (signaturePhotoUrl != null) {
        updateData['signature_photo_url'] = signaturePhotoUrl;
      }
      if (deliveryNotes != null && deliveryNotes.isNotEmpty) {
        updateData['delivery_notes'] = deliveryNotes;
      }

      final result = await _client
          .from('parcel_details')
          .update(updateData)
          .eq('booking_id', bookingId)
          .eq('parcel_status', 'in_transit')
          .select('id');

      final existingDelivered = (result as List).isEmpty
          ? await _client
              .from('parcel_details')
              .select('id')
              .eq('booking_id', bookingId)
              .eq('parcel_status', 'delivered')
              .limit(1)
          : const [];
      if (existingDelivered.isNotEmpty) {
        debugLog('Delivery photos already accepted for booking: $bookingId');
        return true;
      }

      if ((result as List).isEmpty) {
        debugLog('⚠️ Delivery update skipped: not in in_transit state ($bookingId)');
        return false;
      }

      debugLog('✅ Delivery photos updated for booking: $bookingId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating delivery photos: $e');
      return false;
    }
  }

  /// อัปเดตรูปพัสดุ (ลูกค้าถ่ายตอนจอง)
  Future<bool> updateParcelPhoto({
    required String bookingId,
    required String photoUrl,
  }) async {
    try {
      final result = await _client.from('parcel_details').update({
        'parcel_photo_url': photoUrl,
      })
          .eq('booking_id', bookingId)
          .eq('parcel_status', 'created')
          .select('id');

      if ((result as List).isEmpty) {
        debugLog('โ ๏ธ Parcel photo update skipped: not in created state ($bookingId)');
        return false;
      }
      return true;
    } catch (e) {
      debugLog('❌ Error updating parcel photo: $e');
      return false;
    }
  }
}
