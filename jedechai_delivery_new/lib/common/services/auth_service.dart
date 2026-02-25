import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../config/env_config.dart';
import '../config/supabase_config.dart';
import 'mock_auth_service.dart';
import 'profile_service.dart';

/// Authentication Service
///
/// Comprehensive service for handling all authentication operations
/// with Supabase including sign in, sign up, sign out, and user management
/// Automatically switches to mock mode when Supabase is not configured
class AuthService {
  static SupabaseClient get _client {
    if (MockAuthService.useMockMode) {
      // Return a mock client for mock mode
      throw Exception('Mock mode active - Supabase operations not available');
    }
    return Supabase.instance.client;
  }

  /// Initialize AuthService
  ///
  /// Call this method in main() after Supabase.initialize()
  /// Supabase is already initialized in main.dart - do NOT re-initialize here
  static Future<void> initialize() async {
    // Check if Supabase is properly configured
    if (!SupabaseConfig.isConfigured) {
      debugLog('🔧 Using MockAuthService - Supabase not configured');
      await MockAuthService.initialize();
      return;
    }

    try {
      // Verify Supabase is already initialized (done in main.dart)
      Supabase.instance.client;
      debugLog('🔗 AuthService initialized - Supabase connection verified');
    } catch (e) {
      debugLog('❌ Supabase not initialized: $e');
      debugLog('🔧 Falling back to MockAuthService');
      await MockAuthService.initialize();
    }
  }

  // ==================== AUTHENTICATION METHODS ====================

