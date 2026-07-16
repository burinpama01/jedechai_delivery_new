import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../services/auth_service.dart';
import '../services/gp_plan_service.dart';
import '../services/image_picker_service.dart';
import '../services/storage_service.dart';
import '../utils/profile_completion_policy.dart';
import '../../l10n/app_localizations.dart';
import 'app_network_image.dart';
import '../../theme/app_theme.dart';

/// หน้ากรอกข้อมูลโปรไฟล์หลังจากแอดมินอนุมัติ (ใช้ครั้งแรก)
/// สำหรับคนขับ: ชื่อ, เบอร์โทร, ประเภทรถ, ทะเบียน, ข้อมูลธนาคาร
/// สำหรับร้านค้า: ชื่อร้าน, เบอร์โทร, ที่อยู่ร้าน, ข้อมูลธนาคาร
class ProfileCompletionScreen extends StatefulWidget {
  final String role;
  final Map<String, dynamic>? existingProfile;
  final VoidCallback onCompleted;

  const ProfileCompletionScreen({
    super.key,
    required this.role,
    this.existingProfile,
    required this.onCompleted,
  });

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  int _currentStep = 0;

  // Common
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Driver
  final _vehicleTypeController = TextEditingController();
  final _licensePlateController = TextEditingController();

  // Merchant
  final _shopAddressController = TextEditingController();

  // Bank
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();

  String _selectedVehicleType = 'motorcycle';
  String? _selectedMerchantServiceType;

  // GP plan selection (merchant ที่ยังไม่ผ่านการอนุมัติเท่านั้น)
  List<Map<String, dynamic>> _gpPlans = [];
  bool _gpPlansLoading = false;
  String? _gpPlansError;
  String? _selectedGpPlanId;

  // Driver document uploads
  File? _idCardFile;
  File? _driverLicenseFile;
  File? _vehiclePhotoFile;
  File? _licensePlatePhotoFile;

  // จับค่าครั้งเดียวตอนเปิดหน้า กัน step index เพี้ยนถ้า approval_status
  // เปลี่ยนระหว่างที่ผู้ใช้ค้างอยู่ในหน้านี้
  late final bool _gpStepAllowed;

  // แพ็กเกจ GP เป็นเงื่อนไขของร้านอาหาร (ค่าส่ง/กม.) — ร้านซักรีดไม่ต้องเลือก
  bool get _showGpPlanStep =>
      _gpStepAllowed && _selectedMerchantServiceType == 'food';

  @override
  void initState() {
    super.initState();
    // แสดงขั้นตอนเลือกแพ็กเกจ GP เฉพาะร้านที่ยังไม่ผ่านการอนุมัติ
    // (ร้านที่อนุมัติแล้ว การเปลี่ยน GP ต้องให้แอดมินทำ)
    _gpStepAllowed = widget.role == 'merchant' &&
        (widget.existingProfile?['approval_status'] as String?) != 'approved';
    _prefillFromExisting();
    if (_gpStepAllowed) {
      _loadGpPlans();
    }
  }

  Future<void> _loadGpPlans() async {
    setState(() {
      _gpPlansLoading = true;
      _gpPlansError = null;
    });
    try {
      final plans = await GpPlanService.fetchActivePlans();
      if (!mounted) return;
      setState(() {
        _gpPlans = plans;
        _gpPlansLoading = false;
        // preselect ถ้าเคยเลือกไว้แล้ว
        final existingPlanId =
            widget.existingProfile?['gp_plan_id']?.toString();
        if (_selectedGpPlanId == null &&
            existingPlanId != null &&
            plans.any((p) => p['id'].toString() == existingPlanId)) {
          _selectedGpPlanId = existingPlanId;
        }
      });
    } catch (e) {
      debugLog('❌ Error loading GP plans: $e');
      if (!mounted) return;
      setState(() {
        _gpPlansLoading = false;
        _gpPlansError = e.toString();
      });
    }
  }

  void _prefillFromExisting() {
    final p = widget.existingProfile;
    if (p == null) return;
    _fullNameController.text = p['full_name'] ?? '';
    _phoneController.text = p['phone_number'] ?? '';
    _vehicleTypeController.text = p['vehicle_type'] ?? '';
    _licensePlateController.text = p['license_plate'] ?? '';
    _shopAddressController.text = p['shop_address'] ?? '';
    _bankNameController.text = p['bank_name'] ?? '';
    _bankAccountNumberController.text = p['bank_account_number'] ?? '';
    _bankAccountNameController.text = p['bank_account_name'] ?? '';
    _selectedMerchantServiceType =
        normalizeMerchantServiceType(p['merchant_service_types']);
    if (p['vehicle_type'] != null && p['vehicle_type'].toString().isNotEmpty) {
      _selectedVehicleType = _normalizeVehicleTypeLabel(p['vehicle_type']);
    }
  }

