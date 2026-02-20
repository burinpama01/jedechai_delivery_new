/// Parcel Detail Model
///
/// เก็บรายละเอียดพัสดุที่เชื่อมกับ booking
class ParcelDetail {
  final String id;
  final String bookingId;

  // ข้อมูลผู้ส่ง
  final String senderName;
  final String senderPhone;
  final String? senderAddress;

  // ข้อมูลผู้รับ
  final String recipientName;
  final String recipientPhone;
  final String? recipientAddress;

  // รายละเอียดพัสดุ
  final String? description;
  final String parcelSize; // small, medium, large, xlarge
  final double? estimatedWeightKg;

  // รูปภาพ
  final String? parcelPhotoUrl;
  final String? pickupPhotoUrl;
  final String? deliveryPhotoUrl;
  final String? signaturePhotoUrl;

  // สถานะ
  final String parcelStatus;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  ParcelDetail({
    required this.id,
    required this.bookingId,
    required this.senderName,
    required this.senderPhone,
    this.senderAddress,
    required this.recipientName,
    required this.recipientPhone,
    this.recipientAddress,
    this.description,
    required this.parcelSize,
    this.estimatedWeightKg,
    this.parcelPhotoUrl,
    this.pickupPhotoUrl,
    this.deliveryPhotoUrl,
    this.signaturePhotoUrl,
    required this.parcelStatus,
    this.pickedUpAt,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ParcelDetail.fromJson(Map<String, dynamic> json) {
    return ParcelDetail(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      senderName: json['sender_name'] as String,
      senderPhone: json['sender_phone'] as String,
      senderAddress: json['sender_address'] as String?,
      recipientName: json['recipient_name'] as String,
      recipientPhone: json['recipient_phone'] as String,
      recipientAddress: json['recipient_address'] as String?,
      description: json['description'] as String?,
      parcelSize: json['parcel_size'] as String? ?? 'small',
      estimatedWeightKg: json['estimated_weight_kg'] != null
          ? (json['estimated_weight_kg'] as num).toDouble()
          : null,
      parcelPhotoUrl: json['parcel_photo_url'] as String?,
      pickupPhotoUrl: json['pickup_photo_url'] as String?,
      deliveryPhotoUrl: json['delivery_photo_url'] as String?,
      signaturePhotoUrl: json['signature_photo_url'] as String?,
      parcelStatus: json['parcel_status'] as String? ?? 'created',
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'sender_name': senderName,
      'sender_phone': senderPhone,
      'sender_address': senderAddress,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'recipient_address': recipientAddress,
      'description': description,
      'parcel_size': parcelSize,
      'estimated_weight_kg': estimatedWeightKg,
      'parcel_photo_url': parcelPhotoUrl,
      'pickup_photo_url': pickupPhotoUrl,
      'delivery_photo_url': deliveryPhotoUrl,
      'signature_photo_url': signaturePhotoUrl,
      'parcel_status': parcelStatus,
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// ข้อความแสดงขนาดพัสดุ
  String get sizeDisplayText {
    switch (parcelSize) {
      case 'small':
        return 'เล็ก (S) - ซองจดหมาย, เอกสาร';
      case 'medium':
        return 'กลาง (M) - กล่องพัสดุ ไม่เกิน 5 กก.';
      case 'large':
        return 'ใหญ่ (L) - กล่องใหญ่ ไม่เกิน 15 กก.';
      case 'xlarge':
        return 'พิเศษ (XL) - สิ่งของขนาดใหญ่ ไม่เกิน 30 กก.';
      default:
        return parcelSize;
    }
  }

  /// ข้อความแสดงสถานะพัสดุ
  String get statusDisplayText {
    switch (parcelStatus) {
      case 'created':
        return 'รอคนขับรับของ';
      case 'picked_up':
        return 'คนขับรับของแล้ว';
      case 'in_transit':
        return 'กำลังจัดส่ง';
      case 'delivered':
        return 'ส่งถึงแล้ว';
      case 'returned':
        return 'ส่งคืน';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return parcelStatus;
    }
  }

  @override
  String toString() {
    return 'ParcelDetail(id: $id, size: $parcelSize, status: $parcelStatus)';
  }
}
