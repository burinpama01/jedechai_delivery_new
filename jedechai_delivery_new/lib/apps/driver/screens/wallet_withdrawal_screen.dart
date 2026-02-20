import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/withdrawal_service.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/debug_logger.dart';

/// Wallet Withdrawal Screen
///
/// หน้าแจ้งถอนเงินจากกระเป๋า:
/// - กรอกจำนวนเงิน
/// - กรอกข้อมูลบัญชีธนาคาร
/// - ดูประวัติคำขอถอนเงิน
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
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // รายชื่อธนาคาร
  final List<String> _bankList = [
    'ธนาคารกสิกรไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
    'ธนาคารกรุงศรีอยุธยา',
    'ธนาคารทหารไทยธนชาต',
    'ธนาคารออมสิน',
    'ธนาคารเกียรตินาคินภัทร',
    'ธนาคารซีไอเอ็มบีไทย',
    'ธนาคารทิสโก้',
    'ธนาคารยูโอบี',
    'ธนาคารแลนด์ แอนด์ เฮ้าส์',
  ];

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final balance = await _walletService.getBalance(userId);
      final history = await _withdrawalService.getMyWithdrawalRequests();
      final bankInfo = await _withdrawalService.getBankInfo();

      if (mounted) {
        setState(() {
          _currentBalance = balance;
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
      _showErrorDialog('กรุณาระบุจำนวนเงินที่ต้องการถอน');
      return;
    }
    if (amount > _currentBalance) {
      _showErrorDialog('ยอดเงินไม่เพียงพอ\nคงเหลือ: ฿${_currentBalance.toStringAsFixed(2)}');
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
      );

      if (success) {
        if (mounted) {
          _showSuccessDialog(amount);
          _amountController.clear();
          _loadData();
        }
      } else {
        if (mounted) {
          _showErrorDialog('ไม่สามารถแจ้งถอนเงินได้\nกรุณาลองใหม่อีกครั้ง');
        }
      }
    } catch (e) {
      debugLog('❌ Error submitting withdrawal: $e');
      if (mounted) {
        _showErrorDialog('เกิดข้อผิดพลาด\nกรุณาลองใหม่อีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text('เกิดข้อผิดพลาด',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: AppTheme.accentBlue, size: 48),
        title: const Text('แจ้งถอนเงินสำเร็จ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'ระบบได้รับคำขอถอนเงิน ฿${amount.toStringAsFixed(0)} แล้ว\n\nAdmin จะตรวจสอบและโอนเงินภายใน 1-3 วันทำการ',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ถอนเงิน'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 20),
                    _buildAmountSection(),
                    const SizedBox(height: 20),
                    _buildBankInfoSection(),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                    const SizedBox(height: 24),
                    _buildHistorySection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[600]!, Colors.orange[800]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ยอดเงินคงเหลือ',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            '฿${NumberFormat('#,##0.00').format(_currentBalance)}',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('จำนวนเงินที่ต้องการถอน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'จำนวนเงิน (บาท)',
                prefixText: '฿ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
                helperText: 'ขั้นต่ำ ฿100',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'กรุณาระบุจำนวนเงิน';
                final amount = double.tryParse(v);
                if (amount == null || amount < 100) return 'ขั้นต่ำ ฿100';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลบัญชีธนาคาร',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // ธนาคาร dropdown
            DropdownButtonFormField<String>(
              initialValue: _bankNameController.text.isNotEmpty &&
                      _bankList.contains(_bankNameController.text)
                  ? _bankNameController.text
                  : null,
              decoration: InputDecoration(
                labelText: 'ธนาคาร',
                prefixIcon: const Icon(Icons.account_balance),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: _bankList
                  .map((bank) => DropdownMenuItem(value: bank, child: Text(bank, style: const TextStyle(fontSize: 14))))
                  .toList(),
              onChanged: (v) {
                if (v != null) _bankNameController.text = v;
              },
              validator: (v) => v == null ? 'กรุณาเลือกธนาคาร' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'เลขบัญชี',
                prefixIcon: const Icon(Icons.credit_card),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) => v == null || v.isEmpty ? 'กรุณาระบุเลขบัญชี' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อบัญชี',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) => v == null || v.isEmpty ? 'กรุณาระบุชื่อบัญชี' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitWithdrawal,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(
          _isSubmitting ? 'กำลังดำเนินการ...' : 'แจ้งถอนเงิน',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ประวัติคำขอถอนเงิน',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._history.map((req) => _buildHistoryCard(req)),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> req) {
    final amount = (req['amount'] as num).toDouble();
    final status = req['status'] ?? 'pending';
    final createdAt = req['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(req['created_at']).toLocal())
        : '-';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'โอนแล้ว';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'ปฏิเสธ';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'ยกเลิก';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'รอดำเนินการ';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.account_balance_wallet, color: statusColor, size: 22),
        ),
        title: Text('฿${NumberFormat('#,##0.00').format(amount)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}
