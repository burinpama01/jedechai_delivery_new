import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/services/location_service.dart';
import '../../../../common/services/parcel_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/services/profile_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../utils/debug_logger.dart';
import 'waiting_for_driver_screen.dart';
import 'saved_addresses_screen.dart';
import 'delivery_map_picker_screen.dart';
import '../../../../common/models/saved_address.dart';

/// Parcel Service Screen
///
/// Allows customers to book parcel delivery with:
/// - Sender & recipient info (name, phone, address)
/// - Parcel photo upload with auto-compression
/// - Real distance calculation via Google Directions API
/// - Price estimation based on distance + size
class ParcelServiceScreen extends StatefulWidget {
  const ParcelServiceScreen({super.key});

  @override
  State<ParcelServiceScreen> createState() => _ParcelServiceScreenState();
}

class _ParcelServiceScreenState extends State<ParcelServiceScreen> {
  final _formKey = GlobalKey<FormState>();

  // Sender fields
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _pickupController = TextEditingController();

  // Recipient fields
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _dropoffController = TextEditingController();

  // Parcel fields
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();

  String _selectedSize = 'small';
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _isCalculatingDistance = false;
  double _estimatedPrice = 0;
  double _estimatedDistance = 0;
  File? _parcelPhoto;
  String? _parcelPhotoUrl;
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;
  int _nearbyOnlineDrivers = 0;
  double _driverSearchRadiusKm = 30.0;

  // Size options
  final List<Map<String, dynamic>> _sizeOptions = [
    {
      'value': 'small',
      'label': 'เล็ก (S)',
      'desc': 'ซองจดหมาย, เอกสาร',
      'icon': Icons.mail,
      'multiplier': 1.0
    },
    {
      'value': 'medium',
      'label': 'กลาง (M)',
      'desc': 'กล่องพัสดุ ไม่เกิน 5 กก.',
      'icon': Icons.inventory_2,
      'multiplier': 1.3
    },
    {
      'value': 'large',
      'label': 'ใหญ่ (L)',
      'desc': 'กล่องใหญ่ ไม่เกิน 15 กก.',
      'icon': Icons.widgets,
      'multiplier': 1.6
    },
    {
      'value': 'xlarge',
      'label': 'พิเศษ (XL)',
      'desc': 'สิ่งของขนาดใหญ่ ไม่เกิน 30 กก.',
      'icon': Icons.local_shipping,
      'multiplier': 2.0
    },
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDriverSearchRadius();
    _loadSenderProfile();
  }

