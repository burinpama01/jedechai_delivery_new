import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/withdrawal_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/beam_topup_service.dart';
import '../../../common/services/promptpay_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/services/admin_line_notification_service.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/jdc_layout.dart';
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

  // โหมดเติมเงินจาก system_config.topup_mode: admin_approve (แนบสลิป) | beam
  String _topupMode = 'admin_approve';
  bool get _isBeamMode => _topupMode == 'beam';

  // Beam state
  BeamTopupCharge? _beamCharge;
  Timer? _beamPollTimer;
  Timer? _beamCountdownTimer;
  String? _beamStatusMessage;
  bool _beamPollInFlight = false;

  // จำนวนเงินที่เลือกได้
  final List<double> _presetAmounts = [50, 100, 200, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadHistory();
    _loadTopupMode();
  }

  @override
  void dispose() {
    _stopBeamTimers();
    _amountController.dispose();
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
  TextStyle _money({double size = 14, Color? color}) {
    final jdc = context.jdc;
    return TextStyle(
      fontFamily: 'IBMPlexSansThai',
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontVariations: _w(FontWeight.w700),
      color: color ?? jdc.text,
    );
  }

  /// กรอบ input มาตรฐาน JDC (radius 14 / เส้น line)
  OutlineInputBorder _fieldBorder() {
    final jdc = context.jdc;
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(JdcRadius.field),
      borderSide: BorderSide(color: jdc.line),
    );
  }

  /// กรอบการ์ดเนื้อหามาตรฐาน JDC (surface / line / radius 18 / sh-card)
  BoxDecoration _cardDecoration() {
    final jdc = context.jdc;
    return BoxDecoration(
      color: jdc.surface,
      borderRadius: BorderRadius.circular(JdcRadius.card),
      border: Border.all(color: jdc.line),
      boxShadow: jdc.shadowCard,
    );
  }

  Future<void> _loadTopupMode() async {
    try {
      final mode = await BeamTopupService.fetchTopupMode();
      if (mounted) setState(() => _topupMode = mode);
    } catch (e) {
      // โหลดโหมดไม่สำเร็จ (offline/สภาพแวดล้อม test) — คง default admin_approve
      debugLog('⚠️ loadTopupMode failed: $e');
    }
  }

  /// l10n ของหน้านี้ — สำหรับ method ที่ไม่มี context เป็นพารามิเตอร์
  /// (ใช้ตอนที่ widget ยัง mounted เท่านั้น)
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  // ══════════════════════════════════════════
  // Beam Checkout Flow (QR PromptPay อัตโนมัติ)
  // ══════════════════════════════════════════

  void _stopBeamTimers() {
    _beamPollTimer?.cancel();
    _beamPollTimer = null;
    _beamCountdownTimer?.cancel();
    _beamCountdownTimer = null;
  }

  void _resetBeamState() {
    _stopBeamTimers();
    _beamCharge = null;
    _beamStatusMessage = null;
  }

  Future<void> _createBeamCharge(double amount) async {
    try {
      final charge = await BeamTopupService.createCharge(amount);
      if (!mounted) return;
      setState(() {
        _beamCharge = charge;
        _beamStatusMessage = null;
      });
      _beamPollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _pollBeamStatus(),
      );
      _beamCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } on BeamTopupException catch (e) {
      if (e.reason == 'beam_disabled') {
        // แอดมินสลับกลับเป็นแนบสลิประหว่างนี้ — โหลดโหมดใหม่
        await _loadTopupMode();
      }
      if (mounted) _showErrorDialog(e.message);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _pollBeamStatus({bool manual = false}) async {
    final charge = _beamCharge;
    if (charge == null || _beamPollInFlight) return;
    _beamPollInFlight = true;
    if (manual && mounted) setState(() => _isCheckingStatus = true);
    try {
      final status = await BeamTopupService.checkStatus(charge.requestId);
      if (!mounted || _beamCharge?.requestId != charge.requestId) return;
      switch (status) {
        case 'completed':
          _stopBeamTimers();
          setState(() {
            _autoTopupCompleted = true;
            _beamCharge = null;
          });
          await _loadBalance();
          await _loadHistory();
          break;
        case 'failed':
          _stopBeamTimers();
          setState(() => _beamStatusMessage =
              _l10n.topupBeamFailed);
          break;
        case 'expired':
          _stopBeamTimers();
          setState(() => _beamStatusMessage =
              _l10n.topupBeamExpired);
          break;
        case 'manual_review':
          _stopBeamTimers();
          setState(() => _beamStatusMessage =
              _l10n.topupBeamManualReview);
          break;
        default:
          if (manual) {
            setState(() => _beamStatusMessage = _l10n.topupBeamNotFound);
          }
      }
    } catch (e) {
      debugLog('⚠️ beam status poll error: $e');
    } finally {
      _beamPollInFlight = false;
      if (manual && mounted) setState(() => _isCheckingStatus = false);
    }
  }

  String _beamCountdownText() {
    final exp = _beamCharge?.expiresAt;
    if (exp == null) return '';
    final left = exp.difference(DateTime.now());
    if (left.isNegative) return _l10n.topupBeamQrExpired;
    final m = left.inMinutes.toString().padLeft(2, '0');
    final sec = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return _l10n.topupBeamExpiresIn('$m:$sec');
  }

  Widget _buildBeamPaymentSection() {
    final jdc = context.jdc;
    final charge = _beamCharge!;
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.lg),
        child: Column(
          children: [
            Text(_l10n.topupBeamScanPrompt,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            const SizedBox(height: 4),
            Text(
              _l10n.topupBeamHowItWorks,
              style: TextStyle(fontSize: 13, color: jdc.muted),
              textAlign: TextAlign.center,
            ),
            if (charge.isPlayground) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: jdc.brandSoft,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Text(_l10n.topupBeamPlayground,
                    style: TextStyle(
                        fontSize: 12,
                        color: jdc.brandOnSoft,
                        fontWeight: FontWeight.w600,
                        fontVariations: _w(FontWeight.w600))),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: jdc.knob,
                borderRadius: BorderRadius.circular(JdcRadius.small),
                border: Border.all(color: jdc.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(JdcRadius.small),
                child: charge.qrImageBytes != null
                    ? Image.memory(charge.qrImageBytes!, fit: BoxFit.contain)
                    : Center(
                        child: Text(_l10n.topupBeamQrMissing,
                            style: TextStyle(color: jdc.muted))),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!
                  .topupAmount(charge.amount.toStringAsFixed(0)),
              style: _money(size: 20, color: jdc.cta),
            ),
            const SizedBox(height: 6),
            Text(_beamCountdownText(),
                style: TextStyle(fontSize: 13, color: jdc.muted)),
            const SizedBox(height: 12),
            if (_beamStatusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_beamStatusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: jdc.brandOnSoft)),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: jdc.cta)),
                  const SizedBox(width: 8),
                  Text(_l10n.topupBeamWaiting,
                      style: TextStyle(color: jdc.muted)),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isCheckingStatus
                        ? null
                        : () => _pollBeamStatus(manual: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: jdc.cta,
                      side: BorderSide(color: jdc.brandLine),
                      minimumSize: Size(double.infinity, JdcTouch.field),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.field),
                      ),
                    ),
                    child: Text(_l10n.topupBeamCheckStatus),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => setState(_resetBeamState),
                    style: TextButton.styleFrom(
                      foregroundColor: jdc.cta,
                      minimumSize: Size(double.infinity, JdcTouch.field),
                    ),
                    child: Text(_l10n.topupBeamNewQr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      _resetBeamState();
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
      _resetBeamState();
      _qrImageUrl = null;
      _requestSent = false;
      _autoTopupCompleted = false;
      _selectedSlipFile = null;
      _selectedSlipFileName = null;
    });

    // เช็คโหมดล่าสุดก่อนสร้าง QR (แอดมินอาจเพิ่งสลับ)
    await _loadTopupMode();
    if (_isBeamMode) {
      await _createBeamCharge(amount);
      return;
    }
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
      _showErrorDialog(_l10n.topupSlipAttachFirst);
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

      final message = _formatTopupVerificationResult(_l10n, result);
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
          _l10n,
          Map<String, dynamic>.from(details),
        );
      }

      final message = _humanizeSlipVerificationMessage(_l10n, details?.toString());
      if (message != null) return message;
    }

    final message = _humanizeSlipVerificationMessage(_l10n, error.toString());
    return message ??
        _l10n.topupSlipVerifyFailed;
  }

  String _formatTopupVerificationResult(
      AppLocalizations l10n, Map<String, dynamic> result) {
    final reason = result['reason']?.toString();
    final message = result['message']?.toString();

    switch (reason) {
      case 'slip2go_failed':
        return l10n.topupSlipReasonFailed;
      case 'amountMismatch':
        return l10n.topupSlipReasonAmount;
      case 'receiverMismatch':
        return l10n.topupSlipReasonReceiver;
      case 'duplicateSlip':
        return l10n.topupSlipReasonDuplicate;
      case 'rateLimited':
        return l10n.topupSlipReasonRate;
      case 'invalidAmount':
        return l10n.topupSlipReasonInvalidAmount;
      case 'invalidImage':
        return l10n.topupSlipReasonInvalidImage;
    }

    return _humanizeSlipVerificationMessage(l10n, message) ??
        l10n.topupSlipReasonFallback;
  }

  String? _humanizeSlipVerificationMessage(
      AppLocalizations l10n, String? rawMessage) {
    final normalized = rawMessage?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    final lower = normalized.toLowerCase();
    if (lower.contains('functionexception')) {
      if (lower.contains('fraud') || lower.contains('unprocessable entity')) {
        return l10n.topupSlipHumanFraud;
      }
      return null;
    }
    if (lower.contains('fraud') || lower.contains('unprocessable entity')) {
      return l10n.topupSlipHumanFraud;
    }
    if (lower.contains('duplicate')) {
      return l10n.topupSlipReasonDuplicate;
    }
    if (lower.contains('amount')) {
      return l10n.topupSlipReasonAmount;
    }
    if (lower.contains('receiver') || lower.contains('account')) {
      return l10n.topupSlipReasonReceiver;
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
      builder: (ctx) {
        final jdc = ctx.jdc;
        return AlertDialog(
          backgroundColor: jdc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card),
            side: BorderSide(color: jdc.line),
          ),
          icon: Icon(Icons.error_outline, color: jdc.danger, size: 48),
          title: Text(AppLocalizations.of(context)!.topupErrorTitle,
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
                child: Text(AppLocalizations.of(context)!.topupOk),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final jdc = ctx.jdc;
        return AlertDialog(
          backgroundColor: jdc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card),
            side: BorderSide(color: jdc.line),
          ),
          icon: Icon(Icons.hourglass_top, color: jdc.brandOnSoft, size: 48),
          title: Text(AppLocalizations.of(context)!.topupRequestSentTitle,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  fontSize: 18,
                  color: jdc.text)),
          content: Text(
            AppLocalizations.of(context)!
                .topupRequestSentBody(_selectedAmount.toStringAsFixed(0)),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: jdc.text),
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
                  backgroundColor: jdc.cta,
                  foregroundColor: jdc.onCta,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.small)),
                ),
                child: Text(AppLocalizations.of(context)!.topupOk),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final jdc = ctx.jdc;
        return AlertDialog(
          backgroundColor: jdc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card),
            side: BorderSide(color: jdc.line),
          ),
          icon: Icon(Icons.check_circle, color: jdc.successInk, size: 48),
          title: Text(AppLocalizations.of(context)!.topupSuccessTitle,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  fontSize: 18,
                  color: jdc.text)),
          content: Text(
            AppLocalizations.of(context)!
                .topupSuccessBody(_selectedAmount.toStringAsFixed(0)),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: jdc.text),
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
                  backgroundColor: jdc.cta,
                  foregroundColor: jdc.onCta,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.small)),
                ),
                child: Text(AppLocalizations.of(context)!.topupOk),
              ),
            ),
          ],
        );
      },
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
      builder: (ctx) {
        final jdc = ctx.jdc;
        return AlertDialog(
          backgroundColor: jdc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card),
            side: BorderSide(color: jdc.line),
          ),
          title: Text(AppLocalizations.of(context)!.topupWithdrawTitle,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  color: jdc.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    AppLocalizations.of(context)!.topupWithdrawBalance(
                        NumberFormat('#,##0.00').format(_currentBalance)),
                    style: TextStyle(color: jdc.muted, fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: withdrawController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: jdc.text),
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.topupWithdrawAmountLabel,
                    labelStyle: TextStyle(color: jdc.muted),
                    prefixText: '฿ ',
                    filled: true,
                    fillColor: jdc.sunken,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(JdcRadius.field)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNameController,
                  style: TextStyle(color: jdc.text),
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.topupWithdrawBankName,
                    labelStyle: TextStyle(color: jdc.muted),
                    hintText: AppLocalizations.of(context)!.topupWithdrawBankHint,
                    filled: true,
                    fillColor: jdc.sunken,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(JdcRadius.field)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNumController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: jdc.text),
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.topupWithdrawAccountNum,
                    labelStyle: TextStyle(color: jdc.muted),
                    filled: true,
                    fillColor: jdc.sunken,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(JdcRadius.field)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNameController,
                  style: TextStyle(color: jdc.text),
                  decoration: InputDecoration(
                    labelText:
                        AppLocalizations.of(context)!.topupWithdrawAccountName,
                    labelStyle: TextStyle(color: jdc.muted),
                    filled: true,
                    fillColor: jdc.sunken,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(JdcRadius.field)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(AppLocalizations.of(context)!.topupWithdrawCancel,
                  style: TextStyle(color: jdc.muted)),
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
                                backgroundColor: jdc.danger),
                      );
                        return;
                      }
                      if (amount > _currentBalance) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content:
                                  Text(l10n.topupWithdrawInsufficientBalance),
                              backgroundColor: jdc.danger),
                        );
                        return;
                      }
                      if (bankNameController.text.trim().isEmpty ||
                          accountNumController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text(l10n.topupWithdrawBankRequired),
                              backgroundColor: jdc.danger),
                        );
                        return;
                      }
                      final userId = AuthService.userId;
                      if (userId == null) return;
                      _isWithdrawing = true;
                      try {
                      // ถอนผ่าน RPC create_wallet_withdrawal_request (หักเงิน + ledger แบบ atomic ฝั่ง server)
                      final ok = await WithdrawalService().createWithdrawalRequest(
                        amount: amount,
                        bankName: bankNameController.text.trim(),
                        bankAccountNumber: accountNumController.text.trim(),
                        bankAccountName: accountNameController.text.trim(),
                      );
                      if (!ok) {
                        throw Exception(
                            _l10n.topupWithdrawRequestError);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    } catch (e) {
                      debugLog('❌ Error withdraw: $e');
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content:
                                  Text(l10n.topupWithdrawError(e.toString())),
                              backgroundColor: jdc.danger),
                        );
                      }
                    } finally {
                      _isWithdrawing = false;
                    }
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
              ),
              child: Text(AppLocalizations.of(context)!.topupWithdrawSubmit),
            ),
          ],
        );
      },
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
    final jdc = context.jdc;
    final bool hasQR = _qrImageUrl != null &&
        _qrImageUrl!.isNotEmpty &&
        !_requestSent &&
        !_autoTopupCompleted;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: jdc.line)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.topupTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  .topupWithdrawBalance(NumberFormat('#,##0.00').format(_currentBalance)),
              style: TextStyle(fontSize: 12, color: jdc.muted),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(JdcSpacing.lg),
              child: JdcContentFrame(
                maxWidth: JdcBreakpoints.formMaxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: JdcSpacing.xl),
                    _buildAmountSection(),
                    const SizedBox(height: JdcSpacing.xl),
                    if (_autoTopupCompleted) ...[
                      _buildAutoTopupCompletedCard(),
                    ] else if (_beamCharge != null) ...[
                      _buildBeamPaymentSection(),
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
                      height: JdcTouch.button,
                      child: OutlinedButton.icon(
                        onPressed: _showWithdrawDialog,
                        icon: Icon(Icons.account_balance, color: jdc.cta),
                        label: Text(
                            AppLocalizations.of(context)!.topupWithdrawBtn,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontVariations: _w(FontWeight.w700),
                                color: jdc.cta)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: jdc.brandLine, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.card)),
                        ),
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.xxl),
                    // ประวัติถอนเงิน
                    _buildWithdrawalHistorySection(),
                    const SizedBox(height: JdcSpacing.xxl),
                    // ประวัติเติมเงิน
                    _buildHistorySection(),
                    const SizedBox(height: JdcSpacing.xxxl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    final jdc = context.jdc;
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
          Text(AppLocalizations.of(context)!.walletBalance,
              style: TextStyle(
                  fontSize: 14,
                  color: jdc.panelDim,
                  fontWeight: FontWeight.w500,
                  fontVariations: _w(FontWeight.w500))),
          const SizedBox(height: JdcSpacing.xs),
          Text(
            '฿${NumberFormat('#,##0.00').format(_currentBalance)}',
            style: _money(size: 30, color: jdc.onPanel),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    final jdc = context.jdc;
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.topupSelectAmount,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return GestureDetector(
                  onTap: () => _selectAmount(amount),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: JdcTouch.button),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? jdc.brandSoft : jdc.surface,
                      borderRadius: BorderRadius.circular(JdcRadius.field),
                      border: Border.all(
                        color: isSelected ? jdc.brandLine : jdc.line,
                      ),
                    ),
                    child: Text(
                      '฿${amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: isSelected ? jdc.brandOnSoft : jdc.text,
                        fontWeight: FontWeight.w700,
                        fontVariations: _w(FontWeight.w700),
                        fontSize: 15,
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
              style: TextStyle(color: jdc.text),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.topupCustomAmount,
                labelStyle: TextStyle(color: jdc.muted),
                prefixText: '฿ ',
                prefixStyle: _money(size: 16),
                filled: true,
                fillColor: jdc.sunken,
                border: _fieldBorder(),
                enabledBorder: _fieldBorder(),
              ),
              onChanged: (value) {
                final amount = double.tryParse(value) ?? 0;
                setState(() {
                  _selectedAmount = amount;
                  // reset QR เมื่อเปลี่ยนจำนวนเงิน
                  _resetBeamState();
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
    final jdc = context.jdc;
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.lg),
        child: Column(
          children: [
            Text(AppLocalizations.of(context)!.topupScanQR,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.topupManualScanDesc,
              style: TextStyle(fontSize: 13, color: jdc.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: jdc.knob,
                borderRadius: BorderRadius.circular(JdcRadius.small),
                border: Border.all(color: jdc.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(JdcRadius.small),
                child: AppNetworkImage(
                  imageUrl: _qrImageUrl,
                  fit: BoxFit.contain,
                  backgroundColor: jdc.knob,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!
                  .topupAmount(_selectedAmount.toStringAsFixed(0)),
              style: _money(size: 20, color: jdc.cta),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 8),
            Text(
              _l10n.topupSlipStepHint,
              style: TextStyle(fontSize: 12, color: jdc.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSentCard() {
    final jdc = context.jdc;
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxl),
        child: Column(
          children: [
            Icon(Icons.hourglass_top, color: jdc.brandOnSoft, size: 48),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.topupRequestSentCard,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!
                  .topupRequestSentCardBody(_selectedAmount.toStringAsFixed(0)),
              style: TextStyle(fontSize: 14, color: jdc.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoTopupCompletedCard() {
    final jdc = context.jdc;
    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxl),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: jdc.successInk, size: 56),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.topupSuccessTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontVariations: _w(FontWeight.w700),
                color: jdc.successInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!
                  .topupSuccessBody(_selectedAmount.toStringAsFixed(0)),
              style: TextStyle(fontSize: 15, color: jdc.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _l10n.topupSlipAutoDone,
              style: TextStyle(
                  fontSize: 12,
                  color: jdc.link,
                  fontWeight: FontWeight.w500,
                  fontVariations: _w(FontWeight.w500)),
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
              label: Text(_l10n.topupSlipTopUpAgain),
              style: TextButton.styleFrom(foregroundColor: jdc.cta),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlipUploadSection() {
    final jdc = context.jdc;
    final hasSlip = _selectedSlipFile != null;

    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasSlip ? jdc.successSoft : jdc.infoSoft,
                    borderRadius: BorderRadius.circular(JdcRadius.small),
                  ),
                  child: Icon(
                    hasSlip ? Icons.check_circle : Icons.receipt_long,
                    color: hasSlip ? jdc.successInk : jdc.infoInk,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSlip ? _l10n.topupSlipSelected : _l10n.topupSlipAttachSlip,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontVariations: _w(FontWeight.w700),
                          color: jdc.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasSlip
                            ? (_selectedSlipFileName ?? _l10n.topupSlipReady)
                            : _l10n.topupSlipPickHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: jdc.muted,
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
              _l10n.topupSlipVerifyHint,
              style: TextStyle(
                fontSize: 12,
                color: jdc.muted,
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
                    label: Text(hasSlip ? _l10n.topupSlipChange : _l10n.topupSlipChoose),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: jdc.cta,
                      side: BorderSide(color: jdc.brandLine),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.field),
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
                    color: jdc.muted,
                    tooltip: _l10n.topupSlipRemove,
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
    final jdc = context.jdc;
    return SizedBox(
      width: double.infinity,
      height: JdcTouch.button,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateQR,
        icon: _isGenerating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: jdc.onCta))
            : const Icon(Icons.qr_code),
        label: Text(
          _isGenerating
              ? AppLocalizations.of(context)!.topupGeneratingQR
              : AppLocalizations.of(context)!.topupPayPromptPay,
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.card)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildConfirmTransferButton() {
    final jdc = context.jdc;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: JdcTouch.button,
          child: ElevatedButton.icon(
            onPressed: _isCheckingStatus || _selectedSlipFile == null
                ? null
                : _submitTopUpRequest,
            icon: _isCheckingStatus
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: jdc.onCta))
                : const Icon(Icons.receipt_long),
            label: Text(
              _isCheckingStatus
                  ? _l10n.topupSlipChecking
                  : _l10n.topupSlipCheckAndTopUp(_selectedAmount.toStringAsFixed(0)),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontVariations: _w(FontWeight.w700),
                  color: jdc.onCta),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: jdc.cta,
              foregroundColor: jdc.onCta,
              disabledBackgroundColor: jdc.cta.withValues(alpha: 0.6),
              disabledForegroundColor: jdc.onCta,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.card)),
              elevation: 0,
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
          style: TextButton.styleFrom(foregroundColor: jdc.muted),
        ),
      ],
    );
  }

  Widget _buildWithdrawalHistorySection() {
    final jdc = context.jdc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.topupWithdrawHistoryTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            if (_isLoadingHistory)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: jdc.cta),
              )
            else
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: jdc.link),
                onPressed: _loadHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_withdrawalHistory.isEmpty && !_isLoadingHistory)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(JdcSpacing.xxl),
            decoration: _cardDecoration(),
            child: Center(
              child: Text(
                  AppLocalizations.of(context)!.topupWithdrawHistoryEmpty,
                  style: TextStyle(color: jdc.muted, fontSize: 14)),
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
                ? jdc.successInk
                : status == 'rejected'
                    ? jdc.dangerInk
                    : status == 'cancelled'
                        ? jdc.muted
                        : jdc.brandOnSoft;
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

            return Container(
              margin: const EdgeInsets.only(bottom: JdcSpacing.sm),
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.circular(JdcRadius.small),
                border: Border.all(color: jdc.line),
              ),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor, size: 28),
                title: Text('-฿${NumberFormat('#,##0').format(amount)}',
                    style: _money(size: 16, color: jdc.dangerInk)),
                subtitle: Text('$bankName $accountNum\n$createdAt',
                    style: TextStyle(color: jdc.muted, fontSize: 12)),
                isThreeLine: true,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontVariations: _w(FontWeight.w600))),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildHistorySection() {
    final jdc = context.jdc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.topupHistoryTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            if (_isLoadingHistory)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: jdc.cta),
              )
            else
              IconButton(
                icon: Icon(Icons.refresh, size: 20, color: jdc.link),
                onPressed: _loadHistory,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_topupHistory.isEmpty && !_isLoadingHistory)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(JdcSpacing.xxl),
            decoration: _cardDecoration(),
            child: Center(
              child: Text(AppLocalizations.of(context)!.topupHistoryEmpty,
                  style: TextStyle(color: jdc.muted, fontSize: 14)),
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
            // สถานะจาก Beam: awaiting_payment / expired / failed
            final isBeamClosed = status == 'expired' || status == 'failed';
            final statusColor = status == 'completed'
                ? jdc.successInk
                : status == 'rejected'
                    ? jdc.dangerInk
                    : isBeamClosed
                        ? jdc.muted
                        : jdc.brandOnSoft;
            final statusText = status == 'completed'
                ? AppLocalizations.of(context)!.topupStatusApproved
                : status == 'rejected'
                    ? AppLocalizations.of(context)!.topupStatusRejected
                    : status == 'awaiting_payment'
                        ? AppLocalizations.of(context)!.topupStatusAwaiting
                        : status == 'expired'
                            ? AppLocalizations.of(context)!.topupStatusQrExpired
                            : status == 'failed'
                                ? AppLocalizations.of(context)!.topupStatusFailed
                                : AppLocalizations.of(context)!
                                    .topupStatusPending;
            final statusIcon = status == 'completed'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : isBeamClosed
                        ? Icons.remove_circle_outline
                        : Icons.hourglass_top;

            return Container(
              margin: const EdgeInsets.only(bottom: JdcSpacing.sm),
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.circular(JdcRadius.small),
                border: Border.all(color: jdc.line),
              ),
              child: ListTile(
                leading: Icon(statusIcon, color: statusColor, size: 28),
                title: Text('฿${NumberFormat('#,##0').format(amount)}',
                    style: _money(size: 16)),
                subtitle: Text(createdAt,
                    style: TextStyle(color: jdc.muted, fontSize: 12)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontVariations: _w(FontWeight.w600))),
                ),
              ),
            );
          }),
      ],
    );
  }
}
