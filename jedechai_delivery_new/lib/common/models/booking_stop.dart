class BookingStop {
  final String id;
  final String bookingId;
  final int stopOrder;
  final String address;
  final double lat;
  final double lng;
  final String status; // pending | arrived | completed
  final DateTime? completedAt;

  const BookingStop({
    required this.id,
    required this.bookingId,
    required this.stopOrder,
    required this.address,
    required this.lat,
    required this.lng,
    required this.status,
    this.completedAt,
  });

  factory BookingStop.fromJson(Map<String, dynamic> json) {
    return BookingStop(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      stopOrder: (json['stop_order'] as num).toInt(),
      address: json['address'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      status: json['status'] as String? ?? 'pending',
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  BookingStop copyWith({String? status, DateTime? completedAt}) {
    return BookingStop(
      id: id,
      bookingId: bookingId,
      stopOrder: stopOrder,
      address: address,
      lat: lat,
      lng: lng,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
