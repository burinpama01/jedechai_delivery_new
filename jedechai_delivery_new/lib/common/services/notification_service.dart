import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart' as notification_model;

/// Notification Service
/// 
/// Handles notification-related operations
class NotificationService {
  static Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = notification_model.Notification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title,
        body: body,
        type: type,
        data: data,
        createdAt: DateTime.now(),
      );

      await Supabase.instance.client
          .from('notifications')
          .insert(notification.toJson());
    } catch (e) {
      debugLog('Error sending notification: $e');
    }
  }

  static Future<List<notification_model.Notification>> getUserNotifications(
    String userId, {
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await query;
      
      // Filter unread notifications in Dart for now
      List<dynamic> filteredResponse = response;
      if (unreadOnly) {
        filteredResponse = response.where((item) => item['is_read'] == false).toList();
      }

      return filteredResponse
          .map((item) => notification_model.Notification.fromJson(item))
          .toList();
    } catch (e) {
      debugLog('Error fetching notifications: $e');
      return [];
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugLog('Error marking notification as read: $e');
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugLog('Error marking all notifications as read: $e');
    }
  }

  static Future<int> getUnreadCount(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      debugLog('Error getting unread count: $e');
      return 0;
    }
  }

  static Future<void> deleteNotification(String notificationId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e) {
      debugLog('Error deleting notification: $e');
    }
  }

  static Future<void> clearAllNotifications(String userId) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      debugLog('Error clearing all notifications: $e');
    }
  }

  static void showLocalNotification({
    required BuildContext context,
    required String title,
    required String body,
    String? type,
    VoidCallback? onTap,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: _getNotificationColor(type),
        duration: const Duration(seconds: 3),
        action: onTap != null
            ? SnackBarAction(
                label: 'View',
                onPressed: onTap,
                textColor: Colors.white,
              )
            : null,
      ),
    );
  }

  static Color _getNotificationColor(String? type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
