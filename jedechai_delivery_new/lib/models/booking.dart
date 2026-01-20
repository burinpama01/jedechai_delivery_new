/// Booking Model
class Booking {
  final String id;
  final String customerId;
  final String? driverId;
  final String serviceId;
  final String? merchantId;
  final double originLat;
  final double originLng;
  final String? originAddress;
  final double destLat;
  final double destLng;
  final String? destAddress;
  final double? distanceKm;
  final String status;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final double deliveryFee;
  final double? foodCost;
  final double totalAmount;
  final Map<String, dynamic> details;

  Booking({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.serviceId,
    this.merchantId,
    required this.originLat,
    required this.originLng,
    this.originAddress,
    required this.destLat,
    required this.destLng,
    this.destAddress,
    this.distanceKm,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    required this.deliveryFee,
    this.foodCost,
    required this.totalAmount,
    required this.details,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String?,
      serviceId: json['service_id'] as String,
      merchantId: json['merchant_id'] as String?,
      originLat: (json['origin_lat'] as num).toDouble(),
      originLng: (json['origin_lng'] as num).toDouble(),
      originAddress: json['origin_address'] as String?,
      destLat: (json['dest_lat'] as num).toDouble(),
      destLng: (json['dest_lng'] as num).toDouble(),
      destAddress: json['dest_address'] as String?,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      foodCost: json['food_cost'] != null
          ? (json['food_cost'] as num).toDouble()
          : null,
      totalAmount: (json['total_amount'] as num).toDouble(),
      details: json['details'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'driver_id': driverId,
      'service_id': serviceId,
      'merchant_id': merchantId,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'origin_address': originAddress,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'dest_address': destAddress,
      'distance_km': distanceKm,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'delivery_fee': deliveryFee,
      'food_cost': foodCost,
      'total_amount': totalAmount,
      'details': details,
    };
  }
}
