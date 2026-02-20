import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/fcm_notification_service.dart';
import '../services/system_config_service.dart';
import '../services/account_deletion_service.dart';
import '../services/version_check_service.dart';
import 'pending_approval_screen.dart';
import 'pending_deletion_screen.dart';
import 'profile_completion_screen.dart';
import 'app_network_image.dart';
import 'location_disclosure_dialog.dart';
import '../../apps/customer/customer.dart';
import '../../apps/driver/driver.dart';
import '../../apps/merchant/merchant.dart';
import '../../apps/admin/admin.dart';

/// AuthGate Widget
/// 
/// Listens to Supabase auth state changes and navigates accordingly:
/// - If user is authenticated and role is 'customer': Show CustomerMainScreen
/// - If user is authenticated and role is 'driver': Show DriverMainScreen
/// - If user is authenticated and role is 'merchant': Show MerchantMainScreen
/// - If user is not authenticated: Show LoginScreen
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _userRole = 'customer'; // Default role
  String _approvalStatus = 'approved'; // Default approval status
  String? _rejectionReason;
  String? _deletionStatus; // null = normal, 'pending' = awaiting deletion
  bool _profileCompleted = true; // Default true for customers/admin
  Map<String, dynamic>? _userProfile;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Fetch logo + splash delay in parallel so logo shows before splash ends
    await Future.wait([
      _fetchAppLogo(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    // Check initial auth state
    final isAuth = AuthService.isAuthenticated;

    // If authenticated, fetch user role
    if (isAuth) {
      await _fetchUserRole();
    }

    if (mounted) {
      unawaited(VersionCheckService.checkVersion(context));
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    }

    // Listen to auth state changes
    _authSubscription = AuthService.onAuthStateChange(
      callback: (AuthState state) {
        if (mounted) {
          setState(() {
            _isAuthenticated = state.session != null;
            _isLoading = false;
          });
          
          // If user just logged in, fetch their role
          if (state.session != null) {
            _fetchUserRole();
          }
        }
      },
    );
  }

  Future<void> _fetchUserRole() async {
    try {
      final role = await AuthService.getUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
      debugLog('🎭 User role fetched: $_userRole');

      // Check deletion status for all roles
      await _checkDeletionStatus();

      // For driver/merchant, check approval status
      if (role == 'driver' || role == 'merchant') {
        await _fetchApprovalStatus();
      }
      
      // Save FCM token when user is authenticated
      await FCMNotificationService().saveToken();
      
      // Request location permission early
      await _requestLocationPermission();
    } catch (e) {
      debugLog('❌ Error fetching user role: $e');
      // Keep default role on error
    }
  }

  Future<void> _checkDeletionStatus() async {
    try {
      final status = await AccountDeletionService.checkDeletionStatus();
      if (mounted) {
        setState(() {
          _deletionStatus = status;
        });
      }
      if (status != null) {
        debugLog('🗑️ Deletion status: $status');
      }
    } catch (e) {
      debugLog('⚠️ Error checking deletion status: $e');
    }
  }

  Future<void> _fetchAppLogo() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      if (mounted && configService.logoUrl != null) {
        setState(() {
          _logoUrl = configService.logoUrl;
        });
      }
    } catch (e) {
      debugLog('⚠️ Could not fetch app logo: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // แสดง Prominent Disclosure ก่อนขอ permission จากระบบ (Google Play Policy)
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) {
            debugLog('⚠️ User declined location disclosure');
            return;
          }
        }
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugLog('❌ Error requesting location permission: $e');
    }
  }

  Future<void> _fetchApprovalStatus() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _approvalStatus = profile['approval_status'] as String? ?? 'pending';
          _rejectionReason = profile['rejection_reason'] as String?;
          _userProfile = profile;
          _profileCompleted = _checkProfileCompleted(profile);
        });
        debugLog('🔑 Approval status: $_approvalStatus, profile completed: $_profileCompleted');
      }
    } catch (e) {
      debugLog('❌ Error fetching approval status: $e');
    }
  }

  bool _checkProfileCompleted(Map<String, dynamic> profile) {
    final role = profile['role'] as String? ?? '';
    final fullName = (profile['full_name'] as String? ?? '').trim();
    final phone = (profile['phone_number'] as String? ?? '').trim();

    if (fullName.isEmpty || phone.isEmpty) return false;

    if (role == 'driver') {
      final licensePlate = (profile['license_plate'] as String? ?? '').trim();
      if (licensePlate.isEmpty) return false;
    }
    if (role == 'merchant') {
      final shopAddress = (profile['shop_address'] as String? ?? '').trim();
      if (shopAddress.isEmpty) return false;
    }
    return true;
  }

  void _onProfileCompleted() {
    // Re-fetch role and profile to refresh the state
    _fetchUserRole();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF4CAF50),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: AppNetworkImage(
                    imageUrl: _logoUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Jedechai Delivery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'บริการจัดส่งครบวงจร',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'กำลังเตรียมระบบ...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const LoginScreen();
    }

    // Check if account is pending deletion
    if (_deletionStatus == 'pending') {
      return const PendingDeletionScreen();
    }

    // Check approval status for driver/merchant
    if ((_userRole == 'driver' || _userRole == 'merchant') &&
        _approvalStatus != 'approved') {
      return PendingApprovalScreen(
        role: _userRole,
        approvalStatus: _approvalStatus,
        rejectionReason: (_approvalStatus == 'rejected' || _approvalStatus == 'suspended') ? _rejectionReason : null,
      );
    }

    // Check profile completion for driver/merchant
    if ((_userRole == 'driver' || _userRole == 'merchant') && !_profileCompleted) {
      return ProfileCompletionScreen(
        role: _userRole,
        existingProfile: _userProfile,
        onCompleted: _onProfileCompleted,
      );
    }

    // Navigate based on user role
    switch (_userRole) {
      case 'admin':
        return const AdminMainScreen();
      case 'driver':
        return const DriverMainScreen();
      case 'merchant':
        return const MerchantMainScreen();
      case 'customer':
      default:
        return const CustomerMainScreen();
    }
  }
}
