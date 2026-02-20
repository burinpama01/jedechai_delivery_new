import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/support_ticket.dart';
import 'auth_service.dart';
import 'notification_sender.dart';

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
      await _notifyAdmins(subject);

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

  /// Get all tickets (admin)
  Future<List<SupportTicket>> getAllTickets({String? statusFilter}) async {
    try {
      var query = _client
          .from('support_tickets')
          .select();

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

  /// Update ticket status (admin)
  Future<bool> updateTicketStatus(String ticketId, String newStatus, {String? resolution}) async {
    try {
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

      debugLog('✅ Updated ticket $ticketId to $newStatus');
      return true;
    } catch (e) {
      debugLog('❌ Error updating ticket: $e');
      return false;
    }
  }

  /// Get ticket stats (admin dashboard)
  Future<Map<String, int>> getTicketStats() async {
    try {
      final response = await _client
          .from('support_tickets')
          .select('status');

      final stats = <String, int>{
        'open': 0,
        'in_progress': 0,
        'resolved': 0,
        'closed': 0,
        'total': 0,
      };

      for (final row in response) {
        final status = row['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
        stats['total'] = (stats['total'] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugLog('❌ Error fetching ticket stats: $e');
      return {'open': 0, 'in_progress': 0, 'resolved': 0, 'closed': 0, 'total': 0};
    }
  }

  /// Notify admins about new ticket
  Future<void> _notifyAdmins(String subject) async {
    try {
      final admins = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      for (final admin in admins) {
        await NotificationSender.sendNotification(
          targetUserId: admin['id'] as String,
          title: '🎫 Ticket ใหม่',
          body: subject,
          data: {'type': 'new_ticket'},
        );
      }
    } catch (e) {
      debugLog('❌ Error notifying admins: $e');
    }
  }
}
