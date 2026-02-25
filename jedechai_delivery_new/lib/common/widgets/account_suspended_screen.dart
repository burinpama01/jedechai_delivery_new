import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// หน้าจอบัญชีถูกระงับ
/// แสดงเมื่อแอดมินระงับการใช้งานบัญชี
class AccountSuspendedScreen extends StatelessWidget {
  final String role;
  final String? reason;

  const AccountSuspendedScreen({
    super.key,
    required this.role,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleText = switch (role) {
      'driver' => 'คนขับ',
      'merchant' => 'ร้านค้า',
      'admin' => 'ผู้ดูแลระบบ',
      _ => 'ผู้ใช้งาน',
    };

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.block_rounded,
                      size: 64,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'บัญชีถูกระงับ',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'บัญชี$roleTextของคุณถูกแอดมินระงับการใช้งาน\nกรุณาติดต่อผู้ดูแลระบบเพื่อดำเนินการต่อ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (reason != null && reason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: colorScheme.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'เหตุผล: ${reason!.trim()}',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onErrorContainer,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await AuthService.signOut();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('ออกจากระบบ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
