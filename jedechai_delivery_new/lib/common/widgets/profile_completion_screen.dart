import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../services/auth_service.dart';
import '../services/image_picker_service.dart';
import '../services/storage_service.dart';
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
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
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

  String _selectedVehicleType = 'มอเตอร์ไซค์';

  // Driver document uploads
  File? _idCardFile;
  File? _driverLicenseFile;
  File? _vehiclePhotoFile;
  File? _licensePlatePhotoFile;

  @override
  void initState() {
    super.initState();
    _prefillFromExisting();
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
      return 'มอเตอร์ไซค์';
    }

    if (raw.contains('รถยนต์') ||
        lower == 'car' ||
        lower.contains('car') ||
        lower.contains('sedan')) {
      return 'รถยนต์';
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
        case 'id_card': _idCardFile = file; break;
        case 'license': _driverLicenseFile = file; break;
        case 'vehicle': _vehiclePhotoFile = file; break;
        case 'plate': _licensePlatePhotoFile = file; break;
      }
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      final updateData = <String, dynamic>{
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'bank_account_number': _bankAccountNumberController.text.trim(),
        'bank_account_name': _bankAccountNameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isDriver) {
        updateData['vehicle_type'] = _normalizeVehicleTypeLabel(_selectedVehicleType);
        updateData['license_plate'] = _licensePlateController.text.trim();
        // Upload documents if selected
        if (_idCardFile != null) {
          final url = await StorageService.uploadImage(imageFile: _idCardFile!, folder: 'driver_docs/$userId/id_card');
          if (url != null) updateData['id_card_url'] = url;
        }
        if (_driverLicenseFile != null) {
          final url = await StorageService.uploadImage(imageFile: _driverLicenseFile!, folder: 'driver_docs/$userId/license');
          if (url != null) updateData['driver_license_url'] = url;
        }
        if (_vehiclePhotoFile != null) {
          final url = await StorageService.uploadImage(imageFile: _vehiclePhotoFile!, folder: 'driver_docs/$userId/vehicle');
          if (url != null) updateData['vehicle_registration_url'] = url;
        }
        if (_licensePlatePhotoFile != null) {
          final url = await StorageService.uploadImage(imageFile: _licensePlatePhotoFile!, folder: 'driver_docs/$userId/plate');
          if (url != null) updateData['vehicle_plate'] = url;
        }
      } else {
        updateData['shop_address'] = _shopAddressController.text.trim();
      }

      await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId);

      debugLog('✅ Profile completed for $userId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ บันทึกข้อมูลโปรไฟล์สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCompleted();
      }
    } catch (e) {
      debugLog('❌ Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleText = _isDriver ? 'คนขับ' : 'ร้านค้า';
    final steps = _isDriver
        ? ['ข้อมูลส่วนตัว', 'ข้อมูลรถ', 'เอกสาร', 'ธนาคาร']
        : ['ข้อมูลร้านค้า', 'ข้อมูลธนาคาร'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('กรอกข้อมูล$roleText'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
            label: const Text('ออกจากระบบ', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Stepper header
            Container(
              color: Colors.white,
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
                              color: isDone ? AppTheme.primaryGreen : Colors.grey[300],
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
                                        ? Colors.green[300]
                                        : Colors.grey[300],
                                child: isDone
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : Text('${i + 1}',
                                        style: TextStyle(
                                          color: isActive ? Colors.white : Colors.grey[600],
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        )),
                              ),
                              const SizedBox(height: 4),
                              Text(steps[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isActive ? AppTheme.primaryGreen : Colors.grey[500],
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  )),
                            ],
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isDone || isActive ? AppTheme.primaryGreen : Colors.grey[300],
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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ย้อนกลับ'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              _currentStep < steps.length - 1 ? 'ถัดไป' : 'บันทึกและเริ่มใช้งาน',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    final steps = _isDriver ? 4 : 2;
    
    // Validate document uploads on step 2 for drivers
    if (_isDriver && _currentStep == 2) {
      final missing = <String>[];
      if (_idCardFile == null) missing.add('รูปบัตรประชาชน');
      if (_driverLicenseFile == null) missing.add('ใบขับขี่');
      if (_vehiclePhotoFile == null) missing.add('รูปรถ');
      if (_licensePlatePhotoFile == null) missing.add('รูปป้ายทะเบียน');
      
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กรุณาอัปโหลด: ${missing.join(", ")}'),
            backgroundColor: Colors.red,
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
      title: 'ข้อมูลส่วนตัว',
      subtitle: 'กรุณากรอกข้อมูลของคุณ',
      children: [
        _buildField(
          controller: _fullNameController,
          label: 'ชื่อ-นามสกุล',
          icon: Icons.badge,
          validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _phoneController,
          label: 'เบอร์โทรศัพท์',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.trim().length < 9 ? 'กรุณากรอกเบอร์โทร' : null,
        ),
      ],
    );
  }

  Widget _buildVehicleInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.directions_car,
      title: 'ข้อมูลรถ',
      subtitle: 'กรุณาเลือกประเภทรถและกรอกทะเบียน',
      children: [
        const Text('ประเภทรถ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            _vehicleChip('มอเตอร์ไซค์', 'มอเตอร์ไซค์', Icons.two_wheeler),
            _vehicleChip('รถยนต์', 'รถยนต์', Icons.directions_car),
          ],
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _licensePlateController,
          label: 'เลขทะเบียนรถ',
          icon: Icons.confirmation_number,
          validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกทะเบียน' : null,
        ),
      ],
    );
  }

  Widget _buildDocumentUploadStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.folder_open,
      title: 'อัปโหลดเอกสาร',
      subtitle: 'กรุณาถ่ายรูปเอกสารของคุณ',
      children: [
        _buildDocUploadTile(
          label: 'รูปบัตรประชาชน',
          icon: Icons.credit_card,
          file: _idCardFile,
          onTap: () => _pickDocument('id_card'),
        ),
        const SizedBox(height: 12),
        _buildDocUploadTile(
          label: 'ใบขับขี่',
          icon: Icons.badge,
          file: _driverLicenseFile,
          onTap: () => _pickDocument('license'),
        ),
        const SizedBox(height: 12),
        _buildDocUploadTile(
          label: 'รูปรถ',
          icon: Icons.directions_car,
          file: _vehiclePhotoFile,
          onTap: () => _pickDocument('vehicle'),
        ),
        const SizedBox(height: 12),
        _buildDocUploadTile(
          label: 'รูปป้ายทะเบียน',
          icon: Icons.confirmation_number,
          file: _licensePlatePhotoFile,
          onTap: () => _pickDocument('plate'),
        ),
        const SizedBox(height: 8),
        Text(
          '* กรุณาอัปโหลดเอกสารทั้ง 4 รายการ',
          style: TextStyle(fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w500),
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
    final hasFile = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppTheme.primaryGreen : Colors.grey[300]!,
            width: hasFile ? 2 : 1,
          ),
          color: hasFile ? AppTheme.primaryGreen.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: hasFile ? AppTheme.primaryGreen : Colors.grey[400], size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hasFile ? AppTheme.primaryGreen : Colors.grey[700],
                  )),
                  const SizedBox(height: 2),
                  Text(
                    hasFile ? 'เลือกรูปแล้ว ✓' : 'แตะเพื่อถ่ายรูปหรือเลือกจากแกลเลอรี',
                    style: TextStyle(fontSize: 12, color: hasFile ? Colors.green[600] : Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (hasFile)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover),
              )
            else
              Icon(Icons.add_a_photo, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _vehicleChip(String value, String label, IconData icon) {
    final isSelected = _selectedVehicleType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey[600]),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryGreen,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[700]),
      onSelected: (_) => setState(() => _selectedVehicleType = value),
    );
  }

  Widget _buildMerchantInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.store,
      title: 'ข้อมูลร้านค้า',
      subtitle: 'กรุณากรอกข้อมูลร้านค้าของคุณ',
      children: [
        _buildField(
          controller: _fullNameController,
          label: 'ชื่อร้านค้า / เจ้าของ',
          icon: Icons.storefront,
          validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _phoneController,
          label: 'เบอร์โทรศัพท์',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.trim().length < 9 ? 'กรุณากรอกเบอร์โทร' : null,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _shopAddressController,
          label: 'ที่อยู่ร้าน',
          icon: Icons.location_on,
          maxLines: 2,
          validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกที่อยู่' : null,
        ),
      ],
    );
  }

  Widget _buildBankInfoStep({Key? key}) {
    return _StepCard(
      key: key,
      icon: Icons.account_balance,
      title: 'ข้อมูลธนาคาร',
      subtitle: 'สำหรับรับเงินจากระบบ (ไม่บังคับ)',
      children: [
        _buildField(
          controller: _bankNameController,
          label: 'ชื่อธนาคาร',
          icon: Icons.account_balance,
          hint: 'เช่น กสิกรไทย, ไทยพาณิชย์',
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _bankAccountNumberController,
          label: 'เลขบัญชี',
          icon: Icons.numbers,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _buildField(
          controller: _bankAccountNameController,
          label: 'ชื่อบัญชี',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
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
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
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
