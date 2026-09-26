import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/services/ai_menu_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'ai_import_widgets.dart';
import 'ai_menu_import_publish_screen.dart';

const List<String> kAiStoreTypes = [
  'cafe',
  'made_to_order',
  'noodle',
  'isan',
  'dessert',
  'other',
];

String aiStoreTypeLabel(AppLocalizations l10n, String type) => switch (type) {
      'cafe' => l10n.aiImpStoreCafe,
      'made_to_order' => l10n.aiImpStoreMadeToOrder,
      'noodle' => l10n.aiImpStoreNoodle,
      'isan' => l10n.aiImpStoreIsan,
      'dessert' => l10n.aiImpStoreDessert,
      _ => l10n.aiImpStoreOther,
    };

/// ชุดตัวเลือกแนะนำ (ข้อ 11) — แม่แบบจากแอดมิน, จับคู่ด้วยกฎ, ร้านติ๊กใช้เอง (D11)
class AiMenuImportTemplatesScreen extends StatefulWidget {
  const AiMenuImportTemplatesScreen({
    super.key,
    required this.job,
    required this.items,
    this.service,
  });

  final AiImportJob job;

  /// รายการที่จะสร้าง (ยืนยันแล้ว)
  final List<AiImportItem> items;
  final AiMenuImportService? service;

  @override
  State<AiMenuImportTemplatesScreen> createState() =>
      _AiMenuImportTemplatesScreenState();
}

