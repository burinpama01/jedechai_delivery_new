import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/notification.dart';
import 'package:jedechai_delivery_new/common/utils/notification_center_utils.dart';

void main() {
  group('NotificationCenterUtils', () {
    test('filters unread notifications', () {
      final notifications = [
        _notification(id: '1', isRead: false, type: 'driver.job.available'),
        _notification(id: '2', isRead: true, type: 'merchant.order.created'),
      ];

      final filtered = NotificationCenterUtils.filterByType(
        notifications,
        'unread',
      );

      expect(filtered.map((n) => n.id), ['1']);
    });

    test('filters by exact type', () {
      final notifications = [
        _notification(id: '1', type: 'driver.job.available'),
        _notification(id: '2', type: 'merchant.order.created'),
      ];

      final filtered = NotificationCenterUtils.filterByType(
        notifications,
        'merchant.order.created',
      );

      expect(filtered.map((n) => n.id), ['2']);
    });

    test('groups notifications by calendar day', () {
      final notifications = [
        _notification(
          id: '1',
          createdAt: DateTime(2026, 5, 7, 9),
        ),
        _notification(
          id: '2',
          createdAt: DateTime(2026, 5, 7, 18),
        ),
        _notification(
          id: '3',
          createdAt: DateTime(2026, 5, 8, 1),
        ),
      ];

      final grouped = NotificationCenterUtils.groupByDate(notifications);

      expect(grouped.keys, [
        DateTime(2026, 5, 7),
        DateTime(2026, 5, 8),
      ]);
      expect(grouped[DateTime(2026, 5, 7)]?.map((n) => n.id), ['1', '2']);
      expect(grouped[DateTime(2026, 5, 8)]?.map((n) => n.id), ['3']);
    });

    test('uses Thai labels for laundry quote notification types', () {
      expect(
        NotificationCenterUtils.typeLabel('laundry.quote_requested'),
        'คำขอซักผ้า',
      );
      expect(
        NotificationCenterUtils.typeLabel('laundry.quote_message'),
        'แชทซักผ้า',
      );
      expect(
        NotificationCenterUtils.typeLabel('laundry.quote_accepted'),
        'Quote ซักผ้า',
      );
      expect(
        NotificationCenterUtils.typeLabel('laundry.quote_expired'),
        'Quote หมดอายุ',
      );
      expect(
        NotificationCenterUtils.typeLabel('laundry.quote_sent'),
        'ราคาซักผ้า',
      );
    });
  });
}

Notification _notification({
  required String id,
  String type = 'general',
  bool isRead = false,
  DateTime? createdAt,
}) {
  return Notification(
    id: id,
    userId: 'user-1',
    title: 'Title $id',
    body: 'Body $id',
    type: type,
    isRead: isRead,
    createdAt: createdAt ?? DateTime(2026, 5, 7),
  );
}
