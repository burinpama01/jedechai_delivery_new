import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/debug_logger.dart';

/// Version Check Service
///
/// Checks the current app version against the minimum required version
/// stored in the system_config table. If the app is outdated, shows
/// a force-update dialog that blocks usage.
///
/// system_config row expected:
///   key: 'app_min_version'  value: '1.2.0'
///   key: 'app_update_url'   value: 'https://play.google.com/...'
///   key: 'app_update_message' value: 'กรุณาอัปเดตแอป...'
class VersionCheckService {
  static final SupabaseClient _client = Supabase.instance.client;
  static bool _isDialogVisible = false;

  /// Check version on app startup. Call this from AuthGate or main().
  /// Returns true if the app is up-to-date, false if force update is needed.
  static Future<bool> checkVersion(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      final configs = await _loadConfigMap();
      final latestVersion = configs['app_latest_version'];
      final minVersion = configs['app_min_version'];
      final targetVersion =
          (latestVersion != null && latestVersion.trim().isNotEmpty)
              ? latestVersion.trim()
              : minVersion?.trim();

      if (targetVersion == null || targetVersion.isEmpty) {
        debugLog('ℹ️ No app_latest_version/app_min_version in system_config — skipping check');
        return true;
      }

      debugLog('📱 Version check: current=$currentVersion, target=$targetVersion');

      if (_isVersionLower(currentVersion, targetVersion)) {
        final updateUrl = _resolveUpdateUrl(configs);
        final updateMessage = configs['app_update_message'] ??
            'มีเวอร์ชันใหม่แล้ว กรุณาอัปเดตเป็นเวอร์ชันล่าสุดจาก Store';

        if (context.mounted) {
          _showForceUpdateDialog(
            context,
            updateMessage,
            updateUrl,
            targetVersion,
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugLog('⚠️ Version check failed (non-blocking): $e');
      return true; // Don't block on network errors
    }
  }

  static Future<Map<String, String>> _loadConfigMap() async {
    final rows = await _client
        .from('system_config')
        .select('key, value')
        .inFilter('key', [
          'app_latest_version',
          'app_min_version',
          'app_update_url',
          'app_update_url_android',
          'app_update_url_ios',
          'app_update_message',
        ]);

    final map = <String, String>{};
    for (final row in rows) {
      final key = (row['key'] as String?)?.trim();
      final value = (row['value'] as String?)?.trim();
      if (key != null && key.isNotEmpty && value != null && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map;
  }

  static String? _resolveUpdateUrl(Map<String, String> configs) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return configs['app_update_url_android'] ?? configs['app_update_url'];
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return configs['app_update_url_ios'] ?? configs['app_update_url'];
    }
    return configs['app_update_url'];
  }

  /// Compare two semver strings. Returns true if [current] < [minimum].
  static bool _isVersionLower(String current, String minimum) {
    final currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final minParts = minimum.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    // Pad to 3 parts
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (minParts.length < 3) {
      minParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }
    return false; // Equal = OK
  }

  /// Show a non-dismissable force update dialog
  static void _showForceUpdateDialog(
    BuildContext context,
    String message,
    String? updateUrl,
    String targetVersion,
  ) {
    if (_isDialogVisible) return;
    _isDialogVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.system_update, color: Colors.orange, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'อัปเดตแอป ($targetVersion)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Icon(Icons.download_rounded, size: 48, color: Colors.grey[300]),
            ],
          ),
          actions: [
            if (updateUrl != null && updateUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(updateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text(
                    'อัปเดตเลย',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).then((_) {
      _isDialogVisible = false;
    });
  }
}
