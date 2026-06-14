import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../common/services/laundry_service.dart';
import '../../../../common/services/notification_sender.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/debug_logger.dart';

class LaundryServiceScreen extends StatefulWidget {
  const LaundryServiceScreen({super.key});

  @override
  State<LaundryServiceScreen> createState() => _LaundryServiceScreenState();
}

class _LaundryServiceScreenState extends State<LaundryServiceScreen> {
  final LaundryService _laundryService = LaundryService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _pickupAddressController =
      TextEditingController();
  final TextEditingController _itemsController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _isLoading = true;
  bool _isLoadingPackages = false;
  bool _isSubmitting = false;
  bool _isOrderActionBusy = false;
  String? _selectedMerchantId;
  String? _selectedPackageId;
  double? _pickupLat;
  double? _pickupLng;
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _orders = [];
  List<XFile> _attachmentFiles = [];
  Map<String, double> _deliveryRate = const {
    'base_price': 20.0,
    'base_distance': 0.0,
    'price_per_km': 5.0,
  };

  @override
  void initState() {
    super.initState();
    _loadMerchants();
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _itemsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchants() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _laundryService.fetchLaundryMerchants(),
        _laundryService.fetchMyLaundryOrders(),
        _laundryService.fetchLaundryDeliveryRate(),
      ]);
      final merchants = results[0] as List<Map<String, dynamic>>;
      final orders = results[1] as List<Map<String, dynamic>>;
      final deliveryRate = results[2] as Map<String, double>;
      final sortedMerchants = _sortMerchantsByPickup(merchants);
      final selectedStillExists = _selectedMerchantId != null &&
          sortedMerchants
              .any((merchant) => merchant['id'] == _selectedMerchantId);
      if (!mounted) return;
      setState(() {
        _deliveryRate = deliveryRate;
        _merchants = sortedMerchants;
        _orders = orders;
        if (!selectedStillExists) {
          _selectedMerchantId = null;
          _selectedPackageId = null;
          _packages = [];
        }
      });
      if (_selectedMerchantId != null && selectedStillExists) {
        await _loadPackages(_selectedMerchantId!);
      }
    } catch (e) {
      _showMessage('โหลดร้านซักผ้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPackages(String merchantId) async {
    if (mounted) setState(() => _isLoadingPackages = true);
    try {
      final packages = await _laundryService.fetchMerchantPackages(merchantId);
      if (!mounted) return;
      final selectedStillExists = _selectedPackageId != null &&
          packages.any((package) => package['id'] == _selectedPackageId);
      setState(() {
        _packages = packages;
        if (!selectedStillExists) {
          _selectedPackageId = null;
        }
      });
    } catch (e) {
      _showMessage('โหลดแพ็กเกจซักผ้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPackages = false);
    }
  }

  Future<void> _selectMerchant(String merchantId) async {
    setState(() {
      _selectedMerchantId = merchantId;
      _selectedPackageId = null;
      _packages = [];
    });
    await _loadPackages(merchantId);
  }

  Future<void> _useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('กรุณาอนุญาตตำแหน่งเพื่อสร้างคำขอซักผ้า');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _pickupLat = position.latitude;
        _pickupLng = position.longitude;
        _merchants = _sortMerchantsByPickup(_merchants);
      });
      if (_selectedMerchantId != null) {
        await _loadPackages(_selectedMerchantId!);
      }
      _showMessage('ใช้พิกัดปัจจุบันแล้ว');
    } catch (e) {
      _showMessage('ดึงพิกัดปัจจุบันไม่สำเร็จ: $e');
    }
  }

  Future<void> _submitQuoteRequest() async {
    final merchantId = _selectedMerchantId;
    final pickupAddress = _pickupAddressController.text.trim();
    if (merchantId == null || merchantId.isEmpty) {
      _showMessage('กรุณาเลือกร้านซักผ้า');
      return;
    }
    if (pickupAddress.isEmpty) {
      _showMessage('กรุณากรอกที่อยู่รับผ้า');
      return;
    }
    if (_pickupLat == null || _pickupLng == null) {
      await _useCurrentLocation();
      if (_pickupLat == null || _pickupLng == null) return;
    }
    if (_attachmentFiles.isEmpty) {
      _showMessage('กรุณาแนบรูปผ้าก่อนส่งคำขอ');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final itemText = _itemsController.text.trim();
      final requestedItems = itemText.isEmpty
          ? <Map<String, dynamic>>[]
          : <Map<String, dynamic>>[
              {'description': itemText},
            ];

      final attachmentUrls = await _uploadQuoteAttachments();
      final result = await _laundryService.createQuoteRequest(
        merchantId: merchantId,
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        pickupAddress: pickupAddress,
        requestedItems: requestedItems,
        attachmentUrls: attachmentUrls,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        packageId: _selectedPackageId,
      );

      if (result['success'] == true) {
        final laundryOrderId = result['laundry_order_id']?.toString();
        if (laundryOrderId != null && laundryOrderId.isNotEmpty) {
          await _notifyMerchantQuoteRequested(
            merchantId: merchantId,
            laundryOrderId: laundryOrderId,
          );
          unawaited(
            _notifyAdminsQuoteRequested(
              laundryOrderId: laundryOrderId,
            ),
          );
        }
        _showMessage('ส่งคำขอประเมินราคาแล้ว รอร้านตอบกลับ');
        _itemsController.clear();
        _noteController.clear();
        setState(() => _attachmentFiles = []);
        await _loadMerchants();
      } else {
        _showMessage('ส่งคำขอไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
      }
    } catch (e) {
      _showMessage('ส่งคำขอไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _notifyMerchantQuoteRequested({
    required String merchantId,
    required String laundryOrderId,
  }) async {
    final merchant = _merchants.cast<Map<String, dynamic>?>().firstWhere(
          (row) => row?['id'] == merchantId,
          orElse: () => null,
        );
    final soundEnabled =
        (merchant?['laundry_quote_sound_enabled'] as bool?) ?? true;
    if (!soundEnabled) return;

    final soundKey = (merchant?['laundry_quote_sound_key'] as String?)?.trim();
    await NotificationSender.sendNotification(
      targetUserId: merchantId,
      title: 'มีคำขอประเมินราคาซักผ้าใหม่',
      body:
          'ลูกค้าส่งคำขอประเมินราคาซักผ้า รหัส #${laundryOrderId.substring(0, 8)}',
      persistInApp: false,
      data: {
        'type': 'laundry.quote_requested',
        'recipient_role': 'merchant',
        'service_type': 'laundry',
        'laundry_order_id': laundryOrderId,
        'sound_key': soundKey?.isNotEmpty == true
            ? soundKey!
            : 'merchant_laundry_quote_new',
        'play_sound': 'true',
        'screen': 'merchant_laundry',
        'route': 'merchant_laundry',
      },
    );
  }

  Future<void> _notifyAdminsQuoteRequested({
    required String laundryOrderId,
  }) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'notify-laundry-quote-request',
        body: {
          'laundry_order_id': laundryOrderId,
        },
      );
      if (response.status >= 400) {
        debugLog(
          'Laundry admin external notification failed: HTTP ${response.status}',
        );
      }
    } catch (e) {
      debugLog('Laundry admin external notification failed: $e');
    }
  }

  Future<void> _addAttachmentFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;
    setState(() => _attachmentFiles = [..._attachmentFiles, image]);
  }

  Future<void> _addAttachmentsFromGallery() async {
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (images.isEmpty || !mounted) return;
    setState(() => _attachmentFiles = [..._attachmentFiles, ...images]);
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachmentFiles.length) return;
    setState(() {
      _attachmentFiles = [
        for (int i = 0; i < _attachmentFiles.length; i++)
          if (i != index) _attachmentFiles[i],
      ];
    });
  }

  Future<void> _openQuoteChat(Map<String, dynamic> order) async {
    final orderId = order['id'] as String?;
    if (orderId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuoteChatSheet(
        laundryService: _laundryService,
        laundryOrderId: orderId,
        title: 'Chat คำขอ #${orderId.substring(0, 8)}',
      ),
    );
    if (mounted) await _loadMerchants();
  }

  Future<List<String>> _uploadQuoteAttachments() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) throw StateError('unauthenticated');

    final batchId = DateTime.now().millisecondsSinceEpoch;
    final uploadedPaths = <String>[];
    for (int i = 0; i < _attachmentFiles.length; i++) {
      final image = _attachmentFiles[i];
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last.toLowerCase();
      final normalizedExtension =
          ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
              ? extension
              : 'jpg';
      final contentType = switch (normalizedExtension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final objectPath =
          '$userId/$batchId/$i-${DateTime.now().microsecondsSinceEpoch}.$normalizedExtension';

      await SupabaseService.client.storage
          .from('laundry-quote-attachments')
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      uploadedPaths.add(objectPath);
    }
    return uploadedPaths;
  }

  Future<void> _acceptQuote(Map<String, dynamic> order) async {
    var paymentMethod = (order['payment_method'] as String?) ?? 'wallet';
    var pickupPresence =
        (order['pickup_presence'] as String?) ?? 'remote_pickup';
    var returnMode = (order['return_mode'] as String?) ?? 'delivery';
    var returnPaymentMethod =
        (order['return_payment_method'] as String?) ?? 'cash';
    if (returnMode == 'self_pickup' && returnPaymentMethod == 'wallet') {
      returnPaymentMethod = 'cash';
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ยืนยัน quote และเลือกวิธีชำระ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'ยอดที่ต้องชำระ: ฿${_quoteTotal(order).toStringAsFixed(0)}'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: pickupPresence,
                    decoration: const InputDecoration(
                      labelText: 'สถานะจุดรับผ้า',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'remote_pickup',
                        child: Text('ให้คนขับไปรับผ้า'),
                      ),
                      DropdownMenuItem(
                        value: 'customer_at_pickup',
                        child: Text('ลูกค้าอยู่ที่จุดรับ/ส่งมอบเอง'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        pickupPresence = value;
                        if (pickupPresence == 'remote_pickup') {
                          paymentMethod = 'wallet';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'วิธีชำระค่าซักและค่าส่งขาไป',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'wallet',
                        child: Text('Wallet'),
                      ),
                      DropdownMenuItem(
                        value: 'cash',
                        enabled: pickupPresence == 'customer_at_pickup',
                        child: Text(
                          pickupPresence == 'customer_at_pickup'
                              ? 'เงินสด'
                              : 'เงินสด (ใช้ได้เมื่ออยู่ที่จุดรับ)',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      if (value == 'cash' &&
                          pickupPresence != 'customer_at_pickup') {
                        return;
                      }
                      setDialogState(() => paymentMethod = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: returnMode,
                    decoration: const InputDecoration(
                      labelText: 'วิธีรับผ้ากลับ',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'delivery',
                        child: Text('ให้คนขับส่งกลับ'),
                      ),
                      DropdownMenuItem(
                        value: 'self_pickup',
                        child: Text('รับเองที่ร้าน'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        returnMode = value;
                        if (returnMode == 'self_pickup') {
                          returnPaymentMethod = 'cash';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: returnPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'วิธีจ่ายค่าส่งขากลับ',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'cash', child: Text('เงินสด')),
                      DropdownMenuItem(
                        value: 'wallet',
                        enabled: returnMode == 'delivery',
                        child: Text(
                          returnMode == 'delivery'
                              ? 'Wallet'
                              : 'Wallet (ใช้เมื่อให้คนขับส่งกลับ)',
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      if (value == 'wallet' && returnMode != 'delivery') {
                        return;
                      }
                      setDialogState(() => returnPaymentMethod = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isOrderActionBusy = true);
    try {
      final result = await _laundryService.acceptQuote(
        laundryOrderId: order['id'] as String,
        paymentMethod: paymentMethod,
        pickupPresence: pickupPresence,
        returnMode: returnMode,
        returnPaymentMethod: returnPaymentMethod,
      );
      if (result['success'] == true) {
        _showMessage('ยืนยัน quote แล้ว ระบบสร้าง booking ขาไปรอคนขับ');
        await _loadMerchants();
      } else {
        _showMessage('ยืนยัน quote ไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
      }
    } catch (e) {
      _showMessage('ยืนยัน quote ไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isOrderActionBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ซักผ้า')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMerchants,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_selectedMerchantId == null) ...[
                    _buildSectionHeader(
                      title: 'เลือกร้านซักผ้า',
                      subtitle: 'แตะการ์ดร้านเพื่อดูแพ็กเกจและรายละเอียด',
                      icon: Icons.storefront_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildMerchantCards(),
                  ],
                  if (_selectedMerchantId != null &&
                      _selectedPackageId == null) ...[
                    _buildSelectedMerchantHeader(),
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                      title: 'เลือกแพ็กเกจ',
                      subtitle: 'เลือกบริการที่ต้องการก่อนกรอกคำขอ',
                      icon: Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildPackageList(),
                  ],
                  if (_selectedPackageId != null) ...[
                    _buildSelectedMerchantHeader(),
                    const SizedBox(height: 12),
                    _buildSelectedPackageSummary(),
                    const SizedBox(height: 16),
                    _buildPickupForm(),
                    const SizedBox(height: 16),
                    _buildAttachmentPicker(),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submitQuoteRequest,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.request_quote_rounded),
                        label: const Text('ส่งคำขอประเมินราคา'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildMyLaundryOrders(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMerchantCards() {
    if (_merchants.isEmpty) {
      return _InfoPanel(
        icon: Icons.local_laundry_service_rounded,
        title: 'ยังไม่มีร้านซักผ้า',
        subtitle: 'รอแอดมินเปิดประเภทร้านซักผ้าให้ merchant ก่อน',
      );
    }

    return Column(
      children: [
        for (final merchant in _merchants) _buildMerchantCard(merchant),
      ],
    );
  }

  Widget _buildMerchantCard(Map<String, dynamic> merchant) {
    final id = merchant['id'] as String?;
    final name = (merchant['full_name'] as String?)?.trim().isNotEmpty == true
        ? merchant['full_name'] as String
        : 'ร้านซักผ้า';
    final address = (merchant['shop_address'] as String?)?.trim() ?? '';
    final phone = (merchant['phone_number'] as String?)?.trim() ?? '';
    final distanceKm = merchant['_distance_km'] as double?;
    final estimatedFee = merchant['_estimated_delivery_fee'] as double?;
    final meta = [
      if (distanceKm != null) '${distanceKm.toStringAsFixed(1)} กม.',
      if (estimatedFee != null)
        'ค่าส่งประมาณ ฿${estimatedFee.toStringAsFixed(0)}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: id == null ? null : () => _selectMerchant(id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_laundry_service_rounded,
                  color: AppTheme.primaryGreen,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildMetaChip(meta, AppTheme.primaryGreen),
                    ],
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedMerchantHeader() {
    final merchant = _selectedMerchant;
    if (merchant == null) return const SizedBox.shrink();
    final name = (merchant['full_name'] as String?)?.trim().isNotEmpty == true
        ? merchant['full_name'] as String
        : 'ร้านซักผ้า';
    final address = (merchant['shop_address'] as String?)?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    setState(() {
                      _selectedMerchantId = null;
                      _selectedPackageId = null;
                      _packages = [];
                    });
                  },
            child: const Text('เปลี่ยนร้าน'),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList() {
    if (_isLoadingPackages) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_packages.isEmpty) {
      return _InfoPanel(
        icon: Icons.inventory_2_rounded,
        title: 'ยังไม่มีแพ็กเกจ',
        subtitle: 'ร้านนี้ยังไม่ได้เปิดแพ็กเกจสำหรับรับคำขอซักผ้า',
      );
    }

    return Column(
      children: [
        for (final package in _packages) _buildPackageCard(package),
      ],
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final id = package['id'] as String?;
    final name = (package['name'] as String?)?.trim().isNotEmpty == true
        ? package['name'] as String
        : 'แพ็กเกจ';
    final description = (package['description'] as String?)?.trim() ?? '';
    final price = (package['base_price'] as num?)?.toDouble() ?? 0;
    final unit = (package['unit'] as String?)?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap:
            id == null ? null : () => setState(() => _selectedPackageId = id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFFB7791F),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildMetaChip(
                      _formatPackagePrice(price, unit),
                      const Color(0xFFB7791F),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPackageSummary() {
    final package = _selectedPackage;
    if (package == null) return const SizedBox.shrink();
    final name = (package['name'] as String?)?.trim().isNotEmpty == true
        ? package['name'] as String
        : 'แพ็กเกจ';
    final description = (package['description'] as String?)?.trim() ?? '';
    final price = (package['base_price'] as num?)?.toDouble() ?? 0;
    final unit = (package['unit'] as String?)?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D38A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_rounded, color: Color(0xFFB7791F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  _formatPackagePrice(price, unit),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () => setState(() => _selectedPackageId = null),
            child: const Text('เปลี่ยนแพ็กเกจ'),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupForm() {
    return Column(
      children: [
        TextField(
          controller: _pickupAddressController,
          decoration: const InputDecoration(
            labelText: 'ที่อยู่รับผ้า',
            prefixIcon: Icon(Icons.location_on_rounded),
          ),
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _useCurrentLocation,
          icon: const Icon(Icons.my_location_rounded),
          label: Text(_pickupLat == null ? 'ใช้พิกัดปัจจุบัน' : 'ใช้พิกัดแล้ว'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _itemsController,
          decoration: const InputDecoration(
            labelText: 'รายการผ้า / จำนวน / คราบ',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'หมายเหตุถึงร้าน',
            prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
          ),
          minLines: 1,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildAttachmentPicker() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_rounded,
                  color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'รูปผ้าที่ต้องให้ร้านประเมิน',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${_attachmentFiles.length} รูป',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ต้องแนบอย่างน้อย 1 รูป เพื่อให้ร้านประเมินราคาได้ถูกต้อง',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _addAttachmentFromCamera,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('ถ่ายรูป'),
              ),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _addAttachmentsFromGallery,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('เลือกรูป'),
              ),
            ],
          ),
          if (_attachmentFiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _attachmentFiles.length; i++)
                  InputChip(
                    avatar: const Icon(Icons.image_rounded, size: 18),
                    label: Text('รูปที่ ${i + 1}'),
                    onDeleted:
                        _isSubmitting ? null : () => _removeAttachment(i),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMyLaundryOrders() {
    if (_orders.isEmpty) {
      return _InfoPanel(
        icon: Icons.receipt_long_rounded,
        title: 'ยังไม่มีคำขอซักผ้า',
        subtitle: 'ส่งคำขอให้ร้านประเมินราคา แล้วกลับมาดู quote ได้ที่นี่',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'คำขอซักผ้าของฉัน',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        ..._orders.map(_buildOrderCard),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] as String?) ?? 'unknown';
    final canAccept = status == 'quoted';
    final quoteTotal = _quoteTotal(order);
    final expiresAt = _formatDate(order['quote_expires_at'] as String?);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _statusText(status),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  quoteTotal > 0 ? '฿${quoteTotal.toStringAsFixed(0)}' : '-',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _orderSubtitle(order),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (expiresAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'หมดอายุ quote: $expiresAt',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openQuoteChat(order),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Chat กับร้าน'),
            ),
            if (canAccept) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _isOrderActionBusy ? null : () => _acceptQuote(order),
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('ชำระ Wallet และสร้าง booking ขาไป'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _quoteTotal(Map<String, dynamic> order) {
    return _money(order['laundry_amount']) +
        _money(order['delivery_fee_outbound']);
  }

  double _money(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic>? get _selectedMerchant {
    final id = _selectedMerchantId;
    if (id == null) return null;
    for (final merchant in _merchants) {
      if (merchant['id'] == id) return merchant;
    }
    return null;
  }

  Map<String, dynamic>? get _selectedPackage {
    final id = _selectedPackageId;
    if (id == null) return null;
    for (final package in _packages) {
      if (package['id'] == id) return package;
    }
    return null;
  }

  Widget _buildMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatPackagePrice(double price, String unit) {
    final unitLabel = unit.isEmpty ? '' : ' / $unit';
    if (price <= 0) return 'รอร้านประเมินราคา$unitLabel';
    return 'เริ่ม ฿${price.toStringAsFixed(0)}$unitLabel';
  }

  List<Map<String, dynamic>> _sortMerchantsByPickup(
    List<Map<String, dynamic>> merchants,
  ) {
    final sorted = merchants
        .map((merchant) => Map<String, dynamic>.from(merchant))
        .toList();
    final pickupLat = _pickupLat;
    final pickupLng = _pickupLng;

    if (pickupLat == null || pickupLng == null) {
      sorted.sort((a, b) => ((a['full_name'] ?? '') as String)
          .compareTo((b['full_name'] ?? '') as String));
      return sorted;
    }

    for (final merchant in sorted) {
      final distanceKm = _merchantDistanceKm(merchant);
      merchant['_distance_km'] = distanceKm;
      merchant['_estimated_delivery_fee'] = distanceKm == null
          ? null
          : _estimateDeliveryFee(merchant, distanceKm);
    }

    sorted.sort((a, b) {
      final left = (a['_distance_km'] as double?) ?? double.infinity;
      final right = (b['_distance_km'] as double?) ?? double.infinity;
      return left.compareTo(right);
    });
    return sorted;
  }

  double? _merchantDistanceKm(Map<String, dynamic> merchant) {
    final pickupLat = _pickupLat;
    final pickupLng = _pickupLng;
    final merchantLat = (merchant['latitude'] as num?)?.toDouble();
    final merchantLng = (merchant['longitude'] as num?)?.toDouble();
    if (pickupLat == null ||
        pickupLng == null ||
        merchantLat == null ||
        merchantLng == null) {
      return null;
    }

    return Geolocator.distanceBetween(
          pickupLat,
          pickupLng,
          merchantLat,
          merchantLng,
        ) /
        1000;
  }

  double _estimateDeliveryFee(
      Map<String, dynamic> merchant, double distanceKm) {
    final fixedFee = (merchant['custom_delivery_fee'] as num?)?.toDouble();
    if (fixedFee != null && fixedFee > 0) return fixedFee;

    final basePrice = (merchant['custom_base_fare'] as num?)?.toDouble() ??
        _deliveryRate['base_price'] ??
        20.0;
    final baseDistance =
        (merchant['custom_base_distance'] as num?)?.toDouble() ??
            _deliveryRate['base_distance'] ??
            0.0;
    final perKm = (merchant['custom_per_km'] as num?)?.toDouble() ??
        _deliveryRate['price_per_km'] ??
        5.0;
    final usableBasePrice = basePrice > 0 ? basePrice : 20.0;
    final usablePerKm = perKm > 0 ? perKm : 5.0;
    final extraDistance = (distanceKm - baseDistance).clamp(0, double.infinity);
    return usableBasePrice + (extraDistance * usablePerKm);
  }

  String _orderSubtitle(Map<String, dynamic> order) {
    final laundry = _money(order['laundry_amount']);
    final outbound = _money(order['delivery_fee_outbound']);
    final returnFee = _money(order['delivery_fee_return']);
    final parts = <String>[];
    if (laundry > 0) parts.add('ค่าซัก ฿${laundry.toStringAsFixed(0)}');
    if (outbound > 0) parts.add('ค่าส่งขาไป ฿${outbound.toStringAsFixed(0)}');
    if (returnFee > 0) {
      parts.add('ค่าส่งขากลับ ฿${returnFee.toStringAsFixed(0)}');
    }
    return parts.isEmpty ? 'รอร้านประเมินราคา' : parts.join(' · ');
  }

  String _statusText(String status) {
    switch (status) {
      case 'quote_requested':
        return 'รอร้านประเมินราคา';
      case 'quoted':
        return 'ร้านส่ง quote แล้ว';
      case 'quote_expired':
        return 'quote หมดอายุ';
      case 'quote_rejected':
        return 'quote ถูกปฏิเสธ';
      case 'outbound_pending':
        return 'รอคนขับรับงานขาไป';
      case 'outbound_assigned':
        return 'คนขับรับงานขาไปแล้ว';
      case 'outbound_picked_up':
        return 'คนขับรับผ้าแล้ว';
      case 'at_merchant':
        return 'ผ้าถึงร้านแล้ว';
      case 'washing':
        return 'ร้านกำลังซัก';
      case 'ready_for_return':
        return 'ร้านซักเสร็จแล้ว';
      case 'return_pending':
        return 'รอคนขับรับงานขากลับ';
      case 'return_assigned':
        return 'คนขับรับงานขากลับแล้ว';
      case 'return_picked_up':
        return 'คนขับรับผ้าจากร้านแล้ว';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิกแล้ว';
      default:
        return status;
    }
  }

  String? _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    final dateTime = DateTime.tryParse(isoString)?.toLocal();
    if (dateTime == null) return null;
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/${dateTime.year} $hour:$minute';
  }
}

class _QuoteChatSheet extends StatefulWidget {
  const _QuoteChatSheet({
    required this.laundryService,
    required this.laundryOrderId,
    required this.title,
  });

  final LaundryService laundryService;
  final String laundryOrderId;
  final String title;

  @override
  State<_QuoteChatSheet> createState() => _QuoteChatSheetState();
}

class _QuoteChatSheetState extends State<_QuoteChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final rows =
          await widget.laundryService.fetchQuoteMessages(widget.laundryOrderId);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final result = await widget.laundryService.sendQuoteMessage(
        laundryOrderId: widget.laundryOrderId,
        body: body,
      );
      if (result['success'] == true) {
        _messageController.clear();
        await _loadMessages();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? const Center(child: Text('ยังไม่มีข้อความ'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final role =
                                  (message['sender_role'] as String?) ?? '-';
                              final body = (message['body'] as String?) ?? '';
                              return ListTile(
                                dense: true,
                                title: Text(body),
                                subtitle: Text(role),
                                leading: Icon(
                                  role == 'merchant'
                                      ? Icons.storefront_rounded
                                      : Icons.person_rounded,
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'พิมพ์ข้อความถึงร้าน',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
