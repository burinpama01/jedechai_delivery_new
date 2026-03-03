import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/profile_service.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/services/storage_service.dart';
import '../../../common/services/account_deletion_service.dart';
import '../../../common/utils/platform_adaptive.dart';
import '../../../common/screens/profile_screen.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/widgets/language_switcher.dart';
import '../../../theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'auth/login_screen.dart';
import 'rewards/my_coupons_screen.dart';
import 'rewards/referral_screen.dart';

/// Account Screen — Customer
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _error;
  String? _appVersion;
  int _versionTapCount = 0;

  static const Color _accent = AppTheme.accentBlue;
  static const List<Color> _gradient = [AppTheme.accentBlue, Color(0xFF1E3A8A)];

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
    final label = field == 'full_name' ? l10n.accountEditName : l10n.accountEditPhone;
    final hint = field == 'full_name' ? l10n.accountEditNameHint : l10n.accountEditPhoneHint;
    final controller = TextEditingController(text: _userProfile?[field] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
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
            child: Text(l10n.accountEditCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.accountEditSave),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountEditSuccess),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchUserProfile();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.accountEditError(e.toString())),
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
        // Navigate to auth gate which will show pending deletion screen
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
              icon: Icon(
                PlatformAdaptive.icon(
                  android: Icons.refresh,
                  ios: CupertinoIcons.refresh,
                ),
              ),
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
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

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
                    child: hasAvatar
                        ? AppNetworkImage(
                            imageUrl: avatarUrl,
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
            _userProfile?['full_name'] ?? l10n.accountUserFallback,
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
              l10n.accountRoleCustomer,
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
            android: Icons.card_giftcard,
            ios: CupertinoIcons.gift,
          ),
          l10n.accountMenuCoupons,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyCouponsScreen()),
            );
          },
        ),
        _divider(),
        _menuItem(
          PlatformAdaptive.icon(
            android: Icons.people_alt_outlined,
            ios: CupertinoIcons.person_2,
          ),
          l10n.accountMenuReferral,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
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

  // ============================================================
  // App Info Card
  // ============================================================

  Widget _buildAppInfoCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
            l10n.accountAppInfoTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                l10n.accountVersionLabel,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
                    _appVersion ?? l10n.accountLoading,
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                l10n.accountDevelopedByLabel,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                'Jedechai Team',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
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
          foregroundColor: colorScheme.onSurfaceVariant,
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