class _AiMenuImportTemplatesScreenState
    extends State<AiMenuImportTemplatesScreen> {
  late final AiMenuImportService _service =
      widget.service ?? AiMenuImportService();
  late String _storeType = kAiStoreTypes.contains(widget.job.storeType)
      ? widget.job.storeType!
      : (kAiStoreTypes.contains(widget.job.storeTypeGuess)
          ? widget.job.storeTypeGuess!
          : 'other');

  List<AiTemplateSuggestion> _suggestions = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _restoredSaved = false;

  /// เพิ่มเมื่อยกเลิกการเปลี่ยนประเภท → สร้าง dropdown ใหม่ให้กลับไปค่าเดิม
  int _dropdownEpoch = 0;

  Map<String, AiImportItem> get _itemsById =>
      {for (final i in widget.items) i.id: i};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.suggestTemplates(widget.job.id, _storeType);
      final ids = _itemsById.keys.toSet();
      for (final s in list) {
        s.itemIds = s.itemIds.intersection(ids);
      }
      // กลับมาหน้านี้อีกครั้ง → คืนค่าที่เคยบันทึกไว้
      if (!_restoredSaved) {
        _restoredSaved = true;
        final saved = await _service.fetchSavedSelections(widget.job.id);
        for (final row in saved) {
          final match = list.where((s) => s.templateId == row['template_id']);
          if (match.isEmpty) continue;
          final s = match.first;
          s.selected = true;
          s.name = row['name']?.toString() ?? s.name;
          s.minSelection = (row['min_selection'] as num?)?.toInt() ?? s.minSelection;
          s.maxSelection = (row['max_selection'] as num?)?.toInt() ?? s.maxSelection;
          s.options = ((row['options'] as List?) ?? const [])
              .map((o) => AiTemplateOption(
                  o['label']?.toString() ?? '', (o['price'] as num?)?.round() ?? 0))
              .toList();
          s.itemIds =
              Set<String>.from((row['import_item_ids'] as List?) ?? const [])
                  .intersection(ids);
        }
      }
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AiMenuImportService.errorCode(e);
      });
    }
  }

  Future<void> _continue({required bool skip}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final jdc = JdcColors.of(context);
    final selected = skip
        ? <AiTemplateSuggestion>[]
        : _suggestions.where((s) => s.selected && s.itemIds.isNotEmpty).toList();
    setState(() => _saving = true);
    try {
      await _service.saveTemplateSelections(widget.job.id, _storeType, selected);
      if (!mounted) return;
      setState(() => _saving = false);
      final published = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => AiMenuImportPublishScreen(
          job: widget.job,
          items: widget.items,
          selections: selected,
          service: _service,
        ),
      ));
      if (!mounted) return;
      if (published == true) Navigator.of(context).pop(true);
      if (published == false) Navigator.of(context).pop(false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
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
    final selectedCount = _suggestions.where((s) => s.selected).length;
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          AiImportHeader(
            title: l10n.aiImpTemplatesTitle,
            subtitle: l10n.aiImpTemplatesSubtitle,
          ),
          Expanded(child: _buildBody(jdc, l10n)),
          AiImportBottomBar(
            secondaryLabel: l10n.aiImpSkipStep,
            onSecondary: () => _continue(skip: true),
            primaryLabel: selectedCount > 0
                ? l10n.aiImpNextPreviewWith(selectedCount)
                : l10n.aiImpNextPreview,
            onPrimary: _loading ? null : () => _continue(skip: false),
            busy: _saving,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(JdcColors jdc, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      children: [
        Text(l10n.aiImpStoreTypeLabel, style: aiTxt(jdc.text, 14, w: 600)),
        const SizedBox(height: JdcSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('store-type-$_dropdownEpoch'),
                initialValue: _storeType,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: [
                  for (final t in kAiStoreTypes)
                    DropdownMenuItem(value: t, child: Text(aiStoreTypeLabel(l10n, t))),
                ],
                onChanged: _saving ? null : _changeStoreType,
              ),
            ),
          ],
        ),
        if (widget.job.storeTypeGuess != null) ...[
          const SizedBox(height: JdcSpacing.xs),
          Text(l10n.aiImpStoreTypeGuess(aiStoreTypeLabel(l10n, widget.job.storeTypeGuess!)),
              style: aiTxt(jdc.muted, 12)),
        ],
        const SizedBox(height: JdcSpacing.lg),
        if (_loading)
          Padding(
            padding: const EdgeInsets.all(JdcSpacing.xxl),
            child: Center(child: CircularProgressIndicator(color: jdc.cta)),
          )
        else if (_error != null)
          Column(children: [
            Text(aiImportErrorText(l10n, _error!), style: aiTxt(jdc.muted, 13)),
            TextButton(onPressed: _load, child: Text(l10n.aiImpRetry)),
          ])
        else if (_suggestions.isEmpty)
          Text(l10n.aiImpNoTemplates, style: aiTxt(jdc.muted, 13))
        else
          for (final s in _suggestions) ...[
            _buildSuggestionCard(jdc, l10n, s),
            const SizedBox(height: JdcSpacing.md),
          ],
      ],
    );
  }

  /// เปลี่ยนประเภทร้าน → โหลดแม่แบบของประเภทใหม่
  /// ถ้าติ๊กชุดไว้แล้ว ต้องถามก่อน เพราะสิ่งที่เลือก/แก้ไว้จะหาย
  Future<void> _changeStoreType(String? value) async {
    if (value == null || value == _storeType || !mounted) return;
    if (_suggestions.any((s) => s.selected)) {
      final l10n = AppLocalizations.of(context)!;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.aiImpChangeTypeTitle),
          content: Text(l10n.aiImpChangeTypeBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.aiImpCancel)),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.aiImpChangeTypeConfirm)),
          ],
        ),
      );
      if (!mounted) return;
      if (ok != true) {
        setState(() => _dropdownEpoch++);
        return;
      }
    }
    setState(() => _storeType = value);
    _load();
  }

  String _rule(AppLocalizations l10n, AiTemplateSuggestion s) =>
      s.minSelection >= 1
          ? l10n.aiImpRuleRequired(s.minSelection)
          : l10n.aiImpRuleOptional(s.maxSelection);

  Widget _buildSuggestionCard(
      JdcColors jdc, AppLocalizations l10n, AiTemplateSuggestion s) {
    final options = s.options
        .map((o) => o.price > 0 ? '${o.label} +${o.price}' : o.label)
        .join(' · ');
    return AiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: s.selected,
                onChanged: (v) => setState(() => s.selected = v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: aiTxt(jdc.text, 15, w: 700)),
                    Text(_rule(l10n, s), style: aiTxt(jdc.muted, 12)),
                    const SizedBox(height: JdcSpacing.xs),
                    Text(options, style: aiTxt(jdc.text, 13)),
                  ],
                ),
              ),
            ],
          ),
          if (s.options.any((o) => o.price > 0)) ...[
            const SizedBox(height: JdcSpacing.sm),
            AiBadge(l10n.aiImpTemplatePriceBadge, tone: AiBadgeTone.warning),
          ],
          const SizedBox(height: JdcSpacing.sm),
          Text(
            s.itemIds.isEmpty
                ? l10n.aiImpTemplateNoItems
                : l10n.aiImpTemplateItems(s.itemIds.length, _itemNames(s.itemIds)),
            style: aiTxt(jdc.text, 12),
          ),
          if (s.skippedItemIds.isNotEmpty)
            Text(l10n.aiImpTemplateSkipped(s.skippedItemIds.length),
                style: aiTxt(jdc.muted, 12)),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                  onPressed: () => _editItems(s), child: Text(l10n.aiImpEditItems)),
              TextButton(
                  onPressed: () => _editOptions(s), child: Text(l10n.aiImpEditOptions)),
            ],
          ),
        ],
      ),
    );
  }

  String _itemNames(Set<String> ids) {
    final names = ids.map((id) => _itemsById[id]?.name).whereType<String>().toList();
    final head = names.take(3).join(', ');
    return names.length > 3 ? '$head…' : head;
  }

  Future<void> _editItems(AiTemplateSuggestion s) async {
    final chosen = Set<String>.from(s.itemIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.aiImpEditItemsTitle(s.name)),
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).pop(chosen),
                  child: Text(l10n.aiImpDone),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in widget.items)
                      CheckboxListTile(
                        value: chosen.contains(item.id),
                        title: Text(item.name),
                        subtitle: Text(item.category ?? ''),
                        onChanged: (v) => setSheet(() {
                          if (v == true) {
                            chosen.add(item.id);
                          } else {
                            chosen.remove(item.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && mounted) setState(() => s.itemIds = result);
  }

  Future<void> _editOptions(AiTemplateSuggestion s) async {
    final updated = await showModalBottomSheet<AiTemplateSuggestion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OptionsEditorSheet(suggestion: s),
    );
    if (updated != null && mounted) setState(() {});
  }
}

class _OptionsEditorSheet extends StatefulWidget {
  const _OptionsEditorSheet({required this.suggestion});
  final AiTemplateSuggestion suggestion;

  @override
  State<_OptionsEditorSheet> createState() => _OptionsEditorSheetState();
}

class _OptionsEditorSheetState extends State<_OptionsEditorSheet> {
  late final _name = TextEditingController(text: widget.suggestion.name);
  late bool _required = widget.suggestion.minSelection >= 1;
  late int _max = widget.suggestion.maxSelection;
  late final List<(TextEditingController, TextEditingController)> _rows = widget
      .suggestion.options
      .map((o) => (TextEditingController(text: o.label),
          TextEditingController(text: '${o.price}')))
      .toList();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final (a, b) in _rows) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final options = _rows
        .where((r) => r.$1.text.trim().isNotEmpty)
        .map((r) => AiTemplateOption(r.$1.text.trim(), int.tryParse(r.$2.text.trim()) ?? 0))
        .toList();
    if (_name.text.trim().isEmpty || options.isEmpty) {
      setState(() => _error = l10n.aiImpErrOptions);
      return;
    }
    final s = widget.suggestion;
    s.name = _name.text.trim();
    s.options = options;
    s.minSelection = _required ? 1 : 0;
    s.maxSelection = _required ? 1 : _max.clamp(1, options.length);
    Navigator.of(context).pop(s);
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JdcSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiImpEditOptions, style: aiTxt(jdc.text, 17, w: 700)),
            const SizedBox(height: JdcSpacing.md),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: l10n.aiImpFieldGroupName, border: const OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _required,
              title: Text(l10n.aiImpRequiredOne),
              onChanged: (v) => setState(() => _required = v),
            ),
            for (var i = 0; i < _rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: JdcSpacing.sm),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _rows[i].$1,
                      decoration: InputDecoration(
                          labelText: l10n.aiImpFieldOptionLabel,
                          isDense: true,
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: JdcSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _rows[i].$2,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                          labelText: l10n.aiImpFieldAddPrice,
                          isDense: true,
                          border: const OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _rows.removeAt(i)),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _rows
                    .add((TextEditingController(), TextEditingController(text: '0')))),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.aiImpAddVariant),
              ),
            ),
            if (!_required)
              Row(children: [
                Expanded(child: Text(l10n.aiImpMaxSelect, style: aiTxt(jdc.text, 13))),
                IconButton(
                    onPressed: _max > 1 ? () => setState(() => _max--) : null,
                    icon: const Icon(Icons.remove)),
                Text('$_max', style: aiTxt(jdc.text, 14, w: 700)),
                IconButton(
                    onPressed: _max < _rows.length ? () => setState(() => _max++) : null,
                    icon: const Icon(Icons.add)),
              ]),
            if (_error != null) Text(_error!, style: aiTxt(jdc.dangerInk, 13)),
            const SizedBox(height: JdcSpacing.md),
            FilledButton(onPressed: _save, child: Text(l10n.aiImpDone)),
          ],
        ),
      ),
    );
  }
}
