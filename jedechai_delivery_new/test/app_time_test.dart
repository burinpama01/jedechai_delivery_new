import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/models/chat_message.dart';
import 'package:jedechai_delivery_new/common/utils/app_time.dart';

void main() {
  group('AppTime', () {
    test('formats UTC timestamps in Bangkok time', () {
      final utc = DateTime.utc(2026, 5, 20, 17, 30);

      expect(AppTime.formatBangkokDateTime(utc), '21/05/2026 00:30');
      expect(AppTime.formatBangkokTime(utc), '00:30');
    });

    test('serializes scheduled_at to UTC ISO', () {
      final booking = Booking.fromJson({
        'id': 'b1',
        'customer_id': 'c1',
        'service_type': 'food',
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 1,
        'price': 100,
        'status': 'pending',
        'created_at': '2026-05-20T10:00:00Z',
        'updated_at': '2026-05-20T10:00:00Z',
        'scheduled_at': '2026-05-20T12:00:00+07:00',
      });

      expect(booking.scheduledAt, DateTime.utc(2026, 5, 20, 5));
      expect(booking.toJson()['scheduled_at'], '2026-05-20T05:00:00.000Z');
    });

    test('treats offsetless database timestamps as UTC', () {
      expect(
        AppTime.parseDbTimestamp('2026-05-20T05:00:00'),
        DateTime.utc(2026, 5, 20, 5),
      );
    });

    test('converts Bangkok wall-clock schedule to UTC', () {
      final utc = AppTime.bangkokWallClockToUtc(
        year: 2026,
        month: 5,
        day: 20,
        hour: 12,
        minute: 30,
      );

      expect(utc, DateTime.utc(2026, 5, 20, 5, 30));
      expect(AppTime.toDbIso(utc), '2026-05-20T05:30:00.000Z');
    });

    test('groups dates by Bangkok calendar day', () {
      expect(
        AppTime.bangkokDateKey(DateTime.utc(2026, 5, 20, 17, 30)),
        20260521,
      );
    });

    test('normalizes chat timestamps from database', () {
      final message = ChatMessage.fromJson({
        'id': 'm1',
        'chat_room_id': 'r1',
        'sender_id': 'u1',
        'sender_role': 'customer',
        'message': 'hello',
        'created_at': '2026-05-20T12:00:00+07:00',
      });

      expect(message.createdAt, DateTime.utc(2026, 5, 20, 5));
      expect(message.toJson()['created_at'], '2026-05-20T05:00:00.000Z');
    });
  });
}
