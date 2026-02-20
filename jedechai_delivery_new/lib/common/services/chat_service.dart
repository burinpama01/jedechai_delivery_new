import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/chat_message.dart';
import 'auth_service.dart';
import 'notification_sender.dart';

/// Chat Service
///
/// Handles in-app chat using Supabase Realtime
/// - Booking chat: customer ↔ driver (temporary per booking)
/// - Support chat: customer ↔ admin
///
/// Tables: chat_rooms, chat_messages
class ChatService {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _messageChannel;
  StreamController<List<ChatMessage>>? _messagesController;

  /// Get or create a chat room for a booking (customer ↔ driver)
  Future<ChatRoom?> getOrCreateBookingChatRoom({
    required String bookingId,
    required String customerId,
    String? driverId,
  }) async {
    try {
      // Try to find existing room
      final existing = await _client
          .from('chat_rooms')
          .select()
          .eq('booking_id', bookingId)
          .eq('room_type', 'booking')
          .maybeSingle();

      if (existing != null) {
        // If driver joined later, update
        if (driverId != null && existing['driver_id'] == null) {
          await _client
              .from('chat_rooms')
              .update({'driver_id': driverId})
              .eq('id', existing['id']);
          existing['driver_id'] = driverId;
        }
        return ChatRoom.fromJson(existing);
      }

      // Create new room
      final response = await _client
          .from('chat_rooms')
          .insert({
            'booking_id': bookingId,
            'customer_id': customerId,
            'driver_id': driverId,
            'room_type': 'booking',
            'is_active': true,
          })
          .select()
          .single();

      debugLog('✅ Created booking chat room for booking: $bookingId');
      return ChatRoom.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating booking chat room: $e');
      return null;
    }
  }

  /// Get or create a support chat room (customer ↔ admin)
  Future<ChatRoom?> getOrCreateSupportChatRoom({
    required String bookingId,
    required String customerId,
  }) async {
    try {
      // Try to find existing support room for this booking
      final existing = await _client
          .from('chat_rooms')
          .select()
          .eq('booking_id', bookingId)
          .eq('room_type', 'support')
          .maybeSingle();

      if (existing != null) {
        return ChatRoom.fromJson(existing);
      }

      // Create new support room
      final response = await _client
          .from('chat_rooms')
          .insert({
            'booking_id': bookingId,
            'customer_id': customerId,
            'room_type': 'support',
            'is_active': true,
          })
          .select()
          .single();

      debugLog('✅ Created support chat room for booking: $bookingId');
      return ChatRoom.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating support chat room: $e');
      return null;
    }
  }

  /// Get all messages in a chat room (initial load)
  Future<List<ChatMessage>> getMessages(String chatRoomId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .order('created_at', ascending: true)
          .limit(200);

      return (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching messages: $e');
      return [];
    }
  }

  /// Send a message
  Future<ChatMessage?> sendMessage({
    required String chatRoomId,
    required String message,
    String? imageUrl,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      // Determine sender role
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final senderRole = profile?['role'] as String? ?? 'customer';

      final response = await _client
          .from('chat_messages')
          .insert({
            'chat_room_id': chatRoomId,
            'sender_id': userId,
            'sender_role': senderRole,
            'message': message,
            'image_url': imageUrl,
          })
          .select()
          .single();

      final chatMessage = ChatMessage.fromJson(response);

      // Send push notification to other party
      await _notifyOtherParty(chatRoomId, userId, message);

      return chatMessage;
    } catch (e) {
      debugLog('❌ Error sending message: $e');
      return null;
    }
  }

