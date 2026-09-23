// ออเดอร์ฝากซื้อ + รายการของ
//
// ยอดเงินทุกตัวมาจาก server เท่านั้น แอปไม่คำนวณเอง
// (หลักการเดียวกับ Batch 1 — server คำนวณ settlement)

/// รายการของ 1 บรรทัดที่ลูกค้าพิมพ์เอง
class ShopOrderItem {
  final String id;
  final int lineNo;
  final String name;
  final String? quantityText;
  final String? note;

  /// pending | bought | unavailable | substituted
  final String status;
  final double? actualPrice;
  final String? substituteName;

  /// path ของรูปตัวอย่างที่ลูกค้าแนบ (อยู่ใน bucket ส่วนตัว ต้องขอ signed URL ก่อนแสดง)
  final String? refImagePath;

  const ShopOrderItem({
    required this.id,
    required this.lineNo,
    required this.name,
    this.quantityText,
    this.note,
    required this.status,
    this.actualPrice,
    this.substituteName,
    this.refImagePath,
  });

  bool get isPending => status == 'pending';
  bool get isBought => status == 'bought' || status == 'substituted';
  bool get isUnavailable => status == 'unavailable';

  factory ShopOrderItem.fromJson(Map<String, dynamic> json) => ShopOrderItem(
        id: json['id'] as String,
        lineNo: (json['line_no'] as num?)?.toInt() ?? 0,
        name: (json['name_text'] as String?) ?? '',
        quantityText: _emptyToNull(json['quantity_text'] as String?),
        note: _emptyToNull(json['note'] as String?),
        status: (json['status'] as String?) ?? 'pending',
        actualPrice: _toDouble(json['actual_price']),
        substituteName: _emptyToNull(json['substitute_name'] as String?),
        refImagePath: _emptyToNull(json['ref_image_path'] as String?),
      );
}

/// รายการของที่ลูกค้ากำลังพิมพ์ (ยังไม่ส่งขึ้น server)
class ShopDraftItem {
  String name;
  String quantity;
  String note;

  /// path ของไฟล์รูปในเครื่อง (ยังไม่อัปโหลด)
  ///
  /// รูปอัปโหลดได้ก็ต่อเมื่อมี booking_id แล้ว เพราะ policy ของ storage
  /// ตรวจสิทธิ์จาก booking_id ที่อยู่ใน path -> ระหว่างกรอกฟอร์มจึงเก็บไว้ในเครื่องก่อน
  String? localImagePath;

  ShopDraftItem({
    this.name = '',
    this.quantity = '',
    this.note = '',
    this.localImagePath,
  });

  bool get isBlank => name.trim().isEmpty;
  bool get hasImage =>
      localImagePath != null && localImagePath!.trim().isNotEmpty;

  Map<String, dynamic> toRpcJson() => {
        'name': name.trim(),
        'quantity': quantity.trim(),
        'note': note.trim(),
      };

  Map<String, dynamic> toStorageJson() => {
        'name': name,
        'quantity': quantity,
        'note': note,
        'local_image_path': localImagePath,
      };

  factory ShopDraftItem.fromStorageJson(Map<String, dynamic> j) => ShopDraftItem(
        name: (j['name'] as String?) ?? '',
        quantity: (j['quantity'] as String?) ?? '',
        note: (j['note'] as String?) ?? '',
        localImagePath: _emptyToNull(j['local_image_path'] as String?),
      );
}

class ShopOrder {
  final String id;
  final String bookingId;
  final String storeId;
  final String storeName;
  final String storeCategory;
  final double storeLat;
  final double storeLng;

  /// 'receipt' = ร้านออกใบเสร็จ · 'photo' = ต้องให้ลูกค้ายืนยันรูปสินค้า
  final String proofMode;

  final double budgetCap;
  final double holdAmount;
  final double? actualGoodsAmount;
  final double serviceFee;
  final double deliveryFee;
  final double farPickupFee;
  final double? totalAmount;
  final double? refundAmount;
  final double? cancelFee;

  final List<String> proofUrls;
  final DateTime? proofSentAt;
  final DateTime? customerConfirmedAt;
  final String? customerNote;

  /// คนขับขอเพิ่มวงเงิน (ยอดจริงเกินที่กันไว้) — ยอดคำนวณที่ server
  final double? budgetIncreaseAmount;

  /// null · 'requested' · 'approved' · 'declined'
  final String? budgetIncreaseStatus;

  final List<ShopOrderItem> items;

