import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/review.dart';

void main() {
  group('Review.fromJson', () {
    test('uses merchant-specific rating and comment when present', () {
      final review = Review.fromJson({
        'id': 'review-1',
        'booking_id': 'booking-1',
        'customer_id': 'customer-1',
        'merchant_id': 'merchant-1',
        'rating': 2,
        'comment': 'driver comment',
        'merchant_rating': 5,
        'merchant_comment': 'merchant comment',
        'created_at': '2026-05-07T10:00:00Z',
      });

      expect(review.rating, 5);
      expect(review.comment, 'merchant comment');
    });
  });
}