  String _normalizeVehicleTypeLabel(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    final lower = raw.toLowerCase();

    if (raw.contains('มอเตอร์') ||
        lower == 'motorcycle' ||
        lower.contains('moto') ||
        lower.contains('bike')) {
      return 'motorcycle';
    }

    if (raw.contains('รถยนต์') ||
        lower == 'car' ||
        lower.contains('car') ||
        lower.contains('sedan')) {
      return 'car';
    }

    return raw;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _licensePlateController.dispose();
    _shopAddressController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  bool get _isDriver => widget.role == 'driver';

  Future<void> _pickDocument(String type) async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file == null) return;
    setState(() {
      switch (type) {
        case 'id_card':
          _idCardFile = file;
          break;
        case 'license':
          _driverLicenseFile = file;
          break;
        case 'vehicle':
          _vehiclePhotoFile = file;
          break;
        case 'plate':
          _licensePlatePhotoFile = file;
          break;
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isDriver && !_ensureMerchantServiceTypeSelected()) return;
    if (_showGpPlanStep && !_ensureGpPlanSelected()) return;

    setState(() => _isSaving = true);

    try {
      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception(AppLocalizations.of(context)!.menuMgmtUserNotFound);
      }

      final updateData = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'bank_account_number': _bankAccountNumberController.text.trim(),
        'bank_account_name': _bankAccountNameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isDriver) {
        updateData['vehicle_type'] = _selectedVehicleType;
        updateData['license_plate'] = _licensePlateController.text.trim();
        // Upload documents if selected
        if (_idCardFile != null) {
          final url = await StorageService.uploadImage(
              imageFile: _idCardFile!, folder: 'driver_docs/$userId/id_card');
          if (url != null) updateData['id_card_url'] = url;
        }
        if (_driverLicenseFile != null) {
          final url = await StorageService.uploadImage(
              imageFile: _driverLicenseFile!,
              folder: 'driver_docs/$userId/license');
          if (url != null) updateData['driver_license_url'] = url;
        }
        if (_vehiclePhotoFile != null) {
          final url = await StorageService.uploadImage(
              imageFile: _vehiclePhotoFile!,
              folder: 'driver_docs/$userId/vehicle');
          if (url != null) updateData['vehicle_registration_url'] = url;
        }
        if (_licensePlatePhotoFile != null) {
          final url = await StorageService.uploadImage(
              imageFile: _licensePlatePhotoFile!,
              folder: 'driver_docs/$userId/plate');
          if (url != null) updateData['vehicle_plate'] = url;
        }
      } else {
        updateData['shop_address'] = _shopAddressController.text.trim();
        updateData['merchant_service_types'] = [_selectedMerchantServiceType!];
      }

      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);

      // เลือกแพ็กเกจ GP (ค่า GP/ค่าส่งถูก copy ลง profile ฝั่ง server)
      // ถ้าเลือกไม่สำเร็จ policy จะพากลับมาหน้านี้ใหม่จนกว่าจะสำเร็จ
      if (_showGpPlanStep && _selectedGpPlanId != null) {
        try {
          await GpPlanService.selectPlan(_selectedGpPlanId!);
        } catch (e) {
          // แอดมินอนุมัติระหว่างกรอก -> การตั้ง GP เป็นหน้าที่แอดมินแล้ว ไปต่อได้
          if (e.toString().contains('already_approved')) {
            debugLog('⚠️ GP plan skipped: merchant already approved');
          } else {
            rethrow;
          }
        }
      }

