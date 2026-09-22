import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
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
  final TextEditingController _driverCommentController =
      TextEditingController();
  final TextEditingController _merchantCommentController =
      TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  bool get _isFood => widget.booking.serviceType == 'food';
  bool get _hasDriver =>
      widget.booking.driverId != null && widget.booking.driverId!.isNotEmpty;

  @override
  void dispose() {
    _driverCommentController.dispose();
    _merchantCommentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    final jdc = JdcColors.of(context);
    if (_hasDriver && _driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.ratingPleaseRateDriver),
            backgroundColor: jdc.danger),
      );
      return;
    }
    if (_isFood && _merchantRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.ratingPleaseRateMerchant),
            backgroundColor: jdc.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = AuthService.userId;
      if (userId == null)
        throw Exception(AppLocalizations.of(context)!.ratingUserNotFound);

      final client = Supabase.instance.client;

      // บันทึกรีวิวคนขับ
      if (_hasDriver) {
        await client.from('reviews').upsert({
          'booking_id': widget.booking.id,
          'customer_id': userId,
          'driver_id': widget.booking.driverId!,
          'rating': _driverRating.toDouble(),
          'comment': _driverCommentController.text.trim().isEmpty
              ? null
              : _driverCommentController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'booking_id,customer_id,driver_id');
      }

      // บันทึกรีวิวร้านค้า (เฉพาะ food)
      if (_isFood && widget.booking.merchantId != null) {
        await client.from('reviews').upsert({
          'booking_id': widget.booking.id,
          'customer_id': userId,
          'merchant_id': widget.booking.merchantId!,
          'rating': _merchantRating.toDouble(),
          'comment': _merchantCommentController.text.trim().isEmpty
              ? null
              : _merchantCommentController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'booking_id,customer_id,merchant_id');
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
        final jdc2 = JdcColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.ratingError(e.toString())),
              backgroundColor: jdc2.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    if (_submitted) {
      return Scaffold(
        backgroundColor: jdc.paper,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(JdcSpacing.xxl),
                decoration: BoxDecoration(
                  color: jdc.successSoft,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.check_circle, size: 80, color: jdc.successInk),
              ),
              const SizedBox(height: JdcSpacing.xxl),
              Text(AppLocalizations.of(context)!.ratingThankYou,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
              const SizedBox(height: JdcSpacing.sm),
              Text(AppLocalizations.of(context)!.ratingFeedbackHelps,
                  style: TextStyle(fontSize: 16, color: jdc.muted)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.ratingTitle),
        backgroundColor: jdc.panel,
        foregroundColor: jdc.onPanel,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(JdcSpacing.xl),
        child: JdcContentFrame(
          padded: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ข้อมูลออเดอร์
              _buildOrderSummaryCard(),
              const SizedBox(height: JdcSpacing.xxl),

              // ให้คะแนนคนขับ
              _buildRatingSection(
                title: AppLocalizations.of(context)!.ratingRateDriver,
                icon: Icons.delivery_dining,
                rating: _driverRating,
                onRatingChanged: (r) => setState(() => _driverRating = r),
                controller: _driverCommentController,
                hintText: AppLocalizations.of(context)!.ratingDriverHint,
              ),

              // ให้คะแนนร้านค้า (เฉพาะ food)
              if (_isFood) ...[
                const SizedBox(height: JdcSpacing.xxl),
                _buildRatingSection(
                  title: AppLocalizations.of(context)!.ratingRateMerchant,
                  icon: Icons.store,
                  rating: _merchantRating,
                  onRatingChanged: (r) => setState(() => _merchantRating = r),
                  controller: _merchantCommentController,
                  hintText: AppLocalizations.of(context)!.ratingMerchantHint,
                ),
              ],

              const SizedBox(height: JdcSpacing.xxxl),

              // ปุ่มส่ง
              SizedBox(
                width: double.infinity,
                height: JdcTouch.button,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: jdc.cta,
                    foregroundColor: jdc.onCta,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(JdcRadius.field)),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: jdc.onCta, strokeWidth: 2.5),
                        )
                      : Text(AppLocalizations.of(context)!.ratingSubmit,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: JdcSpacing.md),

              // ปุ่มข้าม
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: Text(AppLocalizations.of(context)!.ratingSkip,
                      style: TextStyle(color: jdc.muted, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final serviceLabel = {
          'food': l10n.ratingServiceFood,
          'ride': l10n.ratingServiceRide,
          'parcel': l10n.ratingServiceParcel,
        }[widget.booking.serviceType] ??
        widget.booking.serviceType;

    final serviceIcon = {
          'food': Icons.restaurant,
          'ride': Icons.local_taxi,
          'parcel': Icons.inventory_2,
        }[widget.booking.serviceType] ??
        Icons.receipt;

    return Container(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        boxShadow: jdc.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(JdcSpacing.md),
            decoration: BoxDecoration(
              color: jdc.brandSoft,
              borderRadius: BorderRadius.circular(JdcRadius.small),
            ),
            child: Icon(serviceIcon, color: jdc.brandOnSoft, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(serviceLabel,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: jdc.text)),
                const SizedBox(height: JdcSpacing.xs),
                Text(
                    OrderCodeFormatter.formatByServiceType(
                      widget.booking.id,
                      serviceType: widget.booking.serviceType,
                    ),
                    style: TextStyle(fontSize: 13, color: jdc.muted)),
              ],
            ),
          ),
          Text('฿${widget.booking.totalAmount.ceil()}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: jdc.cta)),
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
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final ratingLabels = [
      '',
      l10n.ratingLabel1,
      l10n.ratingLabel2,
      l10n.ratingLabel3,
      l10n.ratingLabel4,
      l10n.ratingLabel5
    ];
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.xl),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: jdc.cta, size: 22),
              const SizedBox(width: JdcSpacing.sm),
              Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
            ],
          ),
          const SizedBox(height: JdcSpacing.lg),
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
                    starIndex <= rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: starIndex <= rating ? jdc.brandHi : jdc.line,
                  ),
                ),
              );
            }),
          ),
          if (rating > 0) ...[
            const SizedBox(height: JdcSpacing.sm),
            Center(
              child: Text(ratingLabels[rating],
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: rating >= 4
                          ? jdc.successInk
                          : (rating >= 3 ? jdc.brand : jdc.danger))),
            ),
          ],
          const SizedBox(height: JdcSpacing.lg),
          // ช่องความคิดเห็น
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: jdc.dim, fontSize: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.small)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
                borderSide: BorderSide(color: jdc.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
                borderSide: BorderSide(color: jdc.brand, width: 1.5),
              ),
              filled: true,
              fillColor: jdc.sunken,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}
