import 'dart:io';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/services/parcel_service.dart';
import '../../../common/models/parcel_detail.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/services/storage_service.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
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
  final TextEditingController _deliveryNoteController = TextEditingController();

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

  @override
  void dispose() {
    _deliveryNoteController.dispose();
    super.dispose();
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
      _showErrorDialog(AppLocalizations.of(context)!.parcelConfirmPhotoRequired);
      return;
    }

    if (widget.confirmationType == 'delivery' && _signaturePhoto == null) {
      _showErrorDialog(AppLocalizations.of(context)!.parcelConfirmSignatureRequired);
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
        throw Exception(AppLocalizations.of(context)!.parcelConfirmUploadFailed);
      }

      if (widget.confirmationType == 'pickup') {
        // ถ่ายรูปตอนรับของ
        final success = await _parcelService.updatePickupPhoto(
          bookingId: widget.bookingId,
          photoUrl: confirmPhotoUrl,
        );

        if (!success) throw Exception(AppLocalizations.of(context)!.parcelConfirmUpdateFailed);

        if (mounted) {
          _showSuccessDialog(
            AppLocalizations.of(context)!.parcelConfirmPickupSuccess,
            AppLocalizations.of(context)!.parcelConfirmPickupSuccessBody,
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

        final note = _deliveryNoteController.text.trim();
        final success = await _parcelService.updateDeliveryPhotos(
          bookingId: widget.bookingId,
          deliveryPhotoUrl: confirmPhotoUrl,
          signaturePhotoUrl: signatureUrl,
          deliveryNotes: note.isNotEmpty ? note : null,
        );

        if (!success) throw Exception(AppLocalizations.of(context)!.parcelConfirmUpdateFailed);

        if (mounted) {
          _showSuccessDialog(
            AppLocalizations.of(context)!.parcelConfirmDeliverySuccess,
            AppLocalizations.of(context)!.parcelConfirmDeliverySuccessBody,
          );
        }
      }
    } catch (e) {
      debugLog('❌ Error submitting confirmation: $e');
      if (mounted) {
        _showErrorDialog(AppLocalizations.of(context)!.parcelConfirmError);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showErrorDialog(String message) {
    final jdc = JdcColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.card)),
        icon: Icon(Icons.error_outline, color: jdc.danger, size: 48),
        title: Text(AppLocalizations.of(context)!.parcelConfirmErrorTitle,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontVariations: const [FontVariation('wght', 700)])),
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
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.field)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(AppLocalizations.of(context)!.parcelConfirmOk,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)])),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    final jdc = JdcColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.card)),
        icon: Icon(Icons.check_circle, color: jdc.successFill, size: 48),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontVariations: const [FontVariation('wght', 700)])),
        content: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: jdc.muted)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.field)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(AppLocalizations.of(context)!.parcelConfirmOk,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation('wght', 600)])),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final isPickup = widget.confirmationType == 'pickup';

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(isPickup ? AppLocalizations.of(context)!.parcelConfirmPickupTitle : AppLocalizations.of(context)!.parcelConfirmDeliveryTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  context.gutter, JdcSpacing.md, context.gutter, JdcSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ข้อมูลพัสดุ
                  _buildParcelInfoCard(),
                  const SizedBox(height: JdcSpacing.xl),

                  // รูปพัสดุจากลูกค้า (ถ้ามี)
                  if (_parcelDetail?.parcelPhotoUrl != null) ...[
                    _buildCustomerPhotoCard(),
                    const SizedBox(height: JdcSpacing.xl),
                  ],

                  // ถ่ายรูปยืนยัน
                  _buildConfirmPhotoSection(isPickup),
                  const SizedBox(height: JdcSpacing.xl),

                  // ถ่ายรูปลายเซ็น (เฉพาะตอนส่ง)
                  if (!isPickup) ...[
                    _buildSignaturePhotoSection(),
                    const SizedBox(height: JdcSpacing.xl),
                    _buildDeliveryNoteSection(),
                    const SizedBox(height: JdcSpacing.xl),
                  ],

                  // ปุ่มยืนยัน
                  _buildSubmitButton(isPickup),
                  const SizedBox(height: JdcSpacing.xxxl),
                ],
              ),
            ),
    );
  }

  Widget _buildParcelInfoCard() {
    final jdc = JdcColors.of(context);
    if (_parcelDetail == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(JdcSpacing.lg),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
          boxShadow: jdc.shadowCard,
        ),
        child: Text(AppLocalizations.of(context)!.parcelConfirmNoData,
            style: TextStyle(color: jdc.muted)),
      );
    }

    final pd = _parcelDetail!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: jdc.brandSoft,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Icon(
                  Icons.local_shipping,
                  color: jdc.brandOnSoft,
                  size: 20,
                ),
              ),
              const SizedBox(width: JdcSpacing.sm),
              Expanded(
                child: Text(AppLocalizations.of(context)!.parcelConfirmParcelInfo,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: jdc.text,
                        fontVariations: const [FontVariation('wght', 700)])),
              ),
            ],
          ),
          Divider(height: 20, color: jdc.line),
          _infoRow(AppLocalizations.of(context)!.parcelConfirmSender, '${pd.senderName} (${pd.senderPhone})'),
          _infoRow(AppLocalizations.of(context)!.parcelConfirmRecipient, '${pd.recipientName} (${pd.recipientPhone})'),
          _infoRow(AppLocalizations.of(context)!.parcelConfirmSize, pd.sizeDisplayText),
          if (pd.description != null && pd.description!.isNotEmpty)
            _infoRow(AppLocalizations.of(context)!.parcelConfirmDescription, pd.description!),
          if (pd.estimatedWeightKg != null)
            _infoRow(AppLocalizations.of(context)!.parcelConfirmWeightKg, AppLocalizations.of(context)!.parcelConfirmWeightValue(pd.estimatedWeightKg.toString())),
          _infoRow(AppLocalizations.of(context)!.parcelConfirmStatus, pd.statusDisplayText),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final jdc = JdcColors.of(context);
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
                    color: jdc.muted,
                    fontWeight: FontWeight.w500,
                    fontVariations: const [FontVariation('wght', 500)])),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, color: jdc.text)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerPhotoCard() {
    final jdc = JdcColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.parcelConfirmCustomerPhoto,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: jdc.text,
                  fontVariations: const [FontVariation('wght', 700)])),
          const SizedBox(height: JdcSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(JdcRadius.small),
            child: AppNetworkImage(
              imageUrl: _parcelDetail!.parcelPhotoUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              backgroundColor: jdc.sunken,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPhotoSection(bool isPickup) {
    final jdc = JdcColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPickup ? AppLocalizations.of(context)!.parcelConfirmPickupPhotoTitle : AppLocalizations.of(context)!.parcelConfirmDeliveryPhotoTitle,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: jdc.text,
                fontVariations: const [FontVariation('wght', 700)]),
          ),
          const SizedBox(height: 4),
          Text(
            isPickup
                ? AppLocalizations.of(context)!.parcelConfirmPickupPhotoDesc
                : AppLocalizations.of(context)!.parcelConfirmDeliveryPhotoDesc,
            style: TextStyle(fontSize: 12, color: jdc.muted),
          ),
          const SizedBox(height: JdcSpacing.md),
          _buildPhotoBox(
            photo: _confirmPhoto,
            onTap: _takeConfirmPhoto,
            onRemove: () => setState(() => _confirmPhoto = null),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePhotoSection() {
    final jdc = JdcColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.parcelConfirmSignatureTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: jdc.text,
                  fontVariations: const [FontVariation('wght', 700)])),
          const SizedBox(height: 4),
          Text(AppLocalizations.of(context)!.parcelConfirmSignatureDesc,
              style: TextStyle(fontSize: 12, color: jdc.muted)),
          const SizedBox(height: JdcSpacing.md),
          _buildPhotoBox(
            photo: _signaturePhoto,
            onTap: _takeSignaturePhoto,
            onRemove: () => setState(() => _signaturePhoto = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoBox({
    required File? photo,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final jdc = JdcColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 168,
        decoration: BoxDecoration(
          color: jdc.sunken,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(JdcRadius.card),
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
                          decoration: BoxDecoration(
                            color: jdc.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close,
                              color: jdc.knob, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 30, color: jdc.dim),
                  const SizedBox(height: JdcSpacing.sm),
                  Text(AppLocalizations.of(context)!.parcelConfirmTapToPhoto,
                      style: TextStyle(color: jdc.muted, fontSize: 14)),
                ],
              ),
      ),
    );
  }

  Widget _buildDeliveryNoteSection() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.parcelDeliveryNoteTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: jdc.text,
                  fontVariations: const [FontVariation('wght', 700)])),
          const SizedBox(height: 4),
          Text(l10n.parcelDeliveryNoteSubtitle,
              style: TextStyle(fontSize: 12, color: jdc.muted)),
          const SizedBox(height: JdcSpacing.md),
          TextFormField(
            controller: _deliveryNoteController,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            style: TextStyle(color: jdc.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.parcelDeliveryNoteHint,
              hintStyle: TextStyle(color: jdc.muted, fontSize: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                  borderSide: BorderSide(color: jdc.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                  borderSide: BorderSide(color: jdc.line)),
              filled: true,
              fillColor: jdc.surface,
              contentPadding: const EdgeInsets.all(JdcSpacing.md),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isPickup) {
    final jdc = JdcColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: JdcTouch.button,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitConfirmation,
        icon: _isSubmitting
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: jdc.onCta, strokeWidth: 2))
            : Icon(isPickup ? Icons.check_circle : Icons.done_all),
        label: Text(
          isPickup ? AppLocalizations.of(context)!.parcelConfirmPickupBtn : AppLocalizations.of(context)!.parcelConfirmDeliveryBtn,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontVariations: const [FontVariation('wght', 700)]),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: jdc.cta,
          foregroundColor: jdc.onCta,
          disabledBackgroundColor: jdc.offTrack,
          disabledForegroundColor: jdc.onCta,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.field)),
          elevation: 0,
        ),
      ),
    );
  }
}
