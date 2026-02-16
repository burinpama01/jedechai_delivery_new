import 'dart:io';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/utils/platform_adaptive.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../customer/screens/services/delivery_map_picker_screen.dart';

/// Edit Merchant Profile Screen
///
/// Allows merchants to edit their shop profile information
class EditMerchantProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;

  const EditMerchantProfileScreen({
    super.key,
    required this.currentName,
    required this.currentEmail,
  });

  @override
  State<EditMerchantProfileScreen> createState() =>
      _EditMerchantProfileScreenState();
}

class _EditMerchantProfileScreenState extends State<EditMerchantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  File? _shopPhoto;
  String? _shopPhotoUrl;
  double? _shopLat;
  double? _shopLng;
  TimeOfDay _shopOpenTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _shopCloseTime = const TimeOfDay(hour: 22, minute: 0);
  Set<String> _shopOpenDays = {};
  bool _isLoading = false;

  static const List<String> _weekdayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun'
  ];
  static const Map<String, String> _weekdayThai = {
    'mon': 'จ',
    'tue': 'อ',
    'wed': 'พ',
    'thu': 'พฤ',
    'fri': 'ศ',
    'sat': 'ส',
    'sun': 'อา',
  };

  TimeOfDay _parseTimeString(String value,
      {TimeOfDay fallback = const TimeOfDay(hour: 8, minute: 0)}) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeString(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  List<String> _extractShopOpenDays(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((e) => e.toString().toLowerCase().trim())
          .where((e) => _weekdayKeys.contains(e))
          .toSet()
          .toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _loadAdditionalData();
  }

  Widget _buildTimeSelectCard({
    required String label,
    required TimeOfDay value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTimeString(value),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.access_time, color: AppTheme.accentOrange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickShopLocationOnMap() async {
    final initial = (_shopLat != null && _shopLng != null)
        ? LatLng(_shopLat!, _shopLng!)
        : null;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DeliveryMapPickerScreen(initialPosition: initial),
      ),
    );

    if (result == null) return;

    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    final address = result['address']?.toString();

    if (lat == null || lng == null) return;

    if (mounted) {
      setState(() {
        _shopLat = lat;
        _shopLng = lng;
        if (address != null && address.isNotEmpty) {
          _addressController.text = address;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAdditionalData() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
              'phone_number, shop_address, shop_photo_url, latitude, longitude, shop_open_time, shop_close_time, shop_open_days')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _phoneController.text = response['phone_number'] ?? '';
          _addressController.text = response['shop_address'] ?? '';
          _shopPhotoUrl = response['shop_photo_url'];
          _shopLat = (response['latitude'] as num?)?.toDouble();
          _shopLng = (response['longitude'] as num?)?.toDouble();
          _shopOpenTime = _parseTimeString(
            (response['shop_open_time'] as String?) ?? '08:00',
            fallback: const TimeOfDay(hour: 8, minute: 0),
          );
          _shopCloseTime = _parseTimeString(
            (response['shop_close_time'] as String?) ?? '22:00',
            fallback: const TimeOfDay(hour: 22, minute: 0),
          );
          _shopOpenDays =
              _extractShopOpenDays(response['shop_open_days']).toSet();
        });
      }
    } catch (e) {
      debugLog('Error loading additional data: $e');
    }
  }

  Future<void> _pickShopPhoto() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file != null && mounted) {
      setState(() => _shopPhoto = file);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      // Upload shop photo if a new one was selected
      if (_shopPhoto != null) {
        final uploadedUrl = await StorageService.uploadProfileImage(
          imageFile: _shopPhoto!,
          userId: userId,
        );
        if (uploadedUrl != null) {
          _shopPhotoUrl = uploadedUrl;
          debugLog('📷 Shop photo uploaded: $uploadedUrl');
        }
      }

      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'shop_address': _addressController.text.trim(),
        'shop_photo_url': _shopPhotoUrl ?? '',
        'latitude': _shopLat,
        'longitude': _shopLng,
        'shop_open_time': _formatTimeString(_shopOpenTime),
        'shop_close_time': _formatTimeString(_shopCloseTime),
        'shop_open_days': _shopOpenDays.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกข้อมูลสำเร็จ'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถบันทึกข้อมูลได้: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลร้าน'),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Shop Photo Upload
            Center(
              child: GestureDetector(
                onTap: _pickShopPhoto,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentOrange, width: 3),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipOval(
                          child: _shopPhoto != null
                              ? Image.file(
                                  _shopPhoto!,
                                  fit: BoxFit.cover,
                                )
                              : (_shopPhotoUrl != null &&
                                      _shopPhotoUrl!.isNotEmpty)
                                  ? AppNetworkImage(
                                      imageUrl: _shopPhotoUrl,
                                      fit: BoxFit.cover,
                                      backgroundColor: Colors.white,
                                    )
                                  : const GrayscaleLogoPlaceholder(
                                      fit: BoxFit.contain,
                                      backgroundColor: Colors.white,
                                    ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.accentOrange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('แตะเพื่อเปลี่ยนรูปร้าน',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            const SizedBox(height: 24),

            // Shop Name Field
            _buildTextField(
              controller: _nameController,
              label: 'ชื่อร้าน',
              icon: Icons.store,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อร้าน';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email Field (Read-only)
            _buildTextField(
              controller: TextEditingController(text: widget.currentEmail),
              label: 'อีเมล',
              icon: Icons.email,
              enabled: false,
            ),
            const SizedBox(height: 16),

            // Phone Field
            _buildTextField(
              controller: _phoneController,
              label: 'เบอร์โทรศัพท์',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (value.length < 9 || value.length > 10) {
                    return 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address Field
            _buildTextField(
              controller: _addressController,
              label: 'ที่อยู่ร้าน',
              icon: Icons.location_on,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickShopLocationOnMap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_drop, color: AppTheme.accentOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ปักหมุดตำแหน่งร้าน',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_shopLat != null && _shopLng != null)
                                ? 'Lat: ${_shopLat!.toStringAsFixed(5)}, Lng: ${_shopLng!.toStringAsFixed(5)}'
                                : 'ยังไม่ได้เลือกตำแหน่งบนแผนที่',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'วันที่เปิดร้าน',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekdayKeys.map((day) {
                final isSelected = _shopOpenDays.contains(day);
                return FilterChip(
                  label: Text(_weekdayThai[day] ?? day),
                  selected: isSelected,
                  selectedColor: AppTheme.accentOrange.withValues(alpha: 0.18),
                  checkmarkColor: AppTheme.accentOrange,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.accentOrange : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.accentOrange
                        : Colors.grey.shade300,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _shopOpenDays.add(day);
                      } else {
                        _shopOpenDays.remove(day);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimeSelectCard(
                    label: 'เวลาเปิด',
                    value: _shopOpenTime,
                    onTap: () async {
                      final picked = await PlatformAdaptive.pickTime(
                        context: context,
                        initialTime: _shopOpenTime,
                        title: 'เวลาเปิด',
                      );
                      if (picked != null) {
                        setState(() => _shopOpenTime = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeSelectCard(
                    label: 'เวลาปิด',
                    value: _shopCloseTime,
                    onTap: () async {
                      final picked = await PlatformAdaptive.pickTime(
                        context: context,
                        initialTime: _shopCloseTime,
                        title: 'เวลาปิด',
                      );
                      if (picked != null) {
                        setState(() => _shopCloseTime = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_shopOpenDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('กรุณาเลือกวันเปิดร้านอย่างน้อย 1 วัน'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        _saveProfile();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'บันทึกข้อมูล',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.accentOrange),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accentOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}
