import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Online/Offline toggle button for the driver AppBar.
class OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final Animation<double> pulseAnimation;
  final VoidCallback onToggle;

  const OnlineToggle({
    super.key,
    required this.isOnline,
    required this.pulseAnimation,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline
                ? Colors.green.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isOnline
                  ? Colors.greenAccent.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: pulseAnimation,
                builder: (_, __) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.greenAccent : Colors.white54,
                    shape: BoxShape.circle,
                    boxShadow: isOnline
                        ? [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: pulseAnimation.value * 0.8),
                              blurRadius: 4 + pulseAnimation.value * 6,
                              spreadRadius: pulseAnimation.value,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? l10n.driverDashOnline : l10n.driverDashOffline,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOnline ? Colors.greenAccent : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