  /// Subscribe to new messages in a chat room (Realtime)
  Stream<List<ChatMessage>> subscribeToMessages(String chatRoomId) {
    _messageChannel?.unsubscribe();
    _messagesController?.close();

    _messagesController = StreamController<List<ChatMessage>>.broadcast();
    List<ChatMessage> currentMessages = [];

    // Load initial messages
    getMessages(chatRoomId).then((messages) {
      currentMessages = messages;
      _messagesController?.add(currentMessages);
    });

    // Subscribe to new messages via Realtime
    _messageChannel = _client
        .channel('chat_$chatRoomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: chatRoomId,
          ),
          callback: (payload) {
            try {
              final newMessage = ChatMessage.fromJson(payload.newRecord);
              // Avoid duplicates
              if (!currentMessages.any((m) => m.id == newMessage.id)) {
                currentMessages.add(newMessage);
                _messagesController?.add(List.from(currentMessages));
              }
            } catch (e) {
              debugLog('❌ Error parsing realtime message: $e');
            }
          },
        )
        .subscribe((status, [error]) {
          debugLog('💬 Chat channel status: $status');
          if (error != null) {
            debugLog('❌ Chat channel error: $error');
          }
        });

    return _messagesController!.stream;
  }

  /// Mark all messages as read for current user
  Future<void> markAsRead(String chatRoomId) async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      await _client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('chat_room_id', chatRoomId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugLog('❌ Error marking messages as read: $e');
    }
  }

  /// Get unread message count for a chat room
  Future<int> getUnreadCount(String chatRoomId) async {
    final userId = AuthService.userId;
    if (userId == null) return 0;

    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('chat_room_id', chatRoomId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugLog('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Close chat room (when booking is completed/cancelled)
  Future<void> closeChatRoom(String chatRoomId) async {
    try {
      await _client.from('chat_rooms').update({
        'is_active': false,
        'closed_at': DateTime.now().toIso8601String(),
      }).eq('id', chatRoomId);

      debugLog('✅ Closed chat room: $chatRoomId');
    } catch (e) {
      debugLog('❌ Error closing chat room: $e');
    }
  }

  /// Get active chat rooms for admin (support rooms)
  Future<List<ChatRoom>> getActiveSupportRooms() async {
    try {
      final response = await _client
          .from('chat_rooms')
          .select()
          .eq('room_type', 'support')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ChatRoom.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching support rooms: $e');
      return [];
    }
  }

  /// Notify the other party via FCM with sender name
  Future<void> _notifyOtherParty(
    String chatRoomId,
    String senderId,
    String message,
  ) async {
    try {
      // Get chat room + sender profile in parallel
      final futures = await Future.wait([
        _client.from('chat_rooms').select().eq('id', chatRoomId).single(),
        _client.from('profiles').select('full_name, role').eq('id', senderId).maybeSingle(),
      ]);

      final room = futures[0] as Map<String, dynamic>;
      final senderProfile = futures[1];
      final senderName = senderProfile?['full_name'] as String? ?? 'ผู้ใช้';
      final senderRole = senderProfile?['role'] as String? ?? '';

      String? targetUserId;
      if (room['customer_id'] == senderId) {
        targetUserId = room['driver_id'] as String?;
      } else {
        targetUserId = room['customer_id'] as String?;
      }

      if (targetUserId == null) return;

      // Set title based on sender role
      final String title;
      if (senderRole == 'driver') {
        title = '💬 ข้อความจากคนขับ ($senderName)';
      } else if (senderRole == 'customer') {
        title = '💬 ข้อความจากลูกค้า ($senderName)';
      } else {
        title = '💬 ข้อความจาก $senderName';
      }

      final truncatedMsg = message.length > 100 ? '${message.substring(0, 100)}...' : message;

      await NotificationSender.sendNotification(
        targetUserId: targetUserId,
        title: title,
        body: truncatedMsg,
        data: {
          'type': 'chat_message',
          'chat_room_id': chatRoomId,
          'booking_id': room['booking_id'] ?? '',
        },
      );
      debugLog('📤 Chat notification sent to $targetUserId from $senderName');
    } catch (e) {
      debugLog('❌ Error notifying other party: $e');
    }
  }

  /// Dispose subscriptions
  void dispose() {
    _messageChannel?.unsubscribe();
    _messagesController?.close();
    _messageChannel = null;
    _messagesController = null;
  }
}
