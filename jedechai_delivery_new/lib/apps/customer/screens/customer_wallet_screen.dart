import 'package:flutter/material.dart';

import '../../../theme/jdc_colors.dart';
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
    switch (type) {
      case 'topup':
        return 'เติมเงิน';
      case 'payment':
        return 'ชำระค่าออเดอร์';
      case 'refund':
        return 'คืนเงิน';
      case 'withdrawal_pending':
        return 'ถอนเงิน';
      case 'adjustment':
        return 'ปรับยอด';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet ลูกค้า'),
        backgroundColor: JdcColors.of(context).infoInk,
        foregroundColor: JdcColors.of(context).onPanel,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWallet,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 16),
                  _buildActions(),
                  const SizedBox(height: 16),
                  _buildWithdrawalSummary(),
                  const SizedBox(height: 16),
                  _buildTransactionHistory(),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [JdcColors.of(context).infoInk, JdcColors.of(context).panel],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ยอดเงินใน Wallet',
            style: TextStyle(color: JdcColors.of(context).panelDim, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            _money(_balance),
            style: TextStyle(
              color: JdcColors.of(context).onPanel,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ถอนเงินขั้นต่ำ ${_money(_minimumWithdrawalAmount)}',
            style: TextStyle(color: JdcColors.of(context).panelDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _openTopUp,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('เติมเงิน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: JdcColors.of(context).cta,
              foregroundColor: JdcColors.of(context).onPanel,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openWithdrawal,
            icon: const Icon(Icons.account_balance),
            label: const Text('ถอนเงิน'),
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalSummary() {
    final pending = _withdrawals
        .where((item) => item['status']?.toString() == 'pending')
        .length;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.hourglass_empty),
        title: const Text('คำขอถอนเงิน'),
        subtitle: Text(pending == 0 ? 'ไม่มีรายการรอดำเนินการ' : 'รอดำเนินการ $pending รายการ'),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_transactions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('ยังไม่มีประวัติธุรกรรม')),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'ประวัติธุรกรรม',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ..._transactions.take(20).map((item) {
            final amount = (item['amount'] as num?)?.toDouble() ?? 0;
            final type = item['type']?.toString() ?? '-';
            final description = item['description']?.toString();
            return ListTile(
              leading: Icon(
                amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                color: amount >= 0 ? JdcColors.of(context).cta : JdcColors.of(context).danger,
              ),
              title: Text(_transactionTitle(type)),
              subtitle: Text(description?.isNotEmpty == true ? description! : type),
              trailing: Text(
                _money(amount),
                style: TextStyle(
                  color: amount >= 0 ? JdcColors.of(context).cta : JdcColors.of(context).danger,
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
