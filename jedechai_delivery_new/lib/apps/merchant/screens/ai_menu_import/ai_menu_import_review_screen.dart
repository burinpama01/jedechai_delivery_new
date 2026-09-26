import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/services/ai_menu_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'ai_import_widgets.dart';
import 'ai_menu_import_templates_screen.dart';

enum _Filter { all, review, ready, existing, rejected }

/// รอ AI ประมวลผล → ตรวจ/แก้รายการ (ข้อ 9–10 ในแผน)
class AiMenuImportReviewScreen extends StatefulWidget {
  const AiMenuImportReviewScreen({super.key, required this.jobId, this.service});

  final String jobId;
  final AiMenuImportService? service;

  @override
  State<AiMenuImportReviewScreen> createState() =>
      _AiMenuImportReviewScreenState();
}

class _AiMenuImportReviewScreenState extends State<AiMenuImportReviewScreen> {
  late final AiMenuImportService _service =
      widget.service ?? AiMenuImportService();

  AiImportJob? _job;
  List<AiImportItem> _items = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  _Filter _filter = _Filter.all;
  Timer? _poll;
  int _pollCount = 0;

  static const int _maxPolls = 80; // ~6 นาที (3s × 20 แล้ว 6s × 60)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final job = await _service.fetchJob(widget.jobId);
      List<AiImportItem> items = _items;
      if (job != null && (job.isReviewable || job.isPublished)) {
        items = await _service.fetchItems(widget.jobId);
      }
      if (!mounted) return;
      setState(() {
        _job = job;
        _items = items;
        _loading = false;
        _error = job == null ? 'ai_import_job_not_found' : null;
      });
      _schedulePoll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AiMenuImportService.errorCode(e);
      });
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    final job = _job;
    if (job == null || !(job.isProcessing || job.status == 'uploading')) return;
    if (_pollCount >= _maxPolls) return;
    // 1 นาทีแรกถี่ แล้วค่อยห่างขึ้น ลดโหลดตอนงานช้า
    final interval = Duration(seconds: _pollCount < 20 ? 3 : 6);
    _poll = Timer(interval, () {
      _pollCount++;
      _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final jdc = JdcColors.of(context);
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(aiImportErrorText(l10n, AiMenuImportService.errorCode(e))),
        backgroundColor: jdc.danger,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() => _run(() async {
        _pollCount = 0;
        await _service.process(widget.jobId);
      });

  Future<void> _cancel() async {
    await _run(() => _service.cancelJob(widget.jobId));
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _bulkApprove() => _run(() async {
        await _service.bulkApprove(widget.jobId);
      });

  Future<void> _next() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AiMenuImportTemplatesScreen(
        job: _job!,
        items: _items.where((i) => i.willCreate && i.isConfirmed).toList(),
        service: _service,
      ),
    ));
    if (!mounted) return;
    if (changed == true) {
      Navigator.of(context).pop(true);
    } else {
      _load();
    }
  }

  // ─────────────────────────────── counts
  int get _pendingCount =>
      _items.where((i) => i.willCreate && !i.isConfirmed).length;
  int get _readyDraftCount => _items
      .where((i) => i.willCreate && !i.isConfirmed && i.issues.isEmpty)
      .length;
  int get _needsReviewCount => _items.where((i) => i.needsReview).length;
  int get _confirmedCount =>
      _items.where((i) => i.willCreate && i.isConfirmed).length;
  int get _existingCount => _items.where((i) => i.action == 'skip').length;
  int get _rejectedCount =>
      _items.where((i) => i.action == 'create' && i.status == 'rejected').length;

  List<AiImportItem> get _visible => switch (_filter) {
        _Filter.all => _items,
        _Filter.review => _items.where((i) => i.needsReview).toList(),
        _Filter.ready => _items.where((i) => i.isReady).toList(),
        _Filter.existing => _items.where((i) => i.action == 'skip').toList(),
        _Filter.rejected => _items
            .where((i) => i.action == 'create' && i.status == 'rejected')
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final job = _job;
    final reviewable = job?.isReviewable ?? false;

    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          AiImportHeader(
            title: l10n.aiImpReviewTitle,
            subtitle: reviewable
                ? l10n.aiImpReviewSummary(_items.length, _confirmedCount,
                    _needsReviewCount, _existingCount)
                : null,
          ),
          Expanded(child: _buildBody(jdc, l10n)),
          if (reviewable)
            AiImportBottomBar(
              secondaryLabel: _readyDraftCount > 0
                  ? l10n.aiImpApproveAllReady(_readyDraftCount)
                  : null,
              onSecondary: _bulkApprove,
              primaryLabel: _pendingCount > 0
                  ? l10n.aiImpPendingLeft(_pendingCount)
                  : l10n.aiImpNextTemplates,
              onPrimary:
                  _pendingCount == 0 && _confirmedCount > 0 ? _next : null,
              busy: _busy,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(JdcColors jdc, AppLocalizations l10n) {
    if (_loading) return Center(child: CircularProgressIndicator(color: jdc.cta));
    final job = _job;
    if (_error != null || job == null) {
      return _message(jdc, Icons.error_outline,
          aiImportErrorText(l10n, _error ?? 'unknown'),
          action: TextButton(onPressed: _load, child: Text(l10n.aiImpRetry)));
    }
    if (job.isProcessing || job.status == 'uploading') {
      final timedOut = _pollCount >= _maxPolls;
      return _message(
        jdc,
        Icons.auto_awesome,
        timedOut ? l10n.aiImpProcessingSlow : l10n.aiImpProcessing(job.totalFiles),
        progress: !timedOut,
        action: timedOut
            ? TextButton(
                onPressed: () {
                  _pollCount = 0;
                  _load();
                },
                child: Text(l10n.aiImpRetry))
            : null,
      );
    }
    if (job.isFailed) {
      return _message(
        jdc,
        Icons.report_gmailerrorred,
        l10n.aiImpFailed,
        action: Wrap(
          spacing: JdcSpacing.md,
          children: [
            if (job.attempts < 3)
              FilledButton(
                  onPressed: _busy ? null : _retry, child: Text(l10n.aiImpRetry)),
            OutlinedButton(
                onPressed: _busy ? null : _cancel, child: Text(l10n.aiImpCancelJob)),
          ],
        ),
      );
    }
    if (job.isPublished) {
      return _message(jdc, Icons.check_circle_outline, l10n.aiImpAlreadyPublished);
    }
    if (job.status == 'cancelled') {
      return _message(jdc, Icons.block, l10n.aiImpCancelled);
    }
    if (_items.isEmpty) {
      return _message(jdc, Icons.search_off, l10n.aiImpNoItems,
          action: OutlinedButton(
              onPressed: _busy ? null : _cancel, child: Text(l10n.aiImpCancelJob)));
    }

    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _load,
      color: jdc.cta,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            JdcSpacing.lg, JdcSpacing.md, JdcSpacing.lg, JdcSpacing.xxl),
        children: [
          _buildFilters(jdc, l10n),
          if (job.unreadableRegions.isNotEmpty) ...[
            const SizedBox(height: JdcSpacing.md),
            AiCard(
              child: Text(
                l10n.aiImpUnreadable(job.unreadableRegions.join(' · ')),
                style: aiTxt(jdc.muted, 12, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: JdcSpacing.md),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(JdcSpacing.xxl),
              child: Center(
                  child: Text(l10n.aiImpFilterEmpty, style: aiTxt(jdc.muted, 13))),
            ),
          for (final item in visible) ...[
            _buildItemCard(jdc, l10n, item),
            const SizedBox(height: JdcSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _message(JdcColors jdc, IconData icon, String text,
      {Widget? action, bool progress = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: jdc.dim),
            const SizedBox(height: JdcSpacing.md),
            Text(text,
                textAlign: TextAlign.center,
                style: aiTxt(jdc.text, 14, height: 1.5)),
            if (progress) ...[
              const SizedBox(height: JdcSpacing.lg),
              SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(color: jdc.cta, minHeight: 3)),
            ],
            if (action != null) ...[
              const SizedBox(height: JdcSpacing.lg),
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(JdcColors jdc, AppLocalizations l10n) {
    final chips = <(_Filter, String)>[
      (_Filter.all, l10n.aiImpFilterAll(_items.length)),
      (_Filter.review, l10n.aiImpFilterReview(_needsReviewCount)),
      (_Filter.ready, l10n.aiImpFilterReady(_items.where((i) => i.isReady).length)),
      (_Filter.existing, l10n.aiImpFilterExisting(_existingCount)),
      (_Filter.rejected, l10n.aiImpFilterRejected(_rejectedCount)),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (f, label) in chips)
            Padding(
              padding: const EdgeInsets.only(right: JdcSpacing.sm),
              child: ChoiceChip(
                label: Text(label),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ],
      ),
    );
  }

  String _issueText(AppLocalizations l10n, String issue) => switch (issue) {
        'missing_price' => l10n.aiImpIssueMissingPrice,
        'price_out_of_range' => l10n.aiImpIssuePriceRange,
        'price_text_mismatch' => l10n.aiImpIssuePriceText,
        'low_price_conf' => l10n.aiImpIssueLowPrice,
        'check_price' => l10n.aiImpIssueCheckPrice,
        'low_name_conf' => l10n.aiImpIssueLowName,
        'check_name' => l10n.aiImpIssueCheckName,
        'variant_base_mismatch' => l10n.aiImpIssueVariant,
        'price_conflict' => l10n.aiImpIssueConflict,
        'similar_existing' => l10n.aiImpIssueSimilar,
        _ => issue,
      };

  Widget _statusBadge(AppLocalizations l10n, AiImportItem item) {
    if (item.action == 'skip') {
      return item.matchType == 'price_changed'
          ? AiBadge(l10n.aiImpBadgePriceChanged, tone: AiBadgeTone.info)
          : AiBadge(l10n.aiImpBadgeExisting, tone: AiBadgeTone.neutral);
    }
    if (item.status == 'rejected') {
      return AiBadge(l10n.aiImpBadgeRejected, tone: AiBadgeTone.neutral);
    }
    if (item.isConfirmed) {
      return AiBadge(l10n.aiImpBadgeConfirmed, tone: AiBadgeTone.success);
    }
    if (item.issues.isNotEmpty) {
      final danger = item.issues.any((i) =>
          i == 'missing_price' || i == 'low_price_conf' || i == 'price_conflict');
      return AiBadge(l10n.aiImpBadgeNeedsReview,
          tone: danger ? AiBadgeTone.danger : AiBadgeTone.warning);
    }
    return AiBadge(l10n.aiImpBadgeReady, tone: AiBadgeTone.success);
  }

  String _priceLine(AiImportItem item) {
    if (item.variants.length >= 2) {
      return item.variants
          .map((v) => '${v.label} ${aiBaht(v.price)}')
          .join(' · ');
    }
    return aiBaht(item.price);
  }

  Widget _buildItemCard(JdcColors jdc, AppLocalizations l10n, AiImportItem item) {
    final dim = item.action == 'skip' || item.status == 'rejected';
    return AiCard(
      dim: dim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: aiTxt(jdc.text, 15, w: 700)),
                    const SizedBox(height: 2),
                    Text(_priceLine(item), style: aiTxt(jdc.text, 13, w: 600)),
                  ],
                ),
              ),
              const SizedBox(width: JdcSpacing.sm),
              _statusBadge(l10n, item),
            ],
          ),
          const SizedBox(height: JdcSpacing.sm),
          Wrap(
            spacing: JdcSpacing.sm,
            runSpacing: JdcSpacing.xs,
            children: [
              AiBadge(item.category ?? '-', tone: AiBadgeTone.neutral),
              if (item.isNewCategory && item.willCreate)
                AiBadge(l10n.aiImpBadgeNewCategory, tone: AiBadgeTone.info),
              if (item.addons.isNotEmpty)
                AiBadge(l10n.aiImpBadgeAddons(item.addons.length),
                    tone: AiBadgeTone.neutral),
            ],
          ),
          if (item.action == 'skip' && item.matchedPrice != null) ...[
            const SizedBox(height: JdcSpacing.sm),
            Text(
              item.matchType == 'price_changed'
                  ? l10n.aiImpPriceChangedLine(
                      aiBaht(item.matchedPrice), aiBaht(item.price))
                  : l10n.aiImpExistingLine,
              style: aiTxt(jdc.muted, 12),
            ),
          ],
          if (item.willCreate && !item.isConfirmed && item.issues.isNotEmpty) ...[
            const SizedBox(height: JdcSpacing.sm),
            for (final issue in item.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• ${_issueText(l10n, issue)}',
                    style: aiTxt(jdc.dangerInk, 12)),
              ),
            if (item.priceTextRaw != null)
              Text(l10n.aiImpPriceSeen(item.priceTextRaw!),
                  style: aiTxt(jdc.muted, 12)),
          ],
          if (item.hasPriceConflict && item.willCreate && !item.isConfirmed) ...[
            const SizedBox(height: JdcSpacing.sm),
            Text(l10n.aiImpChoosePrice, style: aiTxt(jdc.text, 12, w: 600)),
            const SizedBox(height: JdcSpacing.xs),
            Wrap(
              spacing: JdcSpacing.sm,
              children: [
                for (final p in item.conflictPrices)
                  ActionChip(
                    label: Text(aiBaht(p)),
                    onPressed: _busy
                        ? null
                        : () => _run(() => _service.reviewItem(
                            item.id, 'choose_price', {'price': p})),
                  ),
              ],
            ),
          ],
          const SizedBox(height: JdcSpacing.sm),
          _buildActions(jdc, l10n, item),
        ],
      ),
    );
  }

  Widget _buildActions(JdcColors jdc, AppLocalizations l10n, AiImportItem item) {
    final buttons = <Widget>[];
    if (item.action == 'skip') {
      if (item.matchType != 'exact_dup') {
        buttons.add(TextButton(
          onPressed: _busy ? null : () => _run(() => _service.reviewItem(item.id, 'create')),
          child: Text(l10n.aiImpAddAsNew),
        ));
      }
    } else if (item.status == 'rejected') {
      buttons.add(TextButton(
        onPressed: _busy ? null : () => _run(() => _service.reviewItem(item.id, 'restore')),
        child: Text(l10n.aiImpRestore),
      ));
    } else {
      buttons.add(TextButton(
        onPressed: _busy ? null : () => _openEditor(item),
        child: Text(l10n.aiImpEdit),
      ));
      if (!item.isConfirmed && !item.hasPriceConflict) {
        buttons.add(TextButton(
          onPressed: _busy || item.price == null
              ? null
              : () => _run(() => _service.reviewItem(item.id, 'approve')),
          child: Text(l10n.aiImpConfirm),
        ));
      }
      buttons.add(TextButton(
        onPressed: _busy ? null : () => _run(() => _service.reviewItem(item.id, 'reject')),
        style: TextButton.styleFrom(foregroundColor: jdc.dangerInk),
        child: Text(l10n.aiImpReject),
      ));
      if (item.matchType != 'new') {
        buttons.add(TextButton(
          onPressed: _busy ? null : () => _run(() => _service.reviewItem(item.id, 'skip')),
          child: Text(l10n.aiImpSkip),
        ));
      }
    }
    return Wrap(alignment: WrapAlignment.end, children: buttons);
  }

  Future<void> _openEditor(AiImportItem item) async {
    final patch = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: JdcColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(JdcRadius.sheet)),
      ),
      builder: (_) => _ItemEditorSheet(item: item),
    );
    if (patch == null || !mounted) return;
    await _run(() => _service.reviewItem(item.id, 'edit', patch));
  }
}

