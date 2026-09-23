import 'package:flutter/material.dart';

import '../../../../theme/jdc_colors.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/services/referral_service.dart';
import '../../../../common/services/notification_service.dart';
import '../../../../common/services/auth_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key}) : super(key: key);

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  final ReferralService _referralService = ReferralService();
  String myReferralCode = '-';
  int totalReferrals = 0;

  bool _didCheckReferralRewardDialog = false;
  Map<String, dynamic>? _referralSummary;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
    _loadReferralSummary();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowReferralRewardDialogIfAny();
    });
  }

  Future<void> _checkAndShowReferralRewardDialogIfAny() async {
    if (!mounted) return;
    if (_didCheckReferralRewardDialog) return;
    _didCheckReferralRewardDialog = true;

    final userId = AuthService.userId;
    if (userId == null) return;

    final unread = await NotificationService.getUnreadByTypes(
      userId,
      const ['referral_reward_referrer'],
      limit: 1,
    );
    if (!mounted) return;
    if (unread.isEmpty) return;

    final n = unread.first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title),
        content: Text(n.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.referralOk),
          ),
        ],
      ),
    );

    await NotificationService.markAsRead(n.id);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadReferralData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final code = await _referralService.getOrCreateMyReferralCode();
      final count = await _referralService.getMyTotalReferrals();

      if (!mounted) return;
      setState(() {
        myReferralCode = code;
        totalReferrals = count;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: myReferralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.referralCopied)),
    );
  }

  void _shareReferralCode() {
    final l10n = AppLocalizations.of(context)!;
    Share.share('${l10n.referralShareMessage} $myReferralCode');
  }

  void _submitCode() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _referralService.submitReferralCode(_codeController.text);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.referralCodeSuccess)),
      );
      _codeController.clear();
      await _loadReferralData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.referralTitle,
            style: TextStyle(color: jdc.onPanel)),
        foregroundColor: jdc.onPanel,
        backgroundColor: jdc.panel,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(),
            _buildMyCodeSection(),
            _buildTierSection(),
            _buildStatsSection(),
            _buildEnterCodeSection(),
            _buildHowItWorks(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final jdc = JdcColors.of(context);
    final earned = (_referralSummary?['total_earned'] as num?)?.toDouble();
    return Container(
      width: double.infinity,
      color: jdc.panel,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.referralHeroTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: jdc.onPanel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.referralHeroSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: jdc.panelDim,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            earned == null
                ? '—'
                : NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2).format(earned),
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: jdc.onPanel),
          ),
          const SizedBox(height: 4),
          Text(
            '${AppLocalizations.of(context)!.referralSuccessful}: $totalReferrals',
            style: TextStyle(fontSize: 12, color: jdc.panelDim),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCodeSection() {
    final jdc = JdcColors.of(context);

    return Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: jdc.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.referralMyCodeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: jdc.text,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: jdc.brandSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: jdc.brandLine),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(
                    myReferralCode,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: jdc.brandOnSoft,
                      letterSpacing: 2,
                    ),
                  )),
                  IconButton(
                    icon: Icon(Icons.copy, color: jdc.brandOnSoft),
                    onPressed: _copyToClipboard,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareReferralCode,
                icon: const Icon(Icons.share),
                label: Text(AppLocalizations.of(context)!.referralShareButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: jdc.cta,
                  foregroundColor: jdc.onCta,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildEnterCodeSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final jdc = JdcColors.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.referralHaveCode,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.referralEnterCodeHint,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText:
                        AppLocalizations.of(context)!.referralCodePlaceholder,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: JdcColors.of(context).line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: JdcColors.of(context).line),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: jdc.cta,
                  foregroundColor: jdc.onCta,
                  disabledBackgroundColor: jdc.cta,
                  disabledForegroundColor: jdc.onCta,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: jdc.onCta, strokeWidth: 2))
                    : Text(AppLocalizations.of(context)!.referralUseCode),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadReferralSummary() async {
    final summary = await _referralService.getSummary();
    if (mounted) setState(() => _referralSummary = summary);
  }

  /// ขั้นบันไดรางวัล: ขั้นปัจจุบัน ตัวคูณ และอีกกี่รายถึงขั้นถัดไป
  Widget _buildTierSection() {
    final s = _referralSummary;
    if (s == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final tier = s['current_tier'];
    final multiplier = (s['current_multiplier'] as num?)?.toDouble() ?? 1;
    final toNext = s['referrals_to_next_tier'];
    // ฐานรางวัลตามบทบาทผู้ชวน: คนขับ = S1, ลูกค้า = S2
    final baseKey = AuthService.currentUserRole == 'driver'
        ? 'driver_invite_merchant'
        : 'customer_invite_merchant';
    final base = (s['base'] is Map)
        ? ((s['base'][baseKey] as num?)?.toDouble() ?? 20)
        : 20.0;
    final earned = (s['total_earned'] as num?)?.toDouble() ?? 0;
    final pending = (s['pending_review'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stairs, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                    AppLocalizations.of(context)!
                        .referralTierCurrent('${tier ?? 1}'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context)!.referralTierReward(
                (base * multiplier).toStringAsFixed(0),
                base.toStringAsFixed(0),
                multiplier.toStringAsFixed(2))),
            if (toNext != null)
              Text(
                  AppLocalizations.of(context)!
                      .referralTierToNext('$toNext'),
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            Text(
                '${AppLocalizations.of(context)!.referralTierEarned(earned.toStringAsFixed(0))}'
                '${pending > 0 ? ' · ${AppLocalizations.of(context)!.referralTierPending('$pending')}' : ''}',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            Text(
                AppLocalizations.of(context)!.referralTierWithdrawNote(
                    ((s['withdrawal_min'] is Map ? (s['withdrawal_min']['system'] as num?)?.toDouble() : null) ?? 200)
                        .toStringAsFixed(0)),
                style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(Icons.people, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              '$totalReferrals',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              AppLocalizations.of(context)!.referralSuccessful,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.referralHowTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStepItem('1', AppLocalizations.of(context)!.referralStep1Title,
              AppLocalizations.of(context)!.referralStep1Desc),
          _buildStepItem('2', AppLocalizations.of(context)!.referralStep2Title,
              AppLocalizations.of(context)!.referralStep2Desc),
          _buildStepItem('3', AppLocalizations.of(context)!.referralStep3Title,
              AppLocalizations.of(context)!.referralStep3Desc),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: JdcColors.of(context).cta,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                    color: JdcColors.of(context).onCta,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: JdcColors.of(context).muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
