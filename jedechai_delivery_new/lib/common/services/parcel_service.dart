import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/parcel_detail.dart';
import '../models/booking.dart';
import 'auth_service.dart';
import 'system_config_service.dart';
import 'admin_line_notification_service.dart';

/// ParcelService - บริการจัดการพัสดุ
///
/// ฟีเจอร์:
/// - สร้าง booking + parcel_details พร้อมกัน
/// - อัปเดตสถานะพัสดุ (คนขับ)
/// - อัปโหลดรูปภาพแต่ละขั้นตอน
/// - ดึงรายละเอียดพัสดุ
class ParcelService {
  final SupabaseClient _client = Supabase.instance.client;

  /// สร้าง Parcel Booking ใหม่
  ///
  /// สร้าง booking (service_type='parcel') + parcel_details พร้อมกัน
  Future<Booking?> createParcelBooking({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double distanceKm,
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
  }) async {
    final userId = AuthService.userId;
    if (userId == null) {
      debugLog('❌ User not authenticated');
      return null;
    }

    try {
      // 1. คำนวณราคา
      final configService = SystemConfigService();
      await configService.fetchSettings();
      final calculatedPrice = await configService.calculateDeliveryFee(
        serviceType: 'parcel',
        distanceKm: distanceKm,
      );

      // ปรับราคาตามขนาดพัสดุ
      final sizeMultiplier = _getSizeMultiplier(parcelSize);
      final finalPrice = (calculatedPrice * sizeMultiplier).round();

      debugLog(
          '💰 Parcel price: $finalPrice THB (base: $calculatedPrice × $sizeMultiplier)');

      // 2. สร้าง booking
      final bookingResponse = await _client
          .from('bookings')
          .insert({
            'customer_id': userId,
            'service_type': 'parcel',
            'origin_lat': originLat,
            'origin_lng': originLng,
            'dest_lat': destLat,
            'dest_lng': destLng,
            'distance_km': distanceKm,
            'price': finalPrice,
            'pickup_address': pickupAddress,
            'destination_address': destinationAddress,
            'notes':
                'พัสดุ: ${description ?? "-"}\nขนาด: $parcelSize\nผู้รับ: $recipientName $recipientPhone',
            'status': 'pending',
            'payment_method': 'cash',
            'scheduled_at': scheduledAt?.toIso8601String(),
          })
          .select()
          .single();

      final booking = Booking.fromJson(bookingResponse);
      debugLog('✅ Booking created: ${booking.id}');

      // 3. สร้าง parcel_details
      await _client.from('parcel_details').insert({
        'booking_id': booking.id,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'sender_address': pickupAddress,
        'recipient_name': recipientName,
        'recipient_phone': recipientPhone,
        'recipient_address': destinationAddress,
        'description': description,
        'parcel_size': parcelSize,
        'estimated_weight_kg': estimatedWeightKg,
        'parcel_photo_url': parcelPhotoUrl,
        'parcel_status': 'created',
      });

      debugLog('✅ Parcel details created for booking: ${booking.id}');
      await AdminLineNotificationService.notify(
        eventType: 'parcel_order_new',
        title: 'JDC: มีออเดอร์ส่งพัสดุใหม่',
        message:
            'มีออเดอร์ส่งพัสดุใหม่ ฿${finalPrice.toStringAsFixed(0)} ระยะทาง ${distanceKm.toStringAsFixed(2)} กม.',
        data: {
          'booking_id': booking.id,
          'customer_id': userId,
          'sender_name': senderName,
          'sender_phone': senderPhone,
          'recipient_name': recipientName,
          'recipient_phone': recipientPhone,
          'parcel_size': parcelSize,
          'pickup': pickupAddress,
          'destination': destinationAddress,
          'scheduled_at': scheduledAt?.toIso8601String(),
        },
      );
      return booking;
    } catch (e) {
      debugLog('❌ Error creating parcel booking: $e');
      return null;
    }
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

  /// คนขับ: อัปเดตรูปตอนรับของ
  Future<bool> updatePickupPhoto({
    required String bookingId,
    required String photoUrl,
  }) async {
    try {
      await _client.from('parcel_details').update({
        'pickup_photo_url': photoUrl,
        'parcel_status': 'picked_up',
        'picked_up_at': DateTime.now().toIso8601String(),
      }).eq('booking_id', bookingId);

      debugLog('✅ Pickup photo updated for booking: $bookingId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating pickup photo: $e');
      return false;
    }
  }

  /// คนขับ: อัปเดตสถานะเป็น "กำลังส่ง"
  Future<bool> updateInTransit(String bookingId) async {
    try {
      await _client.from('parcel_details').update({
        'parcel_status': 'in_transit',
      }).eq('booking_id', bookingId);

      debugLog('✅ Parcel in transit: $bookingId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating in_transit: $e');
      return false;
    }
  }

  /// คนขับ: อัปเดตรูปตอนส่งของ + ลายเซ็น
  Future<bool> updateDeliveryPhotos({
    required String bookingId,
    String? deliveryPhotoUrl,
    String? signaturePhotoUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'parcel_status': 'delivered',
        'delivered_at': DateTime.now().toIso8601String(),
      };

      if (deliveryPhotoUrl != null) {
        updateData['delivery_photo_url'] = deliveryPhotoUrl;
      }
      if (signaturePhotoUrl != null) {
        updateData['signature_photo_url'] = signaturePhotoUrl;
      }

      await _client
          .from('parcel_details')
          .update(updateData)
          .eq('booking_id', bookingId);

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
      await _client.from('parcel_details').update({
        'parcel_photo_url': photoUrl,
      }).eq('booking_id', bookingId);
      return true;
    } catch (e) {
      debugLog('❌ Error updating parcel photo: $e');
      return false;
    }
  }

  /// ตัวคูณราคาตามขนาดพัสดุ
  double _getSizeMultiplier(String size) {
    switch (size) {
      case 'small':
        return 1.0;
      case 'medium':
        return 1.3;
      case 'large':
        return 1.6;
      case 'xlarge':
        return 2.0;
      default:
        return 1.0;
    }
  }
}
