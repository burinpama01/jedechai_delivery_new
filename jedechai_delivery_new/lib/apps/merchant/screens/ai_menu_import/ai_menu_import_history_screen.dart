import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/services/ai_menu_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'ai_import_widgets.dart';
import 'ai_menu_import_review_screen.dart';

/// ประวัติการนำเข้าเมนูด้วย AI + ปุ่ม "ซ่อนเมนูชุดนี้ทั้งหมด" (ข้อ 10.4)
class AiMenuImportHistoryScreen extends StatefulWidget {
  const AiMenuImportHistoryScreen({super.key, this.service});

  final AiMenuImportService? service;

  @override
  State<AiMenuImportHistoryScreen> createState() =>
      _AiMenuImportHistoryScreenState();
}

class _AiMenuImportHistoryScreenState extends State<AiMenuImportHistoryScreen> {
  late final AiMenuImportService _service =
      widget.service ?? AiMenuImportService();
  List<AiImportJob> _jobs = [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await _service.fetchJobs();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AiMenuImportService.errorCode(e);
      });
    }
  }

  Future<void> _hide(AiImportJob job) async {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.aiImpHideAllTitle),
        content: Text(l10n.aiImpHideAllBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.aiImpCancel)),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.aiImpHideAll)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final n = await _service.hideImportedItems(job.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiImpHiddenCount(n))));
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

  (String, AiBadgeTone) _statusLabel(AppLocalizations l10n, AiImportJob job) =>
      switch (job.status) {
        'queued' || 'processing' => (l10n.aiImpStatusProcessing, AiBadgeTone.info),
        'review_required' || 'ready' => (l10n.aiImpStatusReview, AiBadgeTone.warning),
        'publishing' || 'published' => (l10n.aiImpStatusPublished, AiBadgeTone.success),
        'failed' => (l10n.aiImpStatusFailed, AiBadgeTone.danger),
        _ => (l10n.aiImpStatusCancelled, AiBadgeTone.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final fmt = DateFormat('d MMM yyyy HH:mm', Localizations.localeOf(context).toString());
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          AiImportHeader(title: l10n.aiImpHistoryTitle),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: jdc.cta))
                : _error != null
                    ? Center(
                        child: TextButton(
                            onPressed: _load, child: Text(l10n.aiImpRetry)))
                    : _jobs.isEmpty
                        ? Center(
                            child: Text(l10n.aiImpHistoryEmpty,
                                style: aiTxt(jdc.muted, 13)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: jdc.cta,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(JdcSpacing.lg),
                              itemCount: _jobs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: JdcSpacing.md),
                              itemBuilder: (context, i) {
                                final job = _jobs[i];
                                final (label, tone) = _statusLabel(l10n, job);
                                final openable = job.isReviewable ||
                                    job.isProcessing ||
                                    job.isFailed;
                                return AiCard(
                                  onTap: openable
                                      ? () async {
                                          await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      AiMenuImportReviewScreen(
                                                          jobId: job.id,
                                                          service: _service)));
                                          _load();
                                        }
                                      : null,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(
                                            job.createdAt == null
                                                ? '-'
                                                : fmt.format(job.createdAt!.toLocal()),
                                            style: aiTxt(jdc.text, 14, w: 700),
                                          ),
                                        ),
                                        AiBadge(label, tone: tone),
                                      ]),
                                      const SizedBox(height: JdcSpacing.xs),
                                      Text(
                                        l10n.aiImpHistoryLine(
                                            job.totalFiles, job.totalItems),
                                        style: aiTxt(jdc.muted, 12),
                                      ),
                                      if (job.isPublished) ...[
                                        const SizedBox(height: JdcSpacing.xs),
                                        Text(
                                          job.hiddenAt != null
                                              ? l10n.aiImpHistoryHidden
                                              : job.visibility == 'live'
                                                  ? l10n.aiImpVisibilityLive
                                                  : l10n.aiImpVisibilityHidden,
                                          style: aiTxt(jdc.muted, 12),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed:
                                                _busy ? null : () => _hide(job),
                                            style: TextButton.styleFrom(
                                                foregroundColor: jdc.dangerInk),
                                            child: Text(l10n.aiImpHideAll),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
