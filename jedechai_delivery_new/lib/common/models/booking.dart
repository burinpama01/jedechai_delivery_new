/// Booking Model
class Booking {
  final String id;
  final String customerId;
  final String? driverId;
  final String serviceType; // 'ride', 'food', 'parcel'
  final String? merchantId;
  final double originLat;
  final double originLng;
  final String? pickupAddress;
  final double destLat;
  final double destLng;
  final String? destinationAddress;
  final double distanceKm;
  final double price;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? assignedAt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicle;
  final String? notes;
  final String? paymentMethod;
  final double? deliveryFee;
  final double? driverEarnings;
  final double? appEarnings;
  final double? actualDistanceKm;
  final int? tripDurationMinutes;

  Booking({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.serviceType,
    this.merchantId,
    required this.originLat,
    required this.originLng,
    this.pickupAddress,
    required this.destLat,
    required this.destLng,
    this.destinationAddress,
    required this.distanceKm,
    required this.price,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignedAt,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.driverName,
    this.driverPhone,
    this.driverVehicle,
    this.notes,
    this.paymentMethod,
    this.deliveryFee,
    this.driverEarnings,
    this.appEarnings,
    this.actualDistanceKm,
    this.tripDurationMinutes,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String? ?? '',
      customerId: json['customer_id'] as String? ?? '',
      driverId: json['driver_id'] as String?,
      serviceType: json['service_type'] as String? ?? '',
      merchantId: json['merchant_id'] as String?,
      originLat: (json['origin_lat'] as num?)?.toDouble() ?? 0.0,
      originLng: (json['origin_lng'] as num?)?.toDouble() ?? 0.0,
      pickupAddress: json['pickup_address'] as String?,
      destLat: (json['dest_lat'] as num?)?.toDouble() ?? 0.0,
      destLng: (json['dest_lng'] as num?)?.toDouble() ?? 0.0,
      destinationAddress: json['destination_address'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      driverVehicle: json['driver_vehicle'] as String?,
      notes: json['notes'] as String?,
      paymentMethod: json['payment_method'] as String?,
      deliveryFee: json['delivery_fee'] != null
          ? (json['delivery_fee'] as num).toDouble()
          : null,
      driverEarnings: json['driver_earnings'] != null
          ? (json['driver_earnings'] as num).toDouble()
          : null,
      appEarnings: json['app_earnings'] != null
          ? (json['app_earnings'] as num).toDouble()
          : null,
      actualDistanceKm: json['actual_distance_km'] != null
          ? (json['actual_distance_km'] as num).toDouble()
          : null,
      tripDurationMinutes: json['trip_duration_minutes'] != null
          ? (json['trip_duration_minutes'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'driver_id': driverId,
      'service_type': serviceType,
      'merchant_id': merchantId,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'pickup_address': pickupAddress,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'destination_address': destinationAddress,
      'distance_km': distanceKm,
      'price': price,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'assigned_at': assignedAt?.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'driver_vehicle': driverVehicle,
      'notes': notes,
      'payment_method': paymentMethod,
      'delivery_fee': deliveryFee,
      'driver_earnings': driverEarnings,
      'app_earnings': appEarnings,
      'actual_distance_km': actualDistanceKm,
      'trip_duration_minutes': tripDurationMinutes,
    };
  }

  // Legacy support for old fields
  
  // Empty constructor for stream mapping
  Booking.empty()
      : id = '',
        customerId = '',
        driverId = null,
        serviceType = '',
        merchantId = null,
        originLat = 0.0,
        originLng = 0.0,
        pickupAddress = null,
        destLat = 0.0,
        destLng = 0.0,
        destinationAddress = null,
        distanceKm = 0.0,
        price = 0.0,
        status = '',
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        assignedAt = null,
        scheduledAt = null,
        startedAt = null,
        completedAt = null,
        driverName = null,
        driverPhone = null,
        driverVehicle = null,
        notes = null,
        paymentMethod = null,
        deliveryFee = null,
        driverEarnings = null,
        appEarnings = null,
        actualDistanceKm = null,
        tripDurationMinutes = null;
  String get serviceId => serviceType;
  String? get originAddress => pickupAddress;
  String? get destAddress => destinationAddress;
  double? get foodCost => serviceType == 'food' ? price : null;
  /// จำนวนเงินรวมที่ต้องเก็บจากลูกค้า
  double get totalAmount => serviceType == 'food' ? price + (deliveryFee ?? 0) : price;
  /// รายได้สุทธิของคนขับ (หลังหักค่าบริการระบบ)
  double get netEarnings => driverEarnings ?? price;
  DateTime? get acceptedAt => assignedAt;
  Map<String, dynamic> get details => {};
}
