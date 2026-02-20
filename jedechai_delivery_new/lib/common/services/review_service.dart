import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/review.dart';
import 'auth_service.dart';

/// Review Service
///
/// Handles fetching reviews and computing rating stats
/// for merchants and drivers
class ReviewService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get reviews for a specific driver
  Future<List<Review>> getDriverReviews(String driverId) async {
    try {
      final response = await _client
          .from('reviews')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Review.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching driver reviews: $e');
      return [];
    }
  }

  /// Get reviews for a specific merchant
  Future<List<Review>> getMerchantReviews(String merchantId) async {
    try {
      final response = await _client
          .from('reviews')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Review.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching merchant reviews: $e');
      return [];
    }
  }

  /// Get reviews for the currently logged-in user (driver or merchant)
  Future<List<Review>> getMyReviews() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    try {
      // Try driver reviews first, then merchant reviews
      final driverReviews = await _client
          .from('reviews')
          .select()
          .eq('driver_id', userId)
          .order('created_at', ascending: false);

      final merchantReviews = await _client
          .from('reviews')
          .select()
          .eq('merchant_id', userId)
          .order('created_at', ascending: false);

      final all = <Review>[];
      for (final json in driverReviews) {
        all.add(Review.fromJson(json));
      }
      for (final json in merchantReviews) {
        all.add(Review.fromJson(json));
      }
      // Sort by date
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return all;
    } catch (e) {
      debugLog('❌ Error fetching my reviews: $e');
      return [];
    }
  }

  /// Compute rating stats from a list of reviews
  static RatingStats computeStats(List<Review> reviews) {
    if (reviews.isEmpty) {
      return const RatingStats(
        averageRating: 0,
        totalReviews: 0,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      );
    }

    double sum = 0;
    final distribution = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in reviews) {
      sum += r.rating;
      final star = r.rating.round().clamp(1, 5);
      distribution[star] = (distribution[star] ?? 0) + 1;
    }

    return RatingStats(
      averageRating: sum / reviews.length,
      totalReviews: reviews.length,
      distribution: distribution,
    );
  }

  /// Get customer name for a review (for display)
  Future<String> getCustomerName(String customerId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('full_name, email')
          .eq('id', customerId)
          .maybeSingle();

      if (response == null) return 'ลูกค้า';
      return response['full_name'] as String? ??
          response['email'] as String? ??
          'ลูกค้า';
    } catch (e) {
      return 'ลูกค้า';
    }
  }
}

/// Rating statistics data class
class RatingStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> distribution; // star → count

  const RatingStats({
    required this.averageRating,
    required this.totalReviews,
    required this.distribution,
  });

  /// Get percentage for a specific star rating
  double percentage(int star) {
    if (totalReviews == 0) return 0;
    return ((distribution[star] ?? 0) / totalReviews) * 100;
  }
}
