import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/payment_service.dart';
import '../../../../utils/debug_logger.dart';

/// Payment Screen
/// 
/// Shows payment method selection and processing
class PaymentScreen extends StatefulWidget {
  final Booking booking;

  const PaymentScreen({super.key, required this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'cash';
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 'cash',
      'label': 'เงินสด',
      'subtitle': 'ชำระเงินสดกับคนขับ',
      'icon': Icons.money,
      'color': AppTheme.primaryGreen,
    },
    {
      'id': 'promptpay',
      'label': 'PromptPay',
      'subtitle': 'โอนผ่าน QR Code',
      'icon': Icons.qr_code,
      'color': const Color(0xFF1A3C6E),
    },
    {
      'id': 'mobile_banking',
      'label': 'Mobile Banking',
      'subtitle': 'โอนผ่านแอปธนาคาร',
      'icon': Icons.account_balance,
      'color': AppTheme.accentBlue,
    },
  ];

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      final payment = await PaymentService.createPayment(
        bookingId: widget.booking.id,
        amount: widget.booking.totalAmount,
        method: _selectedMethod,
      );

      if (payment != null && _selectedMethod != 'cash') {
        await PaymentService.processPayment(
          paymentId: payment.id,
          method: _selectedMethod,
          amount: widget.booking.totalAmount,
        );
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      debugLog('Error processing payment: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 60, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 20),
            const Text('ชำระเงินสำเร็จ!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('฿${widget.booking.totalAmount.ceil()}',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
            const SizedBox(height: 8),
            Text(
              _selectedMethod == 'cash' ? 'กรุณาเตรียมเงินสดให้คนขับ' : 'รายการชำระเงินบันทึกแล้ว',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('ตกลง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('การชำระเงิน'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // สรุปยอดเงิน
                  _buildAmountSummary(),
                  const SizedBox(height: 24),

                  // เลือกวิธีชำระเงิน
                  Text(
                    'เลือกวิธีชำระเงิน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),

                  ...List.generate(_paymentMethods.length, (i) {
                    final method = _paymentMethods[i];
                    final isSelected = _selectedMethod == method['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMethod = method['id'] as String),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.1), blurRadius: 8)]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (method['color'] as Color).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(method['icon'] as IconData,
                                    color: method['color'] as Color, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(method['label'] as String,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        )),
                                    const SizedBox(height: 2),
                                    Text(method['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurfaceVariant,
                                        )),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_off,
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : colorScheme.outlineVariant,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // หมายเหตุ PromptPay
                  if (_selectedMethod == 'promptpay') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C6E).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1A3C6E).withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF1A3C6E), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ระบบจะสร้าง QR Code สำหรับโอนเงินผ่าน PromptPay ให้อัตโนมัติ',
                              style: TextStyle(fontSize: 13, color: Color(0xFF1A3C6E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ปุ่มชำระเงิน
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'ชำระเงิน ฿${widget.booking.totalAmount.ceil()}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSummary() {
    final isFood = widget.booking.serviceType == 'food';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('ยอดรวมทั้งหมด',
              style: TextStyle(fontSize: 15, color: Colors.white70)),
          const SizedBox(height: 6),
          Text('฿${widget.booking.totalAmount.ceil()}',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
          if (isFood && widget.booking.deliveryFee != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniAmount('ค่าอาหาร', '฿${widget.booking.price.ceil()}'),
                  Container(width: 1, height: 24, color: Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 14)),
                  _buildMiniAmount('ค่าส่ง', '฿${widget.booking.deliveryFee!.ceil()}'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniAmount(String label, String amount) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(amount, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}