class _EditableVariant {
  _EditableVariant(String label, num? price)
      : label = TextEditingController(text: label),
        price = TextEditingController(text: price == null ? '' : '${price.round()}');
  final TextEditingController label;
  final TextEditingController price;
}

class _EditableAddon {
  _EditableAddon(String? group, String label, num? price)
      : group = TextEditingController(text: group ?? ''),
        label = TextEditingController(text: label),
        price = TextEditingController(text: price == null ? '' : '${price.round()}');
  final TextEditingController group;
  final TextEditingController label;
  final TextEditingController price;
}

/// แก้ชื่อ/ราคา/หมวด/คำอธิบาย/ตัวเลือกของรายการ — ยืนยันแล้วถือว่าร้านตรวจแล้ว
class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({required this.item});
  final AiImportItem item;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _price = TextEditingController(
      text: widget.item.price == null ? '' : '${widget.item.price!.round()}');
  late final _category = TextEditingController(text: widget.item.category ?? '');
  late final _description =
      TextEditingController(text: widget.item.description ?? '');
  late final _variantGroup =
      TextEditingController(text: widget.item.variantGroup ?? '');
  late final List<_EditableVariant> _variants = widget.item.variants
      .map((v) => _EditableVariant(v.label, v.price))
      .toList();
  late final List<_EditableAddon> _addons = widget.item.addons
      .map((a) => _EditableAddon(a.group, a.label, a.priceDelta))
      .toList();
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _price, _category, _description, _variantGroup]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.label.dispose();
      v.price.dispose();
    }
    for (final a in _addons) {
      a.group.dispose();
      a.label.dispose();
      a.price.dispose();
    }
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();
    final variants = _variants
        .where((v) => v.label.text.trim().isNotEmpty)
        .map((v) => {
              'label': v.label.text.trim(),
              'price': int.tryParse(v.price.text.trim()),
            })
        .toList();
    int? price = int.tryParse(_price.text.trim());
    if (variants.length >= 2) {
      if (variants.any((v) => v['price'] == null || (v['price'] as int) <= 0)) {
        setState(() => _error = l10n.aiImpErrVariantPrice);
        return;
      }
      price = variants.map((v) => v['price'] as int).reduce((a, b) => a < b ? a : b);
    }
    if (name.isEmpty) {
      setState(() => _error = l10n.aiImpErrName);
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = l10n.aiImpErrPrice);
      return;
    }
    final addons = _addons
        .where((a) => a.label.text.trim().isNotEmpty)
        .map((a) => {
              'group': a.group.text.trim().isEmpty ? null : a.group.text.trim(),
              'label': a.label.text.trim(),
              'price_delta': int.tryParse(a.price.text.trim()) ?? 0,
            })
        .toList();
    Navigator.of(context).pop(<String, dynamic>{
      'name': name,
      'price': price,
      'category': _category.text.trim(),
      'description': _description.text.trim(),
      'variant_group': _variantGroup.text.trim(),
      'variants_json': variants.length >= 2 ? variants : <Map<String, dynamic>>[],
      'addons_json': addons,
    });
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JdcSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.aiImpEditTitle, style: aiTxt(jdc.text, 17, w: 700)),
            if (widget.item.priceTextRaw != null) ...[
              const SizedBox(height: JdcSpacing.xs),
              Text(l10n.aiImpPriceSeen(widget.item.priceTextRaw!),
                  style: aiTxt(jdc.muted, 12)),
            ],
            const SizedBox(height: JdcSpacing.lg),
            TextField(controller: _name, decoration: _dec(l10n.aiImpFieldName)),
            const SizedBox(height: JdcSpacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  enabled: _variants.length < 2,
                  decoration: _dec(l10n.aiImpFieldPrice),
                ),
              ),
              const SizedBox(width: JdcSpacing.md),
              Expanded(
                child: TextField(
                    controller: _category, decoration: _dec(l10n.aiImpFieldCategory)),
              ),
            ]),
            const SizedBox(height: JdcSpacing.md),
            TextField(
                controller: _description,
                maxLines: 2,
                decoration: _dec(l10n.aiImpFieldDescription)),
            const SizedBox(height: JdcSpacing.lg),
            Text(l10n.aiImpVariantsTitle, style: aiTxt(jdc.text, 14, w: 700)),
            Text(l10n.aiImpVariantsHint, style: aiTxt(jdc.muted, 12)),
            const SizedBox(height: JdcSpacing.sm),
            TextField(
                controller: _variantGroup,
                decoration: _dec(l10n.aiImpFieldVariantGroup)),
            for (var i = 0; i < _variants.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: JdcSpacing.sm),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: TextField(
                          controller: _variants[i].label,
                          decoration: _dec(l10n.aiImpFieldOptionLabel))),
                  const SizedBox(width: JdcSpacing.sm),
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _variants[i].price,
                          keyboardType: TextInputType.number,
                          inputFormatters: digits,
                          decoration: _dec(l10n.aiImpFieldPrice))),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _variants.removeAt(i)),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _variants.add(_EditableVariant('', null))),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.aiImpAddVariant),
              ),
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(l10n.aiImpAddonsTitle, style: aiTxt(jdc.text, 14, w: 700)),
            for (var i = 0; i < _addons.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: JdcSpacing.sm),
                child: Row(children: [
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _addons[i].group,
                          decoration: _dec(l10n.aiImpFieldAddonGroup))),
                  const SizedBox(width: JdcSpacing.sm),
                  Expanded(
                      flex: 3,
                      child: TextField(
                          controller: _addons[i].label,
                          decoration: _dec(l10n.aiImpFieldOptionLabel))),
                  const SizedBox(width: JdcSpacing.sm),
                  Expanded(
                      flex: 2,
                      child: TextField(
                          controller: _addons[i].price,
                          keyboardType: TextInputType.number,
                          inputFormatters: digits,
                          decoration: _dec(l10n.aiImpFieldAddPrice))),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => _addons.removeAt(i)),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _addons.add(_EditableAddon(null, '', null))),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.aiImpAddAddon),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: JdcSpacing.sm),
              Text(_error!, style: aiTxt(jdc.dangerInk, 13)),
            ],
            const SizedBox(height: JdcSpacing.lg),
            FilledButton(onPressed: _save, child: Text(l10n.aiImpSaveConfirm)),
          ],
        ),
      ),
    );
  }
}
