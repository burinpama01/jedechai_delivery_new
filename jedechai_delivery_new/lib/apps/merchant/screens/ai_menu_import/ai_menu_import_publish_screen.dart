import 'package:flutter/material.dart';

import '../../../../common/services/ai_menu_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'ai_import_widgets.dart';

/// ดูตัวอย่างแบบที่ลูกค้าเห็น → เลือกซ่อน/เปิดขาย (D8) → ติ๊กยืนยัน → Publish
///
/// pop(true) = publish แล้ว, pop(false) = ต้องกลับไปตรวจ (เจอเมนูซ้ำ)
class AiMenuImportPublishScreen extends StatefulWidget {
  const AiMenuImportPublishScreen({
    super.key,
    required this.job,
    required this.items,
    required this.selections,
    this.service,
  });

  final AiImportJob job;
  final List<AiImportItem> items;
  final List<AiTemplateSuggestion> selections;
  final AiMenuImportService? service;

  @override
  State<AiMenuImportPublishScreen> createState() =>
      _AiMenuImportPublishScreenState();
}

class _AiMenuImportPublishScreenState extends State<AiMenuImportPublishScreen> {
  late final AiMenuImportService _service =
      widget.service ?? AiMenuImportService();

  /// D8: ค่าเริ่มต้น "ซ่อนไว้ก่อน"
  bool _live = false;
  bool _confirmed = false;
  bool _publishing = false;

  Map<String, List<AiImportItem>> get _byCategory {
    final out = <String, List<AiImportItem>>{};
    for (final item in widget.items) {
      out.putIfAbsent(item.category ?? '-', () => []).add(item);
    }
    return out;
  }

  /// กลุ่มตัวเลือกของเมนู: variant + add-on จากรูป + แม่แบบที่ร้านเลือก
  List<String> _groupsFor(AppLocalizations l10n, AiImportItem item) {
    final groups = <String>[];
    if (item.variants.length >= 2) {
      final base = item.price ?? 0;
      groups.add('${item.variantGroup ?? l10n.aiImpDefaultVariantGroup}: ${item.variants.map((v) {
        final diff = ((v.price ?? base) - base).round();
        return diff > 0 ? '${v.label} +$diff' : v.label;
      }).join(' / ')}');
    }
    final addonGroups = <String, List<AiAddon>>{};
    for (final a in item.addons) {
      addonGroups.putIfAbsent(a.group ?? l10n.aiImpDefaultAddonGroup, () => []).add(a);
    }
    addonGroups.forEach((g, list) {
      groups.add('$g: ${list.map((a) => '${a.label} +${(a.priceDelta ?? 0).round()}').join(' / ')}');
    });
    for (final s in widget.selections) {
      if (!s.itemIds.contains(item.id)) continue;
      groups.add('${s.name}: ${s.options.map((o) => o.price > 0 ? '${o.label} +${o.price}' : o.label).join(' / ')}');
    }
    return groups;
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _publishing = true);
    try {
      final result = await _service.publish(widget.job.id,
          live: _live, confirmed: _confirmed);
      if (!mounted) return;
      if (result['ok'] == false && result['reason'] == 'duplicates_found') {
        final names = ((result['names'] as List?) ?? const []).join(', ');
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.aiImpDupFoundTitle),
            content: Text(l10n.aiImpDupFoundBody(names)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.aiImpBackToReview)),
            ],
          ),
        );
        navigator.pop(false);
        return;
      }
      final created = (result['created_items'] as num?)?.toInt() ?? 0;
      messenger.showSnackBar(SnackBar(
        content: Text(_live
            ? l10n.aiImpPublishedLive(created)
            : l10n.aiImpPublishedHidden(created)),
        backgroundColor: jdc.successFill,
      ));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      messenger.showSnackBar(SnackBar(
        content: Text(aiImportErrorText(l10n, AiMenuImportService.errorCode(e))),
        backgroundColor: jdc.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isAppend = widget.job.mode == 'append';
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          AiImportHeader(
            title: l10n.aiImpPreviewTitle,
            subtitle: l10n.aiImpPreviewSubtitle(widget.items.length),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(JdcSpacing.lg),
              children: [
                for (final entry in _byCategory.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                        top: JdcSpacing.sm, bottom: JdcSpacing.sm),
                    child: Text(entry.key, style: aiTxt(jdc.text, 15, w: 700)),
                  ),
                  for (final item in entry.value) ...[
                    AiCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(item.name,
                                    style: aiTxt(jdc.text, 14, w: 600))),
                            Text(aiBaht(item.price),
                                style: aiTxt(jdc.text, 14, w: 700)),
                          ]),
                          if (item.description != null) ...[
                            const SizedBox(height: 2),
                            Text(item.description!, style: aiTxt(jdc.muted, 12)),
                          ],
                          for (final g in _groupsFor(l10n, item))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('• $g', style: aiTxt(jdc.muted, 12)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.sm),
                  ],
                ],
                const SizedBox(height: JdcSpacing.md),
                Text(l10n.aiImpVisibilityTitle, style: aiTxt(jdc.text, 15, w: 700)),
                RadioGroup<bool>(
                  groupValue: _live,
                  onChanged: (v) => setState(() => _live = v ?? false),
                  child: Column(children: [
                    RadioListTile<bool>(
                      value: false,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.aiImpVisibilityHidden),
                      subtitle: Text(l10n.aiImpVisibilityHiddenHint),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.aiImpVisibilityLive),
                      subtitle: Text(isAppend
                          ? l10n.aiImpVisibilityLiveHintAppend
                          : l10n.aiImpVisibilityLiveHintOnboarding),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          AiImportBottomBar(
            top: CheckboxListTile(
              value: _confirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.aiImpConfirmChecked, style: aiTxt(jdc.text, 13)),
              onChanged: _publishing
                  ? null
                  : (v) => setState(() => _confirmed = v ?? false),
            ),
            primaryLabel: l10n.aiImpPublishButton(widget.items.length),
            onPrimary: _confirmed ? _publish : null,
            busy: _publishing,
          ),
        ],
      ),
    );
  }
}
