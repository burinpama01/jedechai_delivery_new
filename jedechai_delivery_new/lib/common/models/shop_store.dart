/// ร้านค้าสำหรับบริการฝากซื้อ/ฝากหิ้ว
///
/// ตำแหน่ง ชื่อ และเวลาเปิด-ปิด แอดมินเป็นผู้ตั้งเท่านั้น
/// `isOpenNow` คำนวณมาจาก server แล้ว (ห้ามคำนวณซ้ำจากนาฬิกาเครื่อง
/// เพราะผู้ใช้ตั้งเวลาเครื่องเองได้)
class ShopStore {
  final String id;
  final String name;
  final String category;
  final String? address;
  final double lat;
  final double lng;
  final double distanceKm;
  final bool isOpenNow;
  final DateTime? nextOpenAt;
  final bool issuesReceipt;
  final String? photoUrl;
  final String? note;

  const ShopStore({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.isOpenNow,
    this.nextOpenAt,
    required this.issuesReceipt,
    this.photoUrl,
    this.note,
  });

  factory ShopStore.fromJson(Map<String, dynamic> json) {
    return ShopStore(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'grocery',
      address: json['address'] as String?,
      lat: _toDouble(json['lat']) ?? 0,
      lng: _toDouble(json['lng']) ?? 0,
      distanceKm: _toDouble(json['distance_km']) ?? 0,
      isOpenNow: json['is_open_now'] == true,
      nextOpenAt: json['next_open_at'] == null
          ? null
          : DateTime.tryParse(json['next_open_at'].toString())?.toLocal(),
      issuesReceipt: json['issues_receipt'] != false,
      photoUrl: json['photo_url'] as String?,
      note: json['note'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// หมวดร้าน — ใช้เลือกไอคอนและตัวกรอง
enum ShopStoreCategory { grocery, mall, market, convenience, pharmacy }

ShopStoreCategory? shopCategoryFromKey(String key) {
  switch (key) {
    case 'grocery':
      return ShopStoreCategory.grocery;
    case 'mall':
      return ShopStoreCategory.mall;
    case 'market':
      return ShopStoreCategory.market;
    case 'convenience':
      return ShopStoreCategory.convenience;
    case 'pharmacy':
      return ShopStoreCategory.pharmacy;
  }
  return null;
}

String shopCategoryKey(ShopStoreCategory c) => c.name;
