/// Support Ticket Model
///
/// Represents a customer support ticket for issues like:
/// lost items, wrong food, rude driver, refund requests, etc.
class SupportTicket {
  final String id;
  final String userId;
  final String? bookingId;
  final String category; // 'lost_item', 'wrong_order', 'rude_driver', 'refund', 'app_bug', 'other'
  final String subject;
  final String description;
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final String? assignedAdminId;
  final String? resolution;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  const SupportTicket({
    required this.id,
    required this.userId,
    this.bookingId,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    this.priority = 'medium',
    this.assignedAdminId,
    this.resolution,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookingId: json['booking_id'] as String?,
      category: json['category'] as String? ?? 'other',
      subject: json['subject'] as String,
      description: json['description'] as String,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      assignedAdminId: json['assigned_admin_id'] as String?,
      resolution: json['resolution'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'booking_id': bookingId,
      'category': category,
      'subject': subject,
      'description': description,
      'status': status,
      'priority': priority,
      'assigned_admin_id': assignedAdminId,
      'resolution': resolution,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  bool get isOpen => status == 'open';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved' || status == 'closed';

  String get categoryText {
    switch (category) {
      case 'lost_item':
        return 'ของหาย';
      case 'wrong_order':
        return 'อาหาร/สินค้าผิด';
      case 'rude_driver':
        return 'คนขับไม่สุภาพ';
      case 'refund':
        return 'ขอคืนเงิน';
      case 'app_bug':
        return 'ปัญหาแอป';
      default:
        return 'อื่นๆ';
    }
  }

  String get statusText {
    switch (status) {
      case 'open':
        return 'เปิด';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'resolved':
        return 'แก้ไขแล้ว';
      case 'closed':
        return 'ปิดแล้ว';
      default:
        return status;
    }
  }

  String get priorityText {
    switch (priority) {
      case 'urgent':
        return 'เร่งด่วน';
      case 'high':
        return 'สูง';
      case 'medium':
        return 'ปานกลาง';
      case 'low':
        return 'ต่ำ';
      default:
        return priority;
    }
  }

  @override
  String toString() => 'SupportTicket(id: $id, subject: $subject, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupportTicket && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
