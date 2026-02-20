/// Review Model
/// 
/// Represents a review in the system
class Review {
  final String id;
  final String bookingId;
  final String customerId;
  final String? driverId;
  final String? merchantId;
  final double rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.bookingId,
    required this.customerId,
    this.driverId,
    this.merchantId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final ratingRaw = json['rating'];
    final double ratingValue;
    if (ratingRaw is num) {
      ratingValue = ratingRaw.toDouble();
    } else if (ratingRaw is String) {
      ratingValue = double.tryParse(ratingRaw) ?? 0.0;
    } else {
      ratingValue = 0.0;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return Review(
      id: json['id'] as String? ?? '',
      bookingId: json['booking_id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      driverId: json['driver_id'] as String?,
      merchantId: json['merchant_id'] as String?,
      rating: ratingValue,
      comment: json['comment'] as String?,
      createdAt: parseDate(json['created_at']),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'customer_id': customerId,
      'driver_id': driverId,
      'merchant_id': merchantId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Review copyWith({
    String? id,
    String? bookingId,
    String? customerId,
    String? driverId,
    String? merchantId,
    double? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      merchantId: merchantId ?? this.merchantId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Review(id: $id, rating: $rating, comment: $comment)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Review && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
