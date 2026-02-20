import 'dart:async';
import 'package:flutter/material.dart';

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

  static String getErrorMessage(dynamic error) {
    final errorString = error.toString();
    
    // Handle JWT token expired errors
    if (errorString.contains('InvalidJWTToken') || errorString.contains('Token has expired')) {
      return 'เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่';
    }
    
    if (isConnectionError(error)) {
      return 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตและลองใหม่';
    }
    
    if (errorString.contains('AuthRetryableFetchException')) {
      return 'การยืนยันตัวตนผิดพลาด กรุณาลองเข้าสู่ระบบใหม่';
    }
    
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return 'คุณไม่มีสิทธิ์เข้าถึงข้อมูลนี้';
    }
    
    if (errorString.contains('404') || errorString.contains('Not found')) {
      return 'ไม่พบข้อมูลที่ร้องขอ';
    }
    
    if (errorString.contains('500') || errorString.contains('Internal Server Error')) {
      return 'เซิร์ฟเวอร์ขัดข้อง กรุณาลองใหม่ภายหลัง';
    }
    
    return 'เกิดข้อผิดพลาด: ${error.toString()}';
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
        icon: const Icon(Icons.wifi_off, color: Colors.red, size: 48),
        title: const Text('การเชื่อมต่อขัดข้อง'),
        content: Text(getErrorMessage(error)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ตกลง'),
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
          Icon(
            isConnectionError(error) ? Icons.wifi_off : Icons.error_outline,
            size: 64,
            color: isConnectionError(error) ? Colors.orange : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            title ?? (isConnectionError(error) ? 'Connection Error' : 'Error'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              getErrorMessage(error),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
