import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/booking.dart';
import 'tracking_screen.dart';

/// Booking Confirmation Screen
/// 
/// Shows booking confirmation details after successful order placement
class BookingConfirmationScreen extends StatelessWidget {
  final Booking booking;

  const BookingConfirmationScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final serviceLabel = {
      'food': 'สั่งอาหาร',
      'ride': 'เรียกรถ',
      'parcel': 'ส่งพัสดุ',
    }[booking.serviceType] ?? booking.serviceType;

    final serviceIcon = {
      'food': Icons.restaurant,
      'ride': Icons.local_taxi,
      'parcel': Icons.inventory_2,
    }[booking.serviceType] ?? Icons.receipt;

    final dateFormat = DateFormat('d MMM yyyy HH:mm', 'th');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // ไอคอนสำเร็จ
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, size: 80, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 20),
                    const Text('จองสำเร็จ!',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('ออเดอร์ #${booking.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontSize: 15, color: Colors.grey)),

                    const SizedBox(height: 28),

                    // รายละเอียดออเดอร์
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(serviceIcon, color: AppTheme.primaryGreen, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(serviceLabel,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // จุดรับ
                          _buildInfoRow(Icons.circle, AppTheme.primaryGreen, 'จุดรับ',
                              booking.pickupAddress ?? 'ไม่ระบุ'),
                          const SizedBox(height: 14),

                          // จุดส่ง
                          _buildInfoRow(Icons.location_on, Colors.red, 'จุดส่ง',
                              booking.destinationAddress ?? 'ไม่ระบุ'),
                          const SizedBox(height: 14),

                          // ระยะทาง
                          _buildInfoRow(Icons.straighten, Colors.blue, 'ระยะทาง',
                              '${booking.distanceKm.toStringAsFixed(1)} กม.'),
                          const SizedBox(height: 14),

                          // วันที่สร้าง
                          _buildInfoRow(Icons.access_time, Colors.orange, 'เวลาสั่ง',
                              dateFormat.format(booking.createdAt)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // สรุปราคา
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withValues(alpha: 0.85)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          if (booking.serviceType == 'food' && booking.deliveryFee != null) ...[
                            _buildPriceRow('ค่าอาหาร', '฿${booking.price.ceil()}'),
                            const SizedBox(height: 8),
                            _buildPriceRow('ค่าจัดส่ง', '฿${booking.deliveryFee!.ceil()}'),
                            Divider(color: Colors.white.withValues(alpha: 0.3), height: 20),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ยอดรวม',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                              Text('฿${booking.totalAmount.ceil()}',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.payment, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                booking.paymentMethod == 'cash' ? 'ชำระเงินสด' : (booking.paymentMethod ?? 'เงินสด'),
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ปุ่มด้านล่าง
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => TrackingScreen(booking: booking)),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('ติดตามออเดอร์', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: const Text('กลับหน้าหลัก', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
        Text(amount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      ],
    );
  }
}
