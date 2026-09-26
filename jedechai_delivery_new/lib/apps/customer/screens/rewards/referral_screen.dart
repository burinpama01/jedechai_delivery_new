import 'package:flutter/material.dart';

import '../../../../theme/jdc_colors.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/services/referral_service.dart';
import '../../../../common/services/referral_invite_link.dart';
import '../../../../common/services/notification_service.dart';
import '../../../../common/services/auth_service.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({
    super.key,
    this.forDriver = false,
    this.referralCodeFixture,
    this.referralSummaryFixture,
  });

  final bool forDriver;

  /// ใช้เฉพาะ dev preview/widget test; production โหลดโค้ดจาก ReferralService
  final String? referralCodeFixture;
  final Map<String, dynamic>? referralSummaryFixture;

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

  bool get _hasShareableCode {
    final code = myReferralCode.trim();
    return ReferralInviteLink.isValidCode(code);
  }

  String _rewardAmount(double base, double multiplier) {
    final amount = double.parse((base * multiplier).toStringAsFixed(2));
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    if (widget.referralCodeFixture != null) {
      myReferralCode = widget.referralCodeFixture!;
      _referralSummary = widget.referralSummaryFixture;
      totalReferrals =
          (widget.referralSummaryFixture?['successful_referrals'] as num?)
                  ?.toInt() ??
              0;
    } else {
      _loadReferralData();
      _loadReferralSummary();
    }
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
    if (!_hasShareableCode) return;
    Clipboard.setData(ClipboardData(text: myReferralCode.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.referralCopied)),
    );
  }

  void _shareReferralCode() {
    if (!_hasShareableCode) return;
    final l10n = AppLocalizations.of(context)!;
    final message = widget.forDriver
        ? l10n.driverReferralShareMessage(myReferralCode.trim())
        : '${l10n.referralShareMessage} ${myReferralCode.trim()}';
    Share.share('$message\n${ReferralInviteLink.build(myReferralCode)}');
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
      if (mounted) setState(() => _isLoading = false);
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
            if (widget.forDriver) _buildDriverInviteSection(),
            if (!widget.forDriver) _buildCustomerInviteSection(),
            _buildTierSection(),
            _buildStatsSection(),
            if (!widget.forDriver) _buildEnterCodeSection(),
            if (!widget.forDriver) _buildHowItWorks(),
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
            widget.forDriver
                ? AppLocalizations.of(context)!.driverReferralHeroTitle
                : AppLocalizations.of(context)!.referralHeroTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: jdc.onPanel,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.forDriver
                ? AppLocalizations.of(context)!.driverReferralHeroSubtitle
                : AppLocalizations.of(context)!.referralHeroSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: jdc.panelDim,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            earned == null
                ? '—'
                : NumberFormat.currency(
                        locale: 'th_TH', symbol: '฿', decimalDigits: 2)
                    .format(earned),
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: jdc.onPanel),
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
                Expanded(
                    child: Text(
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
                  onPressed: _hasShareableCode ? _copyToClipboard : null,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_hasShareableCode) ...[
            Center(
              child: Container(
                key: const Key('referral-qr'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: jdc.line),
                ),
                child: QrImageView(
                  data: ReferralInviteLink.build(myReferralCode).toString(),
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  semanticsLabel: myReferralCode.trim(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                AppLocalizations.of(context)!.referralQrHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: jdc.muted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _hasShareableCode ? _shareReferralCode : null,
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

  Widget _buildDriverInviteSection() {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final summary = _referralSummary;
    final base = summary?['base'];
    final multiplier = (summary?['current_multiplier'] as num?)?.toDouble();
    final merchantBase = base is Map
        ? (base['driver_invite_merchant'] as num?)?.toDouble()
        : null;
    final customerBase = base is Map
        ? (base['driver_invite_customer'] as num?)?.toDouble()
        : null;
    final driverBase = base is Map
        ? (base['driver_invite_driver_referrer'] as num?)?.toDouble()
        : null;
    final newDriverBase = base is Map
        ? (base['driver_invite_driver_newdriver'] as num?)?.toDouble()
        : null;
    final configuredTiers = summary?['tiers'];

    Widget inviteCard(String title, String condition, List<String> rewards) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: jdc.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: jdc.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(condition, style: TextStyle(color: jdc.muted, fontSize: 14)),
            for (final reward in rewards) ...[
              const SizedBox(height: 8),
              Text(reward,
                  style: TextStyle(
                      color: jdc.brandOnSoft, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.driverReferralRulesTitle,
              style: TextStyle(
                  color: jdc.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(l10n.driverReferralCodeHint,
              style: TextStyle(color: jdc.muted, fontSize: 14)),
          const SizedBox(height: 12),
          inviteCard(
            l10n.driverReferralMerchantTitle,
            l10n.driverReferralMerchantCondition,
            [
              if (merchantBase != null && multiplier != null)
                l10n.driverReferralYouEarn(
                    _rewardAmount(merchantBase, multiplier)),
            ],
          ),
          const SizedBox(height: 10),
          inviteCard(
            l10n.driverReferralCustomerTitle,
            l10n.referralCustomerFirstJobCondition,
            [
              if (customerBase != null && multiplier != null)
                l10n.driverReferralYouEarn(
                    _rewardAmount(customerBase, multiplier)),
            ],
          ),
          const SizedBox(height: 10),
          inviteCard(
            l10n.driverReferralDriverTitle,
            l10n.driverReferralDriverCondition,
            [
              if (driverBase != null && multiplier != null)
                l10n.driverReferralYouEarn(
                    _rewardAmount(driverBase, multiplier)),
              if (newDriverBase != null)
                l10n.driverReferralNewDriverEarn(
                    newDriverBase.toStringAsFixed(0)),
            ],
          ),
          if (configuredTiers is List && configuredTiers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.driverReferralTierTableTitle,
                style: TextStyle(
                    color: jdc.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final tier in configuredTiers)
              if (tier is Map &&
                  tier['from'] is num &&
                  tier['multiplier'] is num)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    tier['to'] is num
                        ? l10n.driverReferralTierRow(
                            '${tier['from']}',
                            '${tier['to']}',
                            (tier['multiplier'] as num).toStringAsFixed(2),
                          )
                        : l10n.driverReferralTierOpenRow(
                            '${tier['from']}',
                            (tier['multiplier'] as num).toStringAsFixed(2),
                          ),
                    style: TextStyle(color: jdc.muted, fontSize: 13),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerInviteSection() {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    final summary = _referralSummary;
    final base = summary?['base'];
    final merchantBase = base is Map
        ? (base['customer_invite_merchant'] as num?)?.toDouble()
        : null;
    final customerBase = base is Map
        ? (base['customer_invite_customer'] as num?)?.toDouble()
        : null;
    final driverBase = base is Map
        ? (base['customer_invite_driver'] as num?)?.toDouble()
        : null;
    final multiplier = (summary?['current_multiplier'] as num?)?.toDouble();

    Widget inviteCard(String title, String condition, double? reward) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: jdc.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: jdc.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(condition, style: TextStyle(color: jdc.muted, fontSize: 14)),
            if (reward != null && multiplier != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.driverReferralYouEarn(_rewardAmount(reward, multiplier)),
                style: TextStyle(
                    color: jdc.brandOnSoft, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inviteCard(l10n.customerReferralCustomerTitle,
              l10n.referralCustomerFirstJobCondition, customerBase),
          const SizedBox(height: 10),
          inviteCard(l10n.customerReferralDriverTitle,
              l10n.customerReferralDriverCondition, driverBase),
          const SizedBox(height: 10),
          inviteCard(l10n.customerReferralMerchantTitle,
              l10n.driverReferralMerchantCondition, merchantBase),
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
    if (s['current_tier'] == null || s['current_multiplier'] == null) {
      return const SizedBox.shrink();
    }
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
          border:
              Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stairs, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      AppLocalizations.of(context)!
                          .referralTierCurrent('${tier ?? 1}'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context)!
                .referralTierMultiplier(multiplier.toStringAsFixed(2))),
            if (toNext != null)
              Text(AppLocalizations.of(context)!.referralTierToNext('$toNext'),
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
            if (!widget.forDriver ||
                (s['withdrawal_min'] is Map &&
                    s['withdrawal_min']['system'] is num))
              Text(
                  AppLocalizations.of(context)!.referralTierWithdrawNote(
                      ((s['withdrawal_min'] is Map
                                  ? (s['withdrawal_min']['system'] as num?)
                                      ?.toDouble()
                                  : null) ??
                              200)
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
          border:
              Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
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
                  style: TextStyle(
                      color: JdcColors.of(context).muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
