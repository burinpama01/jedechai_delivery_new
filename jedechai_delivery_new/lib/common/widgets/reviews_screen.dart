import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../../theme/app_theme.dart';

/// Reviews Screen
///
/// Displays reviews and rating stats for a merchant or driver.
/// Can be used from merchant app, driver app, or customer-facing detail screens.
class ReviewsScreen extends StatefulWidget {
  final String? targetUserId; // null = current user
  final String targetRole; // 'driver' or 'merchant'
  final String title;

  const ReviewsScreen({
    super.key,
    this.targetUserId,
    required this.targetRole,
    this.title = 'รีวิวและคะแนน',
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ReviewService _reviewService = ReviewService();
  List<Review> _reviews = [];
  RatingStats _stats = const RatingStats(
    averageRating: 0,
    totalReviews: 0,
    distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  );
  bool _isLoading = true;
  final Map<String, String> _customerNames = {};

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    List<Review> reviews;
    if (widget.targetUserId != null) {
      if (widget.targetRole == 'driver') {
        reviews = await _reviewService.getDriverReviews(widget.targetUserId!);
      } else {
        reviews = await _reviewService.getMerchantReviews(widget.targetUserId!);
      }
    } else {
      reviews = await _reviewService.getMyReviews();
    }

    // Fetch customer names
    for (final r in reviews) {
      if (!_customerNames.containsKey(r.customerId)) {
        _customerNames[r.customerId] =
            await _reviewService.getCustomerName(r.customerId);
      }
    }

    if (mounted) {
      setState(() {
        _reviews = reviews;
        _stats = ReviewService.computeStats(reviews);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.targetRole == 'driver'
            ? Colors.blue[700]
            : AppTheme.accentOrange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviews,
              child: CustomScrollView(
                slivers: [
                  // Stats header
                  SliverToBoxAdapter(child: _buildStatsHeader()),

                  // Reviews list
                  if (_reviews.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildReviewCard(_reviews[index]),
                          childCount: _reviews.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.targetRole == 'driver'
              ? [Colors.blue[600]!, Colors.blue[800]!]
              : [Colors.orange[400]!, Colors.deepOrange[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (widget.targetRole == 'driver'
                    ? Colors.blue
                    : Colors.orange)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Big average rating
          Column(
            children: [
              Text(
                _stats.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              _buildStarRow(_stats.averageRating, 20),
              const SizedBox(height: 4),
              Text(
                '${_stats.totalReviews} รีวิว',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Distribution bars
          Expanded(
            child: Column(
              children: List.generate(5, (index) {
                final star = 5 - index;
                return _buildDistributionBar(star);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(int star) {
    final pct = _stats.percentage(star);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$star',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.amber),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '${_stats.distribution[star] ?? 0}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRow(double rating, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        if (rating >= starValue) {
          return Icon(Icons.star, size: size, color: Colors.amber);
        } else if (rating >= starValue - 0.5) {
          return Icon(Icons.star_half, size: size, color: Colors.amber);
        } else {
          return Icon(Icons.star_border, size: size, color: Colors.amber);
        }
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีรีวิว',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'รีวิวจากลูกค้าจะแสดงที่นี่',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    final customerName = _customerNames[review.customerId] ?? 'ลูกค้า';
    final dateStr = DateFormat('d MMM yyyy, HH:mm', 'th').format(review.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + date
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  child: Text(
                    customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Stars
            _buildStarRow(review.rating, 18),

            // Comment
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.comment!,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
