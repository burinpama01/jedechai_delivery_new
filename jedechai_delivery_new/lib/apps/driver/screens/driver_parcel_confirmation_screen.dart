import 'dart:io';
import 'package:flutter/material.dart';
import '../../../common/services/parcel_service.dart';
import '../../../common/models/parcel_detail.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/services/storage_service.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/debug_logger.dart';

/// Driver Parcel Confirmation Screen
///
/// แสดงรายละเอียดพัสดุและให้คนขับถ่ายรูปยืนยันในแต่ละขั้นตอน:
/// - pickup: ถ่ายรูปตอนรับของ
/// - delivery: ถ่ายรูปตอนส่งของ + ลายเซ็นผู้รับ
class DriverParcelConfirmationScreen extends StatefulWidget {
  final String bookingId;
  final String confirmationType; // 'pickup' or 'delivery'

  const DriverParcelConfirmationScreen({
    super.key,
    required this.bookingId,
    required this.confirmationType,
  });

  @override
  State<DriverParcelConfirmationScreen> createState() =>
      _DriverParcelConfirmationScreenState();
}

class _DriverParcelConfirmationScreenState
    extends State<DriverParcelConfirmationScreen> {
  final ParcelService _parcelService = ParcelService();

  ParcelDetail? _parcelDetail;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // รูปภาพ
  File? _confirmPhoto;
  File? _signaturePhoto;

  @override
  void initState() {
    super.initState();
    _loadParcelDetail();
  }

  Future<void> _loadParcelDetail() async {
    try {
      final detail = await _parcelService.getParcelDetail(widget.bookingId);
      if (mounted) {
        setState(() {
          _parcelDetail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading parcel detail: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takeConfirmPhoto() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file != null && mounted) {
      setState(() => _confirmPhoto = file);
    }
  }

  Future<void> _takeSignaturePhoto() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file != null && mounted) {
      setState(() => _signaturePhoto = file);
    }
  }

  Future<void> _submitConfirmation() async {
    if (_confirmPhoto == null) {
      _showErrorDialog('กรุณาถ่ายรูปยืนยัน');
      return;
    }

    if (widget.confirmationType == 'delivery' && _signaturePhoto == null) {
      _showErrorDialog('กรุณาถ่ายรูปลายเซ็นผู้รับ');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // อัปโหลดรูปยืนยัน
      final confirmPhotoUrl = await StorageService.uploadImage(
        imageFile: _confirmPhoto!,
        folder: 'parcels/${widget.bookingId}',
        metadata: {
          'type': widget.confirmationType == 'pickup'
              ? 'pickup_photo'
              : 'delivery_photo',
          'booking_id': widget.bookingId,
        },
      );

      if (confirmPhotoUrl == null) {
        throw Exception('อัปโหลดรูปไม่สำเร็จ');
      }

      if (widget.confirmationType == 'pickup') {
        // ถ่ายรูปตอนรับของ
        final success = await _parcelService.updatePickupPhoto(
          bookingId: widget.bookingId,
          photoUrl: confirmPhotoUrl,
        );

        if (!success) throw Exception('อัปเดตสถานะไม่สำเร็จ');

        if (mounted) {
          _showSuccessDialog(
            'รับพัสดุสำเร็จ!',
            'บันทึกรูปภาพเรียบร้อย\nกรุณาเดินทางไปส่งพัสดุ',
          );
        }
      } else {
        // ถ่ายรูปตอนส่งของ + ลายเซ็น
        String? signatureUrl;
        if (_signaturePhoto != null) {
          signatureUrl = await StorageService.uploadImage(
            imageFile: _signaturePhoto!,
            folder: 'parcels/${widget.bookingId}',
            metadata: {
              'type': 'signature_photo',
              'booking_id': widget.bookingId,
            },
          );
        }

        final success = await _parcelService.updateDeliveryPhotos(
          bookingId: widget.bookingId,
          deliveryPhotoUrl: confirmPhotoUrl,
          signaturePhotoUrl: signatureUrl,
        );

        if (!success) throw Exception('อัปเดตสถานะไม่สำเร็จ');

        if (mounted) {
          _showSuccessDialog(
            'ส่งพัสดุสำเร็จ!',
            'บันทึกรูปภาพและลายเซ็นเรียบร้อย\nงานเสร็จสมบูรณ์',
          );
        }
      }
    } catch (e) {
      debugLog('❌ Error submitting confirmation: $e');
      if (mounted) {
        _showErrorDialog('เกิดข้อผิดพลาด\nกรุณาลองใหม่อีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text('เกิดข้อผิดพลาด',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('ตกลง',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: AppTheme.accentBlue, size: 48),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true); // ส่ง true กลับ = สำเร็จ
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('ตกลง',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPickup = widget.confirmationType == 'pickup';

    return Scaffold(
      appBar: AppBar(
        title: Text(isPickup ? 'ยืนยันรับพัสดุ' : 'ยืนยันส่งพัสดุ'),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ข้อมูลพัสดุ
                  _buildParcelInfoCard(),
                  const SizedBox(height: 20),

                  // รูปพัสดุจากลูกค้า (ถ้ามี)
                  if (_parcelDetail?.parcelPhotoUrl != null) ...[
                    _buildCustomerPhotoCard(),
                    const SizedBox(height: 20),
                  ],

                  // ถ่ายรูปยืนยัน
                  _buildConfirmPhotoSection(isPickup),
                  const SizedBox(height: 20),

                  // ถ่ายรูปลายเซ็น (เฉพาะตอนส่ง)
                  if (!isPickup) ...[
                    _buildSignaturePhotoSection(),
                    const SizedBox(height: 20),
                  ],

                  // ปุ่มยืนยัน
                  _buildSubmitButton(isPickup),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildParcelInfoCard() {
    if (_parcelDetail == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('ไม่พบข้อมูลพัสดุ',
              style: TextStyle(color: Colors.grey[600])),
        ),
      );
    }

    final pd = _parcelDetail!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: AppTheme.accentBlue),
                const SizedBox(width: 8),
                const Text('ข้อมูลพัสดุ',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            _infoRow('ผู้ส่ง', '${pd.senderName} (${pd.senderPhone})'),
            _infoRow('ผู้รับ', '${pd.recipientName} (${pd.recipientPhone})'),
            _infoRow('ขนาด', pd.sizeDisplayText),
            if (pd.description != null && pd.description!.isNotEmpty)
              _infoRow('รายละเอียด', pd.description!),
            if (pd.estimatedWeightKg != null)
              _infoRow('น้ำหนัก', '${pd.estimatedWeightKg} กก.'),
            _infoRow('สถานะ', pd.statusDisplayText),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPhotoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รูปพัสดุจากลูกค้า',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AppNetworkImage(
                imageUrl: _parcelDetail!.parcelPhotoUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                backgroundColor: Colors.grey[200],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmPhotoSection(bool isPickup) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPickup ? 'ถ่ายรูปยืนยันรับพัสดุ *' : 'ถ่ายรูปยืนยันส่งพัสดุ *',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              isPickup
                  ? 'ถ่ายรูปพัสดุที่รับมาเพื่อยืนยัน'
                  : 'ถ่ายรูปพัสดุที่ส่งถึงผู้รับ',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _buildPhotoBox(
              photo: _confirmPhoto,
              onTap: _takeConfirmPhoto,
              onRemove: () => setState(() => _confirmPhoto = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturePhotoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ถ่ายรูปลายเซ็นผู้รับ *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('ถ่ายรูปลายเซ็นหรือบัตรประชาชนผู้รับ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            _buildPhotoBox(
              photo: _signaturePhoto,
              onTap: _takeSignaturePhoto,
              onRemove: () => setState(() => _signaturePhoto = null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required File? photo,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppFileImage(file: photo),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('แตะเพื่อถ่ายรูป',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isPickup) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitConfirmation,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(isPickup ? Icons.check_circle : Icons.done_all),
        label: Text(
          isPickup ? 'ยืนยันรับพัสดุ' : 'ยืนยันส่งพัสดุสำเร็จ',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }
}
