import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/promptpay_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/services/admin_line_notification_service.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/debug_logger.dart';
import '../../../l10n/app_localizations.dart';

/// Wallet TopUp Screen — PromptPay QR + Slip2Go auto verification
///
/// หน้าเติมเงินเข้ากระเป๋า:
/// - เลือกจำนวนเงิน (preset หรือกรอกเอง)
/// - สร้าง PromptPay QR สำหรับโอนเงิน
/// - เลือกรูปสลิปโอนเงิน
/// - ตรวจสลิปผ่าน Edge Function + Slip2Go แล้วเติมเงินอัตโนมัติ
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
  bool _autoTopupCompleted = false;

  // Slip verification state
  File? _selectedSlipFile;
  String? _selectedSlipFileName;

  // จำนวนเงินที่เลือกได้
  final List<double> _presetAmounts = [50, 100, 200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
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
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
      // reset QR state เมื่อเลือกจำนวนเงินใหม่
      _qrImageUrl = null;
      _requestSent = false;
      _autoTopupCompleted = false;
      _selectedSlipFile = null;
      _selectedSlipFileName = null;
    });
  }

  // ── สร้าง PromptPay QR ──

  static const double _maxTopUpAmount = 50000;
  static const double _minTopUpAmount = 20;

  Future<void> _generateQR() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < _minTopUpAmount) {
      _showErrorDialog(AppLocalizations.of(context)!
          .topupMinAmountError(_minTopUpAmount.toStringAsFixed(0)));
      return;
    }
    if (amount > _maxTopUpAmount) {
      _showErrorDialog(AppLocalizations.of(context)!
          .topupMaxAmountError(NumberFormat('#,##0').format(_maxTopUpAmount)));
      return;
    }

    setState(() {
      _isGenerating = true;
      _selectedAmount = amount;
      _qrImageUrl = null;
      _requestSent = false;
      _autoTopupCompleted = false;
      _selectedSlipFile = null;
      _selectedSlipFileName = null;
    });

    await _generateLocalQR(amount);
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
            .eq('id', 1)
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
          _showErrorDialog(AppLocalizations.of(context)!.topupPromptPayNotSet);
        }
        return;
      }

      if (!PromptPayService.isValidPhone(promptPayNumber) &&
          promptPayNumber.length != 13) {
        if (mounted) {
          _showErrorDialog(AppLocalizations.of(context)!.topupPromptPayInvalid);
        }
        return;
      }

      // สร้าง QR payload
      final payload = promptPayNumber.length == 13
          ? PromptPayService.generateFromNationalId(promptPayNumber,
              amount: amount)
          : PromptPayService.generateFromPhone(promptPayNumber, amount: amount);
      final qrUrl = PromptPayService.getQrImageUrl(payload, size: 300);

      if (mounted) {
        setState(() {
          _qrImageUrl = qrUrl;
        });
      }

      debugLog(
          '✅ Local QR สร้างสำเร็จ — PromptPay: $promptPayNumber, amount: $amount');
    } catch (e) {
      debugLog('❌ Error generating local QR: $e');
      if (mounted) {
        _showErrorDialog(
            AppLocalizations.of(context)!.topupLocalError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── ส่งคำขอเติมเงินรอ Admin ยืนยัน (Local flow only) ──

  Future<void> _pickSlipImage() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file == null) return;

    setState(() {
      _selectedSlipFile = file;
      _selectedSlipFileName = file.path.split(RegExp(r'[\\/]')).last;
      _requestSent = false;
      _autoTopupCompleted = false;
    });
  }

  String _slipContentType(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submitTopUpRequest() async {
    final userId = AuthService.userId;
    if (userId == null) return;
    final slipFile = _selectedSlipFile;
    if (slipFile == null) {
      _showErrorDialog('กรุณาแนบรูปสลิปก่อนยืนยันเติมเงิน');
      return;
    }

    setState(() => _isCheckingStatus = true);

    try {
      final bytes = await slipFile.readAsBytes();
      final response = await Supabase.instance.client.functions.invoke(
        'verify-topup-slip',
        body: {
          'amount': _selectedAmount,
          'slipImageBase64': base64Encode(bytes),
          'slipImageContentType': _slipContentType(slipFile),
          'fileName': _selectedSlipFileName,
        },
      );
      final data = response.data;
      final result =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final status = result['status']?.toString();
      final ok = result['ok'] == true && status == 'completed';

      if (ok && mounted) {
        setState(() {
          _requestSent = false;
          _autoTopupCompleted = true;
          _isCheckingStatus = false;
        });
        await _loadBalance();
        await _loadHistory();
        _showSuccessDialog();
        return;
      }

      if (status == 'pending' && mounted) {
        await _handlePendingTopupVerificationResult(userId);
        return;
      }

      final message = _formatTopupVerificationResult(result);
      if (mounted) {
        setState(() => _isCheckingStatus = false);
        _showErrorDialog(message);
      }
    } catch (e) {
      debugLog('❌ Error verifying topup slip: $e');
      final pendingResult = _pendingTopupVerificationResultFromError(e);
      if (pendingResult != null && mounted) {
        await _handlePendingTopupVerificationResult(userId);
        return;
      }

      if (mounted) {
        setState(() => _isCheckingStatus = false);
        _showErrorDialog(_formatTopupVerificationError(e));
      }
    }
  }

  Map<String, dynamic>? _pendingTopupVerificationResultFromError(Object error) {
    if (error is! FunctionException) return null;
    final details = error.details;
    if (details is! Map) return null;

    final result = Map<String, dynamic>.from(details);
    return result['status']?.toString() == 'pending' ? result : null;
  }

  Future<void> _handlePendingTopupVerificationResult(String userId) async {
    await _notifyAdminsTopUpRequest(userId, _selectedAmount);
    if (!mounted) return;

    setState(() {
      _requestSent = true;
      _autoTopupCompleted = false;
      _isCheckingStatus = false;
    });
    _showSuccessRequestDialog();
  }

  String _formatTopupVerificationError(Object error) {
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map) {
        return _formatTopupVerificationResult(
          Map<String, dynamic>.from(details),
        );
      }

      final message = _humanizeSlipVerificationMessage(details?.toString());
      if (message != null) return message;
    }

    final message = _humanizeSlipVerificationMessage(error.toString());
    return message ??
        'ตรวจสลิปไม่สำเร็จ กรุณาเลือกสลิปใหม่ หรือติดต่อแอดมินหากโอนเงินแล้ว';
  }

  String _formatTopupVerificationResult(Map<String, dynamic> result) {
    final reason = result['reason']?.toString();
    final message = result['message']?.toString();

    switch (reason) {
      case 'slip2go_failed':
        return 'สลิปนี้ไม่ผ่านการตรวจสอบอัตโนมัติ กรุณาเลือกสลิปโอนเงินจริงจากธนาคารแล้วลองใหม่';
      case 'amountMismatch':
        return 'ยอดเงินในสลิปไม่ตรงกับยอดเติมเงิน กรุณาตรวจสอบยอดเงินแล้วลองใหม่';
      case 'receiverMismatch':
        return 'บัญชีผู้รับในสลิปไม่ตรงกับบัญชีปลายทางของระบบ กรุณาตรวจสอบบัญชีปลายทาง';
      case 'duplicateSlip':
        return 'สลิปนี้ถูกใช้เติมเงินแล้ว กรุณาใช้สลิปใหม่';
      case 'rateLimited':
        return 'ตรวจสลิปหลายครั้งเกินไป กรุณารอสักครู่แล้วลองใหม่';
      case 'invalidAmount':
        return 'จำนวนเงินเติมไม่ถูกต้อง กรุณาสร้าง QR ใหม่';
      case 'invalidImage':
        return 'ไฟล์สลิปไม่ถูกต้อง กรุณาเลือกไฟล์รูปภาพใหม่';
    }

    return _humanizeSlipVerificationMessage(message) ??
        'ตรวจสลิปไม่ผ่าน กรุณาตรวจสอบสลิปแล้วลองใหม่';
  }

  String? _humanizeSlipVerificationMessage(String? rawMessage) {
    final normalized = rawMessage?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    final lower = normalized.toLowerCase();
    if (lower.contains('functionexception')) {
      if (lower.contains('fraud') || lower.contains('unprocessable entity')) {
        return 'สลิปนี้ไม่ผ่านการตรวจสอบ กรุณาใช้สลิปโอนเงินจริงจากธนาคาร และตรวจสอบว่ายอดเงินกับบัญชีปลายทางถูกต้อง';
      }
      return null;
    }
    if (lower.contains('fraud') || lower.contains('unprocessable entity')) {
      return 'สลิปนี้ไม่ผ่านการตรวจสอบ กรุณาใช้สลิปโอนเงินจริงจากธนาคาร และตรวจสอบว่ายอดเงินกับบัญชีปลายทางถูกต้อง';
    }
    if (lower.contains('duplicate')) {
      return 'สลิปนี้ถูกใช้เติมเงินแล้ว กรุณาใช้สลิปใหม่';
    }
    if (lower.contains('amount')) {
      return 'ยอดเงินในสลิปไม่ตรงกับยอดเติมเงิน กรุณาตรวจสอบยอดเงินแล้วลองใหม่';
    }
    if (lower.contains('receiver') || lower.contains('account')) {
      return 'บัญชีผู้รับในสลิปไม่ตรงกับบัญชีปลายทางของระบบ กรุณาตรวจสอบบัญชีปลายทาง';
    }

    return normalized;
  }

  /// แจ้งเตือน Admin ทุกคนเมื่อมีคำขอเติมเงิน
  Future<void> _notifyAdminsTopUpRequest(String driverId, double amount) async {
    try {
      final l10n = AppLocalizations.of(context)!;

      // ดึงชื่อคนขับ
      final driverProfile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', driverId)
          .maybeSingle();
      final driverName = driverProfile?['full_name'] ?? l10n.topupDriverDefault;
      final amountText = amount.toStringAsFixed(0);

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
            title: l10n.topupAdminPushTitle,
            body: l10n.topupAdminPushBody(driverName, amountText),
            data: {'type': 'topup_request', 'driver_id': driverId},
          );
        } catch (_) {}
      }

      await AdminLineNotificationService.notify(
        eventType: 'topup_request',
        title: 'JDC: คำขอเติมเงินใหม่',
        message:
            'มีคำขอเติมเงินใหม่จาก $driverName จำนวน ฿$amountText รอแอดมินตรวจสอบ',
        data: {
          'driver_id': driverId,
          'driver_name': driverName,
          'amount': amountText,
        },
      );

      // ดึงอีเมลแจ้งเตือนจาก system_config (ตั้งค่าใน admin web)
      try {
        final config = await Supabase.instance.client
            .from('system_config')
            .select('admin_notification_email, admin_notification_email_cc')
            .eq('id', 1)
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
      final l10n = AppLocalizations.of(context)!;
      final amountText = amount.toStringAsFixed(0);
      await Supabase.instance.client.functions.invoke(
        'send-admin-email',
        body: {
          'to': adminEmail,
          'subject': l10n.topupAdminEmailSubject(driverName, amountText),
          'html': l10n.topupAdminEmailHtml(driverName, amountText),
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
        title: Text(AppLocalizations.of(context)!.topupErrorTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              child: Text(AppLocalizations.of(context)!.topupOk),
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
        title: Text(AppLocalizations.of(context)!.topupRequestSentTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          AppLocalizations.of(context)!
              .topupRequestSentBody(_selectedAmount.toStringAsFixed(0)),
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
              child: Text(AppLocalizations.of(context)!.topupOk),
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
        icon: const Icon(Icons.check_circle,
            color: AppTheme.accentBlue, size: 48),
        title: Text(AppLocalizations.of(context)!.topupSuccessTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          AppLocalizations.of(context)!
              .topupSuccessBody(_selectedAmount.toStringAsFixed(0)),
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
              child: Text(AppLocalizations.of(context)!.topupOk),
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
        title: Text(AppLocalizations.of(context)!.topupWithdrawTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  AppLocalizations.of(context)!.topupWithdrawBalance(
                      NumberFormat('#,##0.00').format(_currentBalance)),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: withdrawController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.topupWithdrawAmountLabel,
                  prefixText: '฿ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankNameController,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.topupWithdrawBankName,
                  hintText: AppLocalizations.of(context)!.topupWithdrawBankHint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNumController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.topupWithdrawAccountNum,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountNameController,
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.topupWithdrawAccountName,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.topupWithdrawCancel),
          ),
          ElevatedButton(
            onPressed: _isWithdrawing
                ? null
                : () async {
                    final l10n = AppLocalizations.of(context)!;
                    final amount =
                        double.tryParse(withdrawController.text) ?? 0;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(l10n.topupWithdrawAmountRequired),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (amount > _currentBalance) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content:
                                Text(l10n.topupWithdrawInsufficientBalance),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    if (bankNameController.text.trim().isEmpty ||
                        accountNumController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                            content: Text(l10n.topupWithdrawBankRequired),
                            backgroundColor: Colors.red),
                      );
                      return;
                    }
                    final userId = AuthService.userId;
                    if (userId == null) return;
                    _isWithdrawing = true;
                    try {
                      // สร้างคำขอถอนเงินก่อน (ถ้า insert ล้มเหลว เงินจะไม่หาย)
                      await Supabase.instance.client
                          .from('withdrawal_requests')
                          .insert({
                        'user_id': userId,
                        'amount': amount,
                        'bank_name': bankNameController.text.trim(),
                        'account_number': accountNumController.text.trim(),
                        'status': 'pending',
                      });
                      // หักเงินจาก wallet หลังจาก insert สำเร็จ
                      final wallet =
                          await _walletService.getDriverWallet(userId);
                      if (wallet != null) {
                        await Supabase.instance.client
                            .from('wallet_transactions')
                            .insert({
                          'wallet_id': wallet.id,
                          'amount': -amount,
                          'type': 'withdrawal',
                          'description':
                              l10n.topupWithdrawalTransactionDescription(
                            amount.toStringAsFixed(2),
                            bankNameController.text.trim(),
                            accountNumController.text.trim(),
                          ),
                        });
                        await Supabase.instance.client
                            .from('wallets')
                            .update({'balance': wallet.balance - amount}).eq(
                                'id', wallet.id);
                      }
                      await AdminLineNotificationService.notify(
                        eventType: 'withdrawal_request',
                        title: 'JDC: คำขอถอนเงินใหม่',
                        message:
                            'มีคำขอถอนเงินใหม่ จำนวน ฿${amount.toStringAsFixed(0)} รอแอดมินตรวจสอบ',
                        data: {
                          'user_id': userId,
                          'amount': amount.toStringAsFixed(0),
                          'bank_name': bankNameController.text.trim(),
                          'account_number': accountNumController.text.trim(),
                        },
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    } catch (e) {
                      debugLog('❌ Error withdraw: $e');
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content:
                                  Text(l10n.topupWithdrawError(e.toString())),
                              backgroundColor: Colors.red),
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
            child: Text(AppLocalizations.of(context)!.topupWithdrawSubmit),
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
    final bool hasQR = _qrImageUrl != null &&
        _qrImageUrl!.isNotEmpty &&
        !_requestSent &&
        !_autoTopupCompleted;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.topupTitle),
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
                  if (_autoTopupCompleted) ...[
                    _buildAutoTopupCompletedCard(),
                  ] else if (_requestSent) ...[
                    _buildRequestSentCard(),
                  ] else if (hasQR) ...[
                    _buildQRSection(),
                    const SizedBox(height: 16),
                    _buildSlipUploadSection(),
                    const SizedBox(height: 16),
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
                      icon: const Icon(Icons.account_balance,
                          color: Colors.orange),
                      label: Text(
                          AppLocalizations.of(context)!.topupWithdrawBtn,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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
          Text(AppLocalizations.of(context)!.walletBalance,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.topupSelectAmount,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      color:
                          isSelected ? AppTheme.accentBlue : Colors.grey[100],
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
                        color:
                            isSelected ? Colors.white : colorScheme.onSurface,
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
                labelText: AppLocalizations.of(context)!.topupCustomAmount,
                prefixText: '฿ ',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0;
                setState(() {
                  _selectedAmount = amount;
                  // reset QR เมื่อเปลี่ยนจำนวนเงิน
                  _qrImageUrl = null;
                  _requestSent = false;
                  _autoTopupCompleted = false;
                  _selectedSlipFile = null;
                  _selectedSlipFileName = null;
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
            Text(AppLocalizations.of(context)!.topupScanQR,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.topupManualScanDesc,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
              AppLocalizations.of(context)!
                  .topupAmount(_selectedAmount.toStringAsFixed(0)),
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentBlue),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 8),
            Text(
              'โอนเงินตาม QR แล้วแนบรูปสลิป ระบบจะตรวจสลิปและเติมเงินให้อัตโนมัติ',
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
            Text(AppLocalizations.of(context)!.topupRequestSentCard,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!
                  .topupRequestSentCardBody(_selectedAmount.toStringAsFixed(0)),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoTopupCompletedCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle,
                color: AppTheme.accentBlue, size: 56),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.topupSuccessTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!
                  .topupSuccessBody(_selectedAmount.toStringAsFixed(0)),
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'ตรวจสลิปและเติมเงินเข้ากระเป๋าแล้ว',
              style: TextStyle(fontSize: 12, color: Colors.blue[400]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _qrImageUrl = null;
                  _requestSent = false;
                  _autoTopupCompleted = false;
                  _selectedSlipFile = null;
                  _selectedSlipFileName = null;
                });
              },
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('เติมเงินอีกครั้ง'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipUploadSection() {
    final hasSlip = _selectedSlipFile != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasSlip ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasSlip ? Icons.check_circle : Icons.receipt_long,
                    color: hasSlip ? Colors.green[600] : Colors.blue[600],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSlip ? 'เลือกสลิปแล้ว' : 'แนบสลิปโอนเงิน',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSlip
                            ? (_selectedSlipFileName ?? 'พร้อมตรวจสอบสลิป')
                            : 'ถ่ายรูปหรือเลือกรูปสลิปหลังโอนตาม QR',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ระบบจะตรวจยอดและป้องกันสลิปซ้ำก่อนเติมเงินเข้ากระเป๋า',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingStatus ? null : _pickSlipImage,
                    icon:
                        Icon(hasSlip ? Icons.sync : Icons.add_photo_alternate),
                    label: Text(hasSlip ? 'เปลี่ยนสลิป' : 'เลือกรูปสลิป'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      side: const BorderSide(color: AppTheme.accentBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (hasSlip) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isCheckingStatus
                        ? null
                        : () {
                            setState(() {
                              _selectedSlipFile = null;
                              _selectedSlipFileName = null;
                            });
                          },
                    icon: const Icon(Icons.close),
                    color: Colors.grey[600],
                    tooltip: 'ลบสลิป',
                  ),
                ],
              ],
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
          _isGenerating
              ? AppLocalizations.of(context)!.topupGeneratingQR
              : AppLocalizations.of(context)!.topupPayPromptPay,
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
            onPressed: _isCheckingStatus || _selectedSlipFile == null
                ? null
                : _submitTopUpRequest,
            icon: _isCheckingStatus
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.receipt_long),
            label: Text(
              _isCheckingStatus
                  ? 'กำลังตรวจสลิป...'
                  : 'ตรวจสลิปและเติมเงิน ฿${_selectedAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              _autoTopupCompleted = false;
              _selectedSlipFile = null;
              _selectedSlipFileName = null;
            });
          },
          icon: const Icon(Icons.replay, size: 18),
          label: Text(AppLocalizations.of(context)!.topupGenerateNewQR),
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
            Text(AppLocalizations.of(context)!.topupWithdrawHistoryTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_isLoadingHistory)
              const SizedBox(
                width: 16,
                height: 16,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                    AppLocalizations.of(context)!.topupWithdrawHistoryEmpty,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
          )
        else
          ..._withdrawalHistory.map((r) {
            final amount = (r['amount'] as num?)?.toDouble() ?? 0;
            final status = r['status'] as String? ?? 'pending';
            final createdAt = r['created_at'] != null
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.parse(r['created_at']).toLocal())
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
                ? AppLocalizations.of(context)!.topupStatusCompleted
                : status == 'rejected'
                    ? AppLocalizations.of(context)!.topupStatusRejected
                    : status == 'cancelled'
                        ? AppLocalizations.of(context)!.topupStatusCancelled
                        : AppLocalizations.of(context)!.topupStatusPending;
            final statusIcon = status == 'completed'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : status == 'cancelled'
                        ? Icons.block
                        : Icons.hourglass_top;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor, size: 28),
                title: Text('-฿${NumberFormat('#,##0').format(amount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red)),
                subtitle: Text('$bankName $accountNum\n$createdAt',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                isThreeLine: true,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
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
            Text(AppLocalizations.of(context)!.topupHistoryTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_isLoadingHistory)
              const SizedBox(
                width: 16,
                height: 16,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(AppLocalizations.of(context)!.topupHistoryEmpty,
                    style: const TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
          )
        else
          ..._topupHistory.map((r) {
            final amount = (r['amount'] as num?)?.toDouble() ?? 0;
            final status = r['status'] as String? ?? 'pending';
            final createdAt = r['created_at'] != null
                ? DateFormat('dd/MM/yyyy HH:mm')
                    .format(DateTime.parse(r['created_at']).toLocal())
                : '-';
            final statusColor = status == 'completed'
                ? Colors.green
                : status == 'rejected'
                    ? Colors.red
                    : Colors.orange;
            final statusText = status == 'completed'
                ? AppLocalizations.of(context)!.topupStatusApproved
                : status == 'rejected'
                    ? AppLocalizations.of(context)!.topupStatusRejected
                    : AppLocalizations.of(context)!.topupStatusPending;
            final statusIcon = status == 'completed'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : Icons.hourglass_top;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor, size: 28),
                title: Text('฿${NumberFormat('#,##0').format(amount)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(createdAt,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }),
      ],
    );
  }
}
