import 'package:flutter/material.dart';

/// Centralized Booking Status enum
/// 
/// Single source of truth for all booking statuses across the app.
/// Use extension methods for color, text, and icon.
enum BookingStatus {
  pending,
  pendingMerchant,
  preparing,
  matched,
  readyForPickup,
  accepted,
  driverAccepted,
  arrived,
  arrivedAtMerchant,
  pickingUpOrder,
  inTransit,
  // ISSUE-122: สถานะของงานซักผ้า (laundry_orders) เดิมไม่มีใน enum นี้
  // fromString() จึงตกไปที่ default → pending ทำให้ StatusBadge แสดงว่า
  // "กำลังหาคนขับ" ซึ่งผิดความจริงทั้งหมด
  quoteRequested,
  quoted,
  quoteExpired,
  atMerchant,
  washing,
  readyForReturn,
  completed,
  cancelled;

  /// Convert from database string to enum
  static BookingStatus fromString(String? status) {
    switch (status) {
      case 'pending':
        return BookingStatus.pending;
      case 'pending_merchant':
        return BookingStatus.pendingMerchant;
      case 'preparing':
        return BookingStatus.preparing;
      case 'matched':
        return BookingStatus.matched;
      case 'ready_for_pickup':
        return BookingStatus.readyForPickup;
      case 'accepted':
        return BookingStatus.accepted;
      case 'driver_accepted':
        return BookingStatus.driverAccepted;
      case 'arrived':
        return BookingStatus.arrived;
      case 'arrived_at_merchant':
        return BookingStatus.arrivedAtMerchant;
      case 'picking_up_order':
        return BookingStatus.pickingUpOrder;
      case 'in_transit':
        return BookingStatus.inTransit;
      case 'quote_requested':
        return BookingStatus.quoteRequested;
      case 'quoted':
        return BookingStatus.quoted;
      case 'quote_expired':
        return BookingStatus.quoteExpired;
      case 'at_merchant':
        return BookingStatus.atMerchant;
      case 'washing':
        return BookingStatus.washing;
      case 'ready_for_return':
        return BookingStatus.readyForReturn;
      case 'completed':
        return BookingStatus.completed;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.pending;
    }
  }

