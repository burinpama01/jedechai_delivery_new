import '../models/notification.dart' as notification_model;

class NotificationCenterUtils {
  static List<notification_model.Notification> filterByType(
    List<notification_model.Notification> notifications,
    String type,
  ) {
    if (type == 'all') return List.of(notifications);
    if (type == 'unread') {
      return notifications
          .where((notification) => !notification.isRead)
          .toList();
    }
    return notifications
        .where((notification) => notification.type == type)
        .toList();
  }

  static Map<DateTime, List<notification_model.Notification>> groupByDate(
    List<notification_model.Notification> notifications,
  ) {
    final grouped = <DateTime, List<notification_model.Notification>>{};
    for (final notification in notifications) {
      final key = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );
      grouped.putIfAbsent(key, () => []).add(notification);
    }
    return grouped;
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'customer':
        return 'ลูกค้า';
      case 'driver':
        return 'คนขับ';
      case 'merchant':
        return 'ร้านค้า';
      default:
        return 'แจ้งเตือน';
    }
  }

  static String typeLabel(String? type) {
    if (type == null || type.isEmpty) return 'ทั่วไป';
    switch (type) {
      // งาน / ออเดอร์
      case 'driver.job.available':
        return 'งานใหม่';
      case 'merchant.order.created':
        return 'ออเดอร์ใหม่';
      case 'merchant_accepted':
        return 'ร้านรับออเดอร์';
      case 'food_ready':
      case 'food_ready_driver':
        return 'อาหารพร้อม';
      case 'customer.booking.status_changed':
      case 'booking_status_update':
        return 'สถานะงาน';
      case 'customer.booking.driver_assigned':
        return 'คนขับรับงาน';
      case 'driver_arrived_merchant':
        return 'คนขับถึงร้าน';
      case 'booking_cancelled':
        return 'ยกเลิกงาน';
      // แชท
      case 'chat':
      case 'chat_message':
        return 'แชท';
      // การเงิน
      case 'topup_request':
        return 'คำขอเติมเงิน';
      case 'admin_approve_topup':
        return 'เติมเงินสำเร็จ';
      case 'admin_reject_topup':
        return 'เติมเงินไม่สำเร็จ';
      case 'withdrawal':
        return 'คำขอถอนเงิน';
      case 'withdrawal_refund':
        return 'คืนเงินถอน';
      case 'admin_approve_withdrawal':
        return 'อนุมัติถอนเงิน';
      case 'admin_reject_withdrawal':
        return 'ปฏิเสธถอนเงิน';
      // งานถูกโอนโดยแอดมิน
      case 'admin_reassign':
        return 'โอนงาน';
      case 'admin_reassign_new_driver':
        return 'มอบหมายงานใหม่';
      case 'admin_reassign_old_driver':
        return 'ย้ายงาน';
      case 'admin_reassign_customer':
      case 'admin_reassign_merchant':
        return 'เปลี่ยนคนขับ';
      // ปัญหา / บัญชี
      case 'new_ticket':
        return 'ปัญหาใหม่';
      case 'ticket_updated':
        return 'อัปเดตปัญหา';
      case 'account.deletion.rejected':
        return 'คำขอลบบัญชี';
      // ซักผ้า
      case 'laundry.quote_requested':
        return 'คำขอซักผ้า';
      case 'laundry.quote_ready':
      case 'laundry.quote_sent':
        return 'ราคาซักผ้า';
      case 'laundry.quote_message':
        return 'แชทซักผ้า';
      case 'laundry.quote_accepted':
        return 'Quote ซักผ้า';
      case 'laundry.quote_expired':
        return 'Quote หมดอายุ';
      case 'laundry.return_booking_created':
        return 'ส่งผ้ากลับ';
    }
    // เผื่อ type ที่ต่อท้ายด้วย role (admin_approve_driver/customer/merchant ฯลฯ)
    if (type.startsWith('admin_approve_')) return 'อนุมัติบัญชี';
    if (type.startsWith('admin_reject_')) return 'ปฏิเสธบัญชี';
    if (type.startsWith('admin_reassign')) return 'โอนงาน';
    if (type.startsWith('laundry.')) return 'ซักผ้า';
    if (type.startsWith('chat')) return 'แชท';
    // ไม่โชว์ type code ดิบให้ผู้ใช้เห็นอีกต่อไป
    return 'แจ้งเตือน';
  }
}
