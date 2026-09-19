import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Mock Authentication Service
///
/// This service provides mock authentication for testing purposes
/// when Supabase is not configured or available
class MockAuthService {
  static User? _mockUser;
  static bool _isAuthenticated = false;

  /// Initialize Mock Service
  static Future<void> initialize() async {
    // Mock initialization - no real Supabase connection
    debugLog('🔧 MockAuthService initialized (no Supabase connection)');
  }

  // ==================== MOCK AUTHENTICATION METHODS ====================

  /// Mock Sign In with Email and Password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Mock validation
    if (email.isEmpty || password.isEmpty) {
      throw AuthException('กรุณากรอกอีเมลและรหัสผ่าน');
    }

    if (password.length < 6) {
      throw AuthException('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }

    // Create mock user
    _mockUser = User(
      id: 'mock-user-id-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      appMetadata: {},
      userMetadata: {
        'full_name': 'Mock User',
        'role': 'customer',
      },
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    _isAuthenticated = true;

    return AuthResponse(
      user: _mockUser,
      session: Session(
        accessToken: 'mock-access-token',
        refreshToken: 'mock-refresh-token',
        user: _mockUser!,
        expiresIn: 3600,
        tokenType: 'bearer',
      ),
    );
  }

  /// Mock Sign Up with Email and Password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Mock validation
    if (!isValidEmail(email)) {
      throw AuthException('อีเมลไม่ถูกต้อง');
    }

    if (!isValidPassword(password)) {
      throw AuthException('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }

    // Create mock user
    _mockUser = User(
      id: 'mock-user-id-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      appMetadata: {},
      userMetadata: userData ??
          {
            'full_name': 'New User',
            'role': 'customer',
          },
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    // Keep user logged out after registration to mirror production flow.
    _isAuthenticated = false;

    return AuthResponse(
      user: _mockUser,
      session: null,
    );
  }

  /// Mock Sign Out
  static Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _mockUser = null;
    _isAuthenticated = false;
  }

  // ==================== MOCK USER MANAGEMENT ====================

  /// Get Current User
  static User? get currentUser => _mockUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => _isAuthenticated;

  /// Get Current User ID
  static String? get userId => _mockUser?.id;

  /// Get Current User Email
  static String? get userEmail => _mockUser?.email;

  /// Mock Refresh Session
  static Future<AuthResponse> refreshSession() async {
    if (_mockUser == null) {
      throw AuthException('ไม่มีผู้ใช้ที่ล็อกอินอยู่');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    return AuthResponse(
      user: _mockUser,
      session: Session(
        accessToken: 'mock-refreshed-token',
        refreshToken: 'mock-refresh-token',
        user: _mockUser!,
        expiresIn: 3600,
        tokenType: 'bearer',
      ),
    );
  }

  // ==================== MOCK PASSWORD MANAGEMENT ====================

  /// Mock Reset Password
  static Future<void> resetPassword({required String email}) async {
    await Future.delayed(const Duration(seconds: 1));

    if (!isValidEmail(email)) {
      throw AuthException('อีเมลไม่ถูกต้อง');
    }

    // Mock success - just print message
    debugLog('📧 Mock password reset email sent to: $email');
  }

  /// Mock Update Password
  static Future<void> updatePassword({required String newPassword}) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!isValidPassword(newPassword)) {
      throw AuthException('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }

    debugLog('🔒 Mock password updated successfully');
  }

  /// Mock Update User Profile
  static Future<User?> updateProfile(
      {required Map<String, dynamic> data}) async {
    if (_mockUser == null) {
      throw AuthException('ไม่มีผู้ใช้ที่ล็อกอินอยู่');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Update mock user metadata
    final updatedMetadata =
        Map<String, dynamic>.from(_mockUser!.userMetadata ?? {});
    updatedMetadata.addAll(data);

    _mockUser = User(
      id: _mockUser!.id,
      email: _mockUser!.email,
      appMetadata: _mockUser!.appMetadata,
      userMetadata: updatedMetadata,
      aud: _mockUser!.aud,
      createdAt: _mockUser!.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );

    return _mockUser;
  }

  // ==================== MOCK SESSION MANAGEMENT ====================

  /// Get Current Session
  static Session? get currentSession {
    if (_mockUser == null) return null;

    return Session(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      user: _mockUser!,
      expiresIn: 3600,
      tokenType: 'bearer',
    );
  }

  /// Mock Listen to Auth State Changes
  static Stream<AuthState> get onAuthStateChange {
    return Stream.value(AuthState(
      AuthChangeEvent.initialSession,
      currentSession,
    ));
  }

  // ==================== VALIDATION HELPERS ====================

  /// Validate Email Format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate Password Strength
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Get Password Strength Message
  static String getPasswordStrengthMessage(String password) {
    if (password.isEmpty) return 'กรุณากรอกรหัสผ่าน';
    if (password.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
    if (password.length < 8) return 'รหัสผ่านปานกลาง';
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'ควรมีตัวอักษรพิมพ์ใหญ่';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'ควรมีตัวเลข';
    return 'รหัสผ่านแข็งแรง';
  }

  // ==================== UTILITY METHODS ====================

  /// Check if Supabase is configured
  ///
  /// ISSUE-105: เดิมเช็คแค่ว่าค่าไม่เท่ากับ placeholder ทำให้ค่าว่างถูกนับว่า
  /// "configured" แล้วขัดกับ SupabaseConfig.isConfigured ที่เช็คว่าไม่ว่าง
  /// ตอนนี้ยึด SupabaseConfig.isConfigured เป็น source of truth เดียว
  static bool get isSupabaseConfigured =>
      SupabaseConfig.isConfigured &&
      SupabaseConfig.supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      SupabaseConfig.supabaseAnonKey != 'YOUR_ANON_KEY';

  /// Get appropriate service based on configuration
  ///
  /// ISSUE-105: mock auth รับอีเมลอะไรก็ได้ + รหัสผ่าน 6 ตัวขึ้นไป จึงต้อง
  /// ไม่มีทางทำงานใน release build เด็ดขาด — ถ้า config หายใน production
  /// ให้แอปแสดงหน้า error แทนการปล่อยให้ล็อกอินปลอมได้
  static bool get useMockMode => kDebugMode && !isSupabaseConfigured;

  /// Print current configuration status
  static void printConfigStatus() {
    if (useMockMode) {
      debugLog('🔧 Using MockAuthService (Supabase not configured)');
    } else {
      debugLog('🔗 Using real Supabase connection');
    }
  }
}
