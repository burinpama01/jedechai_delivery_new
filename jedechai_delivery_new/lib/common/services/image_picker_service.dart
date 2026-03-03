import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/debug_logger.dart';
import '../utils/platform_adaptive.dart';
import 'storage_service.dart';

/// ImagePickerService - บริการถ่ายรูป/เลือกรูป พร้อมบีบอัดอัตโนมัติ
///
/// ฟีเจอร์:
/// - ถ่ายรูปจากกล้อง หรือเลือกจากแกลเลอรี
/// - บีบอัดรูปอัตโนมัติ (ถ้าขนาดเกิน maxSizeKB)
/// - อัปโหลดไป Supabase Storage
/// - รองรับเลือกหลายรูป
class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  /// ขนาดสูงสุดของรูปที่อนุญาต (KB) - ถ้าเกินจะบีบอัดอัตโนมัติ
  static const int maxSizeKB = 500;

  /// ความกว้างสูงสุดของรูป (pixels)
  static const int maxWidth = 1024;

  /// ความสูงสูงสุดของรูป (pixels)
  static const int maxHeight = 1024;

  /// คุณภาพเริ่มต้นของการบีบอัด (0-100)
  static const int defaultQuality = 80;

  /// แสดง Bottom Sheet ให้เลือกถ่ายรูปหรือเลือกจากแกลเลอรี
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.imagePickerChooseImage,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF4CAF50),
                  child: Icon(
                    PlatformAdaptive.icon(
                      android: Icons.camera_alt,
                      ios: CupertinoIcons.camera,
                    ),
                    color: Colors.white,
                  ),
                ),
                title: Text(l10n.imagePickerTakePhoto),
                subtitle: Text(l10n.imagePickerTakePhotoSubtitle),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(0xFF2196F3),
                  child: Icon(
                    PlatformAdaptive.icon(
                      android: Icons.photo_library,
                      ios: CupertinoIcons.photo,
                    ),
                    color: Colors.white,
                  ),
                ),
                title: Text(l10n.imagePickerPickGallery),
                subtitle: Text(l10n.imagePickerPickGallerySubtitle),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;
    return await pickAndCompressImage(source: source);
  }

  /// ถ่ายรูปหรือเลือกรูป แล้วบีบอัดอัตโนมัติ
  static Future<File?> pickAndCompressImage({
    required ImageSource source,
    int quality = defaultQuality,
    int maxW = maxWidth,
    int maxH = maxHeight,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxW.toDouble(),
        maxHeight: maxH.toDouble(),
        imageQuality: quality,
      );

      if (pickedFile == null) return null;

      final File originalFile = File(pickedFile.path);
      final int fileSizeKB = await originalFile.length() ~/ 1024;

      debugLog('📷 รูปต้นฉบับ: ${fileSizeKB}KB');

      // ถ้าขนาดเกิน maxSizeKB ให้บีบอัดเพิ่ม
      if (fileSizeKB > maxSizeKB) {
        final compressed = await _compressImage(originalFile, quality: quality);
        if (compressed != null) {
          final compressedSizeKB = await compressed.length() ~/ 1024;
          debugLog(
              '📷 บีบอัดแล้ว: ${compressedSizeKB}KB (จาก ${fileSizeKB}KB)');
          return compressed;
        }
      }

      return originalFile;
    } catch (e) {
      debugLog('❌ Error picking image: $e');
      return null;
    }
  }

  /// ถ่ายรูปจากกล้อง
  static Future<File?> takePhoto({int quality = defaultQuality}) async {
    return await pickAndCompressImage(
      source: ImageSource.camera,
      quality: quality,
    );
  }

  /// เลือกรูปจากแกลเลอรี
  static Future<File?> pickFromGallery({int quality = defaultQuality}) async {
    return await pickAndCompressImage(
      source: ImageSource.gallery,
      quality: quality,
    );
  }

  /// เลือกหลายรูปจากแกลเลอรี
  static Future<List<File>> pickMultipleImages({
    int quality = defaultQuality,
    int maxImages = 5,
  }) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
        limit: maxImages,
      );

      final List<File> compressedFiles = [];
      for (final xfile in pickedFiles) {
        final file = File(xfile.path);
        final sizeKB = await file.length() ~/ 1024;

        if (sizeKB > maxSizeKB) {
          final compressed = await _compressImage(file, quality: quality);
          if (compressed != null) {
            compressedFiles.add(compressed);
            continue;
          }
        }
        compressedFiles.add(file);
      }

      debugLog('📷 เลือก ${compressedFiles.length} รูป');
      return compressedFiles;
    } catch (e) {
      debugLog('❌ Error picking multiple images: $e');
      return [];
    }
  }

  /// บีบอัดรูปภาพ
  static Future<File?> _compressImage(
    File file, {
    int quality = defaultQuality,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
      );

      if (result != null) {
        return File(result.path);
      }
      return null;
    } catch (e) {
      debugLog('❌ Error compressing image: $e');
      return null;
    }
  }

  /// ถ่ายรูปแล้วอัปโหลดไป Supabase Storage ทันที
  ///
  /// [folder] - โฟลเดอร์ใน Storage (เช่น 'parcels', 'deliveries')
  /// Returns: URL ของรูปที่อัปโหลด หรือ null ถ้าล้มเหลว
  static Future<String?> pickAndUpload({
    required BuildContext context,
    required String folder,
    Map<String, String>? metadata,
  }) async {
    final file = await showImageSourceDialog(context);
    if (file == null) return null;

    return await StorageService.uploadImage(
      imageFile: file,
      folder: folder,
      metadata: metadata,
    );
  }

  /// ถ่ายรูปจากกล้องแล้วอัปโหลดทันที
  static Future<String?> takePhotoAndUpload({
    required String folder,
    Map<String, String>? metadata,
  }) async {
    final file = await takePhoto();
    if (file == null) return null;

    return await StorageService.uploadImage(
      imageFile: file,
      folder: folder,
      metadata: metadata,
    );
  }

  /// บีบอัดไฟล์ที่มีอยู่แล้ว (สำหรับกรณีที่ได้ไฟล์จากที่อื่น)
  static Future<File?> compressExistingFile(File file) async {
    final sizeKB = await file.length() ~/ 1024;
    if (sizeKB <= maxSizeKB) return file;
    return await _compressImage(file);
  }
}
