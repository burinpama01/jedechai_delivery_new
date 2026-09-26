import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../apps/customer/screens/auth/register_screen.dart';
import '../services/app_navigation_service.dart';
import '../services/referral_invite_link.dart';
import '../../utils/debug_logger.dart';

/// Routes a verified invite link to the shared registration form.
class ReferralLinkGate extends StatefulWidget {
  const ReferralLinkGate({super.key, required this.child});

  final Widget child;

  @override
  State<ReferralLinkGate> createState() => _ReferralLinkGateState();
}

class _ReferralLinkGateState extends State<ReferralLinkGate> {
  StreamSubscription<Uri>? _subscription;
  String? _lastCode;
  DateTime? _lastOpenedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final links = AppLinks();
        _subscription = links.uriLinkStream.listen(
          _openInvite,
          onError: (Object error) =>
              debugLog('Invite link stream failed: $error'),
        );
        unawaited(_readInitialLink(links));
      } catch (error) {
        debugLog('Invite link setup failed: $error');
      }
    });
  }

  Future<void> _readInitialLink(AppLinks links) async {
    try {
      final uri = await links.getInitialLink();
      if (uri != null) _openInvite(uri);
    } catch (error) {
      debugLog('Initial invite link failed: $error');
    }
  }

  void _openInvite(Uri uri) {
    final code = ReferralInviteLink.codeFromUri(uri);
    if (code == null || !mounted) return;
    final now = DateTime.now();
    if (_lastCode == code &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastCode = code;
    _lastOpenedAt = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppNavigationService.navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/register-invite'),
          builder: (_) => RegisterScreen(initialReferralCode: code),
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
