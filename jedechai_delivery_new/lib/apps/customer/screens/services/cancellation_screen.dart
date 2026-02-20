import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import '../../../../common/services/booking_service.dart';
import '../../../../common/utils/order_code_formatter.dart';
import '../../../../utils/debug_logger.dart';

/// Cancellation Screen
/// 
/// Shows cancellation confirmation and reason selection
class CancellationScreen extends StatefulWidget {
  final Booking booking;

  const CancellationScreen({super.key, required this.booking});

  @override
  State<CancellationScreen> createState() => _CancellationScreenState();
}

class _CancellationScreenState extends State<CancellationScreen> {
  int? _selectedReasonIndex;
  final TextEditingController _otherReasonController = TextEditingController();
  bool _isCancelling = false;

  final List<Map<String, dynamic>> _reasons = [
    {'icon': Icons.access_time, 'text': 'รอนานเกินไป'},
    {'icon': Icons.money_off, 'text': 'เปลี่ยนใจ ไม่ต้องการแล้ว'},
    {'icon': Icons.wrong_location, 'text': 'ใส่ที่อยู่ผิด'},
    {'icon': Icons.price_change, 'text': 'ราคาสูงเกินไป'},
    {'icon': Icons.error_outline, 'text': 'สั่งผิดรายการ'},
    {'icon': Icons.edit_note, 'text': 'เหตุผลอื่น'},
  ];

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  String get _selectedReasonText {
    if (_selectedReasonIndex == null) return '';
    if (_selectedReasonIndex == _reasons.length - 1) {
      return _otherReasonController.text.trim().isEmpty
          ? 'เหตุผลอื่น'
          : _otherReasonController.text.trim();
    }
    return _reasons[_selectedReasonIndex!]['text'] as String;
  }

  Future<void> _confirmCancellation() async {
    if (_selectedReasonIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกเหตุผลการยกเลิก'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('ยืนยันการยกเลิก'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('คุณแน่ใจว่าต้องการยกเลิกออเดอร์นี้?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'เหตุผล: $_selectedReasonText',
                      style: TextStyle(fontSize: 13, color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ไม่ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final bookingService = BookingService();
      await bookingService.updateBookingStatus(
        widget.booking.id,
        'cancelled',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยกเลิกออเดอร์สำเร็จ'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugLog('Error cancelling booking: $e');
      setState(() => _isCancelling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceLabel = {
      'food': 'ออเดอร์อาหาร',
      'ride': 'เรียกรถ',
      'parcel': 'ส่งพัสดุ',
    }[widget.booking.serviceType] ?? 'ออเดอร์';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ยกเลิกออเดอร์'),
        backgroundColor: Colors.red.shade600,
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
                  // ข้อมูลออเดอร์
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.cancel_outlined, color: Colors.red.shade600, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(serviceLabel,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                  OrderCodeFormatter.formatByServiceType(
                                    widget.booking.id,
                                    serviceType: widget.booking.serviceType,
                                  ),
                                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('฿${widget.booking.totalAmount.ceil()}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text('เหตุผลในการยกเลิก',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('กรุณาเลือกเหตุผลเพื่อช่วยเราปรับปรุงบริการ',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 16),

                  // รายการเหตุผล
                  ...List.generate(_reasons.length, (i) {
                    final reason = _reasons[i];
                    final isSelected = _selectedReasonIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedReasonIndex = i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.red.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.red : Colors.grey.shade200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(reason['icon'] as IconData,
                                  color: isSelected ? Colors.red : Colors.grey, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(reason['text'] as String,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      color: isSelected ? Colors.red.shade700 : Colors.black87,
                                    )),
                              ),
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? Colors.red : Colors.grey.shade400,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // ช่องพิมพ์เหตุผลอื่น
                  if (_selectedReasonIndex == _reasons.length - 1) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _otherReasonController,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: InputDecoration(
                        hintText: 'โปรดระบุเหตุผล...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 1.5),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ปุ่มยกเลิก
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCancelling ? null : _confirmCancellation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('ยกเลิกออเดอร์', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
