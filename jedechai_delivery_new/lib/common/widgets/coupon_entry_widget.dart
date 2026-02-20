import 'package:flutter/material.dart';
import '../models/coupon.dart';
import '../services/coupon_service.dart';
import '../../theme/app_theme.dart';

/// Coupon Entry Widget
///
/// Reusable widget for entering and validating a coupon code
/// Used in checkout screens (food, ride, parcel)
class CouponEntryWidget extends StatefulWidget {
  final String serviceType;
  final double orderAmount;
  final double deliveryFee;
  final String? merchantId;
  final ValueChanged<Coupon?> onCouponApplied;
  final ValueChanged<double> onDiscountChanged;

  const CouponEntryWidget({
    super.key,
    required this.serviceType,
    required this.orderAmount,
    this.deliveryFee = 0,
    this.merchantId,
    required this.onCouponApplied,
    required this.onDiscountChanged,
  });

  @override
  State<CouponEntryWidget> createState() => _CouponEntryWidgetState();
}

class _CouponEntryWidgetState extends State<CouponEntryWidget> {
  final CouponService _couponService = CouponService();
  final TextEditingController _codeController = TextEditingController();
  Coupon? _appliedCoupon;
  double _discount = 0;
  bool _isValidating = false;
  String? _errorMessage;

  Future<void> _validateCoupon() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final coupon = await _couponService.validateCoupon(
        code: code,
        serviceType: widget.serviceType,
        orderAmount: widget.orderAmount,
        merchantId: widget.merchantId,
      );

      final discount = coupon.calculateDiscount(
        widget.orderAmount,
        deliveryFee: widget.deliveryFee,
      );

      setState(() {
        _appliedCoupon = coupon;
        _discount = discount;
        _isValidating = false;
      });

      widget.onCouponApplied(coupon);
      widget.onDiscountChanged(discount);
    } on Exception catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isValidating = false;
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _discount = 0;
      _errorMessage = null;
      _codeController.clear();
    });
    widget.onCouponApplied(null);
    widget.onDiscountChanged(0);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Applied coupon display
        if (_appliedCoupon != null) _buildAppliedCoupon(),

        // Input row
        if (_appliedCoupon == null) _buildInputRow(),

        // Error message
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'กรอกโค้ดส่วนลด',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.local_offer_outlined, color: Colors.grey[500]),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
              ),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isValidating ? null : _validateCoupon,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: _isValidating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'ใช้โค้ด',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppliedCoupon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_offer,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _appliedCoupon!.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _appliedCoupon!.discountText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ประหยัด ฿${_discount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _removeCoupon,
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            tooltip: 'ลบโค้ด',
          ),
        ],
      ),
    );
  }
}
