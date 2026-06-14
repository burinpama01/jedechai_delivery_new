import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification.dart' as notification_model;
import '../services/app_navigation_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/notification_center_utils.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String role;

  const NotificationCenterScreen({
    super.key,
    required this.role,
  });

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _dateFormatter = DateFormat('d MMM yyyy', 'th');
  final _timeFormatter = DateFormat('HH:mm', 'th');

  bool _isLoading = true;
  String _selectedFilter = 'all';
  List<notification_model.Notification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = AuthService.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final notifications =
        await NotificationService.getUserNotifications(userId, limit: 100);
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    final userId = AuthService.userId;
    if (userId == null) return;
    await NotificationService.markAllAsRead(userId);
    await _loadNotifications();
  }

  Future<void> _openNotification(
    notification_model.Notification notification,
  ) async {
    if (!notification.isRead) {
      await NotificationService.markAsRead(notification.id);
    }
    if (!mounted) return;

    final data = notification.data;
    if (data != null && data.isNotEmpty) {
      AppNavigationService.openFromNotification(data);
    }
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = NotificationCenterUtils.filterByType(
      _notifications,
      _selectedFilter,
    );
    final grouped = NotificationCenterUtils.groupByDate(filtered);
    final unreadCount =
        _notifications.where((notification) => !notification.isRead).length;
    final typeFilters = _typeFilters();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'แจ้งเตือน${NotificationCenterUtils.roleLabel(widget.role)}',
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('อ่านทั้งหมด'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: 'ทั้งหมด',
                            selected: _selectedFilter == 'all',
                            onSelected: () =>
                                setState(() => _selectedFilter = 'all'),
                          ),
                          _FilterChip(
                            label: 'ยังไม่อ่าน ($unreadCount)',
                            selected: _selectedFilter == 'unread',
                            onSelected: () =>
                                setState(() => _selectedFilter = 'unread'),
                          ),
                          for (final type in typeFilters)
                            _FilterChip(
                              label: _typeLabel(type),
                              selected: _selectedFilter == type,
                              onSelected: () =>
                                  setState(() => _selectedFilter = type),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(role: widget.role),
                    )
                  else
                    for (final entry in grouped.entries) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                          child: Text(
                            _dateFormatter.format(entry.key),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final notification = entry.value[index];
                          return _NotificationTile(
                            notification: notification,
                            timeText:
                                _timeFormatter.format(notification.createdAt),
                            typeLabel: _typeLabel(notification.type),
                            onTap: () => _openNotification(notification),
                          );
                        },
                      ),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
      ),
    );
  }

  List<String> _typeFilters() {
    final types = _notifications
        .map((notification) => notification.type)
        .whereType<String>()
        .where((type) => type.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return types.take(8).toList();
  }

  String _typeLabel(String? type) {
    return NotificationCenterUtils.typeLabel(type);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final notification_model.Notification notification;
  final String timeText;
  final String typeLabel;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.timeText,
    required this.typeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: notification.isRead
            ? colorScheme.surface
            : colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    notification.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            timeText,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String role;

  const _EmptyState({required this.role});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีแจ้งเตือน${NotificationCenterUtils.roleLabel(role)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
