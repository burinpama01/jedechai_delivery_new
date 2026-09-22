import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../common/services/auth_service.dart';
import '../../../../common/services/profile_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/services/account_deletion_service.dart';
import '../../../../common/utils/platform_adaptive.dart';
import '../../../../common/screens/profile_screen.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../common/widgets/language_switcher.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../customer/screens/auth/login_screen.dart';
import '../../../../l10n/app_localizations.dart';

/// Driver Profile Screen — Account & Settings
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _error;
  String? _appVersion;
  int _versionTapCount = 0;

  /// สร้าง TextStyle พร้อม fontVariations คู่กับ fontWeight ตามกฎดีไซน์ JDC
  TextStyle _txt(
    Color color,
    double size, {
    double w = 400,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
      fontFeatures: fontFeatures,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (e) {
      debugLog('❌ Error loading app version: $e');
    }
  }

  Future<void> _showNotificationDebugDialog() async {
    try {
      if (!mounted) return;

      var isLoading = true;
      var hasLoaded = false;
      AuthorizationStatus? permissionStatus;
      String? apnsToken;
      String? fcmToken;
      String? bundleId;
      String? firebaseProjectId;
      String? firebaseAppId;
      String? firebaseError;
      String? settingsError;
      String? apnsError;
      String? fcmError;
      final profileToken = _userProfile?['fcm_token']?.toString();

      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> load() async {
                setDialogState(() {
                  isLoading = true;
                  firebaseError = null;
                  settingsError = null;
                  apnsError = null;
                  fcmError = null;
                });

                try {
                  try {
                    await Firebase.initializeApp();
                  } catch (e) {
                    firebaseError = e.toString();
                  }

                  try {
                    final app = Firebase.app();
                    firebaseProjectId = app.options.projectId;
                    firebaseAppId = app.options.appId;
                  } catch (e) {
                    debugLog('❌ Could not read Firebase.app options: $e');
                  }

                  try {
                    final info = await PackageInfo.fromPlatform();
                    bundleId = info.packageName;
                  } catch (e) {
                    debugLog('❌ Could not read bundle id: $e');
                  }

                  final messaging = FirebaseMessaging.instance;

                  try {
                    final settings = await messaging.getNotificationSettings();
                    permissionStatus = settings.authorizationStatus;
                  } catch (e) {
                    settingsError = e.toString();
                    debugLog('❌ Could not read notification settings: $e');
                  }

                  try {
                    if (defaultTargetPlatform == TargetPlatform.iOS) {
                      apnsToken = await messaging.getAPNSToken();
                    }
                  } catch (e) {
                    apnsError = e.toString();
                    debugLog('❌ Could not get APNs token: $e');
                  }

                  try {
                    fcmToken = await messaging.getToken();
                  } catch (e) {
                    fcmError = e.toString();
                    debugLog('❌ Could not get FCM token: $e');
                  }
                } finally {
                  if (context.mounted) {
                    setDialogState(() {
                      isLoading = false;
                    });
                  }
                }
              }

              if (!hasLoaded) {
                hasLoaded = true;
                Future<void>.microtask(() async {
                  await load();
                });
              }

              return AlertDialog(
                title: const Text('Debug: Notification Token'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('App: ${_appVersion ?? '-'}'),
                      Text('Bundle: ${bundleId ?? '-'}'),
                      Text('Firebase project: ${firebaseProjectId ?? '-'}'),
                      Text('Firebase appId: ${firebaseAppId ?? '-'}'),
                      const SizedBox(height: 8),
                      if (isLoading)
                        const Text('Loading...')
                      else ...[
                        if (firebaseError != null) ...[
                          Text('Firebase init error: $firebaseError'),
                          const SizedBox(height: 8),
                        ],
                        Text('Permission: ${permissionStatus ?? '-'}'),
                        if (settingsError != null)
                          Text('Permission error: $settingsError'),
                        const SizedBox(height: 8),
                        if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                          const Text('APNs Token:'),
                          SelectableText(apnsToken ?? '-'),
                          if (apnsError != null) Text('APNs error: $apnsError'),
                          const SizedBox(height: 8),
                        ],
                        const Text('FCM Token:'),
                        SelectableText(fcmToken ?? '-'),
                        if (fcmError != null) Text('FCM error: $fcmError'),
                        const SizedBox(height: 8),
                        const Text('DB profiles.fcm_token:'),
                        SelectableText(
                          profileToken?.isNotEmpty == true ? profileToken! : '-',
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            try {
                              final messaging = FirebaseMessaging.instance;
                              await messaging.requestPermission(
                                alert: true,
                                badge: true,
                                sound: true,
                              );
                            } catch (e) {
                              debugLog('❌ requestPermission failed: $e');
                            }
                            await load();
                          },
                    child: const Text('Request Permission'),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : () => load(),
                    child: const Text('Refresh'),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final text = fcmToken ?? '';
                            await Clipboard.setData(ClipboardData(text: text));
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Copy FCM'),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final text = [
                              'app=${_appVersion ?? ''}',
                              'permission=$permissionStatus',
                              'apns=${apnsToken ?? ''}',
                              'fcm=${fcmToken ?? ''}',
                              'db=${profileToken ?? ''}',
                            ].join('\n');
                            await Clipboard.setData(
                              ClipboardData(text: text),
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Copy All'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      debugLog('❌ Failed to show notification debug dialog: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final profile = await _profileService.getCurrentProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      debugLog('❌ Error loading profile: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // Actions
  // ============================================================

  Future<void> _pickAndUploadAvatar() async {
    try {
      final file = await ImagePickerService.showImageSourceDialog(context);
      if (file == null) return;
      final userId = AuthService.userId;
      if (userId == null) return;
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountUploadingImage),
            duration: Duration(seconds: 2),
          ),
        );
      }
      final url = await StorageService.uploadProfileImage(
        imageFile: file,
        userId: userId,
      );
      if (url != null) {
        await _profileService.updateProfile(userId: userId, avatarUrl: url);
        await _fetchUserProfile();
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountUploadSuccess),
              backgroundColor: context.jdc.successFill,
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
            backgroundColor: context.jdc.danger,
          ),
        );
      }
    }
  }

  /// คืน user id ปัจจุบัน หรือโยน error ที่ catch ด้านล่างจับได้
  /// แทนการ force-unwrap ซึ่งจะ crash ทั้งหน้าเมื่อ session หมดอายุ
  String _requireUserId() {
    final id = AuthService.userId;
    if (id == null || id.isEmpty) {
      throw StateError('no-session');
    }
    return id;
  }

  Future<void> _editProfileField(String field) async {
    // ถ้าเป็นประเภทรถ ใช้ dialog กดเลือกแทนการพิมพ์
    if (field == 'vehicle_type') {
      final result = await _showVehicleTypePicker();
      if (result != null) {
        try {
          await _profileService.updateProfile(
            userId: _requireUserId(),
            vehicleType: result,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.drvProfileUpdateSuccess),
                backgroundColor: context.jdc.successFill,
              ),
            );
          }
          _fetchUserProfile();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.drvProfileUpdateError(e.toString())),
                backgroundColor: context.jdc.danger,
              ),
            );
          }
        }
      }
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final labels = {
      'full_name': l10n.drvProfileEditName,
      'phone_number': l10n.drvProfileEditPhone,
      'license_plate': l10n.drvProfileEditPlate,
    };
    final hints = {
      'full_name': l10n.drvProfileHintName,
      'phone_number': l10n.drvProfileHintPhone,
      'license_plate': l10n.drvProfileHintPlate,
    };
    final label = labels[field] ?? field;
    final hint = hints[field] ?? '';
    final controller = TextEditingController(text: _userProfile?[field] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: field == 'phone_number'
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(JdcRadius.field),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.drvProfileCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.drvProfileSave),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      try {
        await _profileService.updateProfile(
          userId: _requireUserId(),
          fullName: field == 'full_name' ? result.trim() : null,
          phone: field == 'phone_number' ? result.trim() : null,
          licensePlate: field == 'license_plate' ? result.trim() : null,
        );
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountUpdateSuccess),
              backgroundColor: context.jdc.successFill,
            ),
          );
        }
        _fetchUserProfile();
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountUpdateFailed(e.toString())),
              backgroundColor: context.jdc.danger,
            ),
          );
        }
      }
    }
  }

  void _showDeleteAccountDialog() {
    final reasonController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.card),
        ),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: jdc.danger,
          size: 48,
        ),
        title: Text(
          l10n.accountDeleteDialogTitle,
          style: _txt(jdc.text, 18, w: 700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.accountDeleteDialogBody,
              textAlign: TextAlign.center,
              style: _txt(jdc.text, 14, height: 1.5),
            ),
            const SizedBox(height: JdcSpacing.lg),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l10n.accountDeleteReasonHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                contentPadding: const EdgeInsets.all(JdcSpacing.md),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.accountCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _submitDeleteAccount(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: jdc.danger,
              foregroundColor: jdc.onCta,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
            ),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _submitDeleteAccount(String reason) async {
    try {
      await AccountDeletionService.requestDeletion(reason: reason);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountDeleteRequestSubmitFailed(e.toString())),
            backgroundColor: context.jdc.danger,
          ),
        );
      }
    }
  }

  void _showLogoutConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.accountLogoutDialogTitle),
        content: Text(l10n.accountLogoutDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.accountCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _signOut();
            },
            child: Text(
              l10n.accountLogout,
              style: _txt(ctx.jdc.danger, 14, w: 600),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showVehicleTypePicker() async {
    final current = _userProfile?['vehicle_type'] as String? ?? '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = current;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.drvProfileSelectVehicle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _vehicleOption(
                  AppLocalizations.of(context)!.drvProfileMotorcycle,
                  Icons.two_wheeler,
                  selected == 'มอเตอร์ไซค์',
                  () {
                    setDialogState(() => selected = 'มอเตอร์ไซค์');
                  },
                ),
                const SizedBox(height: 10),
                _vehicleOption(
                  AppLocalizations.of(context)!.drvProfileCar,
                  Icons.directions_car,
                  selected == 'รถยนต์',
                  () {
                    setDialogState(() => selected = 'รถยนต์');
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppLocalizations.of(context)!.drvProfileCancel),
              ),
              ElevatedButton(
                onPressed: selected.isNotEmpty
                    ? () => Navigator.of(ctx).pop(selected)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ctx.jdc.cta,
                  foregroundColor: ctx.jdc.onCta,
                ),
                child: Text(AppLocalizations.of(context)!.drvProfileSave),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _vehicleOption(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final jdc = JdcColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.lg,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected ? jdc.brandSoft : jdc.sunken,
          borderRadius: BorderRadius.circular(JdcRadius.small),
          border: Border.all(
            color: isSelected ? jdc.brandLine : jdc.line,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? jdc.brandOnSoft : jdc.muted,
              size: 28,
            ),
            const SizedBox(width: JdcSpacing.md),
            Expanded(
              child: Text(
                label,
                style: _txt(
                  isSelected ? jdc.brandOnSoft : jdc.text,
                  16,
                  w: isSelected ? 700 : 400,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: jdc.brandOnSoft, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountUpdateFailed(e.toString())),
            backgroundColor: context.jdc.danger,
          ),
        );
      }
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    if (result == true || result == null) _fetchUserProfile();
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _fetchUserProfile,
                  color: jdc.cta,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildError() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: jdc.danger),
            const SizedBox(height: JdcSpacing.lg),
            Text(l10n.accountErrorTitle, style: _txt(jdc.text, 18, w: 700)),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              _error!,
              style: _txt(jdc.muted, 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JdcSpacing.xl),
            ElevatedButton.icon(
              onPressed: _fetchUserProfile,
              icon: Icon(
                PlatformAdaptive.icon(
                  android: Icons.refresh,
                  ios: CupertinoIcons.refresh,
                ),
              ),
              label: Text(l10n.accountRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileHeader(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: JdcBreakpoints.readableMaxWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.gutter,
                        JdcSpacing.lg,
                        context.gutter,
                        JdcSpacing.xxxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInfoCard(),
                          const SizedBox(height: JdcSpacing.lg),
                          _buildMenuCard(),
                          const SizedBox(height: JdcSpacing.lg),
                          _buildAppInfoCard(),
                          const SizedBox(height: JdcSpacing.xxl),
                          _buildLogoutButton(),
                          const SizedBox(height: JdcSpacing.md),
                          _buildDeleteAccountButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // Profile Header
  // ============================================================

  /// ส่วนหัว hero สีเข้ม (hero2) ตาม artboard Driver-Profile —
  /// อวตาร + ชื่อ + คะแนน/ยอดงาน (ถ้ามีข้อมูลจริง) + ประเภทรถ/ทะเบียน + ชิปบทบาท
  Widget _buildProfileHeader() {
    final jdc = JdcColors.of(context);
    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;
    final fullName = (_userProfile?['full_name'] as String?)?.trim();
    final rating = (_userProfile?['average_rating'] as num?)?.toDouble();
    final totalJobs = (_userProfile?['total_completed_jobs'] as num?)?.toInt();
    final vehicle = (_userProfile?['vehicle_type'] as String?)?.trim();
    final plate = (_userProfile?['license_plate'] as String?)?.trim();
    final vehicleParts =
        [vehicle, plate].where((p) => p != null && p.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: jdc.hero2),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (Navigator.of(context).canPop()) ...[
                    _buildBackButton(),
                    const SizedBox(width: JdcSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      l10n.accountTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.onPanel, 18, w: 700),
                    ),
                  ),
                  const LanguageSwitcher(),
                ],
              ),
              const SizedBox(height: JdcSpacing.xl),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: jdc.panelSoft3,
                            shape: BoxShape.circle,
                            boxShadow: jdc.shadowFloat,
                          ),
                          child: ClipOval(
                            child: hasAvatar
                                ? AppNetworkImage(
                                    imageUrl: avatarUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    backgroundColor: jdc.surface,
                                  )
                                : GrayscaleLogoPlaceholder(
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.contain,
                                    backgroundColor: jdc.panelSoft3,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: jdc.cta,
                              shape: BoxShape.circle,
                              border: Border.all(color: jdc.knob, width: 2),
                            ),
                            child: Icon(
                              PlatformAdaptive.icon(
                                android: Icons.camera_alt,
                                ios: CupertinoIcons.camera,
                              ),
                              size: 12,
                              color: jdc.onCta,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: JdcSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (fullName != null && fullName.isNotEmpty)
                              ? fullName
                              : l10n.accountRoleDriver,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _txt(jdc.onPanel, 18, w: 700),
                        ),
                        if (rating != null && rating > 0) ...[
                          const SizedBox(height: JdcSpacing.xs),
                          Row(
                            children: [
                              Icon(Icons.star, size: 13, color: jdc.brandHi),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  totalJobs != null
                                      ? l10n.driverProfileRatingJobs(
                                          rating.toStringAsFixed(2),
                                          totalJobs.toString())
                                      : rating.toStringAsFixed(2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _txt(jdc.brandHi, 12, w: 600),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (vehicleParts.isNotEmpty) ...[
                          const SizedBox(height: JdcSpacing.xs),
                          Text(
                            vehicleParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _txt(jdc.panelDim, 12),
                          ),
                        ],
                        const SizedBox(height: JdcSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: jdc.panelSoft,
                            borderRadius: BorderRadius.circular(JdcRadius.chip),
                          ),
                          child: Text(
                            l10n.accountRoleDriver,
                            style: _txt(jdc.onPanel, 11, w: 700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ปุ่มย้อนกลับบนพื้น hero ตาม artboard (แสดงเฉพาะเมื่อ push เข้ามาเป็น route)
  Widget _buildBackButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      width: JdcTouch.minTarget,
      height: JdcTouch.minTarget,
      child: Material(
        color: jdc.panelSoft2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          side: BorderSide(color: jdc.panelLine),
        ),
        child: InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(Icons.chevron_left, size: 20, color: jdc.onPanel),
        ),
      ),
    );
  }

  // ============================================================
  // Info Card
  // ============================================================

  Widget _buildInfoCard() {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      title: l10n.accountInfoTitle,
      children: [
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.person,
            ios: CupertinoIcons.person,
          ),
          l10n.accountInfoName,
          _userProfile?['full_name'] ?? l10n.accountNotSet,
          () => _editProfileField('full_name'),
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.phone,
            ios: CupertinoIcons.phone,
          ),
          l10n.accountInfoPhone,
          _userProfile?['phone_number'] ?? l10n.accountNotSet,
          () => _editProfileField('phone_number'),
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.email_outlined,
            ios: CupertinoIcons.mail,
          ),
          l10n.accountInfoEmail,
          AuthService.currentUser?.email ?? '-',
          null,
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.motorcycle,
            ios: CupertinoIcons.car,
          ),
          l10n.driverInfoVehicleType,
          _userProfile?['vehicle_type'] ?? l10n.accountNotSet,
          () => _editProfileField('vehicle_type'),
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.pin,
            ios: CupertinoIcons.number,
          ),
          l10n.driverInfoLicensePlate,
          _userProfile?['license_plate'] ?? l10n.accountNotSet,
          () => _editProfileField('license_plate'),
        ),
      ],
    );
  }

  // ============================================================
  // Menu Card
  // ============================================================

  Widget _buildMenuCard() {
    final l10n = AppLocalizations.of(context)!;
    return _card(
      title: l10n.accountMenuTitle,
      children: [
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.edit,
            ios: CupertinoIcons.pencil,
          ),
          l10n.accountMenuEditProfile,
          _navigateToEditProfile,
        ),
        _divider(),
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.notifications_outlined,
            ios: CupertinoIcons.bell,
          ),
          l10n.accountMenuNotifications,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountFeatureComingSoon)),
            );
          },
        ),
        _divider(),
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.help_outline,
            ios: CupertinoIcons.question_circle,
          ),
          l10n.accountMenuHelp,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.accountFeatureComingSoon)),
            );
          },
        ),
        _divider(),
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.privacy_tip_outlined,
            ios: CupertinoIcons.shield,
          ),
          l10n.accountMenuPrivacyPolicy,
          _openPrivacyPolicy,
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
      'https://sites.google.com/view/jdc-delivery-privacy-policy',
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountOpenLinkFailed),
              backgroundColor: context.jdc.danger,
            ),
          );
        }
      }
    } catch (e) {
      debugLog('❌ Error opening privacy policy: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.accountErrorGeneric(e.toString())),
            backgroundColor: context.jdc.danger,
          ),
        );
      }
    }
  }

  // ============================================================
  // App Info Card
  // ============================================================

  Widget _buildAppInfoCard() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountAppInfoTitle,
            style: _txt(jdc.muted, 13, w: 600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(l10n.accountVersionLabel, style: _txt(jdc.muted, 13)),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _versionTapCount += 1;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Debug: $_versionTapCount/7'),
                      duration: const Duration(milliseconds: 700),
                    ),
                  );
                  if (_versionTapCount >= 7) {
                    _versionTapCount = 0;
                    _showNotificationDebugDialog();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 10,
                  ),
                  child: Text(_appVersion ?? l10n.accountLoading,
                      style: _txt(jdc.dim, 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(l10n.accountDevelopedByLabel, style: _txt(jdc.muted, 13)),
              const Spacer(),
              Text('Jedechai Team', style: _txt(jdc.dim, 13)),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Logout Button
  // ============================================================

  /// ปุ่มออกจากระบบสไตล์ artboard — ขอบ danger-line พื้น surface ตัวอักษร danger
  Widget _buildLogoutButton() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showLogoutConfirmation,
        icon: Icon(
          PlatformAdaptive.icon(
            android: Icons.logout,
            ios: CupertinoIcons.square_arrow_right,
          ),
          size: 20,
        ),
        label: Text(l10n.accountLogout, style: _txt(jdc.danger, 14, w: 700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: jdc.danger,
          backgroundColor: jdc.surface,
          side: BorderSide(color: jdc.dangerLine),
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.field),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _showDeleteAccountDialog,
        icon: Icon(
          PlatformAdaptive.icon(
            android: Icons.delete_forever,
            ios: CupertinoIcons.delete,
          ),
          size: 20,
        ),
        label: Text(l10n.accountDelete, style: _txt(jdc.muted, 14)),
        style: TextButton.styleFrom(
          foregroundColor: jdc.muted,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ============================================================
  // Shared Widgets
  // ============================================================

  Widget _card({required String title, required List<Widget> children}) {
    final jdc = JdcColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _txt(jdc.text, 14, w: 700)),
          const SizedBox(height: JdcSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    VoidCallback? onTap,
  ) {
    final jdc = JdcColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(JdcRadius.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: jdc.brandSoft,
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
              child: Icon(icon, color: jdc.brandOnSoft, size: 19),
            ),
            const SizedBox(width: JdcSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _txt(jdc.muted, 12)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _txt(jdc.text, 14, w: 600),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                PlatformAdaptive.icon(
                  android: Icons.chevron_right,
                  ios: CupertinoIcons.chevron_forward,
                ),
                color: jdc.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    final jdc = JdcColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(JdcRadius.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: JdcSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: jdc.sunken,
                borderRadius: BorderRadius.circular(JdcRadius.small),
              ),
              child: Icon(icon, color: jdc.text, size: 19),
            ),
            const SizedBox(width: JdcSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _txt(jdc.text, 14, w: 600),
              ),
            ),
            Icon(
              PlatformAdaptive.icon(
                android: Icons.chevron_right,
                ios: CupertinoIcons.chevron_forward,
              ),
              color: jdc.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    final jdc = JdcColors.of(context);
    return Divider(height: 1, color: jdc.line);
  }
}
