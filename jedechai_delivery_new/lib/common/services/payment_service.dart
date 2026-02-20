import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

/// Payment Service
/// 
/// Handles payment-related operations
class PaymentService {
  static Future<Payment?> createPayment({
    required String bookingId,
    required double amount,
    required String method,
    String? transactionId,
  }) async {
    try {
      final paymentData = {
        'booking_id': bookingId,
        'amount': amount,
        'method': method,
        'status': 'pending',
        'transaction_id': transactionId,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await Supabase.instance.client
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      return Payment.fromJson(response);
    } catch (e) {
      debugLog('Error creating payment: $e');
      return null;
    }
  }

  static Future<Payment?> updatePaymentStatus(
    String paymentId,
    String status, {
    String? transactionId,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (transactionId != null) {
        updateData['transaction_id'] = transactionId;
      }

      final response = await Supabase.instance.client
          .from('payments')
          .update(updateData)
          .eq('id', paymentId)
          .select()
          .single();

      return Payment.fromJson(response);
    } catch (e) {
      debugLog('Error updating payment status: $e');
      return null;
    }
  }

  static Future<Payment?> getPaymentByBookingId(String bookingId) async {
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select('*')
          .eq('booking_id', bookingId)
          .single();

      return Payment.fromJson(response);
    } catch (e) {
      debugLog('Error getting payment by booking ID: $e');
      return null;
    }
  }

  static Future<List<Payment>> getUserPayments(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('payments')
          .select('''
            *,
            bookings!inner(
              customer_id
            )
          ''')
          .eq('bookings.customer_id', userId)
          .order('created_at', ascending: false);

      return response.map((item) => Payment.fromJson(item)).toList();
    } catch (e) {
      debugLog('Error getting user payments: $e');
      return [];
    }
  }

  static Future<bool> processPayment({
    required String paymentId,
    required String method,
    required double amount,
  }) async {
    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Generate mock transaction ID
      final transactionId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';

      // Update payment status
      final payment = await updatePaymentStatus(
        paymentId,
        'completed',
        transactionId: transactionId,
      );

      return payment != null;
    } catch (e) {
      debugLog('Error processing payment: $e');
      return false;
    }
  }

  static Future<bool> refundPayment(String paymentId) async {
    try {
      // Simulate refund processing
      await Future.delayed(const Duration(seconds: 1));

      // Update payment status
      final payment = await updatePaymentStatus(paymentId, 'refunded');

      return payment != null;
    } catch (e) {
      debugLog('Error refunding payment: $e');
      return false;
    }
  }

  static Future<double> getTotalRevenue({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('payments')
          .select('amount')
          .eq('status', 'completed');

      if (userId != null) {
        // Simplified query for now - would need proper join in real implementation
        query = Supabase.instance.client
            .from('payments')
            .select('amount, customer_id')
            .eq('status', 'completed');
        // Note: This would need proper join implementation in real usage
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;

      double total = 0.0;
      for (final item in response) {
        total += (item['amount'] as num).toDouble();
      }

      return total;
    } catch (e) {
      debugLog('Error getting total revenue: $e');
      return 0.0;
    }
  }

  static String formatAmount(double amount) {
    return '฿${amount.ceil()}';
  }

  static String getPaymentMethodDisplayName(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'เงินสด';
      case 'credit_card':
        return 'บัตรเครดิต';
      case 'debit_card':
        return 'บัตรเดบิต';
      case 'mobile_banking':
        return 'ธนาคารมือถือ';
      case 'ewallet':
        return 'อีวอลเล็ต';
      default:
        return method;
    }
  }

  static String getPaymentStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'processing':
        return 'กำลังดำเนินการ';
      case 'completed':
        return 'สำเร็จ';
      case 'failed':
        return 'ล้มเหลว';
      case 'cancelled':
        return 'ยกเลิก';
      case 'refunded':
        return 'คืนเงิน';
      default:
        return status;
    }
  }
}