  /// snapshot ค่า config ที่ server เก็บไว้ตอนสร้างออเดอร์
  /// ใช้เพื่อ **แสดงผล** ตัวเลขให้ตรงกับที่ server จะคิดจริงกับออเดอร์นี้
  final Map<String, dynamic> feeSnapshot;

  const ShopOrder({
    required this.id,
    required this.bookingId,
    required this.storeId,
    required this.storeName,
    required this.storeCategory,
    required this.storeLat,
    required this.storeLng,
    required this.proofMode,
    required this.budgetCap,
    required this.holdAmount,
    this.actualGoodsAmount,
    required this.serviceFee,
    required this.deliveryFee,
    required this.farPickupFee,
    this.totalAmount,
    this.refundAmount,
    this.cancelFee,
    required this.proofUrls,
    this.proofSentAt,
    this.customerConfirmedAt,
    this.customerNote,
    this.budgetIncreaseAmount,
    this.budgetIncreaseStatus,
    required this.items,
    this.feeSnapshot = const {},
  });

  bool get hasPendingBudgetIncrease =>
      budgetIncreaseStatus == 'requested' &&
      (budgetIncreaseAmount ?? 0) > 0;

  bool get needsCustomerConfirm =>
      proofMode == 'photo' && customerConfirmedAt == null;

  /// ยอดที่ซื้อได้จริงจนถึงตอนนี้ (ใช้แสดงระหว่างคนขับกำลังเลือกของ)
  double get boughtSubtotal => items
      .where((i) => i.isBought)
      .fold<double>(0, (sum, i) => sum + (i.actualPrice ?? 0));

  int get unavailableCount => items.where((i) => i.isUnavailable).length;

  /// ค่าปรับถ้ายกเลิกตอนคนขับถึงร้านแล้ว
  ///
  /// อ่านอัตราจาก `fee_config_snapshot` ของ **ออเดอร์นี้เอง** ที่ server เก็บไว้
  /// ตอนสร้าง ไม่ใช่ค่าที่ hardcode ในแอป -> แอดมินแก้ค่าแล้วออเดอร์เก่าไม่เพี้ยน
  /// คืน null เมื่ออ่าน snapshot ไม่ได้ ซึ่งหน้าจอต้องไม่แสดงตัวเลขมั่ว
  double? get cancelFeeIfShopping {
    final pct = _snapNum('cancel_fee_pct');
    final max = _snapNum('cancel_fee_max');
    if (pct == null) return null;
    final byPercent = holdAmount * pct / 100;
    if (max == null) return double.parse(byPercent.toStringAsFixed(2));
    final v = byPercent < max ? byPercent : max;
    return double.parse(v.toStringAsFixed(2));
  }

  double? _snapNum(String key) {
    final raw = feeSnapshot[key];
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  factory ShopOrder.fromJson(
    Map<String, dynamic> json, {
    List<ShopOrderItem> items = const [],
  }) {
    return ShopOrder(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      storeId: json['store_id'] as String,
      storeName: (json['store_name'] as String?) ?? '',
      storeCategory: (json['store_category'] as String?) ?? 'grocery',
      storeLat: _toDouble(json['store_lat']) ?? 0,
      storeLng: _toDouble(json['store_lng']) ?? 0,
      proofMode: (json['proof_mode'] as String?) ?? 'receipt',
      budgetCap: _toDouble(json['budget_cap']) ?? 0,
      holdAmount: _toDouble(json['hold_amount']) ?? 0,
      actualGoodsAmount: _toDouble(json['actual_goods_amount']),
      serviceFee: _toDouble(json['service_fee']) ?? 0,
      deliveryFee: _toDouble(json['delivery_fee']) ?? 0,
      farPickupFee: _toDouble(json['far_pickup_fee']) ?? 0,
      totalAmount: _toDouble(json['total_amount']),
      refundAmount: _toDouble(json['refund_amount']),
      cancelFee: _toDouble(json['cancel_fee']),
      proofUrls: (json['proof_urls'] as List?)?.cast<String>() ?? const [],
      proofSentAt: _toDate(json['proof_sent_at']),
      customerConfirmedAt: _toDate(json['customer_confirmed_at']),
      customerNote: _emptyToNull(json['customer_note'] as String?),
      budgetIncreaseAmount: _toDouble(json['budget_increase_amount']),
      budgetIncreaseStatus: json['budget_increase_status'] as String?,
      items: items,
      feeSnapshot: (json['fee_config_snapshot'] as Map?)
              ?.cast<String, dynamic>() ??
          const {},
    );
  }
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

String? _emptyToNull(String? v) =>
    (v == null || v.trim().isEmpty) ? null : v;
