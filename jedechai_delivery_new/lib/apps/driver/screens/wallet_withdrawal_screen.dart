import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/withdrawal_service.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import '../../../utils/debug_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/services/referral_service.dart';

/// Wallet Withdrawal Screen
///
/// หน้าแจ้งถอนเงินจากกระเป๋า:
/// - กรอกจำนวนเงิน
/// - กรอกข้อมูลบัญชีธนาคาร
/// - ดูประวัติคำขอถอนเงิน
/// ดีไซน์ตาม artboard: Design/jdc-canvas/project/Driver-WalletWithdraw.dc.html
class WalletWithdrawalScreen extends StatefulWidget {
  const WalletWithdrawalScreen({super.key});

  @override
  State<WalletWithdrawalScreen> createState() => _WalletWithdrawalScreenState();
}

class _WalletWithdrawalScreenState extends State<WalletWithdrawalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  final WithdrawalService _withdrawalService = WithdrawalService();
  final WalletService _walletService = WalletService();

  double _currentBalance = 0;
  // ถังเงิน (Batch 3): 'topup' = เติมเอง (ขั้นต่ำ ฿100) · 'system' = จากระบบ (ขั้นต่ำ ฿200)
  String _bucket = 'topup';
  double _availableTopup = 0;
  double _availableSystem = 0;
  double _minTopup = 100;
  double _minSystem = 200;

  double get _bucketAvailable => _bucket == 'system' ? _availableSystem : _availableTopup;
  double get _bucketMinimum => _bucket == 'system' ? _minSystem : _minTopup;
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // รายชื่อธนาคาร
  List<String> _getBankList(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.withdrawBankKasikorn,
      l10n.withdrawBankSCB,
      l10n.withdrawBankBangkok,
      l10n.withdrawBankKrungthai,
      l10n.withdrawBankKrungsri,
      l10n.withdrawBankTTB,
      l10n.withdrawBankGSB,
      l10n.withdrawBankKKP,
      l10n.withdrawBankCIMB,
      l10n.withdrawBankTisco,
      l10n.withdrawBankUOB,
      l10n.withdrawBankLH,
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  /// fontVariations คู่กับ fontWeight ตามกฎธีม (NotoSansThai เป็น variable font)
  static List<FontVariation> _w(FontWeight weight) => [
        FontVariation(
          'wght',
          weight == FontWeight.w700
              ? 700
              : weight == FontWeight.w600
                  ? 600
                  : weight == FontWeight.w500
                      ? 500
                      : 400,
        ),
      ];

  /// ตัวเลขเงินสไตล์ display ตาม artboard (`.dsp` = IBM Plex Sans Thai)
  TextStyle _money(JdcColors jdc, {double size = 14, Color? color}) {
    return TextStyle(
      fontFamily: 'IBMPlexSansThai',
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontVariations: _w(FontWeight.w700),
      color: color ?? jdc.text,
    );
  }

  /// กรอบ input มาตรฐาน JDC (radius 14 / พื้น sunken / เส้น line)
  OutlineInputBorder _fieldBorder(JdcColors jdc) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(JdcRadius.field),
      borderSide: BorderSide(color: jdc.line),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        // ไม่มี session — เลิก spinner แทนการค้างโหลดตลอดไป
        setState(() => _isLoading = false);
        return;
      }

      final balance = await _walletService.getBalance(userId);
      final wallet = await _walletService.getDriverWallet(userId);
      final summary = await ReferralService().getSummary();
      final history = await _withdrawalService.getMyWithdrawalRequests();
      final bankInfo = await _withdrawalService.getBankInfo();
      final mins = summary?['withdrawal_min'];

      if (mounted) {
        setState(() {
          _currentBalance = balance;
          _availableTopup = wallet?.availableTopup ?? balance;
          _availableSystem = wallet?.availableSystem ?? 0;
          if (mins is Map) {
            _minTopup = (mins['topup'] as num?)?.toDouble() ?? 100;
            _minSystem = (mins['system'] as num?)?.toDouble() ?? 200;
          }
          _history = history;
          _isLoading = false;

          // Pre-fill bank info
          if (bankInfo['bank_name'] != null) {
            _bankNameController.text = bankInfo['bank_name']!;
          }
          if (bankInfo['bank_account_number'] != null) {
            _accountNumberController.text = bankInfo['bank_account_number']!;
          }
          if (bankInfo['bank_account_name'] != null) {
            _accountNameController.text = bankInfo['bank_account_name']!;
          }
        });
      }
    } catch (e) {
      debugLog('❌ Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      _showErrorDialog(AppLocalizations.of(context)!.withdrawAmountRequired);
      return;
    }
    if (amount < _bucketMinimum) {
      final l10n = AppLocalizations.of(context)!;
      _showErrorDialog(l10n.withdrawMinBucketError(
        _bucketMinimum.toStringAsFixed(0),
        _bucket == 'system' ? l10n.withdrawBucketSystem : l10n.withdrawBucketTopup,
      ));
      return;
    }
    if (amount > _bucketAvailable) {
      _showErrorDialog(AppLocalizations.of(context)!
          .withdrawInsufficientBalance(_bucketAvailable.toStringAsFixed(2)));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // บันทึกข้อมูลบัญชีธนาคาร
      await _withdrawalService.saveBankInfo(
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _accountNumberController.text.trim(),
        bankAccountName: _accountNameController.text.trim(),
      );

      // สร้างคำขอถอนเงิน
      final success = await _withdrawalService.createWithdrawalRequest(
        amount: amount,
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _accountNumberController.text.trim(),
        bankAccountName: _accountNameController.text.trim(),
        bucket: _bucket,
      );

      if (success) {
        if (mounted) {
          _showSuccessDialog(amount);
          _amountController.clear();
          _loadData();
        }
      } else {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.withdrawFailed);
        }
      }
    } catch (e) {
      debugLog('❌ Error submitting withdrawal: $e');
      if (mounted) {
        _showErrorDialog(AppLocalizations.of(context)!.withdrawGenericError);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    final jdc = context.jdc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.card),
          side: BorderSide(color: jdc.line),
        ),
        icon: Icon(Icons.error_outline, color: jdc.danger, size: 48),
        title: Text(AppLocalizations.of(context)!.withdrawErrorTitle,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontVariations: _w(FontWeight.w700),
                fontSize: 18,
                color: jdc.text)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: jdc.text)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.small)),
              ),
              child: Text(AppLocalizations.of(context)!.withdrawOk),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(double amount) {
    final jdc = context.jdc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.card),
          side: BorderSide(color: jdc.line),
        ),
        icon: Icon(Icons.check_circle, color: jdc.successInk, size: 48),
        title: Text(AppLocalizations.of(context)!.withdrawSuccessTitle,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontVariations: _w(FontWeight.w700),
                fontSize: 18,
                color: jdc.text)),
        content: Text(
          AppLocalizations.of(context)!.withdrawSuccessBody(amount.toStringAsFixed(0)),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: jdc.text),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.small)),
              ),
              child: Text(AppLocalizations.of(context)!.withdrawOk),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = context.jdc;
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        iconTheme: IconThemeData(color: jdc.text),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: jdc.line)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.withdrawTitle,
              style: TextStyle(
                fontFamily: 'IBMPlexSansThai',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontVariations: _w(FontWeight.w700),
                color: jdc.text,
              ),
            ),
            Text(
              AppLocalizations.of(context)!
                  .withdrawAvailable(_bucketAvailable.toStringAsFixed(2)),
              style: TextStyle(fontSize: 12, color: jdc.muted),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(JdcSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(jdc),
                    const SizedBox(height: JdcSpacing.xl),
                    _buildAmountSection(jdc),
                    const SizedBox(height: JdcSpacing.xl),
                    _buildBankInfoSection(jdc),
                    const SizedBox(height: JdcSpacing.xl),
                    _buildSubmitButton(jdc),
                    const SizedBox(height: JdcSpacing.xxl),
                    _buildHistorySection(jdc),
                    const SizedBox(height: JdcSpacing.xxxl),
                  ],
                ),
              ),
            ),
    );
  }

  /// การ์ดยอดถอนได้บนพื้น hero2 (สื่อสาร "เงินในระบบ" ตามภาษาดีไซน์ JDC)
  Widget _buildBalanceCard(JdcColors jdc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.xl),
      decoration: BoxDecoration(
        gradient: jdc.hero2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.withdrawBalance,
              style: TextStyle(
                  fontSize: 14,
                  color: jdc.panelDim,
                  fontWeight: FontWeight.w500,
                  fontVariations: _w(FontWeight.w500))),
          const SizedBox(height: JdcSpacing.xs),
          Text(
            AppLocalizations.of(context)!.driverEarningsBaht(
                NumberFormat('#,##0.00').format(_currentBalance)),
            style: _money(jdc, size: 30, color: jdc.onPanel),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(JdcColors jdc) {
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.withdrawAmountSectionTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  color: jdc.text)),
          const SizedBox(height: JdcSpacing.md),
          _buildBucketSelector(jdc),
          const SizedBox(height: JdcSpacing.md),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: _money(jdc, size: 18),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.withdrawAmountLabel,
              labelStyle: TextStyle(color: jdc.muted),
              prefixText: AppLocalizations.of(context)!.withdrawBahtPrefix,
              prefixStyle: _money(jdc, size: 16),
              border: _fieldBorder(jdc),
              enabledBorder: _fieldBorder(jdc),
              focusedBorder: _fieldBorder(jdc),
              filled: true,
              fillColor: jdc.sunken,
              helperText: AppLocalizations.of(context)!.withdrawMinMaxHelper(
                _bucketMinimum.toStringAsFixed(0),
                _bucketAvailable.toStringAsFixed(2),
              ),
              helperStyle: TextStyle(color: jdc.muted),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return AppLocalizations.of(context)!.withdrawAmountValidation;
              final amount = double.tryParse(v);
              if (amount == null || amount < _bucketMinimum) {
                return AppLocalizations.of(context)!.withdrawMinAmount(_bucketMinimum.toStringAsFixed(0));
              }
              if (amount > _bucketAvailable) {
                return AppLocalizations.of(context)!.withdrawBucketInsufficient(_bucketAvailable.toStringAsFixed(2));
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBucketSelector(JdcColors jdc) {
    final l10n = AppLocalizations.of(context)!;
    Widget option(String value, String title, double available, double min) {
      final selected = _bucket == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _bucket = value),
          borderRadius: BorderRadius.circular(JdcRadius.field),
          child: Container(
            padding: const EdgeInsets.all(JdcSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(JdcRadius.field),
              color: selected ? jdc.brandSoft : jdc.surface,
              border: Border.all(
                color: selected ? jdc.brandLine : jdc.line,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontVariations: _w(FontWeight.w700),
                        color: selected ? jdc.brandOnSoft : jdc.text)),
                const SizedBox(height: 2),
                Text(l10n.driverEarningsBaht(available.toStringAsFixed(2)),
                    style: _money(jdc,
                        size: 16, color: selected ? jdc.brandOnSoft : jdc.text)),
                Text(l10n.withdrawMinAmount(min.toStringAsFixed(0)),
                    style: TextStyle(fontSize: 11, color: jdc.muted)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('topup', l10n.withdrawBucketTopup, _availableTopup, _minTopup),
        const SizedBox(width: JdcSpacing.md),
        option('system', l10n.withdrawBucketSystem, _availableSystem, _minSystem),
      ],
    );
  }

  Widget _buildBankInfoSection(JdcColors jdc) {
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.withdrawBankInfoTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  color: jdc.text)),
          const SizedBox(height: JdcSpacing.md),
          // ธนาคาร dropdown
          DropdownButtonFormField<String>(
            // isExpanded ให้ตัวเลือกยืนเป็น flex กันชื่อธนาคารยาวล้นช่องในจอแคบ
            isExpanded: true,
            initialValue: _bankNameController.text.isNotEmpty &&
                    _getBankList(context).contains(_bankNameController.text)
                ? _bankNameController.text
                : null,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.withdrawBankLabel,
              labelStyle: TextStyle(color: jdc.muted),
              prefixIcon: Icon(Icons.account_balance, color: jdc.infoInk),
              border: _fieldBorder(jdc),
              enabledBorder: _fieldBorder(jdc),
              filled: true,
              fillColor: jdc.sunken,
            ),
            items: _getBankList(context)
                .map((bank) => DropdownMenuItem(
                    value: bank,
                    child: Text(bank,
                        style: TextStyle(
                            fontSize: 14,
                            color: jdc.text,
                            fontWeight: FontWeight.w500,
                            fontVariations: _w(FontWeight.w500)))))
                .toList(),
            onChanged: (v) {
              if (v != null) _bankNameController.text = v;
            },
            validator: (v) => v == null ? AppLocalizations.of(context)!.withdrawBankValidation : null,
          ),
          const SizedBox(height: JdcSpacing.md),
          TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: jdc.text),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.withdrawAccountNumLabel,
              labelStyle: TextStyle(color: jdc.muted),
              prefixIcon: Icon(Icons.credit_card, color: jdc.infoInk),
              border: _fieldBorder(jdc),
              enabledBorder: _fieldBorder(jdc),
              filled: true,
              fillColor: jdc.sunken,
            ),
            validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context)!.withdrawAccountNumValidation : null,
          ),
          const SizedBox(height: JdcSpacing.md),
          TextFormField(
            controller: _accountNameController,
            style: TextStyle(color: jdc.text),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.withdrawAccountNameLabel,
              labelStyle: TextStyle(color: jdc.muted),
              prefixIcon: Icon(Icons.person, color: jdc.infoInk),
              border: _fieldBorder(jdc),
              enabledBorder: _fieldBorder(jdc),
              filled: true,
              fillColor: jdc.sunken,
            ),
            validator: (v) => v == null || v.isEmpty ? AppLocalizations.of(context)!.withdrawAccountNameValidation : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(JdcColors jdc) {
    return SizedBox(
      width: double.infinity,
      height: JdcTouch.button,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitWithdrawal,
        icon: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: jdc.onCta, strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(
          _isSubmitting ? AppLocalizations.of(context)!.withdrawProcessing : AppLocalizations.of(context)!.withdrawSubmitBtn,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontVariations: _w(FontWeight.w700),
            color: jdc.onCta,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: jdc.cta,
          foregroundColor: jdc.onCta,
          disabledBackgroundColor: jdc.cta.withValues(alpha: 0.6),
          disabledForegroundColor: jdc.onCta,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.card)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildHistorySection(JdcColors jdc) {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.withdrawHistoryTitle,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontVariations: _w(FontWeight.w700),
                color: jdc.text)),
        const SizedBox(height: JdcSpacing.md),
        ..._history.map((req) => _buildHistoryCard(jdc, req)),
      ],
    );
  }

  Widget _buildHistoryCard(JdcColors jdc, Map<String, dynamic> req) {
    final amount = (req['amount'] as num).toDouble();
    final status = req['status'] ?? 'pending';
    final createdAt = req['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(req['created_at']).toLocal())
        : '-';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'completed':
        statusColor = jdc.successInk;
        statusText = AppLocalizations.of(context)!.withdrawStatusCompleted;
        break;
      case 'rejected':
        statusColor = jdc.dangerInk;
        statusText = AppLocalizations.of(context)!.withdrawStatusRejected;
        break;
      case 'cancelled':
        statusColor = jdc.muted;
        statusText = AppLocalizations.of(context)!.withdrawStatusCancelled;
        break;
      default:
        statusColor = jdc.brandOnSoft;
        statusText = AppLocalizations.of(context)!.withdrawStatusPending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md, vertical: JdcSpacing.sm),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(JdcRadius.small),
          ),
          child: Icon(Icons.account_balance_wallet, color: statusColor, size: 22),
        ),
        title: Text(AppLocalizations.of(context)!.driverEarningsBaht(NumberFormat('#,##0.00').format(amount)),
            style: _money(jdc, size: 16)),
        subtitle: Text(createdAt,
            style: TextStyle(fontSize: 12, color: jdc.muted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(JdcRadius.chip),
          ),
          child: Text(statusText,
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  fontSize: 12)),
        ),
      ),
    );
  }
}
