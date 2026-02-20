import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/config/env_config.dart';
import '../../../common/services/omise_service.dart';
import '../../../common/services/promptpay_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/debug_logger.dart';

/// Wallet TopUp Screen — PromptPay QR + Admin Confirmation
///
/// หน้าเติมเงินเข้ากระเป๋า:
/// - เลือกจำนวนเงิน (preset หรือกรอกเอง)
/// - สร้าง PromptPay QR สำหรับโอนเงิน
/// - บันทึกคำขอเติมเงินรอ Admin ยืนยัน
/// - เติมเงินเข้า wallet เมื่อ Admin ยืนยัน
class WalletTopUpScreen extends StatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  State<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends State<WalletTopUpScreen> {
  final _amountController = TextEditingController();
  final WalletService _walletService = WalletService();

  double _currentBalance = 0;
  double _selectedAmount = 0;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isCheckingStatus = false;

  // QR state
  String? _qrImageUrl;
  bool _requestSent = false;

  // Omise state
  bool _useOmise = false;
  String? _omiseChargeId;
  Timer? _omisePollTimer;
  bool _omisePaymentSuccess = false;

  // จำนวนเงินที่เลือกได้
  final List<double> _presetAmounts = [50, 100, 200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _useOmise = EnvConfig.isOmiseConfigured;
    debugLog('💳 Omise configured (env): $_useOmise');
    _fetchTopupMode();
    _loadBalance();
    _loadHistory();
  }

