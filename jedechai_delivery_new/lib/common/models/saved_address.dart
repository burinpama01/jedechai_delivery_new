/// Saved Address Model
///
/// Represents a saved address (home, work, etc.) for quick selection
class SavedAddress {
  final String id;
  final String userId;
  final String label; // 'home', 'work', 'other'
  final String name; // Display name e.g. "บ้าน", "ที่ทำงาน"
  final String address; // Full address text
  final double latitude;
  final double longitude;
  final String? note; // Additional note e.g. "ตึก A ชั้น 5"
  final String? iconName; // Icon identifier
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SavedAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.note,
    this.iconName,
    required this.createdAt,
    this.updatedAt,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String? ?? 'other',
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      note: json['note'] as String?,
      iconName: json['icon_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'label': label,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'note': note,
      'icon_name': iconName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// For inserting new address (without id and timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'label': label,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'note': note,
      'icon_name': iconName,
    };
  }

  SavedAddress copyWith({
    String? id,
    String? userId,
    String? label,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? note,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      label: label ?? this.label,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      note: note ?? this.note,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this is the "home" address
  bool get isHome => label == 'home';

  /// Check if this is the "work" address
  bool get isWork => label == 'work';

  @override
  String toString() {
    return 'SavedAddress(id: $id, label: $label, name: $name, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedAddress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
