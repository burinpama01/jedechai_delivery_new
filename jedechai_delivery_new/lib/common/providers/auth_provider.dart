import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/fcm_notification_service.dart';
import '../../utils/debug_logger.dart';

/// AuthProvider - Centralized auth state management
/// 
/// Provides reactive auth state across the entire app:
/// - Current user info (id, email, role)
/// - Profile data (name, phone)
/// - Login/logout actions
/// - Auth state change listener
class AuthProvider extends ChangeNotifier {
  // Auth state
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _userRole = 'customer';
  Map<String, dynamic>? _userProfile;
  StreamSubscription<AuthState>? _authSubscription;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String get userRole => _userRole;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get userId => AuthService.userId;
  String? get userEmail => AuthService.userEmail;
  String get displayName => _userProfile?['full_name'] ?? userEmail ?? 'ผู้ใช้';
  String? get phoneNumber => _userProfile?['phone_number'];

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isAuthenticated = AuthService.isAuthenticated;
    _isLoading = false;
    notifyListeners();

    if (_isAuthenticated) {
      await _fetchUserRole();
      await _fetchProfile();
    }

    // Listen to auth state changes
    _authSubscription = AuthService.onAuthStateChange(
      callback: (AuthState state) {
        _isAuthenticated = state.session != null;
        _isLoading = false;
        notifyListeners();

        if (state.session != null) {
          _fetchUserRole();
          _fetchProfile();
        } else {
          _userRole = 'customer';
          _userProfile = null;
          notifyListeners();
        }
      },
    );
  }

  Future<void> _fetchUserRole() async {
    try {
      final role = await AuthService.getUserRole();
      _userRole = role;
      notifyListeners();
      debugLog('🎭 AuthProvider: role = $_userRole');

      // Save FCM token when authenticated
      await FCMNotificationService().saveToken();
    } catch (e) {
      debugLog('❌ AuthProvider: Error fetching role: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final profile = await ProfileService().getCurrentProfile();
      _userProfile = profile;
      notifyListeners();
    } catch (e) {
      debugLog('❌ AuthProvider: Error fetching profile: $e');
    }
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await _fetchProfile();
  }

  /// Sign out
  Future<void> signOut() async {
    await FCMNotificationService().clearToken();
    await AuthService.signOut();
    _isAuthenticated = false;
    _userRole = 'customer';
    _userProfile = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
