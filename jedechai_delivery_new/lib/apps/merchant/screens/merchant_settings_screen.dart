import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/profile_service.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/services/storage_service.dart';
import '../../../common/services/account_deletion_service.dart';
import '../../../common/utils/platform_adaptive.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/widgets/language_switcher.dart';
import '../../customer/screens/auth/login_screen.dart';
import '../../../l10n/app_localizations.dart';
import 'merchant_coupon_management_screen.dart';
import 'profile/edit_merchant_profile_screen.dart';

/// Merchant Settings Screen — Account & Settings
class MerchantSettingsScreen extends StatefulWidget {
  const MerchantSettingsScreen({super.key});

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _error;
  String? _appVersion;
  int _versionTapCount = 0;

  static const Color _accent = AppTheme.accentOrange;
  static const List<Color> _gradient = [
    AppTheme.accentOrange,
    Color(0xFFE65100),
  ];
  static const List<String> _weekdayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
  Map<String, String> _weekdayLocal(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return {
      'mon': l10n.mchSetWeekMon,
      'tue': l10n.mchSetWeekTue,
      'wed': l10n.mchSetWeekWed,
      'thu': l10n.mchSetWeekThu,
      'fri': l10n.mchSetWeekFri,
      'sat': l10n.mchSetWeekSat,
      'sun': l10n.mchSetWeekSun,
    };
  }
  static const String _acceptModeManual = 'manual';
  static const String _acceptModeAuto = 'auto';

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