  /// Fetch topup_mode from system_config to allow admin runtime switching.
  /// Values: 'omise' → use Omise, 'admin_approve' → local PromptPay + admin.
  /// Falls back to EnvConfig.isOmiseConfigured if column doesn't exist.
  Future<void> _fetchTopupMode() async {
    try {
      final config = await Supabase.instance.client
          .from('system_config')
          .select('topup_mode')
          .maybeSingle();
      if (config != null && config['topup_mode'] != null) {
        final mode = (config['topup_mode'] as String).trim().toLowerCase();
        if (mode == 'omise') {
          // Only enable Omise if keys are actually configured
          _useOmise = EnvConfig.isOmiseConfigured;
          if (!_useOmise) {
            debugLog('⚠️ topup_mode=omise but Omise keys not configured — falling back to admin_approve');
          }
        } else {
          _useOmise = false;
        }
        debugLog('💳 topup_mode from system_config: $mode → _useOmise=$_useOmise');
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugLog('⚠️ Could not fetch topup_mode: $e (using env default)');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _omisePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      final balance = await _walletService.getBalance(userId);
      if (mounted) {
        setState(() {
          _currentBalance = balance;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading balance: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectAmount(double amount) {
    _omisePollTimer?.cancel();
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
      // reset QR state เมื่อเลือกจำนวนเงินใหม่
      _qrImageUrl = null;
      _requestSent = false;
      _omiseChargeId = null;
      _omisePaymentSuccess = false;
    });
  }

  // ── สร้าง PromptPay QR ──

  static const double _maxTopUpAmount = 50000;
  static const double _minTopUpAmount = 20;

  Future<void> _generateQR() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < _minTopUpAmount) {
      _showErrorDialog('กรุณาระบุจำนวนเงินอย่างน้อย ${_minTopUpAmount.toStringAsFixed(0)} บาท');
      return;
    }
    if (amount > _maxTopUpAmount) {
      _showErrorDialog('จำนวนเงินเกินวงเงินต่อครั้ง (สูงสุด ฿${NumberFormat('#,##0').format(_maxTopUpAmount)})');
      return;
    }

    _omisePollTimer?.cancel();
    setState(() {
      _isGenerating = true;
      _selectedAmount = amount;
      _qrImageUrl = null;
      _requestSent = false;
      _omiseChargeId = null;
      _omisePaymentSuccess = false;
    });

    if (_useOmise) {
      await _generateOmiseQR(amount);
    } else {
      await _generateLocalQR(amount);
    }
  }

  // ══════════════════════════════════════════
  // Omise PromptPay Flow
  // ══════════════════════════════════════════

  Future<void> _generateOmiseQR(double amount) async {
    try {
      final amountSatang = (amount * 100).toInt();

      debugLog('📤 Omise: สร้าง PromptPay Source — ฿$amount ($amountSatang สตางค์)');

      // Step 1: สร้าง PromptPay Source
      final source = await OmiseService.createPromptPaySource(amountSatang);
      if (source == null) {
        if (mounted) {
          _showErrorDialog('ไม่สามารถสร้าง PromptPay Source ได้\nกรุณาตรวจสอบ Omise Key ใน .env');
        }
        return;
      }

      final sourceId = source['id'] as String;
      debugLog('✅ Omise Source: $sourceId');

      // Step 2: สร้าง Charge จาก Source
      final charge = await OmiseService.createCharge(sourceId, amountSatang);
      if (charge == null) {
        if (mounted) {
          _showErrorDialog('ไม่สามารถสร้าง Charge ได้\nกรุณาตรวจสอบ Omise Secret Key');
        }
        return;
      }

      final chargeId = charge['id'] as String;
      final qrUrl = OmiseService.extractQrUrl(charge);
      debugLog('✅ Omise Charge: $chargeId');
      debugLog('📷 QR URL: $qrUrl');

      if (qrUrl == null) {
        if (mounted) {
          _showErrorDialog('ไม่พบ QR Code ใน Charge response\nกรุณาลองใหม่');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _qrImageUrl = qrUrl;
          _omiseChargeId = chargeId;
        });

        // Step 3: เริ่ม poll สถานะทุก 5 วินาที
        _startOmisePolling(chargeId);
      }

      debugLog('✅ Omise QR สร้างสำเร็จ — กำลัง poll สถานะ...');
    } catch (e) {
      debugLog('❌ Error Omise QR: $e');
      if (mounted) {
        _showErrorDialog('เกิดข้อผิดพลาด Omise: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _startOmisePolling(String chargeId) {
    _omisePollTimer?.cancel();
    _omisePollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _omisePaymentSuccess) {
        _omisePollTimer?.cancel();
        return;
      }

      debugLog('🔍 Omise: ตรวจสอบสถานะ Charge $chargeId...');
      final status = await OmiseService.checkChargeStatus(chargeId);
      debugLog('📋 Omise status: $status');

      if (!mounted) return;

      if (status == 'successful') {
        _omisePollTimer?.cancel();
        setState(() {
          _omisePaymentSuccess = true;
        });
        // เติมเงินเข้า wallet อัตโนมัติ
        await _omiseAutoCredit();
      } else if (status == 'failed' || status == 'expired') {
        _omisePollTimer?.cancel();
        _showErrorDialog(status == 'expired'
            ? 'QR Code หมดอายุ กรุณาสร้างใหม่'
            : 'การชำระเงินล้มเหลว กรุณาลองใหม่');
      }
    });
  }

  Future<void> _omiseAutoCredit() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      final success = await _walletService.topUpWallet(
        driverId: userId,
        amount: _selectedAmount,
        description: 'เติมเงินผ่าน Omise PromptPay (฿${_selectedAmount.toStringAsFixed(0)}) — Charge: ${_omiseChargeId?.substring(0, 12) ?? ''}',
      );

      // บันทึกลง topup_requests ด้วย (ถ้าตารางมี)
      try {
        await Supabase.instance.client.from('topup_requests').insert({
          'user_id': userId,
          'amount': _selectedAmount,
          'status': 'completed',
          'processed_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        _showErrorDialog('ชำระเงินสำเร็จแล้ว แต่ไม่สามารถเติมเงินเข้ากระเป๋าได้\nกรุณาติดต่อ Admin พร้อมหลักฐานการโอน');
      }
    } catch (e) {
      debugLog('❌ Error auto-credit: $e');
      if (mounted) {
        _showErrorDialog('ชำระเงินสำเร็จแล้ว แต่เกิดข้อผิดพลาด\nกรุณาติดต่อ Admin');
      }
    }
  }

  // ══════════════════════════════════════════
  // Local PromptPay Flow (Fallback)
  // ══════════════════════════════════════════

  Future<void> _generateLocalQR(double amount) async {
    try {
      // ดึงเบอร์ PromptPay ของระบบจาก system_config
      String? promptPayNumber;
      try {
        final config = await Supabase.instance.client
            .from('system_config')
            .select('promptpay_number')
            .maybeSingle();
        if (config != null && config['promptpay_number'] != null) {
          final num = (config['promptpay_number'] as String).trim();
          if (num.isNotEmpty && num != '0812345678') {
            promptPayNumber = num;
          }
        }
      } catch (_) {}

      if (promptPayNumber == null || promptPayNumber.isEmpty) {
        if (mounted) {
          _showErrorDialog('ระบบยังไม่ได้ตั้งค่าเลข PromptPay\nกรุณาติดต่อ Admin เพื่อตั้งค่า');
        }
        return;
      }

      if (!PromptPayService.isValidPhone(promptPayNumber) && promptPayNumber.length != 13) {
        if (mounted) {
          _showErrorDialog('เลข PromptPay ในระบบไม่ถูกต้อง\nกรุณาติดต่อ Admin');
        }
        return;
      }

      // สร้าง QR payload
      final payload = promptPayNumber.length == 13
          ? PromptPayService.generateFromNationalId(promptPayNumber, amount: amount)
          : PromptPayService.generateFromPhone(promptPayNumber, amount: amount);
      final qrUrl = PromptPayService.getQrImageUrl(payload, size: 300);

      if (mounted) {
        setState(() {
          _qrImageUrl = qrUrl;
        });
      }

      debugLog('✅ Local QR สร้างสำเร็จ — PromptPay: $promptPayNumber, amount: $amount');
    } catch (e) {
      debugLog('❌ Error generating local QR: $e');
      if (mounted) {
        _showErrorDialog('เกิดข้อผิดพลาด: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── ส่งคำขอเติมเงินรอ Admin ยืนยัน (Local flow only) ──

  Future<void> _submitTopUpRequest() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    setState(() => _isCheckingStatus = true);

    try {
      await Supabase.instance.client.from('topup_requests').insert({
        'user_id': userId,
        'amount': _selectedAmount,
        'status': 'pending',
      });

      // แจ้งเตือน Admin ทุกคนผ่าน push notification
      _notifyAdminsTopUpRequest(userId, _selectedAmount);

      if (mounted) {
        setState(() {
          _requestSent = true;
          _isCheckingStatus = false;
        });
        _showSuccessRequestDialog();
      }
    } catch (e) {
      debugLog('❌ Error submitting topup request: $e');
      if (mounted) {
        setState(() => _isCheckingStatus = false);
        // Fallback: top up directly if table doesn't exist
        await _directTopUp();
      }
    }
  }

  /// Direct top-up fallback (เติมตรงเข้า wallet)
  Future<void> _directTopUp() async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      final success = await _walletService.topUpWallet(
        driverId: userId,
        amount: _selectedAmount,
        description: 'เติมเงินผ่าน PromptPay (฿${_selectedAmount.toStringAsFixed(0)})',
      );

      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted) {
        _showErrorDialog('ไม่สามารถเติมเงินเข้ากระเป๋าได้\nกรุณาติดต่อ Admin');
      }
    } catch (e) {
      debugLog('❌ Error direct topup: $e');
      if (mounted) {
        _showErrorDialog('เกิดข้อผิดพลาดในการเติมเงิน\nกรุณาติดต่อ Admin');
      }
    }
  }

  /// แจ้งเตือน Admin ทุกคนเมื่อมีคำขอเติมเงิน
  Future<void> _notifyAdminsTopUpRequest(String driverId, double amount) async {
    try {
      // ดึงชื่อคนขับ
      final driverProfile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', driverId)
          .maybeSingle();
      final driverName = driverProfile?['full_name'] ?? 'คนขับ';

      // ดึง admin ทุกคน (สำหรับ push notification)
      final admins = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      // ส่ง push notification ไปยัง admin ทุกคน
      for (final admin in admins) {
        final adminId = admin['id'] as String;
        try {
          await NotificationSender.sendToUser(
            userId: adminId,
            title: '💰 คำขอเติมเงินใหม่',
            body: '$driverName แจ้งเติมเงิน ฿${amount.toStringAsFixed(0)} — รอการอนุมัติ',
            data: {'type': 'topup_request', 'driver_id': driverId},
          );
        } catch (_) {}
      }

      // ดึงอีเมลแจ้งเตือนจาก system_config (ตั้งค่าใน admin web)
      try {
        final config = await Supabase.instance.client
            .from('system_config')
            .select('admin_notification_email, admin_notification_email_cc')
            .maybeSingle();
        final primaryEmail = config?['admin_notification_email'] as String?;
        final ccEmail = config?['admin_notification_email_cc'] as String?;

        if (primaryEmail != null && primaryEmail.isNotEmpty) {
          _sendAdminEmailNotification(
            adminEmail: primaryEmail,
            driverName: driverName,
            amount: amount,
          );
        }
        if (ccEmail != null && ccEmail.isNotEmpty) {
          _sendAdminEmailNotification(
            adminEmail: ccEmail,
            driverName: driverName,
            amount: amount,
          );
        }
      } catch (_) {}

      debugLog('✅ Notified ${admins.length} admins about topup request');
    } catch (e) {
      debugLog('⚠️ Error notifying admins: $e');
    }
  }

  /// ส่งอีเมลแจ้งเตือนไปยัง admin ผ่าน Supabase Edge Function
  Future<void> _sendAdminEmailNotification({
    required String adminEmail,
    required String driverName,
    required double amount,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-admin-email',
        body: {
          'to': adminEmail,
          'subject': '💰 คำขอเติมเงินใหม่ — $driverName ฿${amount.toStringAsFixed(0)}',
          'html': '''
<div style="font-family:sans-serif;max-width:500px;margin:0 auto;padding:20px;">
  <h2 style="color:#1565C0;">💰 คำขอเติมเงินใหม่</h2>
  <div style="background:#f5f5f5;padding:16px;border-radius:12px;margin:16px 0;">
    <p><strong>คนขับ:</strong> $driverName</p>
    <p><strong>จำนวนเงิน:</strong> <span style="color:#4CAF50;font-size:24px;font-weight:bold;">฿${amount.toStringAsFixed(0)}</span></p>
    <p><strong>สถานะ:</strong> <span style="color:#FF9800;">รอการอนุมัติ</span></p>
  </div>
  <p style="color:#666;">กรุณาเข้าสู่ระบบ Admin เพื่อตรวจสอบและอนุมัติคำขอเติมเงิน</p>
  <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">
  <p style="color:#999;font-size:12px;">Jedechai Delivery Admin System</p>
</div>
''',
        },
      );
      debugLog('📧 Admin email sent to: $adminEmail');
    } catch (e) {
      debugLog('⚠️ Email notification failed: $e');
    }
  }

  // ── Dialogs ──

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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.hourglass_top, color: Colors.orange, size: 48),
        title: const Text('ส่งคำขอเติมเงินแล้ว',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'คำขอเติมเงิน ฿${_selectedAmount.toStringAsFixed(0)} ถูกส่งแล้ว\nรอ Admin ตรวจสอบและยืนยัน',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: AppTheme.accentBlue, size: 48),
        title: const Text('เติมเงินสำเร็จ!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'เติมเงิน ฿${_selectedAmount.toStringAsFixed(0)} เข้ากระเป๋าเรียบร้อยแล้ว',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('ตกลง'),
            ),
          ),
        ],
      ),
    );
  }

  // ── ถอนเงิน ──

  bool _isWithdrawing = false;

  Future<void> _showWithdrawDialog() async {
    final withdrawController = TextEditingController();
    final bankNameController = TextEditingController();
    final accountNumController = TextEditingController();
    final accountNameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ถอนเงิน', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ยอดคงเหลือ: ฿${NumberFormat('#,##0.00').format(_currentBalance)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: withdrawController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'จำนวนเงินที่ต้องการถอน',
                  prefixText: '฿ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankNameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อธนาคาร',
                  hintText: 'เช่น กสิกรไทย, ไทยพาณิชย์',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNumController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'เลขบัญชี',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อบัญชี',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: _isWithdrawing ? null : () async {
              final amount = double.tryParse(withdrawController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('กรุณาระบุจำนวนเงิน'), backgroundColor: Colors.red),
                );
                return;
              }
              if (amount > _currentBalance) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('ยอดเงินไม่เพียงพอ'), backgroundColor: Colors.red),
                );
                return;
              }
              if (bankNameController.text.trim().isEmpty || accountNumController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('กรุณากรอกข้อมูลธนาคาร'), backgroundColor: Colors.red),
                );
                return;
              }
              final userId = AuthService.userId;
              if (userId == null) return;
              _isWithdrawing = true;
              try {
                // สร้างคำขอถอนเงินก่อน (ถ้า insert ล้มเหลว เงินจะไม่หาย)
                await Supabase.instance.client.from('withdrawal_requests').insert({
                  'user_id': userId,
                  'amount': amount,
                  'bank_name': bankNameController.text.trim(),
                  'account_number': accountNumController.text.trim(),
                  'status': 'pending',
                });
                // หักเงินจาก wallet หลังจาก insert สำเร็จ
                final wallet = await _walletService.getDriverWallet(userId);
                if (wallet != null) {
                  await Supabase.instance.client.from('wallet_transactions').insert({
                    'wallet_id': wallet.id,
                    'amount': -amount,
                    'type': 'withdrawal',
                    'description': 'แจ้งถอนเงิน ฿${amount.toStringAsFixed(2)} ไปยัง ${bankNameController.text.trim()} ${accountNumController.text.trim()}',
                  });
                  await Supabase.instance.client.from('wallets')
                      .update({'balance': wallet.balance - amount})
                      .eq('id', wallet.id);
                }
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                debugLog('❌ Error withdraw: $e');
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                _isWithdrawing = false;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('ส่งคำขอถอนเงิน'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _showSuccessDialog();
      _loadBalance();
      _loadHistory();
    }
  }

  // ── ประวัติ ──

  List<Map<String, dynamic>> _topupHistory = [];
  List<Map<String, dynamic>> _withdrawalHistory = [];
  bool _isLoadingHistory = false;

  Future<void> _loadHistory() async {
    final userId = AuthService.userId;
    if (userId == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final topupRes = await Supabase.instance.client
          .from('topup_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      final withdrawRes = await Supabase.instance.client
          .from('withdrawal_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _topupHistory = List<Map<String, dynamic>>.from(topupRes);
          _withdrawalHistory = List<Map<String, dynamic>>.from(withdrawRes);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugLog('⚠️ ไม่สามารถโหลดประวัติ: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ══════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool hasQR = _qrImageUrl != null && _qrImageUrl!.isNotEmpty && !_requestSent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('เติมเงิน / ถอนเงิน'),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  _buildAmountSection(),
                  const SizedBox(height: 20),
                  if (_omisePaymentSuccess) ...[
                    _buildOmiseSuccessCard(),
                  ] else if (_requestSent) ...[
                    _buildRequestSentCard(),
                  ] else if (hasQR) ...[
                    _buildQRSection(),
                    const SizedBox(height: 16),
                    if (_useOmise && _omiseChargeId != null)
                      _buildOmiseStatusSection()
                    else
                      _buildConfirmTransferButton(),
                  ] else ...[
                    _buildGenerateQRButton(),
                  ],
                  const SizedBox(height: 16),
                  // ปุ่มถอนเงิน
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _showWithdrawDialog,
                      icon: const Icon(Icons.account_balance, color: Colors.orange),
                      label: const Text('ถอนเงิน',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ประวัติถอนเงิน
                  _buildWithdrawalHistorySection(),
                  const SizedBox(height: 24),
                  // ประวัติเติมเงิน
                  _buildHistorySection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
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
            const Text('เลือกจำนวนเงิน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return GestureDetector(
                  onTap: () => _selectAmount(amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentBlue
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentBlue
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      '฿${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              decoration: InputDecoration(
                labelText: 'หรือกรอกจำนวนเงินเอง',
                prefixText: '฿ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                _omisePollTimer?.cancel();
                final amount = double.tryParse(value) ?? 0;
                setState(() {
                  _selectedAmount = amount;
                  // reset QR เมื่อเปลี่ยนจำนวนเงิน
                  _qrImageUrl = null;
                  _requestSent = false;
                  _omiseChargeId = null;
                  _omisePaymentSuccess = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('สแกน QR Code เพื่อโอนเงิน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _useOmise
                  ? 'สแกน QR ผ่านแอปธนาคาร — ระบบตรวจยอดอัตโนมัติ'
                  : 'โอนเงินผ่าน PromptPay แล้วกดยืนยัน',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (_useOmise)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.blue[600], size: 14),
                    const SizedBox(width: 4),
                    Text('Powered by Omise',
                        style: TextStyle(fontSize: 11, color: Colors.blue[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppNetworkImage(
                  imageUrl: _qrImageUrl,
                  fit: BoxFit.contain,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'จำนวนเงิน: ฿${_selectedAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentBlue),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 8),
            Text(
              _useOmise
                  ? 'สแกน QR โอนเงิน — ระบบจะตรวจยอดให้อัตโนมัติ'
                  : 'สแกน QR โอนเงินแล้วกด "แจ้งโอนเงิน" ด้านล่าง',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSentCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.hourglass_top, color: Colors.orange, size: 48),
            const SizedBox(height: 12),
            const Text('คำขอเติมเงินถูกส่งแล้ว',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'จำนวน ฿${_selectedAmount.toStringAsFixed(0)} — รอ Admin ตรวจสอบและยืนยัน',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOmiseStatusSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.blue[600],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'กำลังตรวจสอบการชำระเงิน...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ระบบจะตรวจยอดอัตโนมัติทุก 5 วินาที\nเมื่อชำระเงินสำเร็จจะเติมเงินเข้ากระเป๋าทันที',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _omisePollTimer?.cancel();
                setState(() {
                  _qrImageUrl = null;
                  _omiseChargeId = null;
                });
              },
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('ยกเลิก / สร้าง QR ใหม่'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOmiseSuccessCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.accentBlue, size: 56),
            const SizedBox(height: 12),
            const Text('ชำระเงินสำเร็จ!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentBlue)),
            const SizedBox(height: 8),
            Text(
              'เติมเงิน ฿${_selectedAmount.toStringAsFixed(0)} เข้ากระเป๋าเรียบร้อยแล้ว',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ตรวจยอดอัตโนมัติผ่าน Omise',
              style: TextStyle(fontSize: 12, color: Colors.blue[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateQRButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateQR,
        icon: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.qr_code),
        label: Text(
          _isGenerating ? 'กำลังสร้าง QR...' : 'ชำระเงินด้วย PromptPay',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildConfirmTransferButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isCheckingStatus ? null : _submitTopUpRequest,
            icon: _isCheckingStatus
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(
              _isCheckingStatus ? 'กำลังส่ง...' : 'แจ้งโอนเงิน ฿${_selectedAmount.toStringAsFixed(0)}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _qrImageUrl = null;
              _requestSent = false;
            });
          },
          icon: const Icon(Icons.replay, size: 18),
          label: const Text('สร้าง QR ใหม่'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildWithdrawalHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ประวัติถอนเงิน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_isLoadingHistory)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_withdrawalHistory.isEmpty && !_isLoadingHistory)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('ยังไม่มีประวัติถอนเงิน',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
          )
        else
          ..._withdrawalHistory.map((r) {
            final amount = (r['amount'] as num?)?.toDouble() ?? 0;
            final status = r['status'] as String? ?? 'pending';
            final createdAt = r['created_at'] != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(r['created_at']).toLocal())
                : '-';
            final bankName = r['bank_name'] as String? ?? '-';
            final accountNum = r['account_number'] as String? ?? '-';
            final statusColor = status == 'completed'
                ? Colors.green
                : status == 'rejected'
                    ? Colors.red
                    : status == 'cancelled'
                        ? Colors.grey
                        : Colors.orange;
            final statusText = status == 'completed'
                ? 'โอนแล้ว'
                : status == 'rejected'
                    ? 'ปฏิเสธ'
                    : status == 'cancelled'
                        ? 'ยกเลิก'
                        : 'รอดำเนินการ';
            final statusIcon = status == 'completed'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : status == 'cancelled'
                        ? Icons.block
                        : Icons.hourglass_top;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor, size: 28),
                title: Text('-฿${NumberFormat('#,##0').format(amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                subtitle: Text('$bankName $accountNum\n$createdAt',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                isThreeLine: true,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ประวัติเติมเงิน',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_isLoadingHistory)
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_topupHistory.isEmpty && !_isLoadingHistory)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('ยังไม่มีประวัติเติมเงิน',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
          )
        else
          ..._topupHistory.map((r) {
            final amount = (r['amount'] as num?)?.toDouble() ?? 0;
            final status = r['status'] as String? ?? 'pending';
            final createdAt = r['created_at'] != null
                ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(r['created_at']).toLocal())
                : '-';
            final statusColor = status == 'completed'
                ? Colors.green
                : status == 'rejected'
                    ? Colors.red
                    : Colors.orange;
            final statusText = status == 'completed'
                ? 'อนุมัติแล้ว'
                : status == 'rejected'
                    ? 'ปฏิเสธ'
                    : 'รอดำเนินการ';
            final statusIcon = status == 'completed'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : Icons.hourglass_top;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor, size: 28),
                title: Text('฿${NumberFormat('#,##0').format(amount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(createdAt, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
      ],
    );
  }
}