  /// Convert enum to database string
  String toDbString() {
    switch (this) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.pendingMerchant:
        return 'pending_merchant';
      case BookingStatus.preparing:
        return 'preparing';
      case BookingStatus.matched:
        return 'matched';
      case BookingStatus.readyForPickup:
        return 'ready_for_pickup';
      case BookingStatus.accepted:
        return 'accepted';
      case BookingStatus.driverAccepted:
        return 'driver_accepted';
      case BookingStatus.arrived:
        return 'arrived';
      case BookingStatus.arrivedAtMerchant:
        return 'arrived_at_merchant';
      case BookingStatus.pickingUpOrder:
        return 'picking_up_order';
      case BookingStatus.inTransit:
        return 'in_transit';
      case BookingStatus.quoteRequested:
        return 'quote_requested';
      case BookingStatus.quoted:
        return 'quoted';
      case BookingStatus.quoteExpired:
        return 'quote_expired';
      case BookingStatus.atMerchant:
        return 'at_merchant';
      case BookingStatus.washing:
        return 'washing';
      case BookingStatus.readyForReturn:
        return 'ready_for_return';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Thai display text for customers
  String get customerText {
    switch (this) {
      case BookingStatus.pending:
        return 'กำลังหาคนขับ';
      case BookingStatus.pendingMerchant:
        return 'รอร้านค้ารับออเดอร์';
      case BookingStatus.preparing:
        return 'ร้านค้ากำลังเตรียมอาหาร';
      case BookingStatus.matched:
        return 'จับคู่คนขับแล้ว';
      case BookingStatus.readyForPickup:
        return 'อาหารพร้อมรับ';
      case BookingStatus.accepted:
        return 'คนขับรับงานแล้ว';
      case BookingStatus.driverAccepted:
        return 'คนขับรับงานแล้ว';
      case BookingStatus.arrived:
        return 'คนขับถึงจุดรับแล้ว';
      case BookingStatus.arrivedAtMerchant:
        return 'คนขับถึงร้านแล้ว';
      case BookingStatus.pickingUpOrder:
        return 'กำลังรับอาหาร';
      case BookingStatus.inTransit:
        return 'กำลังเดินทาง';
      case BookingStatus.quoteRequested:
        return 'รอร้านประเมินราคา';
      case BookingStatus.quoted:
        return 'ร้านเสนอราคาแล้ว';
      case BookingStatus.quoteExpired:
        return 'ใบเสนอราคาหมดอายุ';
      case BookingStatus.atMerchant:
        return 'ของถึงร้านแล้ว';
      case BookingStatus.washing:
        return 'ร้านกำลังซัก';
      case BookingStatus.readyForReturn:
        return 'พร้อมส่งคืน';
      case BookingStatus.completed:
        return 'เสร็จสิ้น';
      case BookingStatus.cancelled:
        return 'ยกเลิกแล้ว';
    }
  }

  /// Thai display text for drivers
  String get driverText {
    switch (this) {
      case BookingStatus.pending:
        return 'รอคนขับ';
      case BookingStatus.pendingMerchant:
        return 'รอร้านค้ารับ';
      case BookingStatus.preparing:
        return 'กำลังทำอาหาร';
      case BookingStatus.matched:
        return 'จับคู่แล้ว';
      case BookingStatus.readyForPickup:
        return 'อาหารพร้อม';
      case BookingStatus.accepted:
        return 'รับงานแล้ว';
      case BookingStatus.driverAccepted:
        return 'คนขับรับแล้ว';
      case BookingStatus.arrived:
        return 'ถึงจุดรับแล้ว';
      case BookingStatus.arrivedAtMerchant:
        return 'ถึงร้านแล้ว';
      case BookingStatus.pickingUpOrder:
        return 'กำลังรับอาหาร';
      case BookingStatus.inTransit:
        return 'กำลังส่ง';
      case BookingStatus.quoteRequested:
        return 'รอร้านประเมินราคา';
      case BookingStatus.quoted:
        return 'ร้านเสนอราคาแล้ว';
      case BookingStatus.quoteExpired:
        return 'ใบเสนอราคาหมดอายุ';
      case BookingStatus.atMerchant:
        return 'ส่งของถึงร้านแล้ว';
      case BookingStatus.washing:
        return 'ร้านกำลังซัก';
      case BookingStatus.readyForReturn:
        return 'รอรับไปส่งคืน';
      case BookingStatus.completed:
        return 'ส่งเสร็จแล้ว';
      case BookingStatus.cancelled:
        return 'ยกเลิกแล้ว';
    }
  }

  /// Thai display text for merchants
  String get merchantText {
    switch (this) {
      case BookingStatus.pending:
        return 'รอดำเนินการ';
      case BookingStatus.pendingMerchant:
        return 'รอรับออเดอร์';
      case BookingStatus.preparing:
        return 'กำลังเตรียม';
      case BookingStatus.matched:
        return 'จับคู่คนขับแล้ว';
      case BookingStatus.readyForPickup:
        return 'พร้อมรับ';
      case BookingStatus.accepted:
        return 'คนขับรับแล้ว';
      case BookingStatus.driverAccepted:
        return 'คนขับรับแล้ว';
      case BookingStatus.arrived:
        return 'คนขับถึงแล้ว';
      case BookingStatus.arrivedAtMerchant:
        return 'คนขับถึงร้านแล้ว';
      case BookingStatus.pickingUpOrder:
        return 'กำลังรับอาหาร';
      case BookingStatus.inTransit:
        return 'กำลังส่ง';
      case BookingStatus.quoteRequested:
        return 'รอเสนอราคา';
      case BookingStatus.quoted:
        return 'เสนอราคาแล้ว';
      case BookingStatus.quoteExpired:
        return 'ใบเสนอราคาหมดอายุ';
      case BookingStatus.atMerchant:
        return 'รับของแล้ว';
      case BookingStatus.washing:
        return 'กำลังซัก';
      case BookingStatus.readyForReturn:
        return 'พร้อมส่งคืน';
      case BookingStatus.completed:
        return 'เสร็จสิ้น';
      case BookingStatus.cancelled:
        return 'ยกเลิก';
    }
  }

  /// Status color
  Color get color {
    switch (this) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.pendingMerchant:
        return Colors.orange;
      case BookingStatus.preparing:
        return Colors.blue;
      case BookingStatus.matched:
        return Colors.indigo;
      case BookingStatus.readyForPickup:
        return Colors.teal;
      case BookingStatus.accepted:
        return Colors.blue;
      case BookingStatus.driverAccepted:
        return Colors.blue;
      case BookingStatus.arrived:
        return Colors.purple;
      case BookingStatus.arrivedAtMerchant:
        return Colors.purple;
      case BookingStatus.pickingUpOrder:
        return Colors.deepPurple;
      case BookingStatus.inTransit:
        return Colors.indigo;
      case BookingStatus.quoteRequested:
        return Colors.orange;
      case BookingStatus.quoted:
        return Colors.blue;
      case BookingStatus.quoteExpired:
        return Colors.grey;
      case BookingStatus.atMerchant:
        return Colors.purple;
      case BookingStatus.washing:
        return Colors.cyan;
      case BookingStatus.readyForReturn:
        return Colors.teal;
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
    }
  }

