import 'dart:io';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../../theme/jdc_colors.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/utils/platform_adaptive.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../l10n/app_localizations.dart';
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
  Map<String, String> _weekdayLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return {
      'mon': l10n.editProfileDayMon,
      'tue': l10n.editProfileDayTue,
      'wed': l10n.editProfileDayWed,
      'thu': l10n.editProfileDayThu,
      'fri': l10n.editProfileDayFri,
      'sat': l10n.editProfileDaySat,
      'sun': l10n.editProfileDaySun,
    };
  }

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
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
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
                Icon(Icons.access_time, color: JdcColors.of(context).cta),
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
        throw Exception(AppLocalizations.of(context)!.menuMgmtUserNotFound);
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
          SnackBar(
            content: Text(AppLocalizations.of(context)!.editProfileSaveSuccess),
            backgroundColor: JdcColors.of(context).successFill,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .editProfileSaveFailed(e.toString()),
                style: TextStyle(color: JdcColors.of(context).paper)),
            backgroundColor: JdcColors.of(context).danger,
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
    final colorScheme = Theme.of(context).colorScheme;
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editProfileTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: jdc.line)),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: jdc.surface,
            border: Border(top: BorderSide(color: jdc.line)),
            boxShadow: jdc.shadowSheet,
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: jdc.onCta,
                      ),
                    )
                  : Text(AppLocalizations.of(context)!.editProfileSaveBtn),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          children: [
            // Shop Photo Upload
            Center(
              child: GestureDetector(
                onTap: _pickShopPhoto,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: jdc.sunken,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: jdc.line),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: _shopPhoto != null
                              ? AppFileImage(
                                  file: _shopPhoto!,
                                )
                              : (_shopPhotoUrl != null &&
                                      _shopPhotoUrl!.isNotEmpty)
                                  ? AppNetworkImage(
                                      imageUrl: _shopPhotoUrl,
                                      fit: BoxFit.cover,
                                      backgroundColor:
                                          JdcColors.of(context).surface,
                                    )
                                  : GrayscaleLogoPlaceholder(
                                      fit: BoxFit.contain,
                                      backgroundColor:
                                          JdcColors.of(context).surface,
                                    ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: JdcColors.of(context).cta,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit,
                              size: 16, color: JdcColors.of(context).onCta),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(AppLocalizations.of(context)!.editProfileTapPhoto,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  )),
            ),
            const SizedBox(height: 16),

            // Shop Name Field
            _buildTextField(
              controller: _nameController,
              label: AppLocalizations.of(context)!.editProfileShopName,
              icon: Icons.store,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!
                      .editProfileShopNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email Field (Read-only)
            _buildTextField(
              controller: TextEditingController(text: widget.currentEmail),
              label: AppLocalizations.of(context)!.editProfileEmail,
              icon: Icons.email,
              enabled: false,
            ),
            const SizedBox(height: 16),

            // Phone Field
            _buildTextField(
              controller: _phoneController,
              label: AppLocalizations.of(context)!.editProfilePhone,
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (value.length < 9 || value.length > 10) {
                    return AppLocalizations.of(context)!
                        .editProfilePhoneInvalid;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address Field
            _buildTextField(
              controller: _addressController,
              label: AppLocalizations.of(context)!.editProfileAddress,
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
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pin_drop, color: JdcColors.of(context).cta),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!
                                .editProfilePinLocation,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_shopLat != null && _shopLng != null)
                                ? 'Lat: ${_shopLat!.toStringAsFixed(5)}, Lng: ${_shopLng!.toStringAsFixed(5)}'
                                : AppLocalizations.of(context)!
                                    .editProfileNoLocation,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              AppLocalizations.of(context)!.editProfileOpenDays,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weekdayKeys.map((day) {
                final isSelected = _shopOpenDays.contains(day);
                return FilterChip(
                  label: Text(_weekdayLabels(context)[day] ?? day),
                  selected: isSelected,
                  selectedColor: JdcColors.of(context).brandSoft,
                  checkmarkColor: JdcColors.of(context).brandOnSoft,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? JdcColors.of(context).brandOnSoft
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? JdcColors.of(context).brandOnSoft
                        : colorScheme.outlineVariant.withValues(alpha: 0.8),
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
                    label: AppLocalizations.of(context)!.editProfileOpenTime,
                    value: _shopOpenTime,
                    onTap: () async {
                      final picked = await PlatformAdaptive.pickTime(
                        context: context,
                        initialTime: _shopOpenTime,
                        title:
                            AppLocalizations.of(context)!.editProfileOpenTime,
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
                    label: AppLocalizations.of(context)!.editProfileCloseTime,
                    value: _shopCloseTime,
                    onTap: () async {
                      final picked = await PlatformAdaptive.pickTime(
                        context: context,
                        initialTime: _shopCloseTime,
                        title:
                            AppLocalizations.of(context)!.editProfileCloseTime,
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
          ],
        ),
      ),
    );
  }

  void _submitProfile() {
    if (_shopOpenDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.editProfileSelectDayRequired,
                  style: TextStyle(color: JdcColors.of(context).paper)),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
      return;
    }
    _saveProfile();
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
    final jdc = JdcColors.of(context);
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: jdc.muted, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: enabled ? jdc.surface : jdc.sunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jdc.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jdc.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jdc.cta, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jdc.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jdc.danger, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: jdc.line),
        ),
      ),
    );
  }
}
