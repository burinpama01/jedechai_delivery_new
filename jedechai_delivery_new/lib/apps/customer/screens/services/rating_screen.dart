import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../utils/debug_logger.dart';

/// Rating Screen
/// 
/// Shows rating and review interface after order completion
class RatingScreen extends StatefulWidget {
  final Booking booking;

  const RatingScreen({super.key, required this.booking});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _driverRating = 0;
  int _merchantRating = 0;
  final TextEditingController _driverCommentController = TextEditingController();
  final TextEditingController _merchantCommentController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  bool get _isFood => widget.booking.serviceType == 'food';
  bool get _hasDriver => widget.booking.driverId != null && widget.booking.driverId!.isNotEmpty;

  @override
  void dispose() {
    _driverCommentController.dispose();
    _merchantCommentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_hasDriver && _driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาให้คะแนนคนขับ'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_isFood && _merchantRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาให้คะแนนร้านค้า'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      final client = Supabase.instance.client;

      Future<void> upsertReview({
        required Map<String, Object> match,
        required Map<String, dynamic> data,
      }) async {
        final existing = await client
            .from('reviews')
            .select('id')
            .match(match)
            .maybeSingle();

        if (existing != null && existing['id'] != null) {
          await client
              .from('reviews')
              .update(data)
              .eq('id', existing['id']);
        } else {
          await client.from('reviews').insert({...match, ...data});
        }
      }

      // บันทึกรีวิวคนขับ
      if (_hasDriver) {
        await upsertReview(
          match: {
            'booking_id': widget.booking.id,
            'customer_id': userId,
            'driver_id': widget.booking.driverId!,
          },
          data: {
            'rating': _driverRating.toDouble(),
            'comment': _driverCommentController.text.trim().isEmpty
                ? null
                : _driverCommentController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      // บันทึกรีวิวร้านค้า (เฉพาะ food)
      if (_isFood && widget.booking.merchantId != null) {
        await upsertReview(
          match: {
            'booking_id': widget.booking.id,
            'customer_id': userId,
            'merchant_id': widget.booking.merchantId!,
          },
          data: {
            'rating': _merchantRating.toDouble(),
            'comment': _merchantCommentController.text.trim().isEmpty
                ? null
                : _merchantCommentController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });

      // แสดงข้อความสำเร็จ แล้วปิดหน้า
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugLog('❌ Error submitting rating: $e');
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, size: 80, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 24),
              const Text('ขอบคุณสำหรับการให้คะแนน!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('ความคิดเห็นของคุณช่วยพัฒนาบริการ',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ให้คะแนน'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ข้อมูลออเดอร์
            _buildOrderSummaryCard(),
            const SizedBox(height: 24),

            // ให้คะแนนคนขับ
            _buildRatingSection(
              title: 'ให้คะแนนคนขับ',
              icon: Icons.delivery_dining,
              rating: _driverRating,
              onRatingChanged: (r) => setState(() => _driverRating = r),
              controller: _driverCommentController,
              hintText: 'แสดงความคิดเห็นเกี่ยวกับคนขับ (ไม่บังคับ)',
            ),

            // ให้คะแนนร้านค้า (เฉพาะ food)
            if (_isFood) ...[
              const SizedBox(height: 24),
              _buildRatingSection(
                title: 'ให้คะแนนร้านค้า',
                icon: Icons.store,
                rating: _merchantRating,
                onRatingChanged: (r) => setState(() => _merchantRating = r),
                controller: _merchantCommentController,
                hintText: 'แสดงความคิดเห็นเกี่ยวกับร้านค้า (ไม่บังคับ)',
              ),
            ],

            const SizedBox(height: 32),

            // ปุ่มส่ง
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('ส่งคะแนน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 12),

            // ปุ่มข้าม
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                child: const Text('ข้ามไปก่อน', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    final serviceLabel = {
      'food': 'สั่งอาหาร',
      'ride': 'เรียกรถ',
      'parcel': 'ส่งพัสดุ',
    }[widget.booking.serviceType] ?? widget.booking.serviceType;

    final serviceIcon = {
      'food': Icons.restaurant,
      'ride': Icons.local_taxi,
      'parcel': Icons.inventory_2,
    }[widget.booking.serviceType] ?? Icons.receipt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(serviceIcon, color: AppTheme.primaryGreen, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('#${widget.booking.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          Text('฿${widget.booking.totalAmount.ceil()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
        ],
      ),
    );
  }

  Widget _buildRatingSection({
    required String title,
    required IconData icon,
    required int rating,
    required ValueChanged<int> onRatingChanged,
    required TextEditingController controller,
    required String hintText,
  }) {
    final ratingLabels = ['', 'แย่มาก', 'ไม่ดี', 'ปานกลาง', 'ดี', 'ยอดเยี่ยม'];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryGreen, size: 22),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          // ดาว
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 44,
                    color: starIndex <= rating ? const Color(0xFFFFB800) : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(ratingLabels[rating],
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: rating >= 4 ? AppTheme.primaryGreen : (rating >= 3 ? Colors.orange : Colors.red))),
            ),
          ],
          const SizedBox(height: 16),
          // ช่องความคิดเห็น
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
