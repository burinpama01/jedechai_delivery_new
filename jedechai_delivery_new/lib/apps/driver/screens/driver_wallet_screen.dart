import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import 'wallet_topup_screen.dart';
import 'wallet_withdrawal_screen.dart';
import '../../../l10n/app_localizations.dart';

/// Driver Wallet Screen
///
/// แสดงยอดเงินคงเหลือและประวัติการทำรายการของคนขับ
/// ดีไซน์ตาม artboard: Design/jdc-canvas/project/Driver-Wallet.dc.html
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final WalletService _walletService = WalletService();
  late Future<double> _balanceFuture;
  late Future<DriverWallet?> _walletFuture;
  late Future<List<Map<String, dynamic>>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final driverId = AuthService.userId;
    if (driverId == null) {
      // ไม่มี session (token หมดอายุ/สภาพแวดล้อม test) — FutureBuilder
      // ทุกตัวมี fallback ของ snapshot.data อยู่แล้ว จึงแสดงค่าว่างแทน crash
      _balanceFuture = Future<double>.error('no-session');
      _walletFuture = Future<DriverWallet?>.error('no-session');
      _transactionsFuture =
          Future<List<Map<String, dynamic>>>.error('no-session');
      return;
    }
    _balanceFuture = _walletService.getBalance(driverId);
    _walletFuture = _walletService.getDriverWallet(driverId);
    _transactionsFuture = _walletService.getTransactions(driverId);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadData();
    });
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

  @override
  Widget build(BuildContext context) {
    final jdc = context.jdc;
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── ส่วนหัว hero2: ปุ่มย้อนกลับ + ชื่อหน้า + การ์ดยอดเงิน ──
          Container(
            decoration: BoxDecoration(gradient: jdc.hero2),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  JdcSpacing.lg, JdcSpacing.sm, JdcSpacing.lg, JdcSpacing.xl,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildBackButton(jdc),
                        const SizedBox(width: JdcSpacing.md),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.walletTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansThai',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontVariations: _w(FontWeight.w700),
                              color: jdc.onPanel,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: JdcSpacing.lg),
                    _buildBalancePanel(jdc),
                  ],
                ),
              ),
            ),
          ),
          // ── เนื้อหา: ประวัติธุรกรรม ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: jdc.cta,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: JdcSpacing.md, bottom: JdcSpacing.xxl,
                ),
                child: JdcContentFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTransactionsSection(jdc),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ปุ่มย้อนกลับบนพื้น hero (44x44 / radius 14 / panelSoft2 + panelLine)
  Widget _buildBackButton(JdcColors jdc) {
    return Material(
      color: jdc.panelSoft2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JdcRadius.field),
        side: BorderSide(color: jdc.panelLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: JdcTouch.minTarget,
          height: JdcTouch.minTarget,
          child: Icon(Icons.chevron_left, size: 24, color: jdc.onPanel),
        ),
      ),
    );
  }

  /// การ์ดยอดเงินบนพื้น hero (panelSoft2 / panelLine / radius 18)
  Widget _buildBalancePanel(JdcColors jdc) {
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.panelSoft2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.panelLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.walletBalance,
            style: TextStyle(
              fontSize: 12,
              color: jdc.panelDim,
              fontWeight: FontWeight.w500,
              fontVariations: _w(FontWeight.w500),
            ),
          ),
          const SizedBox(height: JdcSpacing.xs),
          FutureBuilder<double>(
            future: _balanceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: jdc.onPanel,
                      ),
                    ),
                  ),
                );
              }
              final balance = snapshot.data ?? 0.0;
              return Text(
                // โหลดไม่สำเร็จ (no-session/network) — แสดงขีดแทนเลข 0.00
                // กันคนขับเข้าใจว่ายอดหาย
                snapshot.hasError
                    ? '—'
                    : AppLocalizations.of(context)!
                        .walletBalanceBaht(balance.toStringAsFixed(2)),
                style: _money(jdc, size: 28, color: jdc.onPanel),
              );
            },
          ),
          const SizedBox(height: JdcSpacing.lg),
          // แยกถังเงิน (Batch 3): เติมเอง vs จากระบบ
          _buildBucketRow(jdc),
          const SizedBox(height: JdcSpacing.lg),
          Row(
            children: [
              Expanded(child: _buildPanelAction(
                jdc: jdc,
                label: AppLocalizations.of(context)!.withdrawTitle,
                background: jdc.brand,
                foreground: jdc.panel,
                onTap: _openWithdrawal,
              )),
              const SizedBox(width: JdcSpacing.md),
              Expanded(child: _buildPanelAction(
                jdc: jdc,
                label: AppLocalizations.of(context)!.walletTopUp,
                background: jdc.panelSoft,
                foreground: jdc.onPanel,
                border: jdc.panelLine,
                onTap: _showTopUpDialog,
              )),
            ],
          ),
        ],
      ),
    );
  }

  /// ปุ่ม action ในการ์ดยอดเงิน (สูง 48 / radius 14)
  Widget _buildPanelAction({
    required JdcColors jdc,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
    Color? border,
  }) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JdcRadius.field),
        side: border == null ? BorderSide.none : BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: JdcTouch.field,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontVariations: _w(FontWeight.w700),
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// สร้างแถวถังเงิน (เติมเอง / จากระบบ) บนพื้น hero
  Widget _buildBucketRow(JdcColors jdc) {
    return FutureBuilder<DriverWallet?>(
      future: _walletFuture,
      builder: (context, snapshot) {
        final wallet = snapshot.data;
        if (wallet == null) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        Widget cell(String label, double value, String hint) => Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: jdc.panelDim,
                      fontWeight: FontWeight.w500,
                      fontVariations: _w(FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    l10n.driverEarningsBaht(value.toStringAsFixed(2)),
                    style: _money(jdc, size: 16, color: jdc.onPanel),
                  ),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: jdc.panelDim),
                  ),
                ],
              ),
            );
        return Row(
          children: [
            cell(l10n.driverWalletBucketTopup, wallet.availableTopup,
                l10n.driverWalletBucketTopupHint),
            const SizedBox(width: JdcSpacing.md),
            cell(l10n.driverWalletBucketSystem, wallet.availableSystem,
                l10n.driverWalletBucketSystemHint),
          ],
        );
      },
    );
  }

  /// สร้างส่วนแสดงประวัติการทำรายการ
  Widget _buildTransactionsSection(JdcColors jdc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          AppLocalizations.of(context)!.walletTransactionHistory,
          style: TextStyle(
            fontFamily: 'IBMPlexSansThai',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontVariations: _w(FontWeight.w700),
            color: jdc.text,
          ),
        ),
        const SizedBox(height: JdcSpacing.md),

        // Transactions List
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _transactionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(JdcSpacing.xxxl),
                  child: CircularProgressIndicator(color: jdc.cta),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(JdcSpacing.xxxl),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: jdc.danger),
                      const SizedBox(height: JdcSpacing.sm),
                      Text(
                        AppLocalizations.of(context)!.walletLoadError,
                        style: TextStyle(fontSize: 16, color: jdc.muted),
                      ),
                      const SizedBox(height: JdcSpacing.sm),
                      TextButton(
                        onPressed: _refreshData,
                        child: Text(
                          AppLocalizations.of(context)!.walletRetry,
                          style: TextStyle(color: jdc.link),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final transactions = snapshot.data ?? [];

            if (transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(JdcSpacing.xxxl),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: jdc.muted),
                      const SizedBox(height: JdcSpacing.sm),
                      Text(
                        AppLocalizations.of(context)!.walletNoTransactions,
                        style: TextStyle(fontSize: 16, color: jdc.muted),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: JdcSpacing.lg,
                vertical: JdcSpacing.md,
              ),
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.circular(JdcRadius.card),
                border: Border.all(color: jdc.line),
                boxShadow: jdc.shadowCard,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: JdcSpacing.md),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionTile(jdc, transaction);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// สร้างแถวรายการธุรกรรมแต่ละรายการ (tile 34-36 / radius 12 / sunken)
  Widget _buildTransactionTile(JdcColors jdc, Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num).toDouble();
    final type = transaction['type'] as String? ?? 'unknown';
    final description = transaction['description'] as String? ?? '';
    final createdAt = DateTime.parse(transaction['created_at'] as String).toLocal();

    final isIncome = amount >= 0;
    final iconColor = jdc.muted;
    final amountColor = isIncome ? jdc.successInk : jdc.text;

    IconData iconData;
    String displayType;

    switch (type) {
      case 'topup':
        iconData = Icons.add_circle;
        displayType = AppLocalizations.of(context)!.walletTypeTopup;
        break;
      case 'commission':
        iconData = Icons.remove_circle;
        displayType = AppLocalizations.of(context)!.walletTypeCommission;
        break;
      case 'food_commission':
        iconData = Icons.remove_circle;
        displayType = AppLocalizations.of(context)!.walletTypeFoodCommission;
        break;
      case 'job_income':
        iconData = Icons.attach_money;
        displayType = AppLocalizations.of(context)!.walletTypeJobIncome;
        break;
      case 'penalty':
        iconData = Icons.gavel;
        displayType = AppLocalizations.of(context)!.walletTypePenalty;
        break;
      case 'coupon_compensation':
        iconData = Icons.local_offer;
        displayType = AppLocalizations.of(context)!.driverWalletTypeCouponCompensation;
        break;
      case 'job_payout':
        iconData = Icons.attach_money;
        displayType = AppLocalizations.of(context)!.driverWalletTypeJobPayout;
        break;
      case 'withdrawal_pending':
        iconData = Icons.account_balance;
        displayType = AppLocalizations.of(context)!.driverWalletTypeWithdrawalPending;
        break;
      case 'withdrawal_refund':
      case 'refund':
        iconData = Icons.undo;
        displayType = AppLocalizations.of(context)!.driverWalletTypeRefund;
        break;
      default:
        iconData = Icons.receipt;
        displayType = type;
    }

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: jdc.sunken,
            borderRadius: BorderRadius.circular(JdcRadius.small),
          ),
          child: Icon(iconData, color: iconColor, size: 18),
        ),
        const SizedBox(width: JdcSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description.isNotEmpty ? description : displayType,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  color: jdc.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDateTime(createdAt),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: jdc.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: JdcSpacing.md),
        Text(
          '${isIncome ? '+' : ''}${AppLocalizations.of(context)!.walletBalanceBaht(amount.toStringAsFixed(2))}',
          style: _money(jdc, size: 14, color: amountColor),
        ),
      ],
    );
  }

  /// จัดรูปแบบวันที่และเวลา
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // วันนี้ - แสดงเวลา
      return AppLocalizations.of(context)!.walletToday(DateFormat('HH:mm').format(dateTime));
    } else if (difference.inDays == 1) {
      // เมื่อวาน
      return AppLocalizations.of(context)!.walletYesterday(DateFormat('HH:mm').format(dateTime));
    } else if (difference.inDays < 7) {
      // ภายในสัปดาห์
      return DateFormat('EEEE HH:mm', 'th').format(dateTime);
    } else {
      // เกินสัปดาห์ - แสดงวันที่เต็ม
      return DateFormat('d MMM yyyy HH:mm', 'th').format(dateTime);
    }
  }

  /// เปิดหน้าเติมเงินผ่าน Omise PromptPay
  void _showTopUpDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletTopUpScreen()),
    );
    // รีเฟรชยอดเงินเมื่อกลับมา
    if (result == true) {
      _loadData();
    }
  }

  /// เปิดหน้าแจ้งถอนเงิน แล้วรีเฟรชยอดเมื่อกลับมา
  void _openWithdrawal() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletWithdrawalScreen()),
    );
    if (mounted) {
      _refreshData();
    }
  }
}
