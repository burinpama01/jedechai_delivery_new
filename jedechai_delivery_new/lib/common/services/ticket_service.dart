import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/support_ticket.dart';
import 'auth_service.dart';
import 'notification_sender.dart';
import 'admin_line_notification_service.dart';

/// Ticket Service
///
/// CRUD operations for support tickets
/// Table: support_tickets
class TicketService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Create a new support ticket (customer/driver/merchant)
  Future<SupportTicket?> createTicket({
    required String category,
    required String subject,
    required String description,
    String? bookingId,
    String priority = 'medium',
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('support_tickets')
          .insert({
            'user_id': userId,
            'booking_id': bookingId,
            'category': category,
            'subject': subject,
            'description': description,
            'status': 'open',
            'priority': priority,
          })
          .select()
          .single();

      debugLog('✅ Created support ticket: ${response['id']}');

      // Notify admins
      await _notifyAdmins(
        subject: subject,
        ticketId: response['id'] as String,
        userId: userId,
        category: category,
        priority: priority,
        bookingId: bookingId,
      );

      return SupportTicket.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating ticket: $e');
      return null;
    }
  }

  /// Get tickets for current user
  Future<List<SupportTicket>> getMyTickets() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupportTicket.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching my tickets: $e');
      return [];
    }
  }

  // ── Admin Methods ──

  /// Get all tickets (admin) with reporter info joined from profiles.
  Future<List<SupportTicket>> getAllTickets({String? statusFilter}) async {
    try {
      var query = _client
          .from('support_tickets')
          .select('*, profiles!user_id(full_name, phone_number)');

      if (statusFilter != null && statusFilter != 'all') {
        query = query.eq('status', statusFilter);
      }

      final response = await query.order('created_at', ascending: false);

      return (response as List)
          .map((json) => SupportTicket.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching all tickets: $e');
      return [];
    }
  }

  static const _allowedTransitions = <String, List<String>>{
    'open': ['in_progress', 'closed'],
    'in_progress': ['resolved', 'open'],
    'resolved': ['closed'],
    'closed': [],
  };

  /// Update ticket status (admin) and notify the ticket owner.
  Future<bool> updateTicketStatus(String ticketId, String newStatus,
      {String? resolution}) async {
    try {
      final currentRow = await _client
          .from('support_tickets')
          .select('status, user_id, subject')
          .eq('id', ticketId)
          .maybeSingle();
      if (currentRow == null) return false;

      final currentStatus = currentRow['status'] as String;
      final allowed = _allowedTransitions[currentStatus] ?? [];
      if (!allowed.contains(newStatus)) {
        debugLog('⚠️ Invalid transition $currentStatus → $newStatus');
        return false;
      }

      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      if (resolution != null) {
        updateData['resolution'] = resolution;
      }

      if (newStatus == 'resolved' || newStatus == 'closed') {
        updateData['resolved_at'] = DateTime.now().toIso8601String();
      }

      if (newStatus == 'in_progress') {
        updateData['assigned_admin_id'] = AuthService.userId;
      }

      await _client
          .from('support_tickets')
          .update(updateData)
          .eq('id', ticketId);

      // Notify the ticket owner about status change
      {
        final userId = currentRow['user_id'] as String;
        final subject = currentRow['subject'] as String? ?? '';
        final statusMessages = {
          'in_progress': 'เจ้าหน้าที่กำลังดำเนินการแก้ไขปัญหาของคุณแล้ว',
          'resolved': 'ปัญหาของคุณได้รับการแก้ไขแล้ว',
          'closed': 'เรื่องร้องเรียนของคุณถูกปิดแล้ว',
        };
        final body = statusMessages[newStatus];
        if (body != null) {
          try {
            await NotificationSender.sendToUser(
              userId: userId,
              title: 'อัปเดตสถานะ: $subject',
              body: body,
              data: {'type': 'ticket_updated', 'ticket_id': ticketId, 'status': newStatus},
            );
          } catch (e) {
            debugLog('⚠️ Failed to notify ticket owner: $e');
          }
        }
      }

      debugLog('✅ Updated ticket $ticketId to $newStatus');
      return true;
    } catch (e) {
      debugLog('❌ Error updating ticket: $e');
      return false;
    }
  }

  /// Get ticket stats (admin dashboard) using server-side counts.
  Future<Map<String, int>> getTicketStats() async {
    try {
      final statuses = ['open', 'in_progress', 'resolved', 'closed'];
      final counts = await Future.wait(
        statuses.map((s) async {
          final res = await _client
              .from('support_tickets')
              .select('id')
              .eq('status', s)
              .count();
          return MapEntry(s, res.count);
        }),
      );
      final stats = Map.fromEntries(counts);
      stats['total'] = stats.values.fold(0, (a, b) => a + b);
      return stats;
    } catch (e) {
      debugLog('❌ Error fetching ticket stats: $e');
      return {'open': 0, 'in_progress': 0, 'resolved': 0, 'closed': 0, 'total': 0};
    }
  }

  /// Notify admins about new ticket
  Future<void> _notifyAdmins({
    required String subject,
    required String ticketId,
    required String userId,
    required String category,
    required String priority,
    String? bookingId,
  }) async {
    try {
      final admins =
          await _client.from('profiles').select('id').eq('role', 'admin');

      await Future.wait((admins as List).map((admin) =>
          NotificationSender.sendNotification(
            targetUserId: admin['id'] as String,
            title: '🎫 Ticket ใหม่',
            body: subject,
            data: {'type': 'new_ticket'},
          )));

      final priorityLabel = const {
        'low': '🟢 ต่ำ',
        'medium': '🟡 กลาง',
        'high': '🔴 สูง',
        'urgent': '🚨 เร่งด่วน',
      }[priority] ?? priority;
      await AdminLineNotificationService.notify(
        eventType: 'support_ticket_new',
        title: 'JDC: มี Ticket ใหม่',
        message: 'หัวข้อ: $subject\nหมวด: $category | ความสำคัญ: $priorityLabel',
        data: {
          'ticket_id': ticketId,
          'subject': subject,
          'category': category,
          'priority': priorityLabel,
          if (bookingId != null && bookingId.isNotEmpty) 'booking_id': bookingId,
        },
      );
    } catch (e) {
      debugLog('❌ Error notifying admins: $e');
    }
  }
}