  /// Status icon
  IconData get icon {
    switch (this) {
      case BookingStatus.pending:
        return Icons.hourglass_empty;
      case BookingStatus.pendingMerchant:
        return Icons.store;
      case BookingStatus.preparing:
        return Icons.restaurant;
      case BookingStatus.matched:
        return Icons.person_pin;
      case BookingStatus.readyForPickup:
        return Icons.check_circle;
      case BookingStatus.accepted:
        return Icons.directions_car;
      case BookingStatus.driverAccepted:
        return Icons.directions_car;
      case BookingStatus.arrived:
        return Icons.location_on;
      case BookingStatus.arrivedAtMerchant:
        return Icons.storefront;
      case BookingStatus.pickingUpOrder:
        return Icons.shopping_bag;
      case BookingStatus.inTransit:
        return Icons.local_shipping;
      case BookingStatus.quoteRequested:
        return Icons.request_quote;
      case BookingStatus.quoted:
        return Icons.price_check;
      case BookingStatus.quoteExpired:
        return Icons.timer_off;
      case BookingStatus.atMerchant:
        return Icons.storefront;
      case BookingStatus.washing:
        return Icons.local_laundry_service;
      case BookingStatus.readyForReturn:
        return Icons.inventory_2;
      case BookingStatus.completed:
        return Icons.done_all;
      case BookingStatus.cancelled:
        return Icons.cancel;
    }
  }

  /// Whether this status is active (not completed or cancelled)
  bool get isActive =>
      this != BookingStatus.completed && this != BookingStatus.cancelled;

  /// Whether a driver has been assigned
  bool get hasDriver =>
      this == BookingStatus.accepted ||
      this == BookingStatus.driverAccepted ||
      this == BookingStatus.arrived ||
      this == BookingStatus.arrivedAtMerchant ||
      this == BookingStatus.pickingUpOrder ||
      this == BookingStatus.inTransit;

  /// Whether the order is in food preparation phase
  bool get isFoodPreparation =>
      this == BookingStatus.pendingMerchant ||
      this == BookingStatus.preparing ||
      this == BookingStatus.readyForPickup;
}
