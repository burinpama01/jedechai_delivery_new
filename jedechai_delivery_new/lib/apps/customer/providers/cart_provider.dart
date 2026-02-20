import 'package:flutter/foundation.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';

/// Cart Item Model
class CartItem {
  final String menuItemId;
  final String name;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final double optionsPrice;
  final List<String> selectedOptions;
  int quantity;

  CartItem({
    required this.menuItemId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.basePrice,
    this.optionsPrice = 0,
    this.selectedOptions = const [],
    this.quantity = 1,
  });

  double get totalPrice => (basePrice + optionsPrice) * quantity;

  Map<String, dynamic> toJson() => {
    'id': menuItemId,
    'name': name,
    'description': description,
    'image_url': imageUrl,
    'base_price': basePrice,
    'price': totalPrice,
    'selected_options': selectedOptions,
    'quantity': quantity,
  };

  CartItem copyWith({int? quantity}) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      basePrice: basePrice,
      optionsPrice: optionsPrice,
      selectedOptions: selectedOptions,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Cart Provider — จัดการ state ตะกร้าสินค้าทั้งแอป
class CartProvider extends ChangeNotifier {
  // ข้อมูลร้านค้าปัจจุบัน
  String? _merchantId;
  String? _merchantName;

  // รายการในตะกร้า
  final List<CartItem> _items = [];

  // ค่าจัดส่ง
  double _deliveryFee = 0.0;

  // หมายเหตุถึงร้าน
  String _note = '';

  // Getters
  String? get merchantId => _merchantId;
  String? get merchantName => _merchantName;
  List<CartItem> get items => List.unmodifiable(_items);
  double get deliveryFee => _deliveryFee;
  String get note => _note;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get totalPrice => subtotal + _deliveryFee;

  /// เพิ่มรายการลงตะกร้า
  /// ถ้าเปลี่ยนร้าน จะล้างตะกร้าเดิมก่อน
  /// Returns true ถ้าเพิ่มสำเร็จ, false ถ้าต้องยืนยันเปลี่ยนร้าน
  bool addItem({
    required String merchantId,
    required String merchantName,
    required CartItem item,
  }) {
    // ถ้าตะกร้ามีของจากร้านอื่น
    if (_merchantId != null && _merchantId != merchantId && _items.isNotEmpty) {
      return false; // ต้องยืนยันก่อน
    }

    _merchantId = merchantId;
    _merchantName = merchantName;
    _items.add(item);

    debugLog('🛒 เพิ่ม ${item.name} x${item.quantity} ลงตะกร้า');
    debugLog('   └─ ตะกร้ามี $totalItems รายการ รวม ฿${subtotal.toStringAsFixed(2)}');

    notifyListeners();
    return true;
  }

  /// บังคับเพิ่ม (ล้างร้านเดิมแล้วเพิ่มร้านใหม่)
  void forceAddItem({
    required String merchantId,
    required String merchantName,
    required CartItem item,
  }) {
    clearCart();
    _merchantId = merchantId;
    _merchantName = merchantName;
    _items.add(item);
    notifyListeners();
  }

  /// อัพเดทจำนวน
  void updateQuantity(int index, int newQuantity) {
    if (index < 0 || index >= _items.length) return;

    if (newQuantity <= 0) {
      removeItem(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      notifyListeners();
    }
  }

  /// ลบรายการ
  void removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);
    debugLog('🗑️ ลบ ${removed.name} ออกจากตะกร้า');

    if (_items.isEmpty) {
      _merchantId = null;
      _merchantName = null;
      _deliveryFee = 0.0;
    }
    notifyListeners();
  }

  /// ตั้งค่าจัดส่ง
  void setDeliveryFee(double fee) {
    _deliveryFee = fee;
    notifyListeners();
  }

  /// ตั้งหมายเหตุ
  void setNote(String note) {
    _note = note;
    notifyListeners();
  }

  /// ล้างตะกร้า
  void clearCart() {
    _items.clear();
    _merchantId = null;
    _merchantName = null;
    _deliveryFee = 0.0;
    _note = '';
    debugLog('🗑️ ล้างตะกร้าทั้งหมด');
    notifyListeners();
  }

  /// แปลงเป็น list ของ Map สำหรับส่ง API
  List<Map<String, dynamic>> toCartList() {
    return _items.map((item) => item.toJson()).toList();
  }
}
