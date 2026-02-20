import 'dart:async';
import '../common/services/auth_service.dart';

/// Auth Helper
/// 
/// Utility class for handling authentication-related operations
/// including automatic token refresh and error handling
class AuthHelper {
  static Timer? _refreshTimer;
  static const Duration _refreshInterval = Duration(minutes: 5); // Refresh every 5 minutes

  /// Initialize automatic token refresh
  static void initializeAutoRefresh() {
    // Cancel existing timer if any
    _refreshTimer?.cancel();
    
    // Start periodic refresh
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) async {
      await _attemptTokenRefresh();
    });
  }

  /// Stop automatic token refresh
  static void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Attempt to refresh the current session
  static Future<void> _attemptTokenRefresh() async {
    try {
      final session = AuthService.currentSession;
      if (session != null) {
        // Check if token is close to expiry (within 10 minutes)
        final expiresAt = session.expiresAt;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final timeUntilExpiry = expiresAt! - now;
        
        if (timeUntilExpiry < 600) { // Less than 10 minutes
          await AuthService.refreshSession();
        }
      }
    } catch (e) {
      // If refresh fails, sign out the user
      if (e.toString().contains('InvalidJWTToken') || 
          e.toString().contains('Token has expired')) {
        await AuthService.signOut();
      }
    }
  }

  /// Handle JWT token expired error
  static Future<bool> handleTokenExpired() async {
    try {
      // Try to refresh the session
      final response = await AuthService.refreshSession();
      
      if (response.session != null) {
        return true;
      } else {
        await AuthService.signOut();
        return false;
      }
    } catch (e) {
      // Sign out the user if refresh fails
      await AuthService.signOut();
      return false;
    }
  }

  /// Check if current session is valid
  static bool isSessionValid() {
    final session = AuthService.currentSession;
    if (session == null) return false;
    
    final expiresAt = session.expiresAt;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    return expiresAt! > now;
  }

  /// Get remaining time until token expires
  static Duration getTimeUntilExpiry() {
    final session = AuthService.currentSession;
    if (session == null || session.expiresAt == null) {
      return Duration.zero;
    }
    
    final expiresAt = session.expiresAt!;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remainingSeconds = expiresAt - now;
    
    return Duration(seconds: remainingSeconds > 0 ? remainingSeconds : 0);
  }

  /// Format remaining time for display
  static String formatRemainingTime() {
    final remaining = getTimeUntilExpiry();
    
    if (remaining.inSeconds <= 0) {
      return 'Expired';
    }
    
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m ${remaining.inSeconds % 60}s';
    } else {
      return '${remaining.inSeconds}s';
    }
  }

  /// Cleanup resources
  static void dispose() {
    stopAutoRefresh();
  }
}
