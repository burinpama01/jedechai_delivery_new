import 'package:flutter/material.dart';

import '../../../theme/jdc_colors.dart';
import '../../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../common/services/auth_service.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/withdrawal_service.dart';
import '../../driver/screens/wallet_topup_screen.dart';
import '../../driver/screens/wallet_withdrawal_screen.dart';

class CustomerWalletScreen extends StatefulWidget {
  const CustomerWalletScreen({super.key});

  @override
  State<CustomerWalletScreen> createState() => _CustomerWalletScreenState();
}

class _CustomerWalletScreenState extends State<CustomerWalletScreen> {
  static const double _minimumWithdrawalAmount = 100;

  final WalletService _walletService = WalletService();
  final WithdrawalService _withdrawalService = WithdrawalService();

  bool _isLoading = true;
  bool _hasLoadedBalance = false;
  double _balance = 0;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final userId = AuthService.userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final results = await Future.wait([
      _walletService.getBalance(userId),
      _walletService.getTransactions(userId),
      _withdrawalService.getMyWithdrawalRequests(),
    ]);

    if (!mounted) return;
    setState(() {
      _balance = results[0] as double;
      _hasLoadedBalance = true;
      _transactions = (results[1] as List).cast<Map<String, dynamic>>();
      _withdrawals = (results[2] as List).cast<Map<String, dynamic>>();
      _isLoading = false;
    });
  }

  Future<void> _openTopUp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WalletTopUpScreen()),
    );
    if (mounted) await _loadWallet();
  }

  Future<void> _openWithdrawal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WalletWithdrawalScreen()),
    );
    if (mounted) await _loadWallet();
  }

  String _money(num amount) => '฿${NumberFormat('#,##0').format(amount)}';

  String _transactionTitle(String type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case 'topup':
        return l10n.walletTypeTopup;
      case 'payment':
        return l10n.customerWalletPayment;
      case 'refund':
        return l10n.customerWalletRefund;
      case 'withdrawal_pending':
        return l10n.topupWithdrawTitle;
      case 'adjustment':
        return l10n.customerWalletAdjustment;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          _buildBalanceCard(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadWallet,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        _buildMinimumNotice(),
                        const SizedBox(height: 14),
                        _buildWithdrawalSummary(),
                        const SizedBox(height: 20),
                        _buildTransactionHistory(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: jdc.hero,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: jdc.onPanel,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                  ),
                  Expanded(
                    child: Text(l10n.customerWalletTitle,
                        style: TextStyle(
                            color: jdc.onPanel,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l10n.customerWalletBalance,
                  style: TextStyle(color: jdc.panelDim, fontSize: 12)),
              const SizedBox(height: 5),
              if (_isLoading)
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(color: jdc.onPanel),
                  ),
                )
              else
                Text(
                  _hasLoadedBalance ? _money(_balance) : '—',
                  style: TextStyle(
                    color: jdc.onPanel,
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                  ),
              ),
              const SizedBox(height: 20),
              if (!_isLoading) _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimumNotice() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: jdc.brandSoft,
        border: Border.all(color: jdc.brandLine),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: jdc.brandOnSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.customerWalletMinimumWithdrawal(
                  _money(_minimumWithdrawalAmount)),
              style: TextStyle(
                  color: jdc.brandOnSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openTopUp,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.walletTopUp),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: jdc.brand,
              foregroundColor: jdc.panel,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openWithdrawal,
            icon: const Icon(Icons.account_balance),
            label: Text(l10n.topupWithdrawTitle),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: jdc.onPanel,
              side: BorderSide(color: jdc.panelLine),
              backgroundColor: jdc.panelSoft2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalSummary() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pending = _withdrawals
        .where((item) => item['status']?.toString() == 'pending')
        .length;
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border.all(color: jdc.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(Icons.schedule_rounded, color: jdc.infoInk),
        title: Text(l10n.customerWalletPending),
        subtitle: Text(pending == 0
            ? l10n.customerWalletNoPending
            : l10n.customerWalletPendingCount(pending)),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text(l10n.customerWalletNoHistory)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border.all(color: jdc.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.customerWalletHistory,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ..._transactions.take(20).map((item) {
            final amount = (item['amount'] as num?)?.toDouble() ?? 0;
            final type = item['type']?.toString() ?? '-';
            final description = item['description']?.toString();
            return ListTile(
              leading: Icon(
                amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                color: amount >= 0
                    ? JdcColors.of(context).cta
                    : JdcColors.of(context).danger,
              ),
              title: Text(_transactionTitle(type)),
              subtitle:
                  Text(description?.isNotEmpty == true ? description! : type),
              trailing: Text(
                _money(amount),
                style: TextStyle(
                  color: amount >= 0
                      ? JdcColors.of(context).cta
                      : JdcColors.of(context).danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
