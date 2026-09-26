import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/fcm_notification_service.dart';
import '../services/notification_consent_store.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool? _enabled;
  bool? _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = AuthService.userId;
    final enabled =
        userId != null && await NotificationConsentStore(userId).isAllowed();
    if (!mounted) return;
    setState(() => _enabled = enabled);
    if (enabled) {
      final active = await FCMNotificationService().saveToken();
      if (mounted) setState(() => _active = active);
    } else {
      setState(() => _active = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    final userId = AuthService.userId;
    if (userId == null || _saving) return;
    setState(() => _saving = true);
    try {
      final store = NotificationConsentStore(userId);
      if (value) {
        await store.saveDecision(true);
        final active = await FCMNotificationService().saveToken();
        if (mounted) {
          setState(() {
            _enabled = true;
            _active = active;
          });
          if (!active) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.notificationSettingsSystemHint),
            ));
          }
        }
      } else {
        await FCMNotificationService().disableForCurrentUser();
        if (mounted) {
          setState(() {
            _enabled = false;
            _active = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context)!.notificationSettingsError),
        ));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: _enabled == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile.adaptive(
                  title: Text(l10n.notificationConsentAllow),
                  subtitle: Text(l10n.notificationSettingsDescription),
                  value: _enabled!,
                  onChanged: _saving ? null : _setEnabled,
                ),
                if (_enabled == true && _active == false)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(l10n.notificationSettingsNotReady),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.notificationSettingsSystemHint),
                ),
              ],
            ),
    );
  }
}
