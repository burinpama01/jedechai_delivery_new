import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../../l10n/app_localizations.dart';

/// หน้ากำลังดำเนินการลบบัญชี
/// แสดงเมื่อผู้ใช้ส่งคำขอลบบัญชีแล้วและรออนุมัติจากแอดมิน
/// รับ realtime update บน profiles.deletion_status และแสดง UI ตามสถานะจริง
class PendingDeletionScreen extends StatefulWidget {
  const PendingDeletionScreen({super.key});

  @override
  State<PendingDeletionScreen> createState() => _PendingDeletionScreenState();
}

class _PendingDeletionScreenState extends State<PendingDeletionScreen> {
  StreamSubscription? _profileSubscription;
  // null = rejected/cleared, 'pending' = waiting; starts null until first fetch
  String? _deletionStatus;
  bool _initialFetchDone = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialStatus();
    _subscribeToProfileChanges();
  }

  Future<void> _fetchInitialStatus() async {
    final userId = AuthService.userId;
    if (userId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('deletion_status')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _deletionStatus = row?['deletion_status'] as String?;
        _initialFetchDone = true;
      });
    } catch (_) {
      if (mounted) setState(() => _initialFetchDone = true);
    }
  }

  void _subscribeToProfileChanges() {
    final userId = AuthService.userId;
    if (userId == null) return;

    _profileSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (!mounted) return;
          if (data.isEmpty) return;
          final status = data.first['deletion_status'] as String?;
          setState(() {
            _deletionStatus = status;
          });
        });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_initialFetchDone) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_deletionStatus == null) {
      return _buildRejectedScreen(colorScheme);
    }
    return _buildPendingScreen(colorScheme);
  }

  Widget _buildPendingScreen(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 64,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.pendingDeletionTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.pendingDeletionBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.tertiary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.tertiary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.pendingDeletionWaiting,
                          style: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(
                      l10n.pendingDeletionLogout,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: colorScheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  l10n.rejectedDeletionTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.rejectedDeletionBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                    },
                    icon: const Icon(Icons.login),
                    label: Text(
                      l10n.rejectedDeletionBack,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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
