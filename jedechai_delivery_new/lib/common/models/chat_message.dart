/// Chat Message Model
///
/// Represents a single message in a chat room (per booking)
class ChatMessage {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderRole; // 'customer', 'driver', 'admin'
  final String message;
  final String? imageUrl;
  final bool isRead;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    this.imageUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      chatRoomId: json['chat_room_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String? ?? 'customer',
      message: json['message'] as String,
      imageUrl: json['image_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': message,
      'image_url': imageUrl,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// For inserting new message (without id and timestamps — DB auto-generates)
  Map<String, dynamic> toInsertJson() {
    return {
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': message,
      'image_url': imageUrl,
    };
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  @override
  String toString() => 'ChatMessage(id: $id, sender: $senderId, message: $message)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Chat Room Model
///
/// Represents a temporary chat room linked to a booking
class ChatRoom {
  final String id;
  final String bookingId;
  final String customerId;
  final String? driverId;
  final String roomType; // 'booking' (customer↔driver), 'support' (customer↔admin)
  final bool isActive;
  final DateTime createdAt;
  final DateTime? closedAt;
  final ChatMessage? lastMessage;

  const ChatRoom({
    required this.id,
    required this.bookingId,
    required this.customerId,
    this.driverId,
    required this.roomType,
    this.isActive = true,
    required this.createdAt,
    this.closedAt,
    this.lastMessage,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      customerId: json['customer_id'] as String,
      driverId: json['driver_id'] as String?,
      roomType: json['room_type'] as String? ?? 'booking',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'customer_id': customerId,
      'driver_id': driverId,
      'room_type': roomType,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'ChatRoom(id: $id, bookingId: $bookingId, type: $roomType)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRoom && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
