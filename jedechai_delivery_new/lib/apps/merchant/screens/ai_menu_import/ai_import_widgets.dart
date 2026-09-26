import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';

/// ชิ้นส่วน UI ร่วมของหน้า AI Menu Import (ตามโทนหน้าร้านค้า Wave 1.5:
/// หัวพื้น surface + ปุ่มย้อนกลับ 44px, การ์ดขอบเส้น, ปุ่มหลักสี panel)

TextStyle aiTxt(Color color, double size, {double w = 400, double? height}) {
  return TextStyle(
    color: color,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
    fontVariations: [FontVariation('wght', w)],
  );
}

String aiBaht(num? value) => value == null ? '฿–' : '฿${value.round()}';

class AiImportHeader extends StatelessWidget {
  const AiImportHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(bottom: BorderSide(color: jdc.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.lg, JdcSpacing.lg, JdcSpacing.lg, JdcSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: JdcTouch.minTarget,
                height: JdcTouch.minTarget,
                child: Material(
                  color: jdc.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                    side: BorderSide(color: jdc.line),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    child: Icon(Icons.chevron_left, size: 20, color: jdc.text),
                  ),
                ),
              ),
              const SizedBox(width: JdcSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: aiTxt(jdc.text, 17, w: 700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: aiTxt(jdc.muted, 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// แถบปุ่มล่าง: ปุ่มหลัก (panel) + ปุ่มรองแบบ outline (ถ้ามี)
class AiImportBottomBar extends StatelessWidget {
  const AiImportBottomBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
    this.top,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final enabled = onPrimary != null && !busy;
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(top: BorderSide(color: jdc.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (top != null) ...[top!, const SizedBox(height: JdcSpacing.md)],
              Row(
                children: [
                  if (secondaryLabel != null) ...[
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: busy ? null : onSecondary,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: jdc.line),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(JdcRadius.card)),
                          ),
                          child: Text(secondaryLabel!,
                              textAlign: TextAlign.center,
                              style: aiTxt(jdc.text, 14, w: 700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: JdcSpacing.md),
                  ],
                  Expanded(
                    flex: secondaryLabel != null ? 2 : 1,
                    child: SizedBox(
                      height: 54,
                      child: Material(
                        color: enabled ? jdc.panel : jdc.sunken,
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(JdcRadius.card),
                          onTap: enabled ? onPrimary : null,
                          child: Center(
                            child: busy
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: jdc.onPanel),
                                  )
                                : Text(primaryLabel,
                                    textAlign: TextAlign.center,
                                    style: aiTxt(
                                        enabled ? jdc.onPanel : jdc.muted, 15,
                                        w: 700)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AiBadgeTone { success, warning, danger, info, neutral }

class AiBadge extends StatelessWidget {
  const AiBadge(this.label, {super.key, this.tone = AiBadgeTone.neutral});

  final String label;
  final AiBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final (Color bg, Color fg, Color line) = switch (tone) {
      AiBadgeTone.success => (jdc.successSoft, jdc.successInk, jdc.successLine),
      AiBadgeTone.warning => (jdc.brandSoft, jdc.brandOnSoft, jdc.brandLine),
      AiBadgeTone.danger => (jdc.dangerSoft, jdc.dangerInk, jdc.dangerLine),
      AiBadgeTone.info => (jdc.infoSoft, jdc.infoInk, jdc.line),
      AiBadgeTone.neutral => (jdc.sunken, jdc.muted, jdc.line),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(JdcRadius.chip),
        border: Border.all(color: line),
      ),
      child: Text(label, style: aiTxt(fg, 11, w: 700)),
    );
  }
}

class AiCard extends StatelessWidget {
  const AiCard({super.key, required this.child, this.onTap, this.dim = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Material(
        color: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.card),
          side: BorderSide(color: jdc.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(JdcRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(JdcSpacing.lg),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ข้อความ error ที่อ่านรู้เรื่องจากรหัส ai_import_*
String aiImportErrorText(AppLocalizations l10n, String code) {
  if (code.startsWith('ai_import_not_allowed')) {
    if (code.endsWith('quota_exceeded')) return l10n.aiImpErrQuota;
    return l10n.aiImpErrNotAllowed;
  }
  return switch (code) {
    'ai_import_job_in_progress' => l10n.aiImpErrInProgress,
    'ai_not_configured' => l10n.aiImpErrNotConfigured,
    'ai_import_items_pending_review' => l10n.aiImpErrPending,
    'ai_import_nothing_to_publish' => l10n.aiImpErrNothing,
    'ai_import_duplicate_in_import' => l10n.aiImpErrDupInImport,
    'ai_import_duplicate_item' => l10n.aiImpErrDupItem,
    'ai_import_price_conflict_unresolved' => l10n.aiImpErrConflict,
    'ai_import_invalid_price' || 'ai_import_price_required' =>
      l10n.aiImpErrPrice,
    'ai_import_invalid_name' => l10n.aiImpErrName,
    'ai_import_max_attempts' => l10n.aiImpErrMaxAttempts,
    'ai_import_confirm_required' => l10n.aiImpErrConfirm,
    'ai_import_job_not_editable' || 'ai_import_job_not_publishable' =>
      l10n.aiImpErrNotEditable,
    _ => l10n.aiImpErrGeneric,
  };
}
