import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../utils/debug_logger.dart';

/// Rating Screen — Wave 1.5 b2ride layout
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
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _merchantCommentController =
      TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;

  // Quick-pick tag chips (driver rating tags)
  final Set<int> _selectedDriverTags = {};

  bool get _isFood => widget.booking.serviceType == 'food';
  bool get _hasDriver =>
      widget.booking.driverId != null && widget.booking.driverId!.isNotEmpty;

  @override
  void dispose() {
    _commentController.dispose();
    _merchantCommentController.dispose();
    super.dispose();
  }

  List<String> _getDriverTags(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.ratingTagFast,
      l10n.ratingTagPolite,
      l10n.ratingTagNeatPacking,
      l10n.ratingTagEasyContact,
      l10n.ratingTagOnTime,
    ];
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
      if (userId == null) {
        throw Exception(AppLocalizations.of(context)!.ratingUserNotFound);
      }

      final client = Supabase.instance.client;
      final tags = _getDriverTags(context);
      final selectedTagText = _selectedDriverTags
          .map((i) => tags[i])
          .join(', ');
      final driverComment = [
        if (selectedTagText.isNotEmpty) selectedTagText,
        if (_commentController.text.trim().isNotEmpty)
          _commentController.text.trim(),
      ].join(' · ');

      // บันทึกรีวิวคนขับ
      if (_hasDriver) {
        await client.from('reviews').upsert({
          'booking_id': widget.booking.id,
          'customer_id': userId,
          'driver_id': widget.booking.driverId!,
          'rating': _driverRating.toDouble(),
          'comment': driverComment.isEmpty ? null : driverComment,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'booking_id,customer_id,driver_id');
      }

      // บันทึกรีวิวร้านค้า (เฉพาะ food)
      if (_isFood && widget.booking.merchantId != null) {
        final merchantComment = _merchantCommentController.text.trim();
        await client.from('reviews').upsert({
          'booking_id': widget.booking.id,
          'customer_id': userId,
          'merchant_id': widget.booking.merchantId!,
          'rating': _merchantRating.toDouble(),
          'comment': merchantComment.isEmpty ? null : merchantComment,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'booking_id,customer_id,merchant_id');
      }

      setState(() {
        _submitted = true;
        _isSubmitting = false;
      });

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
    final l10n = AppLocalizations.of(context)!;

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
              Text(l10n.ratingThankYou,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
              const SizedBox(height: JdcSpacing.sm),
              Text(l10n.ratingFeedbackHelps,
                  style: TextStyle(fontSize: 16, color: jdc.muted)),
            ],
          ),
        ),
      );
    }

    final driverInitials = _buildInitials(widget.booking.driverName);
    final orderId = OrderCodeFormatter.formatByServiceType(
        widget.booking.id,
        serviceType: widget.booking.serviceType);

    return Scaffold(
      backgroundColor: jdc.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: skip link
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.ratingSkip,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: jdc.muted),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Driver avatar + heading
                    _buildDriverHeader(
                        context, jdc, l10n, driverInitials, orderId),
                    const SizedBox(height: 18),

                    // Driver star rating
                    _buildStarSection(context, jdc, l10n),
                    const SizedBox(height: 14),

                    // Quick-pick tags
                    _buildTagSection(context, jdc, l10n),
                    const SizedBox(height: 14),

                    // Comment field
                    _buildCommentField(context, jdc, l10n),

                    // Merchant rating (food only)
                    if (_isFood) ...[
                      const SizedBox(height: 18),
                      _buildMerchantRatingSection(context, jdc, l10n),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Sticky bottom bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              decoration: BoxDecoration(
                color: jdc.surface,
                border: Border(top: BorderSide(color: jdc.line)),
              ),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: jdc.cta,
                    foregroundColor: jdc.onCta,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: jdc.onCta, strokeWidth: 2.5),
                        )
                      : Text(l10n.ratingSubmit,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0].isNotEmpty ? parts[0][0] : ''}${parts[1].isNotEmpty ? parts[1][0] : ''}';
    }
    return name.length >= 2 ? name.substring(0, 2) : name;
  }

  Widget _buildDriverHeader(BuildContext context, JdcColors jdc,
      AppLocalizations l10n, String initials, String orderId) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: jdc.panel,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: jdc.onPanel),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.ratingHeaderTitle,
          style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: jdc.text),
        ),
        const SizedBox(height: 5),
        Text(
          '${widget.booking.driverName ?? ''} · $orderId · ฿${widget.booking.totalAmount.ceil()}',
          style: TextStyle(fontSize: 13, color: jdc.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStarSection(
      BuildContext context, JdcColors jdc, AppLocalizations l10n) {
    final ratingLabels = [
      '',
      l10n.ratingLabel1,
      l10n.ratingLabel2,
      l10n.ratingLabel3,
      l10n.ratingLabel4,
      l10n.ratingLabel5,
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        children: [
          Text(l10n.ratingRateDriver,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: jdc.text)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final isOn = starIndex <= _driverRating;
              return GestureDetector(
                onTap: () => setState(() => _driverRating = starIndex),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isOn ? jdc.brandSoft : jdc.sunken,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.star_rounded,
                    size: 26,
                    color: isOn ? jdc.brand : jdc.offTrack,
                  ),
                ),
              );
            }),
          ),
          if (_driverRating > 0) ...[
            const SizedBox(height: JdcSpacing.sm),
            Text(
              ratingLabels[_driverRating],
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _driverRating >= 4
                      ? jdc.successInk
                      : (_driverRating >= 3 ? jdc.brand : jdc.danger)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagSection(
      BuildContext context, JdcColors jdc, AppLocalizations l10n) {
    final tags = _getDriverTags(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.ratingTagsTitle,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: jdc.text)),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(tags.length, (i) {
            final isSelected = _selectedDriverTags.contains(i);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedDriverTags.remove(i);
                } else {
                  _selectedDriverTags.add(i);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? jdc.brandSoft : jdc.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? jdc.brandLine : jdc.line,
                  ),
                ),
                child: Text(
                  tags[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? jdc.brandOnSoft : jdc.muted,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCommentField(
      BuildContext context, JdcColors jdc, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.ratingCommentTitle,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: jdc.text)),
        const SizedBox(height: 9),
        TextField(
          controller: _commentController,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: l10n.ratingCommentHint,
            hintStyle: TextStyle(color: jdc.dim, fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: jdc.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: jdc.brand, width: 1.5),
            ),
            filled: true,
            fillColor: jdc.surface,
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantRatingSection(
      BuildContext context, JdcColors jdc, AppLocalizations l10n) {
    final ratingLabels = [
      '',
      l10n.ratingLabel1,
      l10n.ratingLabel2,
      l10n.ratingLabel3,
      l10n.ratingLabel4,
      l10n.ratingLabel5,
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jdc.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: jdc.cta, size: 20),
              const SizedBox(width: 8),
              Text(l10n.ratingRateMerchant,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: jdc.text)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              return GestureDetector(
                onTap: () =>
                    setState(() => _merchantRating = starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starIndex <= _merchantRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 44,
                    color: starIndex <= _merchantRating
                        ? jdc.brandHi
                        : jdc.line,
                  ),
                ),
              );
            }),
          ),
          if (_merchantRating > 0) ...[
            const SizedBox(height: JdcSpacing.sm),
            Center(
              child: Text(ratingLabels[_merchantRating],
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _merchantRating >= 4
                          ? jdc.successInk
                          : (_merchantRating >= 3
                              ? jdc.brand
                              : jdc.danger))),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _merchantCommentController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n.ratingMerchantHint,
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
