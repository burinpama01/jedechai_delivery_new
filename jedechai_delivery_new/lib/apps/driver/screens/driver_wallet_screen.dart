import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import 'wallet_topup_screen.dart';

/// Driver Wallet Screen
/// 
/// แสดงยอดเงินคงเหลือและประวัติการทำรายการของคนขับ
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  final WalletService _walletService = WalletService();
  late Future<double> _balanceFuture;
  late Future<List<Map<String, dynamic>>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final driverId = AuthService.userId!;
    _balanceFuture = _walletService.getBalance(driverId);
    _transactionsFuture = _walletService.getTransactions(driverId);
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('กระเป๋าเงิน'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Balance Card
              _buildBalanceCard(),
              const SizedBox(height: 16),
              
              // Transactions List
              _buildTransactionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// สร้างการ์ดแสดงยอดเงินคงเหลือ
  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'ยอดเงินคงเหลือ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Balance Amount
          FutureBuilder<double>(
            future: _balanceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                );
              }
              
              if (snapshot.hasError) {
                return Text(
                  '0.00 บาท',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              
              final balance = snapshot.data ?? 0.0;
              return Text(
                '${balance.toStringAsFixed(2)} บาท',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Top Up Button
          ElevatedButton.icon(
            onPressed: () {
              _showTopUpDialog();
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('เติมเงิน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[600],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// สร้างส่วนแสดงประวัติการทำรายการ
  Widget _buildTransactionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Icon(
                Icons.history,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ประวัติการทำรายการ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Transactions List
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _transactionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'เกิดข้อผิดพลาดในการโหลดข้อมูล',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _refreshData,
                          child: const Text('ลองใหม่'),
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
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ยังไม่มีประวัติการทำรายการ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey,
                ),
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionTile(transaction);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  /// สร้าง ListTile สำหรับแต่ละรายการ
  Widget _buildTransactionTile(Map<String, dynamic> transaction) {
    final amount = (transaction['amount'] as num).toDouble();
    final type = transaction['type'] as String? ?? 'unknown';
    final description = transaction['description'] as String? ?? '';
    final createdAt = DateTime.parse(transaction['created_at'] as String).toLocal();
    
    // กำหนดสีและไอคอนตามประเภท
    final isIncome = amount >= 0;
    final iconColor = isIncome ? Colors.green : Colors.red;
    final amountColor = isIncome ? Colors.green : Colors.red;
    
    IconData iconData;
    String displayType;
    
    switch (type) {
      case 'topup':
        iconData = Icons.add_circle;
        displayType = 'เติมเงิน';
        break;
      case 'commission':
        iconData = Icons.remove_circle;
        displayType = 'ค่าบริการระบบ';
        break;
      case 'job_income':
        iconData = Icons.attach_money;
        displayType = 'รายได้จากงาน';
        break;
      case 'penalty':
        iconData = Icons.gavel;
        displayType = 'ค่าปรับ';
        break;
      default:
        iconData = Icons.receipt;
        displayType = type;
    }
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.1),
        child: Icon(
          iconData,
          color: iconColor,
          size: 20,
        ),
      ),
      title: Text(
        description.isNotEmpty ? description : displayType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _formatDateTime(createdAt),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: Text(
        '${isIncome ? '+' : ''}${amount.toStringAsFixed(2)} บาท',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: amountColor,
        ),
      ),
    );
  }

  /// จัดรูปแบบวันที่และเวลา
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // วันนี้ - แสดงเวลา
      return 'วันนี้ ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      // เมื่อวาน
      return 'เมื่อวาน ${DateFormat('HH:mm').format(dateTime)}';
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
}