  Future<void> _loadDriverSearchRadius() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      _driverSearchRadiusKm = configService.parcelDriverToPickupRadiusKm;
    } catch (_) {
      _driverSearchRadiusKm = 30.0;
    }
    if (mounted) {
      await _checkNearbyOnlineDrivers();
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _pickupController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _dropoffController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadSenderProfile() async {
    try {
      final profile = await ProfileService().getCurrentProfile();
      if (profile != null && mounted) {
        setState(() {
          _senderNameController.text = profile['full_name'] ?? '';
          _senderPhoneController.text = profile['phone'] ?? '';
        });
      }
    } catch (e) {
      debugLog('⚠️ Could not load sender profile: $e');
    }
  }

  Future<void> _pickLocationOnMap({required bool isPickup}) async {
    final initialLat = isPickup ? _pickupLat : _dropoffLat;
    final initialLng = isPickup ? _pickupLng : _dropoffLng;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DeliveryMapPickerScreen(
          initialPosition: (initialLat != null && initialLng != null)
              ? LatLng(initialLat, initialLng)
              : null,
        ),
      ),
    );

    if (result == null) return;
    final lat = (result['lat'] as num?)?.toDouble();
    final lng = (result['lng'] as num?)?.toDouble();
    final address = result['address']?.toString() ?? '';
    if (lat == null || lng == null) return;

    setState(() {
      if (isPickup) {
        _pickupLat = lat;
        _pickupLng = lng;
        _pickupController.text = address.isNotEmpty
            ? address
            : 'จุดรับ (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      } else {
        _dropoffLat = lat;
        _dropoffLng = lng;
        _dropoffController.text = address.isNotEmpty
            ? address
            : 'จุดส่ง (${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
      }
    });

    if (!isPickup) {
      await _calculateRealDistance();
    }
    await _checkNearbyOnlineDrivers();
  }

  Future<void> _checkNearbyOnlineDrivers() async {
    if (_pickupLat == null || _pickupLng == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('driver_locations')
          .select('location_lat, location_lng')
          .eq('is_online', true)
          .eq('is_available', true);

      int count = 0;
      for (final row in rows) {
        final lat = (row['location_lat'] as num?)?.toDouble();
        final lng = (row['location_lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distanceKm =
            Geolocator.distanceBetween(_pickupLat!, _pickupLng!, lat, lng) /
                1000;
        if (distanceKm <= _driverSearchRadiusKm) count++;
      }

      if (mounted) {
        setState(() => _nearbyOnlineDrivers = count);
      }
    } catch (e) {
      debugLog('⚠️ ตรวจสอบคนขับใกล้เคียงไม่สำเร็จ: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await LocationService.getCurrentLocation();
      if (mounted && position != null) {
        setState(() {
          _pickupLat = position.latitude;
          _pickupLng = position.longitude;
          _pickupController.text =
              'ตำแหน่งปัจจุบัน (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
          _isLoadingLocation = false;
        });
        await _checkNearbyOnlineDrivers();
      } else {
        if (mounted) setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      debugLog('❌ Error getting location: $e');
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _calculateRealDistance() async {
    if (_pickupLat == null ||
        _pickupLng == null ||
        _dropoffController.text.isEmpty) return;

    final destLat = _dropoffLat ?? (_pickupLat! + 0.02);
    final destLng = _dropoffLng ?? (_pickupLng! + 0.02);

    setState(() => _isCalculatingDistance = true);
    try {
      final distance = await LocationService.calculateDistance(
        _pickupLat!,
        _pickupLng!,
        destLat,
        destLng,
      );

      if (mounted) {
        setState(() {
          _estimatedDistance = distance > 0 ? distance : 3.0;
          _isCalculatingDistance = false;
        });
        _calculatePrice();
      }
    } catch (e) {
      debugLog('❌ Error calculating distance: $e');
      if (mounted) {
        setState(() {
          _estimatedDistance = 5.0; // fallback
          _isCalculatingDistance = false;
        });
        _calculatePrice();
      }
    }
  }

  void _calculatePrice() {
    if (_estimatedDistance <= 0) return;

    final sizeOption =
        _sizeOptions.firstWhere((s) => s['value'] == _selectedSize);
    final multiplier = sizeOption['multiplier'] as double;

    // Base: 20 baht + 5 baht/km (from service_rates) × size multiplier
    final basePrice = 20;
    final pricePerKm = 5;
    final roundedDist = _estimatedDistance.round();
    final baseDist = 2;

    int fee;
    if (roundedDist <= baseDist) {
      fee = basePrice;
    } else {
      fee = basePrice + ((roundedDist - baseDist) * pricePerKm);
    }

    final finalPrice = (fee * multiplier).round();
    setState(() => _estimatedPrice = finalPrice.toDouble());
  }

  Future<void> _pickParcelPhoto() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file != null && mounted) {
      setState(() => _parcelPhoto = file);
    }
  }

  Future<void> _bookParcel() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupLat == null || _pickupLng == null) {
      _showErrorDialog('กรุณารอระบุตำแหน่ง\nหรือเปิด GPS แล้วลองใหม่');
      return;
    }

    await _checkNearbyOnlineDrivers();
    if (_nearbyOnlineDrivers <= 0) {
      _showErrorDialog(
          'ไม่พบคนขับออนไลน์ภายในรัศมี ${_driverSearchRadiusKm.toStringAsFixed(0)} กม.\nกรุณาลองใหม่อีกครั้งภายหลัง');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. อัปโหลดรูปพัสดุ (ถ้ามี)
      if (_parcelPhoto != null) {
        _parcelPhotoUrl = await StorageService.uploadImage(
          imageFile: _parcelPhoto!,
          folder: 'parcels',
          metadata: {'type': 'parcel_photo'},
        );
        debugLog('📷 Parcel photo uploaded: $_parcelPhotoUrl');
      }

      // 2. คำนวณระยะทางจริง (ถ้ายังไม่ได้คำนวณ)
      if (_estimatedDistance <= 0) {
        _estimatedDistance = 5.0; // fallback
      }

      // 3. สร้าง parcel booking
      final parcelService = ParcelService();
      final destLat = _dropoffLat ?? (_pickupLat! + 0.02);
      final destLng = _dropoffLng ?? (_pickupLng! + 0.02);
      final booking = await parcelService.createParcelBooking(
        originLat: _pickupLat!,
        originLng: _pickupLng!,
        destLat: destLat,
        destLng: destLng,
        distanceKm: _estimatedDistance,
        pickupAddress: _pickupController.text,
        destinationAddress: _dropoffController.text,
        senderName: _senderNameController.text.trim(),
        senderPhone: _senderPhoneController.text.trim(),
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        parcelSize: _selectedSize,
        description: _descriptionController.text.trim(),
        estimatedWeightKg: _weightController.text.isNotEmpty
            ? double.tryParse(_weightController.text)
            : null,
        parcelPhotoUrl: _parcelPhotoUrl,
      );

      if (booking == null) {
        throw Exception('ไม่สามารถสร้างการจองได้');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WaitingForDriverScreen(booking: booking),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error booking parcel: $e');
      if (mounted) {
        _showErrorDialog('ไม่สามารถจองส่งพัสดุได้\nกรุณาลองใหม่อีกครั้ง');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text(
          'เกิดข้อผิดพลาด',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('ตกลง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverAvailabilityHint() {
    final hasDriver = _nearbyOnlineDrivers > 0;
    final bgColor = hasDriver ? Colors.green[50] : Colors.orange[50];
    final borderColor = hasDriver ? Colors.green[200] : Colors.orange[200];
    final textColor = hasDriver ? Colors.green[800] : Colors.orange[800];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor!),
      ),
      child: Text(
        hasDriver
            ? 'พบคนขับออนไลน์ใกล้คุณ $_nearbyOnlineDrivers คน (ในรัศมี ${_driverSearchRadiusKm.toStringAsFixed(0)} กม.)'
            : 'ยังไม่พบคนขับออนไลน์ในรัศมี ${_driverSearchRadiusKm.toStringAsFixed(0)} กม.',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }

  Future<void> _pickSavedAddressForDropoff() async {
    final result = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(pickMode: true),
      ),
    );
    if (result != null) {
      setState(() {
        _dropoffController.text = result.address;
        _dropoffLat = result.latitude;
        _dropoffLng = result.longitude;
        if (result.name.isNotEmpty && _recipientNameController.text.isEmpty) {
          _recipientNameController.text = result.name;
        }
      });
      _calculateRealDistance();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ส่งพัสดุ'),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildSenderSection(),
                    const SizedBox(height: 20),
                    _buildRecipientSection(),
                    const SizedBox(height: 20),
                    _buildSizeSection(),
                    const SizedBox(height: 20),
                    _buildDetailsSection(),
                    const SizedBox(height: 20),
                    _buildPhotoSection(),
                    const SizedBox(height: 20),
                    if (_estimatedPrice > 0) ...[
                      _buildPriceCard(),
                      const SizedBox(height: 20),
                    ],
                    _buildDriverAvailabilityHint(),
                    const SizedBox(height: 14),
                    _buildBookButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.local_shipping, color: Colors.white, size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('บริการส่งพัสดุ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('ส่งของถึงที่ รวดเร็ว ปลอดภัย',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderSection() {
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
                Icon(Icons.person_pin_circle,
                    color: Colors.green[700], size: 22),
                const SizedBox(width: 8),
                const Text('ข้อมูลผู้ส่ง',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senderNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้ส่ง',
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาระบุชื่อผู้ส่ง' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรผู้ส่ง',
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาระบุเบอร์โทรผู้ส่ง' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: 'ที่อยู่จุดรับพัสดุ',
                prefixIcon: const Icon(Icons.my_location, color: Colors.green),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาระบุจุดรับพัสดุ' : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pickLocationOnMap(isPickup: true),
              icon: const Icon(Icons.pin_drop, size: 18),
              label: const Text('ปักหมุดจุดรับบนแผนที่'),
            ),
            if (_pickupLat != null && _pickupLng != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'พิกัดจุดรับ: ${_pickupLat!.toStringAsFixed(5)}, ${_pickupLng!.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSection() {
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
                Icon(Icons.location_on, color: Colors.red[700], size: 22),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('ข้อมูลผู้รับ',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                GestureDetector(
                  onTap: _pickSavedAddressForDropoff,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_outline,
                            size: 16, color: AppTheme.primaryGreen),
                        SizedBox(width: 4),
                        Text('ที่อยู่บันทึก',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickLocationOnMap(isPickup: false),
              icon: const Icon(Icons.pin_drop, size: 18),
              label: const Text('ปักหมุดจุดส่งบนแผนที่'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้รับ',
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาระบุชื่อผู้รับ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'เบอร์โทรผู้รับ',
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาระบุเบอร์โทรผู้รับ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dropoffController,
              decoration: InputDecoration(
                labelText: 'ที่อยู่จุดส่งพัสดุ',
                prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
                suffixIcon: _isCalculatingDistance
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาระบุจุดส่งพัสดุ' : null,
              onChanged: (value) {
                if (value.length > 5) {
                  _calculateRealDistance();
                }
              },
            ),
            if (_estimatedDistance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'ระยะทางโดยประมาณ: ${_estimatedDistance.toStringAsFixed(1)} กม.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            if (_dropoffLat != null && _dropoffLng != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'พิกัดจุดส่ง: ${_dropoffLat!.toStringAsFixed(5)}, ${_dropoffLng!.toStringAsFixed(5)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ขนาดพัสดุ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._sizeOptions.map((option) => RadioListTile<String>(
                  value: option['value'],
                  groupValue: _selectedSize,
                  onChanged: (v) {
                    setState(() => _selectedSize = v!);
                    _calculatePrice();
                  },
                  title: Text(option['label'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(option['desc'],
                      style: const TextStyle(fontSize: 12)),
                  secondary: Icon(option['icon'], color: AppTheme.accentBlue),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รายละเอียดพัสดุ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'อธิบายสิ่งของ (เช่น เอกสาร, อาหาร, เสื้อผ้า)',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Icon(Icons.description),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'กรุณาอธิบายสิ่งของ' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'น้ำหนักโดยประมาณ (กก.) - ไม่บังคับ',
                prefixIcon: const Icon(Icons.scale),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รูปภาพพัสดุ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('ถ่ายรูปพัสดุเพื่อให้คนขับเห็นสิ่งของ (ไม่บังคับ)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickParcelPhoto,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: _parcelPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_parcelPhoto!, fit: BoxFit.cover),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _parcelPhoto = null),
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
                          Icon(Icons.add_a_photo,
                              size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('แตะเพื่อถ่ายรูปหรือเลือกรูป',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ค่าบริการโดยประมาณ',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                'ระยะทาง ${_estimatedDistance.toStringAsFixed(1)} กม.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          Text(
            '฿${_estimatedPrice.ceil()}',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _bookParcel,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping, size: 22),
                  SizedBox(width: 8),
                  Text('จองส่งพัสดุ',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}
