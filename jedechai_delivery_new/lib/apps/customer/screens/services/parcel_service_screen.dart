import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/services/location_service.dart';
import '../../../../common/services/parcel_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/services/profile_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../common/widgets/app_network_image.dart';
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

  // Size options (multipliers only - labels are localized)
  static const List<Map<String, dynamic>> _sizeMultipliers = [
    {'value': 'small', 'icon': Icons.mail, 'multiplier': 1.0},
    {'value': 'medium', 'icon': Icons.inventory_2, 'multiplier': 1.3},
    {'value': 'large', 'icon': Icons.widgets, 'multiplier': 1.6},
    {'value': 'xlarge', 'icon': Icons.local_shipping, 'multiplier': 2.0},
  ];

  List<Map<String, dynamic>> _getSizeOptions() {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'value': 'small', 'label': l10n.parcelSizeSmall, 'desc': l10n.parcelSizeSmallDesc, 'icon': Icons.mail, 'multiplier': 1.0},
      {'value': 'medium', 'label': l10n.parcelSizeMedium, 'desc': l10n.parcelSizeMediumDesc, 'icon': Icons.inventory_2, 'multiplier': 1.3},
      {'value': 'large', 'label': l10n.parcelSizeLarge, 'desc': l10n.parcelSizeLargeDesc, 'icon': Icons.widgets, 'multiplier': 1.6},
      {'value': 'xlarge', 'label': l10n.parcelSizeXLarge, 'desc': l10n.parcelSizeXLargeDesc, 'icon': Icons.local_shipping, 'multiplier': 2.0},
    ];
  }

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
            : AppLocalizations.of(context)!.parcelPickupCoord(lat.toStringAsFixed(5), lng.toStringAsFixed(5));
      } else {
        _dropoffLat = lat;
        _dropoffLng = lng;
        _dropoffController.text = address.isNotEmpty
            ? address
            : AppLocalizations.of(context)!.parcelDropoffCoord(lat.toStringAsFixed(5), lng.toStringAsFixed(5));
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
          .select('driver_id, location_lat, location_lng')
          .eq('is_online', true)
          .eq('is_available', true);

      final nearbyDriverIds = <String>[];
      int count = 0;
      for (final row in rows) {
        final driverId = row['driver_id'] as String?;
        final lat = (row['location_lat'] as num?)?.toDouble();
        final lng = (row['location_lng'] as num?)?.toDouble();
        if (driverId == null || lat == null || lng == null) continue;

        final distanceKm =
            Geolocator.distanceBetween(_pickupLat!, _pickupLng!, lat, lng) /
                1000;
        if (distanceKm <= _driverSearchRadiusKm) {
          nearbyDriverIds.add(driverId);
        }
      }

      if (nearbyDriverIds.isNotEmpty) {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('approval_status', 'approved')
            .inFilter('id', nearbyDriverIds);
        count = (profileResponse as List).length;
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
              AppLocalizations.of(context)!.parcelCurrentLocation(position.latitude.toStringAsFixed(4), position.longitude.toStringAsFixed(4));
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
        _sizeMultipliers.firstWhere((s) => s['value'] == _selectedSize);
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
      _showErrorDialog(AppLocalizations.of(context)!.parcelErrorNoLocation);
      return;
    }

    await _checkNearbyOnlineDrivers();
    if (_nearbyOnlineDrivers <= 0) {
      _showErrorDialog(
          AppLocalizations.of(context)!.parcelErrorNoDrivers(_driverSearchRadiusKm.toStringAsFixed(0)));
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
        throw Exception(AppLocalizations.of(context)!.parcelErrorCreateBooking);
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
        _showErrorDialog(AppLocalizations.of(context)!.parcelErrorBookFailed);
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
        title: Text(
          AppLocalizations.of(context)!.parcelErrorTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              child: Text(AppLocalizations.of(context)!.parcelOk,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            ? AppLocalizations.of(context)!.parcelDriversFound(_nearbyOnlineDrivers.toString(), _driverSearchRadiusKm.toStringAsFixed(0))
            : AppLocalizations.of(context)!.parcelNoDriversNearby(_driverSearchRadiusKm.toStringAsFixed(0)),
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
        title: Text(AppLocalizations.of(context)!.parcelTitle),
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
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: Colors.white, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.parcelHeaderTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.parcelHeaderSubtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderSection() {
    final colorScheme = Theme.of(context).colorScheme;
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
                Text(AppLocalizations.of(context)!.parcelSenderInfo,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senderNameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelSenderName,
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelSenderNameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _senderPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelSenderPhone,
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelSenderPhoneRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelPickupAddress,
                prefixIcon: const Icon(Icons.my_location, color: Colors.green),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelPickupRequired : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _pickLocationOnMap(isPickup: true),
              icon: const Icon(Icons.pin_drop, size: 18),
              label: Text(AppLocalizations.of(context)!.parcelPinPickup),
            ),
            if (_pickupLat != null && _pickupLng != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  AppLocalizations.of(context)!.parcelPickupCoords(_pickupLat!.toStringAsFixed(5), _pickupLng!.toStringAsFixed(5)),
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSection() {
    final colorScheme = Theme.of(context).colorScheme;
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
                Expanded(
                    child: Text(AppLocalizations.of(context)!.parcelRecipientInfo,
                        style: const TextStyle(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_outline,
                            size: 16, color: AppTheme.primaryGreen),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(context)!.parcelSavedAddresses,
                            style: const TextStyle(
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
              label: Text(AppLocalizations.of(context)!.parcelPinDropoff),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientNameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelRecipientName,
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelRecipientNameRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _recipientPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelRecipientPhone,
                prefixIcon: const Icon(Icons.phone),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelRecipientPhoneRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dropoffController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelDropoffAddress,
                prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
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
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelDropoffRequired : null,
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
                  AppLocalizations.of(context)!.parcelEstimatedDistance(_estimatedDistance.toStringAsFixed(1)),
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ),
            if (_dropoffLat != null && _dropoffLng != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  AppLocalizations.of(context)!.parcelDropoffCoords(_dropoffLat!.toStringAsFixed(5), _dropoffLng!.toStringAsFixed(5)),
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
            Text(AppLocalizations.of(context)!.parcelSizeTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._getSizeOptions().map((option) => RadioListTile<String>(
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.parcelDetailsTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelDescriptionLabel,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 50),
                  child: Icon(Icons.description),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? AppLocalizations.of(context)!.parcelDescriptionRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelWeightLabel,
                prefixIcon: const Icon(Icons.scale),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.parcelPhotoTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.parcelPhotoHint,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickParcelPhoto,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant, style: BorderStyle.solid),
                ),
                child: _parcelPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppFileImage(file: _parcelPhoto!),
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
                              size: 48, color: colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text(AppLocalizations.of(context)!.parcelPhotoTap,
                              style: TextStyle(
                                  color: colorScheme.onSurfaceVariant, fontSize: 14)),
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
    final colorScheme = Theme.of(context).colorScheme;
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
              Text(AppLocalizations.of(context)!.parcelEstimatedFee,
                  style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!.parcelDistanceKm(_estimatedDistance.toStringAsFixed(1)),
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_shipping, size: 22),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.parcelBookButton,
                      style:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}
