import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/jdc_colors.dart';

/// Connection Helper
/// 
/// Utility class for handling Supabase connection issues
class ConnectionHelper {
  static bool isConnectionError(dynamic error) {
    final errorString = error.toString();
    return errorString.contains('SocketException') ||
           errorString.contains('host lookup') ||
           errorString.contains('Failed host lookup') ||
           errorString.contains('NetworkException') ||
           errorString.contains('Connection refused') ||
           errorString.contains('timeout') ||
           errorString.contains('No address associated with hostname') ||
           errorString.contains('InvalidJWTToken') ||
           errorString.contains('Token has expired');
  }

  /// [l10n] ส่งมาเมื่อมี BuildContext เพื่อให้ข้อความตามภาษาที่เลือก;
  /// ไม่ส่ง = ข้อความไทย (ตรงกับ app_th.arb) สำหรับจุดที่ไม่มี context
  static String getErrorMessage(dynamic error, [AppLocalizations? l10n]) {
    final errorString = error.toString();
    
    // Handle JWT token expired errors
    if (errorString.contains('InvalidJWTToken') || errorString.contains('Token has expired')) {
      return l10n?.connErrSessionExpired ?? 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
    }
    
    if (isConnectionError(error)) {
      return l10n?.connErrNoConnection ??
          'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตและลองใหม่';
    }
    
    if (errorString.contains('AuthRetryableFetchException')) {
      return l10n?.connErrAuth ?? 'การยืนยันตัวตนผิดพลาด กรุณาลองเข้าสู่ระบบใหม่';
    }
    
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return l10n?.connErrForbidden ?? 'คุณไม่มีสิทธิ์เข้าถึงข้อมูลนี้';
    }
    
    if (errorString.contains('404') || errorString.contains('Not found')) {
      return l10n?.connErrNotFound ?? 'ไม่พบข้อมูลที่ร้องขอ';
    }
    
    if (errorString.contains('500') || errorString.contains('Internal Server Error')) {
      return l10n?.connErrServer ?? 'เซิร์ฟเวอร์ขัดข้อง กรุณาลองใหม่ภายหลัง';
    }
    
    return l10n?.connErrGeneric(errorString) ?? 'เกิดข้อผิดพลาด: $errorString';
  }

  static Future<T> withTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await operation().timeout(timeout);
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('คำขอหมดเวลา กรุณาตรวจสอบการเชื่อมต่อและลองใหม่');
      }
      rethrow;
    }
  }

  static void showConnectionErrorSnackBar(BuildContext context, dynamic error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.wifi_off, color: JdcColors.of(ctx).danger, size: 48),
        title: Text(AppLocalizations.of(ctx)!.connErrDialogTitle),
        content: Text(getErrorMessage(error, AppLocalizations.of(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  static Widget buildErrorWidget({
    required String error,
    required VoidCallback onRetry,
    String? title,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Builder(
            builder: (context) => Icon(
              isConnectionError(error) ? Icons.wifi_off : Icons.error_outline,
              size: 64,
              color: isConnectionError(error)
                  ? JdcColors.of(context).muted
                  : JdcColors.of(context).danger,
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) => Text(
              title ??
                  (isConnectionError(error)
                      ? AppLocalizations.of(context)!.connErrTitle
                      : AppLocalizations.of(context)!.connErrTitleGeneric),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Builder(
              builder: (context) => Text(
                getErrorMessage(error, AppLocalizations.of(context)),
                style: TextStyle(
                  fontSize: 14,
                  color: JdcColors.of(context).muted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            final jdc = JdcColors.of(context);
            return ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.accountRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
              ),
            );
          }),
        ],
      ),
    );
  }
}
