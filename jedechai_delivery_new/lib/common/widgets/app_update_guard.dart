import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jedechai_delivery_new/common/models/app_update_policy.dart';
import 'package:jedechai_delivery_new/common/services/app_update_policy_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateGuard extends StatefulWidget {
  const AppUpdateGuard({
    super.key,
    required this.child,
    this.service,
  });

  final Widget child;
  final AppUpdatePolicyService? service;

  @override
  State<AppUpdateGuard> createState() => _AppUpdateGuardState();
}

class _AppUpdateGuardState extends State<AppUpdateGuard>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSubscription;
  bool _checking = false;
  bool _dialogVisible = false;

  AppUpdatePolicyService get _service =>
      widget.service ?? AppUpdatePolicyService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _checkPolicy(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPolicy());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPolicy();
    }
  }

  Future<void> _checkPolicy() async {
    if (_checking || _dialogVisible || !mounted) return;
    _checking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber);
      final policy = await _service.fetchPolicy();
      final currentRole = policy.targetRoles.isEmpty
          ? null
          : await _service.fetchCurrentUserRole();
      final decision = policy.evaluate(
        currentVersion: packageInfo.version,
        currentBuild: currentBuild,
        role: currentRole,
        platform: defaultTargetPlatform,
      );

      if (!mounted || decision == AppUpdateDecision.none) return;
      if (decision == AppUpdateDecision.optional &&
          await _isOptionalDismissed(policy)) {
        return;
      }

      _dialogVisible = true;
      await _showUpdateDialog(policy, decision);
    } finally {
      _checking = false;
      _dialogVisible = false;
    }
  }

  Future<bool> _isOptionalDismissed(AppUpdatePolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dismissKey(policy)) ?? false;
  }

  Future<void> _dismissOptional(AppUpdatePolicy policy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissKey(policy), true);
  }

  String _dismissKey(AppUpdatePolicy policy) {
    final target = policy.latestBuild?.toString() ??
        policy.latestVersion ??
        policy.targetLabel;
    return 'app_update_dismissed_$target';
  }

  Future<void> _showUpdateDialog(
    AppUpdatePolicy policy,
    AppUpdateDecision decision,
  ) {
    final isForce = decision == AppUpdateDecision.force;

    return showDialog<void>(
      context: context,
      barrierDismissible: !isForce,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isForce,
          child: AlertDialog(
            icon: Icon(
              isForce ? Icons.system_update_alt : Icons.new_releases_outlined,
              color: isForce ? Colors.red.shade600 : Colors.blue.shade700,
              size: 34,
            ),
            title: Text(isForce ? 'ต้องอัปเดตแอป' : policy.displayTitle),
            content: Text(
              isForce
                  ? '${policy.displayMessage}\n\nเวอร์ชันเป้าหมาย: ${policy.targetLabel}'
                  : policy.displayMessage,
              textAlign: TextAlign.center,
            ),
            actions: [
              if (!isForce)
                TextButton(
                  onPressed: () async {
                    await _dismissOptional(policy);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('ไว้ภายหลัง'),
                ),
              FilledButton.icon(
                onPressed: () => _openStore(policy),
                icon: const Icon(Icons.open_in_new),
                label: const Text('อัปเดตตอนนี้'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openStore(AppUpdatePolicy policy) async {
    final url = policy.storeUrlForPlatform(defaultTargetPlatform);
    if (url == null) {
      _showLaunchFailure('ยังไม่ได้ตั้งค่าลิงก์ Store');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showLaunchFailure('ลิงก์ Store ไม่ถูกต้อง: $url');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _showLaunchFailure('เปิด Store ไม่ได้: $url');
    }
  }

  void _showLaunchFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
