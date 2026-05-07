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
}