  Future<void> _editProfileField(String field) async {
    final l10n = AppLocalizations.of(context)!;
    final labels = {'full_name': l10n.mchSetShopName, 'phone_number': l10n.mchSetPhone};
    final hints = {'full_name': l10n.mchSetHintShopName, 'phone_number': l10n.mchSetHintPhone};
    final label = labels[field] ?? field;
    final hint = hints[field] ?? '';
    final controller = TextEditingController(text: _userProfile?[field] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mchSetEditField(label)),
        content: TextField(
          controller: controller,
          keyboardType: field == 'phone_number'
              ? TextInputType.phone
              : TextInputType.name,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.mchSetCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.mchSetSave),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      try {
        await _profileService.updateProfile(
          userId: AuthService.userId!,
          fullName: field == 'full_name' ? result.trim() : null,
          phone: field == 'phone_number' ? result.trim() : null,
        );
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountUpdateSuccess),
              backgroundColor: Colors.green,
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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showDeleteAccountDialog() {
    final reasonController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.red[700],
          size: 48,
        ),
        title: Text(
          l10n.accountDeleteDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.accountDeleteDialogBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: l10n.accountDeleteReasonHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
            backgroundColor: Colors.red,
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
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditMerchantProfileScreen(
          currentName: _userProfile?['full_name'] ?? '',
          currentEmail: _userProfile?['email'] ?? '',
        ),
      ),
    );
    if (result == true) _fetchUserProfile();
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.accountTitle),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
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
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            )
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _fetchUserProfile,
                  color: _accent,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              l10n.accountErrorTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchUserProfile,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.accountRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProfileHeader(),
        const SizedBox(height: 16),
        _buildInfoCard(),
        const SizedBox(height: 16),
        _buildMenuCard(),
        const SizedBox(height: 16),
        _buildAppInfoCard(),
        const SizedBox(height: 24),
        _buildLogoutButton(),
        const SizedBox(height: 12),
        _buildDeleteAccountButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ============================================================
  // Profile Header
  // ============================================================

  Widget _buildProfileHeader() {
    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final shopPhotoUrl = _userProfile?['shop_photo_url'] as String?;
    final displayUrl =
        avatarUrl != null && avatarUrl.isNotEmpty ? avatarUrl : shopPhotoUrl;
    final hasImage = displayUrl != null && displayUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAndUploadAvatar,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? AppNetworkImage(
                            imageUrl: displayUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            backgroundColor: Colors.white,
                          )
                        : const GrayscaleLogoPlaceholder(
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                            backgroundColor: Colors.white,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      PlatformAdaptive.icon(
                        android: Icons.camera_alt,
                        ios: CupertinoIcons.camera,
                      ),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _userProfile?['full_name'] ?? AppLocalizations.of(context)!.accountRoleMerchant,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.of(context)!.accountRoleMerchant,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Info Card
  // ============================================================

  Widget _buildInfoCard() {
    final shopStatus = _userProfile?['shop_status'] as bool?;
    final shopOpenDays = _extractShopOpenDays(_userProfile?['shop_open_days']);
    final orderAcceptMode =
        (_userProfile?['order_accept_mode'] as String?) ?? _acceptModeManual;
    final autoScheduleEnabled =
        (_userProfile?['shop_auto_schedule_enabled'] as bool?) ?? true;

    return _card(
      title: AppLocalizations.of(context)!.mchSetShopInfoTitle,
      children: [
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.store,
            ios: CupertinoIcons.building_2_fill,
          ),
          AppLocalizations.of(context)!.mchSetShopName,
          _userProfile?['full_name'] ?? AppLocalizations.of(context)!.mchSetNotSet,
          () => _editProfileField('full_name'),
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.phone,
            ios: CupertinoIcons.phone,
          ),
          AppLocalizations.of(context)!.mchSetPhone,
          _userProfile?['phone_number'] ?? AppLocalizations.of(context)!.mchSetNotSet,
          () => _editProfileField('phone_number'),
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.email_outlined,
            ios: CupertinoIcons.mail,
          ),
          AppLocalizations.of(context)!.mchSetEmail,
          AuthService.currentUser?.email ?? '-',
          null,
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.location_on_outlined,
            ios: CupertinoIcons.location,
          ),
          AppLocalizations.of(context)!.mchSetAddress,
          _userProfile?['shop_address'] ?? AppLocalizations.of(context)!.mchSetNotSet,
          null,
        ),
        _divider(),
        _infoRow(
          shopStatus == true
              ? PlatformAdaptive.icon(
                  android: Icons.check_circle,
                  ios: CupertinoIcons.check_mark_circled_solid,
                )
              : PlatformAdaptive.icon(
                  android: Icons.cancel,
                  ios: CupertinoIcons.xmark_circle_fill,
                ),
          AppLocalizations.of(context)!.mchSetShopStatus,
          shopStatus == true ? AppLocalizations.of(context)!.mchSetShopOpen : AppLocalizations.of(context)!.mchSetShopClosed,
          null,
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.schedule,
            ios: CupertinoIcons.clock,
          ),
          AppLocalizations.of(context)!.mchSetOpenCloseTime,
          '${_userProfile?['shop_open_time'] ?? '08:00'} - ${_userProfile?['shop_close_time'] ?? '22:00'}',
          _showEditShopHoursDialog,
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.calendar_today_outlined,
            ios: CupertinoIcons.calendar,
          ),
          AppLocalizations.of(context)!.mchSetOpenDays,
          _formatOpenDaysText(shopOpenDays),
          _showEditShopHoursDialog,
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.rule_folder_outlined,
            ios: CupertinoIcons.doc_text,
          ),
          AppLocalizations.of(context)!.mchSetOrderAcceptMode,
          _formatOrderAcceptMode(orderAcceptMode),
          _showEditShopHoursDialog,
        ),
        _divider(),
        _infoRow(
          PlatformAdaptive.icon(
            android: Icons.av_timer_outlined,
            ios: CupertinoIcons.timer,
          ),
          AppLocalizations.of(context)!.mchSetAutoSchedule,
          autoScheduleEnabled ? AppLocalizations.of(context)!.mchSetAutoScheduleOn : AppLocalizations.of(context)!.mchSetAutoScheduleOff,
          _showEditShopHoursDialog,
        ),
      ],
    );
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

  String _formatOpenDaysText(List<String> days) {
    if (days.isEmpty) return AppLocalizations.of(context)!.mchSetEveryDay;
    return days.map((d) => _weekdayLocal(context)[d] ?? d).join(' ');
  }

  String _formatOrderAcceptMode(String mode) {
    switch (mode) {
      case _acceptModeAuto:
        return AppLocalizations.of(context)!.mchSetAcceptAuto;
      case _acceptModeManual:
      default:
        return AppLocalizations.of(context)!.mchSetAcceptManual;
    }
  }

  Future<void> _showEditShopHoursDialog() async {
    final openTime = _userProfile?['shop_open_time'] as String? ?? '08:00';
    final closeTime = _userProfile?['shop_close_time'] as String? ?? '22:00';

    TimeOfDay parseTime(String t) {
      final parts = t.split(':');
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    String formatTime(TimeOfDay t) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }

    TimeOfDay selectedOpen = parseTime(openTime);
    TimeOfDay selectedClose = parseTime(closeTime);
    final selectedDays = _extractShopOpenDays(
      _userProfile?['shop_open_days'],
    ).toSet();
    String selectedAcceptMode =
        (_userProfile?['order_accept_mode'] as String?) ?? _acceptModeManual;
    bool autoScheduleEnabled =
        (_userProfile?['shop_auto_schedule_enabled'] as bool?) ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                AppLocalizations.of(context)!.mchSetEditShopHoursTitle,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.wb_sunny, color: _accent),
                    title: Text(AppLocalizations.of(context)!.mchSetOpenTime),
                    trailing: Text(
                      formatTime(selectedOpen),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _accent,
                      ),
                    ),
                    onTap: () async {
                      final picked = await PlatformAdaptive.pickTime(
                        context: context,
                        initialTime: selectedOpen,
                        title: AppLocalizations.of(context)!.mchSetOpenTime,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedOpen = picked);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Icon(Icons.nights_stay, color: Colors.indigo[400]),
                    title: Text(AppLocalizations.of(context)!.mchSetCloseTime),
                    trailing: Text(
                      formatTime(selectedClose),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[400],
                      ),
                    ),
                    onTap: () async {
                      final picked = await PlatformAdaptive.pickTime(
                        context: context,
                        initialTime: selectedClose,
                        title: AppLocalizations.of(context)!.mchSetCloseTime,
                      );
                      if (picked != null) {
                        setDialogState(() => selectedClose = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context)!.mchSetOpenDaysLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _weekdayKeys.map((day) {
                      final isSelected = selectedDays.contains(day);
                      return FilterChip(
                        label: Text(_weekdayLocal(context)[day] ?? day),
                        selected: isSelected,
                        selectedColor: _accent.withValues(alpha: 0.15),
                        checkmarkColor: _accent,
                        labelStyle: TextStyle(
                          color: isSelected ? _accent : colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSelected ? _accent : Colors.grey.shade300,
                        ),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedDays.add(day);
                            } else {
                              selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppLocalizations.of(context)!.mchSetOrderAcceptModeLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: _acceptModeManual,
                        icon: Icon(Icons.pan_tool_alt_outlined),
                        label: Text(AppLocalizations.of(context)!.mchSetAcceptManualShort),
                      ),
                      ButtonSegment<String>(
                        value: _acceptModeAuto,
                        icon: Icon(Icons.auto_mode_outlined),
                        label: Text(AppLocalizations.of(context)!.mchSetAcceptAutoShort),
                      ),
                    ],
                    selected: {selectedAcceptMode},
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return _accent.withValues(alpha: 0.18);
                        }
                        return Colors.white;
                      }),
                      side: WidgetStateProperty.resolveWith<BorderSide?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return BorderSide(color: _accent);
                        }
                        return BorderSide(color: Colors.grey.shade300);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return _accent;
                        }
                        return colorScheme.onSurface;
                      }),
                    ),
                    onSelectionChanged: (selected) {
                      setDialogState(() {
                        selectedAcceptMode = selected.first;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: autoScheduleEnabled,
                    activeThumbColor: _accent,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppLocalizations.of(context)!.mchSetAutoScheduleSwitch,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      autoScheduleEnabled
                          ? AppLocalizations.of(context)!.mchSetAutoScheduleOnDesc
                          : AppLocalizations.of(context)!.mchSetAutoScheduleOffDesc,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        autoScheduleEnabled = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppLocalizations.of(context)!.mchSetCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedDays.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.mchSetSelectAtLeast1Day),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(AppLocalizations.of(context)!.mchSetSave),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        final userId = AuthService.userId;
        if (userId == null) return;

        final openStr = formatTime(selectedOpen);
        final closeStr = formatTime(selectedClose);

        await Supabase.instance.client.from('profiles').update({
          'shop_open_time': openStr,
          'shop_close_time': closeStr,
          'shop_open_days': selectedDays.toList(),
          'order_accept_mode': selectedAcceptMode,
          'shop_auto_schedule_enabled': autoScheduleEnabled,
        }).eq('id', userId);

        await _fetchUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.mchSetShopHoursSaved(openStr, closeStr, _formatOpenDaysText(selectedDays.toList())),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugLog('❌ Error updating shop hours: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.mchSetSaveFailed(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ============================================================
  // Menu Card
  // ============================================================

  Widget _buildMenuCard() {
    return _card(
      title: AppLocalizations.of(context)!.accountMenuTitle,
      children: [
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.edit,
            ios: CupertinoIcons.pencil,
          ),
          AppLocalizations.of(context)!.merchantMenuEditShop,
          _navigateToEditProfile,
        ),
        _divider(),
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.local_offer_outlined,
            ios: CupertinoIcons.ticket,
          ),
          AppLocalizations.of(context)!.merchantMenuCoupons,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MerchantCouponManagementScreen(),
              ),
            );
          },
        ),
        _divider(),
        _menuItem(
          Icons.notifications_outlined,
          AppLocalizations.of(context)!.accountMenuNotifications,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.accountFeatureComingSoon,
                ),
              ),
            );
          },
        ),
        _divider(),
        _menuItem(
          Icons.help_outline,
          AppLocalizations.of(context)!.accountMenuHelp,
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.accountFeatureComingSoon,
                ),
              ),
            );
          },
        ),
        _divider(),
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.privacy_tip_outlined,
            ios: CupertinoIcons.shield,
          ),
          AppLocalizations.of(context)!.accountMenuPrivacyPolicy,
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
              backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // App Info Card
  // ============================================================

  Widget _buildAppInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.accountAppInfoTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.accountVersionLabel,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _versionTapCount += 1;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Debug: ${_versionTapCount}/7'),
                      duration: const Duration(milliseconds: 700),
                    ),
                  );
                  if (_versionTapCount >= 7) {
                    _versionTapCount = 0;
                    _showNotificationDebugDialog();
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Text(
                    _appVersion ?? AppLocalizations.of(context)!.accountLoading,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.accountDevelopedByLabel,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const Spacer(),
              Text(
                'Jedechai Team',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Logout Button
  // ============================================================

  Widget _buildLogoutButton() {
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
        label: Text(
          l10n.accountLogout,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
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
        label: Text(l10n.accountDelete, style: const TextStyle(fontSize: 14)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.grey[500],
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ============================================================
  // Shared Widgets
  // ============================================================

  Widget _card({required String title, required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
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
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
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
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              PlatformAdaptive.icon(
                android: Icons.chevron_right,
                ios: CupertinoIcons.chevron_forward,
              ),
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
