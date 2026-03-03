import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/profile_service.dart';
import '../services/image_picker_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/language_switcher.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Profile Screen - Universal for all roles
/// 
/// Handles profile CRUD operations for Customer, Driver, and Admin
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _profile;
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _licensePlateController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPhoneController = TextEditingController();
  
  String _userRole = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _vehicleTypeController.dispose();
    _licensePlateController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _shopPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      _userEmail = currentUser.email ?? '';
      _userRole = await _profileService.getUserRole() ?? 'customer';
      
      _profile = await _profileService.getCurrentProfile();
      
      if (_profile != null) {
        _fullNameController.text = _profile!['full_name'] ?? '';
        _phoneController.text = _profile!['phone_number'] ?? '';
        _vehicleTypeController.text = _profile!['vehicle_type'] ?? '';
        _licensePlateController.text = _profile!['license_plate'] ?? '';
        _shopNameController.text = _profile!['shop_name'] ?? '';
        _shopAddressController.text = _profile!['shop_address'] ?? '';
        _shopPhoneController.text = _profile!['shop_phone'] ?? '';
      } else {
        // Create initial profile if it doesn't exist
        await _createInitialProfile();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugLog('❌ Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: Text(l10n.profileLoadFailedTitle),
            content: Text(l10n.profileLoadFailedBody(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _createInitialProfile() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      await _profileService.createOrUpdateProfile(
        userId: currentUser.id,
        email: _userEmail,
        role: _userRole,
        fullName: _userEmail.split('@')[0],
      );
      
      _profile = await _profileService.getCurrentProfile();
      
      if (_profile != null) {
        _fullNameController.text = _profile!['full_name'] ?? '';
      }
    } catch (e) {
      debugLog('❌ Error creating initial profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      setState(() {
        _isSaving = true;
      });

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _profileService.updateProfile(
        userId: currentUser.id,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        vehicleType: _vehicleTypeController.text.trim(),
        licensePlate: _licensePlateController.text.trim(),
        shopName: _shopNameController.text.trim(),
        shopAddress: _shopAddressController.text.trim(),
        shopPhone: _shopPhoneController.text.trim(),
      );

      // Reload profile
      await _loadProfile();

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileSaveSuccess),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error saving profile: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: Text(l10n.profileSaveFailedTitle),
            content: Text(l10n.profileSaveFailedBody(e.toString())),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        title: Text(l10n.profileEditTitle),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: LanguageSwitcher(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    _buildProfileHeader(),
                    
                    const SizedBox(height: 32),
                    
                    // Basic Information
                    _buildSectionTitle(l10n.profileBasicInfoSection),
                    _buildBasicInfoSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Driver Specific Fields
                    if (_userRole == 'driver') ...[
                      _buildSectionTitle(l10n.profileVehicleSection),
                      _buildVehicleSection(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Merchant Specific Fields
                    if (_userRole == 'merchant') ...[
                      _buildSectionTitle(l10n.profileMerchantSection),
                      _buildMerchantSection(),
                      const SizedBox(height: 24),
                    ],
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                l10n.profileSave,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final file = await ImagePickerService.showImageSourceDialog(context);
      if (file == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileUploadingImage),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final uploadedUrl = await StorageService.uploadProfileImage(
        imageFile: file,
        userId: userId,
      );

      if (uploadedUrl != null) {
        await _profileService.updateProfile(
          userId: userId,
          avatarUrl: uploadedUrl,
        );
        debugLog('📷 Avatar uploaded: $uploadedUrl');

        // Reload profile
        await _loadProfile();

        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountUploadSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugLog('❌ Error uploading avatar: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountUploadFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarUrl = _profile?['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryGreen,
                  child: ClipOval(
                    child: hasAvatar
                        ? AppNetworkImage(
                            imageUrl: avatarUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            backgroundColor: Colors.white,
                          )
                        : const GrayscaleLogoPlaceholder(
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            backgroundColor: Colors.white,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _fullNameController.text.isNotEmpty
                ? _fullNameController.text
                : _userEmail.split('@')[0],
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _userRole == 'driver'
                  ? AppLocalizations.of(context)!.accountRoleDriver
                  : _userRole == 'merchant'
                      ? AppLocalizations.of(context)!.accountRoleMerchant
                      : AppLocalizations.of(context)!.accountRoleCustomer,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: l10n.profileFullNameLabel,
              prefixIcon: const Icon(Icons.person),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.profileFullNameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: l10n.profilePhoneLabel,
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.profilePhoneRequired;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.driverInfoVehicleType,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildVehicleChip(
                  l10n.profileVehicleMotorcycle,
                  Icons.two_wheeler,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildVehicleChip(
                  l10n.profileVehicleCar,
                  Icons.directions_car,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licensePlateController,
            decoration: InputDecoration(
              labelText: l10n.driverInfoLicensePlate,
              prefixIcon: const Icon(Icons.pin),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.profileLicensePlateRequired;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleChip(String label, IconData icon) {
    final isSelected = _vehicleTypeController.text == label;
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        setState(() {
          _vehicleTypeController.text = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryGreen : colorScheme.onSurfaceVariant, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryGreen : colorScheme.onSurface,
                )),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantSection() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _shopNameController,
            decoration: InputDecoration(
              labelText: l10n.profileShopNameLabel,
              prefixIcon: const Icon(Icons.store),
              border: const OutlineInputBorder(),
              hintText: l10n.profileShopNameHint,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.profileShopNameRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shopAddressController,
            decoration: InputDecoration(
              labelText: l10n.profileShopAddressLabel,
              prefixIcon: const Icon(Icons.location_on),
              border: const OutlineInputBorder(),
              hintText: l10n.profileShopAddressHint,
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.profileShopAddressRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shopPhoneController,
            decoration: InputDecoration(
              labelText: l10n.profileShopPhoneLabel,
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
              hintText: l10n.profileShopPhoneHint,
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.profileShopPhoneRequired;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

}
