import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

/// Storage Service
///
/// Handles file storage operations using Supabase Storage
class StorageService {
  static const String _bucketName = 'app-uploads';

  static Future<String?> uploadFile({
    required File file,
    required String path,
    Map<String, String>? metadata,
    String? bucketName,
  }) async {
    try {
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_extractFileName(file.path)}';
      final String filePath = '$path/$fileName';
      final String targetBucket = bucketName ?? _bucketName;

      await Supabase.instance.client.storage.from(targetBucket).upload(
            filePath,
            file,
            fileOptions: FileOptions(
              contentType: _getContentType(file.path),
              metadata: metadata,
            ),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from(targetBucket)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      debugLog('Error uploading file: $e');
      return null;
    }
  }

  static Future<String?> uploadImage({
    required File imageFile,
    required String folder,
    Map<String, String>? metadata,
    String? bucketName,
  }) async {
    return await uploadFile(
      file: imageFile,
      path: folder,
      metadata: metadata,
      bucketName: bucketName,
    );
  }

  static Future<bool> deleteFile(String path, {String? bucketName}) async {
    try {
      final String targetBucket = bucketName ?? _bucketName;
      await Supabase.instance.client.storage.from(targetBucket).remove([path]);
      return true;
    } catch (e) {
      debugLog('Error deleting file: $e');
      return false;
    }
  }

  static Future<String?> getPublicUrl(String path, {String? bucketName}) async {
    try {
      final String targetBucket = bucketName ?? _bucketName;
      return Supabase.instance.client.storage
          .from(targetBucket)
          .getPublicUrl(path);
    } catch (e) {
      debugLog('Error getting public URL: $e');
      return null;
    }
  }

  static Future<String?> uploadProfileImage({
    required File imageFile,
    required String userId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'profiles/$userId',
      metadata: {
        'user_id': userId,
        'type': 'profile_image',
        'uploaded_at': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<String?> uploadMenuItemImage({
    required File imageFile,
    required String merchantId,
    required String menuItemId,
  }) async {
    return await uploadImage(
      imageFile: imageFile,
      folder: 'menu_items/$merchantId',
      metadata: {
        'merchant_id': merchantId,
        'menu_item_id': menuItemId,
        'type': 'menu_item_image',
        'uploaded_at': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<String?> uploadDocument({
    required File documentFile,
    required String folder,
    required String documentType,
    Map<String, String>? metadata,
  }) async {
    return await uploadFile(
      file: documentFile,
      path: folder,
      metadata: {
        ...?metadata,
        'type': documentType,
        'uploaded_at': DateTime.now().toIso8601String(),
      },
    );
  }

  static Future<String?> generateSignedUrl({
    required String path,
    int expiresIn = 3600, // 1 hour in seconds
  }) async {
    try {
      return Supabase.instance.client.storage
          .from(_bucketName)
          .createSignedUrl(path, expiresIn);
    } catch (e) {
      debugLog('Error generating signed URL: $e');
      return null;
    }
  }

  static Future<bool> fileExists(String path) async {
    try {
      await Supabase.instance.client.storage.from(_bucketName).download(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> listFiles({
    required String folder,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await Supabase.instance.client.storage
          .from(_bucketName)
          .list(path: folder);

      return response.map((item) => item.name).toList();
    } catch (e) {
      debugLog('Error listing files: $e');
      return [];
    }
  }

  static String _getContentType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'txt':
        return 'text/plain';
      case 'json':
        return 'application/json';
      case 'xml':
        return 'application/xml';
      case 'zip':
        return 'application/zip';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static String _extractFileName(String fullPath) {
    final normalizedPath = fullPath.replaceAll('\\', '/');
    final segments = normalizedPath.split('/');
    if (segments.isEmpty || segments.last.isEmpty) {
      return 'upload.bin';
    }
    return segments.last;
  }

  static Future<double?> getFileSize(String path) async {
    try {
      final response = await Supabase.instance.client.storage
          .from(_bucketName)
          .list(path: path);

      if (response.isNotEmpty) {
        // FileObject doesn't have size property in current version
        // Return null for now
        return null;
      }
      return null;
    } catch (e) {
      debugLog('Error getting file size: $e');
      return null;
    }
  }

  static String formatFileSize(double bytes) {
    if (bytes < 1024) {
      return '${bytes.round()} B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).round()} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round()} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).round()} GB';
    }
  }
}
