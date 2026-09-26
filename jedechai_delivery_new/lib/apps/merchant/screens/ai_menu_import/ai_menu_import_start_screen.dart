import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/services/ai_menu_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'ai_import_widgets.dart';
import 'ai_menu_import_history_screen.dart';
import 'ai_menu_import_review_screen.dart';

/// หน้าเริ่ม AI Menu Import — เลือก/ถ่ายรูปป้ายเมนู 1–8 รูป แล้วส่งให้ AI อ่าน
///
/// โหมดมาจาก server: ร้านยังไม่อนุมัติ = onboarding, อนุมัติแล้ว = append
class AiMenuImportStartScreen extends StatefulWidget {
  const AiMenuImportStartScreen({super.key, this.service});

  final AiMenuImportService? service;

  @override
  State<AiMenuImportStartScreen> createState() =>
      _AiMenuImportStartScreenState();
}

class _AiMenuImportStartScreenState extends State<AiMenuImportStartScreen> {
  late final AiMenuImportService _service =
      widget.service ?? AiMenuImportService();
  final ImagePicker _picker = ImagePicker();

  AiImportStatus? _status;
  bool _loading = true;
  bool _uploading = false;
  String? _error;
  final List<Uint8List> _images = [];

  // ย่อฝั่ง client ก่อนส่ง: ≤2048px, JPEG q80 (image_picker จัด EXIF rotation ให้)
  static const double _maxSide = 2048;
  static const int _quality = 80;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _service.fetchStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AiMenuImportService.errorCode(e);
        _loading = false;
      });
    }
  }

  int get _maxFiles => _status?.maxFiles ?? 8;

  Future<void> _addFromCamera() async {
    if (_images.length >= _maxFiles) return;
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
      imageQuality: _quality,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _images.add(bytes));
  }

  Future<void> _addFromGallery() async {
    final remaining = _maxFiles - _images.length;
    if (remaining <= 0) return;
    final List<XFile> files;
    if (remaining == 1) {
      final one = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
      );
      files = one == null ? const [] : [one];
    } else {
      files = await _picker.pickMultiImage(
        maxWidth: _maxSide,
        maxHeight: _maxSide,
        imageQuality: _quality,
        limit: remaining,
      );
    }
    final bytes = <Uint8List>[];
    for (final f in files.take(remaining)) {
      bytes.add(await f.readAsBytes());
    }
    if (!mounted) return;
    setState(() => _images.addAll(bytes));
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final jdc = JdcColors.of(context);
    setState(() => _uploading = true);
    try {
      final jobId = await _service.startImport(List.of(_images));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => AiMenuImportReviewScreen(jobId: jobId, service: _service),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      messenger.showSnackBar(SnackBar(
        content: Text(aiImportErrorText(l10n, AiMenuImportService.errorCode(e))),
        backgroundColor: jdc.danger,
      ));
      _loadStatus();
    }
  }

  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AiMenuImportHistoryScreen(service: _service),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final status = _status;
    final isAppend = status?.isAppend ?? false;
    final canStart = status != null &&
        status.allowed &&
        status.activeJobId == null &&
        _images.isNotEmpty;

    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          AiImportHeader(
            title: isAppend ? l10n.aiImpTitleAppend : l10n.aiImpTitleOnboarding,
            subtitle: l10n.aiImpStartSubtitle,
            trailing: IconButton(
              tooltip: l10n.aiImpHistoryTitle,
              icon: Icon(Icons.history, color: jdc.muted),
              onPressed: _openHistory,
            ),
          ),
          Expanded(child: _buildBody(jdc, l10n)),
          AiImportBottomBar(
            primaryLabel: _images.isEmpty
                ? l10n.aiImpStartButtonEmpty
                : l10n.aiImpStartButton(_images.length),
            onPrimary: canStart ? _start : null,
            busy: _uploading,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(JdcColors jdc, AppLocalizations l10n) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: jdc.cta));
    }
    if (_error != null || _status == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(JdcSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(aiImportErrorText(l10n, _error ?? 'unknown'),
                  textAlign: TextAlign.center, style: aiTxt(jdc.muted, 14)),
              const SizedBox(height: JdcSpacing.md),
              TextButton(onPressed: _loadStatus, child: Text(l10n.aiImpRetry)),
            ],
          ),
        ),
      );
    }
    final status = _status!;
    return ListView(
      padding: const EdgeInsets.all(JdcSpacing.xl),
      children: [
        if (status.activeJobId != null) ...[
          AiCard(
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => AiMenuImportReviewScreen(
                  jobId: status.activeJobId!, service: _service),
            )),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, color: jdc.infoInk),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                    child: Text(l10n.aiImpActiveJob,
                        style: aiTxt(jdc.text, 14, w: 600))),
                Icon(Icons.chevron_right, color: jdc.muted),
              ],
            ),
          ),
          const SizedBox(height: JdcSpacing.lg),
        ],
        if (!status.allowed && status.reason == 'quota_exceeded') ...[
          AiCard(
            child: Text(
              status.isAppend
                  ? l10n.aiImpQuotaFullAppend(status.quotaLimit)
                  : l10n.aiImpQuotaFullOnboarding(status.quotaLimit),
              style: aiTxt(jdc.dangerInk, 14, w: 600),
            ),
          ),
          const SizedBox(height: JdcSpacing.lg),
        ],
        _buildSteps(jdc, l10n, status),
        const SizedBox(height: JdcSpacing.lg),
        Text(l10n.aiImpPhotosTitle(_images.length, _maxFiles),
            style: aiTxt(jdc.text, 15, w: 700)),
        const SizedBox(height: JdcSpacing.sm),
        Text(l10n.aiImpPhotosHint, style: aiTxt(jdc.muted, 12)),
        const SizedBox(height: JdcSpacing.md),
        _buildPhotoGrid(jdc, l10n),
        const SizedBox(height: JdcSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _images.length < _maxFiles && !_uploading
                    ? _addFromCamera
                    : null,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.aiImpTakePhoto),
              ),
            ),
            const SizedBox(width: JdcSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _images.length < _maxFiles && !_uploading
                    ? _addFromGallery
                    : null,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(l10n.aiImpPickGallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: JdcSpacing.xl),
        Text(l10n.aiImpPrivacyNote, style: aiTxt(jdc.muted, 11, height: 1.5)),
      ],
    );
  }

  Widget _buildSteps(JdcColors jdc, AppLocalizations l10n, AiImportStatus s) {
    final steps = [
      l10n.aiImpStep1,
      l10n.aiImpStep2,
      s.isAppend ? l10n.aiImpStep3Append : l10n.aiImpStep3Onboarding,
    ];
    return AiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: JdcSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: jdc.brandSoft,
                    child: Text('${i + 1}', style: aiTxt(jdc.brandOnSoft, 11, w: 700)),
                  ),
                  const SizedBox(width: JdcSpacing.md),
                  Expanded(child: Text(steps[i], style: aiTxt(jdc.text, 13, height: 1.45))),
                ],
              ),
            ),
          const SizedBox(height: JdcSpacing.xs),
          Text(
            s.isAppend
                ? l10n.aiImpQuotaAppend(s.quotaUsed, s.quotaLimit)
                : l10n.aiImpQuotaOnboarding(s.quotaUsed, s.quotaLimit),
            style: aiTxt(jdc.muted, 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(JdcColors jdc, AppLocalizations l10n) {
    if (_images.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: jdc.sunken,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu, color: jdc.dim, size: 32),
            const SizedBox(height: JdcSpacing.sm),
            Text(l10n.aiImpNoPhotos, style: aiTxt(jdc.muted, 13)),
          ],
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: JdcSpacing.sm,
        crossAxisSpacing: JdcSpacing.sm,
      ),
      itemBuilder: (context, i) => Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(JdcRadius.small),
            child: Image.memory(_images[i], fit: BoxFit.cover),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: _uploading ? null : () => setState(() => _images.removeAt(i)),
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.black54,
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