  /// Sign In with Email and Password
  ///
  /// [email] User's email address
  /// [password] User's password
  /// Returns [AuthResponse] with user session
  /// Throws [AuthException] on authentication failure
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.signInWithEmail(
          email: email, password: password);
    }

    try {
      final client = Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      // If it's a network error, suggest checking connection
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw AuthException(
            'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      }
      throw AuthException('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
    }
  }

  /// Sign Up with Email and Password
  ///
  /// [email] User's email address
  /// [password] User's password (min 6 characters)
  /// [userData] Additional user data (optional)
  /// Returns [AuthResponse] with user session
  /// Throws [AuthException] on registration failure
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.signUpWithEmail(
        email: email,
        password: password,
        userData: userData,
      );
    }

    try {
      final client = Supabase.instance.client;

      debugLog('═══ [AuthService.signUpWithEmail] ═══');
      debugLog('📧 Email: ${email.trim()}');
      debugLog('📋 UserData: $userData');

      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: userData ?? {},
      );

      debugLog('📦 auth.signUp สำเร็จ:');
      debugLog('   user.id: ${response.user?.id}');
      debugLog('   user.email: ${response.user?.email}');
      debugLog(
          '   session: ${response.session != null ? "มี" : "ไม่มี (อาจต้องยืนยัน email)"}');
      debugLog('   user.metadata: ${response.user?.userMetadata}');
      debugLog('   user.createdAt: ${response.user?.createdAt}');

      // Create profile after successful signup
      if (response.user != null) {
        try {
          final profileService = ProfileService();
          final role = userData?['role'] ?? 'customer';
          debugLog(
              '📝 กำลังสร้าง profile สำหรับ ${response.user!.id} (role: $role)');

          // Use direct upsert — bypasses column checking and handles
          // the case where session may not be established yet (email confirmation)
          await profileService.upsertProfileDirect(
            userId: response.user!.id,
            email: email,
            role: role,
            fullName: userData?['full_name'] ?? email.split('@')[0],
            phone: userData?['phone_number'] ?? userData?['phone'] ?? '',
            vehicleType: userData?['vehicle_type'] ?? '',
            licensePlate: userData?['license_plate'] ?? '',
            shopName: userData?['shop_name'] ?? '',
            shopAddress: userData?['shop_address'] ?? '',
            shopPhone: userData?['shop_phone'] ?? '',
          );
          debugLog('✅ Profile ถูกสร้างสำเร็จสำหรับ: ${response.user!.id}');
        } catch (profileError, profileStack) {
          debugLog('❌ สร้าง profile ล้มเหลว!');
          debugLog('   Error: $profileError');
          debugLog('   Type: ${profileError.runtimeType}');
          debugLog('   Stack: $profileStack');
          debugLog(
              '⚠️ Profile จะถูกสร้างตอน login ผ่าน getUserRole() fallback');
        }
      } else {
        debugLog('❌ response.user เป็น null — ไม่สามารถสร้าง user ได้');
      }

      // Prevent automatic login immediately after sign-up.
      // Users should explicitly log in from the login screen.
      var normalizedResponse = response;
      if (response.session != null) {
        try {
          await client.auth.signOut();
          normalizedResponse = AuthResponse(
            user: response.user,
            session: null,
          );
          debugLog('🔒 Sign-up session cleared (explicit login required)');
        } catch (signOutError) {
          debugLog('⚠️ Could not clear sign-up session: $signOutError');
        }
      }

      debugLog('═══ [AuthService.signUpWithEmail] จบ ═══');
      return normalizedResponse;
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      // If it's a network error, suggest checking connection
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        throw AuthException(
            'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต');
      }
      throw AuthException('เกิดข้อผิดพลาดในการสมัครสมาชิก: $e');
    }
  }

  /// Sign Out current user
  ///
  /// Clears the current session and signs out the user
  /// Throws [AuthException] on sign out failure
  static Future<void> signOut() async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.signOut();
    }

    try {
      // Phase 3: Clear role cache
      clearRoleCache();

      // Phase 5: Clear FCM token before sign-out to prevent ghost notifications
      try {
        final uid = currentUser?.id;
        if (uid != null) {
          await Supabase.instance.client
              .from('profiles')
              .update({'fcm_token': null})
              .eq('id', uid);
        }
      } catch (_) {
        // Best-effort — don't block sign-out
      }

      final client = Supabase.instance.client;
      await client.auth.signOut();
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการออกจากระบบ: $e');
    }
  }

  // ==================== USER MANAGEMENT ====================

  /// Get Current User
  ///
  /// Returns the currently authenticated user
  /// Returns null if no user is authenticated
  static User? get currentUser {
    if (MockAuthService.useMockMode) {
      return MockAuthService.currentUser;
    }
    return Supabase.instance.client.auth.currentUser;
  }

  /// Check if user is authenticated
  ///
  /// Returns true if user is logged in, false otherwise
  static bool get isAuthenticated {
    if (MockAuthService.useMockMode) {
      return MockAuthService.isAuthenticated;
    }
    return currentUser != null;
  }

  /// Check if app is running in mock mode
  static bool get isMockMode => MockAuthService.useMockMode;

  /// Get Current User ID
  ///
  /// Returns the ID of the currently authenticated user
  /// Returns null if no user is authenticated
  static String? get userId {
    if (MockAuthService.useMockMode) {
      return MockAuthService.userId;
    }
    return currentUser?.id;
  }

  /// Get Current User Email
  ///
  /// Returns the email of the currently authenticated user
  /// Returns null if no user is authenticated
  static String? get userEmail {
    if (MockAuthService.useMockMode) {
      return MockAuthService.currentUser?.email;
    }
    return currentUser?.email;
  }

  // Phase 3: Role cache to avoid repeated DB lookups
  static String? _cachedRole;

  /// Clear cached role (call on sign-out)
  static void clearRoleCache() {
    _cachedRole = null;
  }

  /// Get Current User Role
  ///
  /// Fetches the user's role from the profiles table.
  /// Phase 3 fix: throws on error instead of defaulting to 'customer',
  /// so AuthGate can show an error/retry screen.
  /// Also prevents role injection from userMetadata.
  static Future<String> getUserRole() async {
    if (MockAuthService.useMockMode) {
      return 'customer';
    }

    // Return cached role if available
    if (_cachedRole != null) return _cachedRole!;

    final userId = currentUser?.id;
    if (userId == null) {
      throw Exception('ไม่พบผู้ใช้ที่เข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่');
    }

    try {
      debugLog('🔍 Fetching role for user: $userId');

      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
        debugLog('❌ No profile found for user: $userId');

        // Phase 3B: Auto-create profile but NEVER trust role from metadata.
        // Always default new profiles to 'customer'. Admin/driver/merchant
        // roles must be assigned by an admin.
        try {
          final user = currentUser;
          if (user != null && user.userMetadata != null) {
            final metadata = user.userMetadata!;
            // SECURITY: Ignore metadata['role'] — always use 'customer'
            const safeRole = 'customer';
            debugLog('📝 Creating profile with safe role: $safeRole');

            final profileService = ProfileService();
            await profileService.upsertProfileDirect(
              userId: userId,
              email: user.email ?? '',
              role: safeRole,
              fullName: metadata['full_name'] as String? ?? 'Unknown User',
              phone: metadata['phone_number'] as String? ?? '',
              vehicleType: '',
              licensePlate: '',
              shopName: '',
              shopAddress: '',
              shopPhone: '',
            );

            debugLog('✅ Profile created with safe role: $safeRole');
            _cachedRole = safeRole;
            return safeRole;
          }
        } catch (createError) {
          debugLog('❌ Failed to create profile: $createError');
        }

        throw Exception('ไม่พบโปรไฟล์ผู้ใช้ กรุณาติดต่อแอดมิน');
      }

      final role = response['role'] as String? ?? 'customer';
      debugLog('✅ User role fetched: $role');
      _cachedRole = role;
      return role;
    } catch (e) {
      debugLog('Error fetching user role: $e');
      // Phase 3 fix: rethrow instead of defaulting to 'customer'
      // This lets AuthGate show an error screen instead of wrong routing
      rethrow;
    }
  }

  /// Get Current User Role (Synchronous)
  ///
  /// Returns cached role or null if not yet fetched.
  /// Phase 3 fix: returns cached value instead of hardcoded 'customer'.
  static String? get currentUserRole {
    return _cachedRole;
  }

  /// Refresh Session
  ///
  /// Refreshes the current authentication session
  /// Returns [AuthResponse] with updated session
  /// Throws [AuthException] on refresh failure
  static Future<AuthResponse> refreshSession() async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.refreshSession();
    }

    try {
      final response = await _client.auth.refreshSession();
      return response;
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการรีเฟรชเซสชัน: $e');
    }
  }

  // ==================== PASSWORD MANAGEMENT ====================

  /// Reset Password
  ///
  /// [email] User's email address
  /// Sends password reset email to the user
  /// Throws [AuthException] on failure
  static Future<void> resetPassword({required String email}) async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.resetPassword(email: email);
    }

    try {
      final redirectTo = EnvConfig.passwordResetRedirectUrl.trim();

      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo.isNotEmpty ? redirectTo : null,
      );
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการส่งอีเมลรีเซ็ตรหัสผ่าน: $e');
    }
  }

  /// Update Password
  ///
  /// [newPassword] New password (min 6 characters)
  /// Updates the current user's password
  /// Throws [AuthException] on failure
  static Future<void> updatePassword({required String newPassword}) async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.updatePassword(newPassword: newPassword);
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการอัพเดตรหัสผ่าน: $e');
    }
  }

  // ==================== USER PROFILE MANAGEMENT ====================

  /// Update User Profile
  ///
  /// [data] User data to update (email, name, etc.)
  /// Updates the current user's profile information
  /// Throws [AuthException] on failure
  static Future<User?> updateProfile(
      {required Map<String, dynamic> data}) async {
    if (MockAuthService.useMockMode) {
      return await MockAuthService.updateProfile(data: data);
    }

    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          email: data['email'],
          data: data,
        ),
      );
      return response.user;
    } on AuthException {
      rethrow; // Re-throw AuthException as-is
    } catch (e) {
      throw AuthException('เกิดข้อผิดพลาดในการอัพเดตโปรไฟล์: $e');
    }
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Get Current Session
  ///
  /// Returns the current authentication session
  /// Returns null if no active session
  static Session? get currentSession {
    if (MockAuthService.useMockMode) {
      return MockAuthService.currentSession;
    }
    return Supabase.instance.client.auth.currentSession;
  }

  /// Listen to Auth State Changes
  ///
  /// [callback] Function to call when auth state changes
  /// Returns a subscription that can be cancelled
  static StreamSubscription<AuthState> onAuthStateChange({
    required Function(AuthState state) callback,
  }) {
    if (MockAuthService.useMockMode) {
      return MockAuthService.onAuthStateChange.listen(callback);
    }

    return Supabase.instance.client.auth.onAuthStateChange.listen(callback);
  }

  // ==================== VALIDATION HELPERS ====================

  /// Validate Email Format
  ///
  /// [email] Email address to validate
  /// Returns true if email format is valid, false otherwise
  static bool isValidEmail(String email) {
    return MockAuthService.isValidEmail(email);
  }

  /// Validate Password Strength
  ///
  /// [password] Password to validate
  /// Returns true if password meets requirements, false otherwise
  static bool isValidPassword(String password) {
    return MockAuthService.isValidPassword(password);
  }

  /// Get Password Strength Message
  ///
  /// [password] Password to check
  /// Returns message describing password strength
  static String getPasswordStrengthMessage(String password) {
    return MockAuthService.getPasswordStrengthMessage(password);
  }

  // ==================== CONFIGURATION HELPERS ====================

  /// Print configuration status
  static void printConfigStatus() {
    MockAuthService.printConfigStatus();
  }
}
