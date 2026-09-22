import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/payment_service.dart';
import '../../../../utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  List<Map<String, dynamic>> _getPaymentMethods(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'id': 'cash',
        'label': l10n.payCash,
        'subtitle': l10n.payCashSubtitle,
        'icon': Icons.money,
        'colorKey': 'cta',
      },
      {
        'id': 'promptpay',
        'label': 'PromptPay',
        'subtitle': l10n.payPromptPaySubtitle,
        'icon': Icons.qr_code,
        'colorKey': 'info',
      },
      {
        'id': 'mobile_banking',
        'label': 'Mobile Banking',
        'subtitle': l10n.payMobileBankingSubtitle,
        'icon': Icons.account_balance,
        'colorKey': 'info',
      },
      {
        'id': 'wallet',
        'label': 'Wallet',
        'subtitle': 'ชำระจากยอดเงินใน Wallet',
        'icon': Icons.account_balance_wallet,
        'colorKey': 'brand',
      },
    ];
  }

  Color _methodColor(String colorKey, JdcColors jdc) {
    switch (colorKey) {
      case 'cta':
        return jdc.cta;
      case 'info':
        return jdc.infoInk;
      case 'brand':
        return jdc.brand;
      default:
        return jdc.brand;
    }
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      if (_selectedMethod == 'wallet') {
        final userId = Supabase.instance.client.auth.currentUser?.id ??
            widget.booking.customerId;
        if (userId.isEmpty) {
          throw Exception('ไม่พบข้อมูลผู้ใช้สำหรับชำระผ่าน Wallet');
        }
        await PaymentService.payBookingWithWallet(
          userId: userId,
          bookingId: widget.booking.id,
          amount: widget.booking.totalAmount,
          description: 'ชำระค่า${widget.booking.serviceType}ด้วย Wallet',
        );

        if (mounted) {
          _showSuccessDialog();
        }
        return;
      }

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
        final jdc = JdcColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.payError(e.toString())),
            backgroundColor: jdc.danger,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final jdc2 = JdcColors.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(JdcRadius.sheet)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: JdcSpacing.sm),
              Container(
                padding: const EdgeInsets.all(JdcSpacing.xl),
                decoration: BoxDecoration(
                  color: jdc2.successSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, size: 60, color: jdc2.successInk),
              ),
              const SizedBox(height: JdcSpacing.xl),
              Text(AppLocalizations.of(context)!.paySuccess,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: jdc2.text)),
              const SizedBox(height: JdcSpacing.sm),
              Text('฿${widget.booking.totalAmount.ceil()}',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: jdc2.cta)),
              const SizedBox(height: JdcSpacing.sm),
              Text(
                _selectedMethod == 'cash'
                    ? AppLocalizations.of(context)!.payCashPrepare
                    : AppLocalizations.of(context)!.payRecorded,
                style: TextStyle(fontSize: 14, color: jdc2.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: JdcSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: jdc2.cta,
                    foregroundColor: jdc2.onCta,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(JdcRadius.small)),
                    padding: const EdgeInsets.symmetric(
                        vertical: JdcSpacing.md),
                  ),
                  child: Text(AppLocalizations.of(context)!.payOk,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final methods = _getPaymentMethods(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.payTitle),
        backgroundColor: jdc.panel,
        foregroundColor: jdc.onPanel,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(JdcSpacing.xl),
              child: JdcContentFrame(
                padded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // สรุปยอดเงิน
                    _buildAmountSummary(),
                    const SizedBox(height: JdcSpacing.xxl),

                    // เลือกวิธีชำระเงิน
                    Text(
                      AppLocalizations.of(context)!.paySelectMethod,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: jdc.text,
                      ),
                    ),
                    const SizedBox(height: 14),

                    ...List.generate(methods.length, (i) {
                      final method = methods[i];
                      final isSelected =
                          _selectedMethod == method['id'];
                      final color =
                          _methodColor(method['colorKey'] as String, jdc);
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: JdcSpacing.md),
                        child: InkWell(
                          onTap: () => setState(
                              () => _selectedMethod = method['id'] as String),
                          borderRadius:
                              BorderRadius.circular(JdcRadius.field),
                          child: Container(
                            padding: const EdgeInsets.all(JdcSpacing.lg),
                            decoration: BoxDecoration(
                              color: jdc.surface,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.field),
                              border: Border.all(
                                color: isSelected ? jdc.cta : jdc.line,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: jdc.cta
                                              .withValues(alpha: 0.08),
                                          blurRadius: 8)
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(JdcSpacing.md),
                                  decoration: BoxDecoration(
                                    color:
                                        color.withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(JdcRadius.small),
                                  ),
                                  child: Icon(method['icon'] as IconData,
                                      color: color, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(method['label'] as String,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: jdc.text,
                                          )),
                                      const SizedBox(height: 2),
                                      Text(method['subtitle'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: jdc.muted,
                                          )),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.radio_button_off,
                                  color: isSelected ? jdc.cta : jdc.dim,
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
                      const SizedBox(height: JdcSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(JdcSpacing.md),
                        decoration: BoxDecoration(
                          color: jdc.infoSoft,
                          borderRadius:
                              BorderRadius.circular(JdcRadius.small),
                          border: Border.all(
                              color: jdc.infoInk.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: jdc.infoInk, size: 20),
                            const SizedBox(width: JdcSpacing.md),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!
                                    .payPromptPayNote,
                                style: TextStyle(
                                    fontSize: 13, color: jdc.infoInk),
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
          ),

          // ปุ่มชำระเงิน
          Container(
            padding: const EdgeInsets.all(JdcSpacing.xl),
            decoration: BoxDecoration(
              color: jdc.surface,
              boxShadow: jdc.shadowSheet,
            ),
            child: SafeArea(
              child: JdcContentFrame(
                padded: false,
                child: SizedBox(
                  width: double.infinity,
                  height: JdcTouch.button,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: jdc.cta,
                      foregroundColor: jdc.onCta,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(JdcRadius.field)),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: jdc.onCta, strokeWidth: 2.5),
                          )
                        : Text(
                            AppLocalizations.of(context)!.payButton(
                                widget.booking.totalAmount.ceil().toString()),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
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
    final jdc = JdcColors.of(context);
    final isFood = widget.booking.serviceType == 'food';
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.xl),
      decoration: BoxDecoration(
        gradient: jdc.hero2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
      ),
      child: Column(
        children: [
          Text(AppLocalizations.of(context)!.payTotalAmount,
              style: TextStyle(fontSize: 15, color: jdc.panelDim)),
          const SizedBox(height: JdcSpacing.sm),
          Text('฿${widget.booking.totalAmount.ceil()}',
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: jdc.onPanel)),
          if (isFood && widget.booking.deliveryFee != null) ...[
            const SizedBox(height: JdcSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: JdcSpacing.sm),
              decoration: BoxDecoration(
                color: jdc.panelSoft3,
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMiniAmount(
                      AppLocalizations.of(context)!.payFoodCost,
                      '฿${widget.booking.price.ceil()}'),
                  Container(
                      width: 1,
                      height: 24,
                      color: jdc.panelLine,
                      margin: const EdgeInsets.symmetric(
                          horizontal: JdcSpacing.md)),
                  _buildMiniAmount(
                      AppLocalizations.of(context)!.payDeliveryFee,
                      '฿${widget.booking.deliveryFee!.ceil()}'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniAmount(String label, String amount) {
    final jdc = JdcColors.of(context);
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: jdc.panelDim)),
        const SizedBox(height: 2),
        Text(amount,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: jdc.onPanel)),
      ],
    );
  }
}