      debugLog('✅ Profile completed for $userId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.profileCompleteSaveSuccess),
          ),
        );
        widget.onCompleted();
      }
    } catch (e) {
      debugLog('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .profileCompleteError(e.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roleText = _isDriver
        ? l10n.profileCompleteRoleDriver
        : l10n.profileCompleteRoleMerchant;
    final steps = _isDriver
        ? [
            l10n.profileCompleteStepPersonalTitle,
            l10n.profileCompleteStepVehicleTitle,
            l10n.profileCompleteStepDocsTitle,
            l10n.profileCompleteStepBankTitle,
          ]
        : [
            l10n.profileCompleteStepMerchantTitle,
            if (_showGpPlanStep) 'แพ็กเกจ GP',
            l10n.profileCompleteStepBankTitle,
          ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.profileCompleteTitle(roleText)),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: colorScheme.onPrimary,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await AuthService.signOut();
            },
            icon: Icon(
              Icons.logout,
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
              size: 18,
            ),
            label: Text(
              l10n.profileCompleteLogout,
              style: TextStyle(
                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Stepper header
            Container(
              color: colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Row(
                children: List.generate(steps.length, (i) {
                  final isActive = i == _currentStep;
                  final isDone = i < _currentStep;
                  return Expanded(
                    child: Row(
                      children: [
                        if (i > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isDone
                                  ? AppTheme.primaryGreen
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                        GestureDetector(
                          onTap: () => setState(() => _currentStep = i),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isActive
                                    ? AppTheme.primaryGreen
                                    : isDone
                                        ? colorScheme.primaryContainer
                                        : colorScheme.outlineVariant,
                                child: isDone
                                    ? Icon(
                                        Icons.check,
                                        color: colorScheme.onPrimaryContainer,
                                        size: 16,
                                      )
                                    : Text('${i + 1}',
                                        style: TextStyle(
                                          color: isActive
                                              ? colorScheme.onPrimary
                                              : colorScheme.onSurfaceVariant,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        )),
                              ),
                              const SizedBox(height: 4),
                              Text(steps[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isActive
                                        ? AppTheme.primaryGreen
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ],
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isDone || isActive
                                  ? AppTheme.primaryGreen
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildStepContent(),
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l10n.profileCompleteBack),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Text(
                              _currentStep < steps.length - 1
                                  ? l10n.profileCompleteNext
                                  : l10n.profileCompleteSaveStart,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNext() {
    final steps = _isDriver ? 4 : (_showGpPlanStep ? 3 : 2);
    if (!_isDriver &&
        _currentStep == 0 &&
        !_ensureMerchantServiceTypeSelected()) {
      return;
    }

    // ต้องเลือกแพ็กเกจ GP ก่อนไปขั้นถัดไป
    if (_showGpPlanStep && _currentStep == 1 && !_ensureGpPlanSelected()) {
      return;
    }

    // Validate document uploads on step 2 for drivers
    if (_isDriver && _currentStep == 2) {
      final missing = <String>[];
      final l10n = AppLocalizations.of(context)!;
      if (_idCardFile == null) {
        missing.add(l10n.profileCompleteDocIdCard);
      }
      if (_driverLicenseFile == null) {
        missing.add(l10n.profileCompleteDocDriverLicense);
      }
      if (_vehiclePhotoFile == null) {
        missing.add(l10n.profileCompleteDocVehiclePhoto);
      }
      if (_licensePlatePhotoFile == null) {
        missing.add(l10n.profileCompleteDocPlatePhoto);
      }

      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .profileCompleteUploadMissing(missing.join(", "))),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    if (_currentStep < steps - 1) {
      setState(() => _currentStep++);
    } else {
      _saveProfile();
    }
  }

  bool _ensureMerchantServiceTypeSelected() {
    if (_selectedMerchantServiceType != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณาเลือกประเภทร้าน')),
    );
    return false;
  }

  bool _ensureGpPlanSelected() {
    if (_selectedGpPlanId != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กรุณาเลือกแพ็กเกจ GP สำหรับร้านของคุณ')),
    );
    return false;
  }

  static String _fmtNum(dynamic value) {
    final n = (value is num) ? value : num.tryParse(value?.toString() ?? '');
    if (n == null) return '0';
    if (n == n.roundToDouble()) return n.round().toString();
    return n.toString();
  }

  Widget _buildGpPlanStep({Key? key}) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget body;
    if (_gpPlansLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_gpPlansError != null) {
      body = Column(
        children: [
          const SizedBox(height: 8),
          Icon(Icons.wifi_off, color: colorScheme.error, size: 36),
          const SizedBox(height: 8),
          Text(
            'โหลดแพ็กเกจ GP ไม่สำเร็จ',
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadGpPlans,
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
          ),
        ],
      );
    } else if (_gpPlans.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'ยังไม่มีแพ็กเกจ GP ให้เลือกในขณะนี้ กรุณาติดต่อแอดมิน',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      body = Column(
        children: [
          for (final plan in _gpPlans) ...[
            _buildGpPlanCard(plan),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return _StepCard(
      key: key,
      icon: Icons.percent,
      title: 'เลือกแพ็กเกจ GP',
      subtitle: 'เลือกรูปแบบที่ใช่สำหรับร้านคุณ (เปลี่ยนภายหลังได้โดยติดต่อแอดมิน)',
      children: [body],
    );
  }

  Widget _buildGpPlanCard(Map<String, dynamic> plan) {
    final colorScheme = Theme.of(context).colorScheme;
    final planId = plan['id'].toString();
    final isSelected = _selectedGpPlanId == planId;
    final name = (plan['name'] as String?)?.trim() ?? 'แพ็กเกจ';
    final description = (plan['description'] as String?)?.trim();

    final gpRate = (plan['gp_rate'] as num?)?.toDouble() ?? 0;
    final gpPercent = _fmtNum(gpRate * 100);
    final baseFee = _fmtNum(plan['base_delivery_fee']);
    final baseKm = _fmtNum(plan['base_distance_km']);
    final perKm = _fmtNum(plan['per_km_charge']);

    return InkWell(
      onTap: () => setState(() => _selectedGpPlanId = planId),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryGreen : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppTheme.primaryGreen.withValues(alpha: 0.06)
              : colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppTheme.primaryGreen
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'หัก GP $gpPercent%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ค่าส่ง $baseFee ฿ ในระยะ $baseKm กิโลเมตรจากร้าน',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'เมื่อเกินระยะคิด $perKm บาท/กิโลเมตร',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    if (_isDriver) {
      switch (_currentStep) {
        case 0:
          return _buildPersonalInfoStep(key: const ValueKey('driver_personal'));
        case 1:
          return _buildVehicleInfoStep(key: const ValueKey('driver_vehicle'));
        case 2:
          return _buildDocumentUploadStep(key: const ValueKey('driver_docs'));
        case 3:
          return _buildBankInfoStep(key: const ValueKey('driver_bank'));
      }
    } else if (_showGpPlanStep) {
      switch (_currentStep) {
        case 0:
          return _buildMerchantInfoStep(key: const ValueKey('merchant_info'));
        case 1:
          return _buildGpPlanStep(key: const ValueKey('merchant_gp_plan'));
        case 2:
          return _buildBankInfoStep(key: const ValueKey('merchant_bank'));
      }
    } else {
      switch (_currentStep) {
        case 0:
          return _buildMerchantInfoStep(key: const ValueKey('merchant_info'));
        case 1:
          return _buildBankInfoStep(key: const ValueKey('merchant_bank'));
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildPersonalInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.person,
      title: AppLocalizations.of(context)!.profileCompleteStepPersonalTitle,
      subtitle:
          AppLocalizations.of(context)!.profileCompleteStepPersonalSubtitle,
      children: [
        _buildField(
          controller: _fullNameController,
          label: AppLocalizations.of(context)!.profileCompleteFullNameLabel,
          icon: Icons.badge,
          validator: (v) => v == null || v.trim().isEmpty
              ? AppLocalizations.of(context)!.profileCompleteFullNameRequired
              : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _phoneController,
          label: AppLocalizations.of(context)!.profileCompletePhoneLabel,
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.trim().length < 9
              ? AppLocalizations.of(context)!.profileCompletePhoneRequired
              : null,
        ),
      ],
    );
  }

  Widget _buildVehicleInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.directions_car,
      title: AppLocalizations.of(context)!.profileCompleteStepVehicleTitle,
      subtitle:
          AppLocalizations.of(context)!.profileCompleteStepVehicleSubtitle,
      children: [
        Text(
          AppLocalizations.of(context)!.profileCompleteVehicleTypeLabel,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            _vehicleChip(
              'motorcycle',
              AppLocalizations.of(context)!.profileCompleteVehicleMotorcycle,
              Icons.two_wheeler,
            ),
            _vehicleChip(
              'car',
              AppLocalizations.of(context)!.profileCompleteVehicleCar,
              Icons.directions_car,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _licensePlateController,
          label: AppLocalizations.of(context)!.profileCompletePlateLabel,
          icon: Icons.confirmation_number,
          validator: (v) => v == null || v.trim().isEmpty
              ? AppLocalizations.of(context)!.profileCompletePlateRequired
              : null,
        ),
      ],
    );
  }

  Widget _buildDocumentUploadStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.folder_open,
      title: AppLocalizations.of(context)!.profileCompleteStepDocsTitle,
      subtitle: AppLocalizations.of(context)!.profileCompleteStepDocsSubtitle,
      children: [
        _buildDocUploadTile(
          label: AppLocalizations.of(context)!.profileCompleteDocIdCard,
          icon: Icons.credit_card,
          file: _idCardFile,
          onTap: () => _pickDocument('id_card'),
        ),
        const SizedBox(height: 12),
        _buildDocUploadTile(
          label: AppLocalizations.of(context)!.profileCompleteDocDriverLicense,
          icon: Icons.badge,
          file: _driverLicenseFile,
          onTap: () => _pickDocument('license'),
        ),
        const SizedBox(height: 12),
        _buildDocUploadTile(
          label: AppLocalizations.of(context)!.profileCompleteDocVehiclePhoto,
          icon: Icons.directions_car,
          file: _vehiclePhotoFile,
          onTap: () => _pickDocument('vehicle'),
        ),
        const SizedBox(height: 12),
        _buildDocUploadTile(
          label: AppLocalizations.of(context)!.profileCompleteDocPlatePhoto,
          icon: Icons.confirmation_number,
          file: _licensePlatePhotoFile,
          onTap: () => _pickDocument('plate'),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.profileCompleteDocsHint,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDocUploadTile({
    required String label,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppTheme.primaryGreen : colorScheme.outlineVariant,
            width: hasFile ? 2 : 1,
          ),
          color: hasFile
              ? AppTheme.primaryGreen.withValues(alpha: 0.05)
              : colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: hasFile
                  ? AppTheme.primaryGreen
                  : colorScheme.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: hasFile
                            ? AppTheme.primaryGreen
                            : colorScheme.onSurface,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    hasFile
                        ? AppLocalizations.of(context)!
                            .profileCompleteDocSelected
                        : AppLocalizations.of(context)!
                            .profileCompleteDocTapToPick,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasFile
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFile)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppFileImage(file: file, width: 48, height: 48),
              )
            else
              Icon(Icons.add_a_photo, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _vehicleChip(String value, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedVehicleType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      onSelected: (_) => setState(() => _selectedVehicleType = value),
    );
  }

  Widget _buildMerchantInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.store,
      title: AppLocalizations.of(context)!.profileCompleteStepMerchantTitle,
      subtitle:
          AppLocalizations.of(context)!.profileCompleteStepMerchantSubtitle,
      children: [
        _buildField(
          controller: _fullNameController,
          label: AppLocalizations.of(context)!.profileCompleteMerchantNameLabel,
          icon: Icons.storefront,
          validator: (v) => v == null || v.trim().isEmpty
              ? AppLocalizations.of(context)!.profileCompleteFullNameRequired
              : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _phoneController,
          label: AppLocalizations.of(context)!.profileCompletePhoneLabel,
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.trim().length < 9
              ? AppLocalizations.of(context)!.profileCompletePhoneRequired
              : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _shopAddressController,
          label: AppLocalizations.of(context)!.profileCompleteAddressLabel,
          icon: Icons.location_on,
          maxLines: 2,
          validator: (v) => v == null || v.trim().isEmpty
              ? AppLocalizations.of(context)!.profileCompleteAddressRequired
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          'ประเภทร้าน',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _merchantServiceTypeChip('food', 'Food', Icons.restaurant),
            _merchantServiceTypeChip(
              'laundry',
              'Laundry',
              Icons.local_laundry_service,
            ),
          ],
        ),
      ],
    );
  }

  Widget _merchantServiceTypeChip(String value, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedMerchantServiceType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
      ),
      onSelected: (_) => setState(() => _selectedMerchantServiceType = value),
    );
  }

  Widget _buildBankInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.account_balance,
      title: AppLocalizations.of(context)!.profileCompleteStepBankTitle,
      subtitle: AppLocalizations.of(context)!.profileCompleteStepBankSubtitle,
      children: [
        _buildField(
          controller: _bankNameController,
          label: AppLocalizations.of(context)!.profileCompleteBankNameLabel,
          icon: Icons.account_balance,
          hint: AppLocalizations.of(context)!.profileCompleteBankNameHint,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _bankAccountNumberController,
          label: AppLocalizations.of(context)!
              .profileCompleteBankAccountNumberLabel,
          icon: Icons.numbers,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _bankAccountNameController,
          label:
              AppLocalizations.of(context)!.profileCompleteBankAccountNameLabel,
          icon: Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _StepCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}
