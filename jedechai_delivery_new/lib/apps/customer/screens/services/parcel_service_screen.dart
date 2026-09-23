import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/services/location_service.dart';
import '../../../../common/services/parcel_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/services/profile_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../common/services/coupon_service.dart';
import '../../../../common/utils/parcel_pricing.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../common/widgets/coupon_entry_widget.dart';
import '../../../../common/models/coupon.dart';
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
  Coupon? _appliedCoupon;
  double _couponDiscount = 0;
  File? _parcelPhoto;
  String? _parcelPhotoUrl;
  double? _pickupLat;
  double? _pickupLng;
  double? _dropoffLat;
  double? _dropoffLng;
  int _nearbyOnlineDrivers = 0;
  double _driverSearchRadiusKm = 30.0;
  Timer? _dropoffDebounceTimer;

  // Parcel rates loaded from service_rates table
  double _parcelBasePrice = 20.0;
  double _parcelPricePerKm = 5.0;
  double _parcelBaseDistance = 2.0;

  List<Map<String, dynamic>> _getSizeOptions() {
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'value': 'small',
        'label': l10n.parcelSizeSmall,
        'desc': l10n.parcelSizeSmallDesc,
        'icon': Icons.mail,
        'multiplier': 1.0
      },
      {
        'value': 'medium',
        'label': l10n.parcelSizeMedium,
        'desc': l10n.parcelSizeMediumDesc,
        'icon': Icons.inventory_2,
        'multiplier': 1.3
      },
      {
        'value': 'large',
        'label': l10n.parcelSizeLarge,
        'desc': l10n.parcelSizeLargeDesc,
        'icon': Icons.widgets,
        'multiplier': 1.6
      },
      {
        'value': 'xlarge',
        'label': l10n.parcelSizeXLarge,
        'desc': l10n.parcelSizeXLargeDesc,
        'icon': Icons.local_shipping,
        'multiplier': 2.0
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadDriverSearchRadius();
    _loadSenderProfile();
    _loadParcelRates();
  }

  Future<void> _loadParcelRates() async {
    try {
      final row = await Supabase.instance.client
          .from('service_rates')
          .select('base_price, price_per_km, base_distance')
          .eq('service_type', 'parcel')
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _parcelBasePrice = (row['base_price'] as num?)?.toDouble() ?? 20.0;
          _parcelPricePerKm = (row['price_per_km'] as num?)?.toDouble() ?? 5.0;
          _parcelBaseDistance =
              (row['base_distance'] as num?)?.toDouble() ?? 2.0;
        });
        _calculatePrice();
      }
    } catch (_) {
      // Keep fallback values
    }
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
    _dropoffDebounceTimer?.cancel();
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
          _senderPhoneController.text = profile['phone_number'] ?? '';
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
            : AppLocalizations.of(context)!.parcelPickupCoord(
                lat.toStringAsFixed(5), lng.toStringAsFixed(5));
      } else {
        _dropoffLat = lat;
        _dropoffLng = lng;
        _dropoffController.text = address.isNotEmpty
            ? address
            : AppLocalizations.of(context)!.parcelDropoffCoord(
                lat.toStringAsFixed(5), lng.toStringAsFixed(5));
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
        if (driverId == null || lat == null || lng == null ||
            (lat == 0.0 && lng == 0.0)) continue;

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
            .select('id, accepted_service_types, service_type')
            .eq('approval_status', 'approved')
            .inFilter('id', nearbyDriverIds);
        count = (profileResponse as List).where((profile) {
          final serviceType = profile['service_type']?.toString();
          final acceptedTypes = profile['accepted_service_types'];
          if (serviceType == 'parcel') return true;
          if (acceptedTypes is List) return acceptedTypes.contains('parcel');
          if (acceptedTypes is String) return acceptedTypes.contains('parcel');
          return false;
        }).length;
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
          _pickupController.text = AppLocalizations.of(context)!
              .parcelCurrentLocation(position.latitude.toStringAsFixed(4),
                  position.longitude.toStringAsFixed(4));
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
        _dropoffLat == null ||
        _dropoffLng == null) {
      return;
    }

    final destLat = _dropoffLat!;
    final destLng = _dropoffLng!;

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

    final multiplier = kParcelSizeMultipliers[_selectedSize] ?? 1.0;

    final finalPrice = calculateParcelPrice(
      distanceKm: _estimatedDistance,
      sizeMultiplier: multiplier,
      basePrice: _parcelBasePrice,
      pricePerKm: _parcelPricePerKm,
      baseDistance: _parcelBaseDistance,
    );
    setState(() => _estimatedPrice = finalPrice);
  }

  double get _finalParcelPrice {
    final discounted = _estimatedPrice - _couponDiscount;
    return discounted > 0 ? discounted : 0;
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
    if (_dropoffLat == null || _dropoffLng == null) {
      _showErrorDialog(AppLocalizations.of(context)!.parcelErrorNoDropoff);
      return;
    }

    await _checkNearbyOnlineDrivers();
    if (_nearbyOnlineDrivers <= 0) {
      _showErrorDialog(AppLocalizations.of(context)!
          .parcelErrorNoDrivers(_driverSearchRadiusKm.toStringAsFixed(0)));
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
        _calculatePrice();
      }
      if (_estimatedPrice <= 0) {
        throw Exception(AppLocalizations.of(context)!.parcelErrorCreateBooking);
      }

      // 3. สร้าง parcel booking
      final parcelService = ParcelService();
      final booking = await parcelService.createParcelBooking(
        originLat: _pickupLat!,
        originLng: _pickupLng!,
        destLat: _dropoffLat!,
        destLng: _dropoffLng!,
        distanceKm: _estimatedDistance,
        price: _finalParcelPrice,
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
        notifyDrivers: false,
      );

      if (booking == null) {
        throw Exception(AppLocalizations.of(context)!.parcelErrorCreateBooking);
      }

      if (_appliedCoupon != null && _couponDiscount > 0) {
        try {
          await CouponService().recordUsage(
            couponId: _appliedCoupon!.id,
            bookingId: booking.id,
            discountAmount: _couponDiscount,
          );
        } catch (e) {
          debugLog('❌ recordUsage failed — auto-cancelling parcel booking: $e');
          try {
            await Supabase.instance.client.from('bookings').update({
              'status': 'cancelled',
              'notes': 'auto_cancelled: coupon_record_failed',
            }).eq('id', booking.id);
          } catch (cancelErr) {
            debugLog('⚠️ Could not auto-cancel parcel booking: $cancelErr');
          }
          throw Exception(AppLocalizations.of(context)!.parcelErrorBookFailed);
        }
      }

      await parcelService.notifyParcelBookingCreated(
        booking: booking,
        price: _finalParcelPrice,
        distanceKm: _estimatedDistance,
        pickupAddress: _pickupController.text,
        destinationAddress: _dropoffController.text,
        senderName: _senderNameController.text.trim(),
        senderPhone: _senderPhoneController.text.trim(),
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: _recipientPhoneController.text.trim(),
        parcelSize: _selectedSize,
      );

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
      if (_parcelPhotoUrl != null) {
        await StorageService.deleteImage(_parcelPhotoUrl!);
        _parcelPhotoUrl = null;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        final jdc = JdcColors.of(context);
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.error_outline, color: jdc.dangerInk, size: 48),
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
                backgroundColor: jdc.infoInk,
                foregroundColor: jdc.onCta,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(AppLocalizations.of(context)!.parcelOk,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _buildDriverAvailabilityHint() {
    final jdc = JdcColors.of(context);
    final hasDriver = _nearbyOnlineDrivers > 0;
    final bgColor = hasDriver ? jdc.successSoft : jdc.brandSoft;
    final borderColor = hasDriver ? jdc.successLine : jdc.brandLine;
    final textColor = hasDriver ? jdc.successInk : jdc.brandOnSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        hasDriver
            ? AppLocalizations.of(context)!.parcelDriversFound(
                _nearbyOnlineDrivers.toString(),
                _driverSearchRadiusKm.toStringAsFixed(0))
            : AppLocalizations.of(context)!.parcelNoDriversNearby(
                _driverSearchRadiusKm.toStringAsFixed(0)),
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
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.parcelTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        iconTheme: IconThemeData(color: jdc.text),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: jdc.line),
        ),
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Route card (pickup + dropoff)
                          _buildRouteCard(),
                          const SizedBox(height: 14),

                          // Sender info (compact)
                          _buildSenderSection(),
                          const SizedBox(height: 14),

                          // Recipient info (compact)
                          _buildRecipientSection(),
                          const SizedBox(height: 14),

                          // Size selector
                          _buildSizeSection(),
                          const SizedBox(height: 14),

                          // Parcel photo
                          _buildPhotoSection(),
                          const SizedBox(height: 14),

                          // Description + weight
                          _buildDetailsSection(),
                          const SizedBox(height: 14),

                          // Coupon
                          if (_estimatedPrice > 0)
                            CouponEntryWidget(
                              serviceType: 'parcel',
                              orderAmount: _estimatedPrice,
                              deliveryFee: _estimatedPrice,
                              onCouponApplied: (coupon) {
                                setState(() => _appliedCoupon = coupon);
                              },
                              onDiscountChanged: (discount) {
                                setState(
                                    () => _couponDiscount = discount);
                              },
                            ),

                          _buildDriverAvailabilityHint(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sticky bottom: price + CTA
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: jdc.surface,
                    border: Border(top: BorderSide(color: jdc.line)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_estimatedPrice > 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${l10n.parcelEstimatedDistanceShort} ${_estimatedDistance.toStringAsFixed(1)} กม. · ${_getSizeOptions().firstWhere((s) => s['value'] == _selectedSize, orElse: () => _getSizeOptions().first)['label']}',
                                style: TextStyle(
                                    fontSize: 12, color: jdc.muted),
                              ),
                            ),
                            if (_couponDiscount > 0)
                              Text(
                                '฿${_estimatedPrice.ceil()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: jdc.muted,
                                  decoration:
                                      TextDecoration.lineThrough,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              '฿${_finalParcelPrice.ceil()}',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: jdc.text),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : _bookParcel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: jdc.cta,
                            foregroundColor: jdc.onCta,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: jdc.onCta,
                                      strokeWidth: 2))
                              : Text(l10n.parcelCallDriver,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // Route card — artboard style (Wave 1.5 b2ride)
  Widget _buildRouteCard() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pickupText = _pickupController.text.isNotEmpty
        ? _pickupController.text
        : l10n.parcelOriginLabel;
    final dropoffText = _dropoffController.text.isNotEmpty
        ? _dropoffController.text
        : l10n.parcelDestinationLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: jdc.panel, width: 3),
                ),
              ),
              Container(width: 2, height: 24, color: jdc.line),
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: jdc.cta,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                // Pickup button
                GestureDetector(
                  onTap: () => _pickLocationOnMap(isPickup: true),
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: jdc.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: jdc.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.parcelOriginLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: jdc.muted)),
                        const SizedBox(height: 2),
                        Text(pickupText,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: jdc.text)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Dropoff button
                GestureDetector(
                  onTap: () => _pickLocationOnMap(isPickup: false),
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: jdc.brandSoft2,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: jdc.brandLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.parcelDestinationLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: jdc.muted)),
                        const SizedBox(height: 2),
                        Text(dropoffText,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: jdc.text)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // _buildHeader replaced by _buildRouteCard (Wave 1.5 b2ride) — kept as dead stub
  // ignore: unused_element
  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [jdc.infoInk, jdc.infoInk.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, color: jdc.onCta, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.parcelHeaderTitle,
                    style: TextStyle(
                        color: jdc.onCta,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.parcelHeaderSubtitle,
                    style: TextStyle(
                        color: jdc.onCta.withValues(alpha: 0.7),
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderSection() {
    final jdc = JdcColors.of(context);
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
                    color: jdc.successInk, size: 22),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.parcelSenderInfo,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
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
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelSenderNameRequired
                  : null,
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
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelSenderPhoneRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pickupController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelPickupAddress,
                prefixIcon: Icon(Icons.my_location, color: jdc.cta),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelPickupRequired
                  : null,
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
                  AppLocalizations.of(context)!.parcelPickupCoords(
                      _pickupLat!.toStringAsFixed(5),
                      _pickupLng!.toStringAsFixed(5)),
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSection() {
    final jdc = JdcColors.of(context);
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
                Icon(Icons.location_on, color: jdc.dangerInk, size: 22),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        AppLocalizations.of(context)!.parcelRecipientInfo,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                GestureDetector(
                  onTap: _pickSavedAddressForDropoff,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: jdc.cta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: jdc.cta.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_outline,
                            size: 16, color: jdc.cta),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(context)!.parcelSavedAddresses,
                            style: TextStyle(
                                fontSize: 12,
                                color: jdc.cta,
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
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelRecipientNameRequired
                  : null,
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
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelRecipientPhoneRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dropoffController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.parcelDropoffAddress,
                prefixIcon: Icon(Icons.location_on, color: jdc.dangerInk),
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
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelDropoffRequired
                  : null,
              onChanged: (value) {
                if (value.length > 5) {
                  _dropoffDebounceTimer?.cancel();
                  _dropoffDebounceTimer = Timer(
                    const Duration(milliseconds: 500),
                    _calculateRealDistance,
                  );
                }
              },
            ),
            if (_estimatedDistance > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppLocalizations.of(context)!.parcelEstimatedDistance(
                      _estimatedDistance.toStringAsFixed(1)),
                  style: TextStyle(
                      fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ),
            if (_dropoffLat != null && _dropoffLng != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  AppLocalizations.of(context)!.parcelDropoffCoords(
                      _dropoffLat!.toStringAsFixed(5),
                      _dropoffLng!.toStringAsFixed(5)),
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection() {
    final jdc = JdcColors.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.parcelSizeTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  secondary: Icon(option['icon'], color: jdc.infoInk),
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              validator: (v) => v == null || v.isEmpty
                  ? AppLocalizations.of(context)!.parcelDescriptionRequired
                  : null,
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
    final jdc = JdcColors.of(context);
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.parcelPhotoHint,
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
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
                      color: colorScheme.outlineVariant,
                      style: BorderStyle.solid),
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
                                  decoration: BoxDecoration(
                                    color: jdc.dangerInk,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close,
                                      color: jdc.onCta, size: 18),
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
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // _buildPriceCard replaced by sticky bottom bar (Wave 1.5 b2ride)
  // ignore: unused_element
  Widget _buildPriceCard() {
    final jdc = JdcColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: jdc.successSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: jdc.successLine),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.parcelEstimatedFee,
                  style: TextStyle(
                      fontSize: 14, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                AppLocalizations.of(context)!
                    .parcelDistanceKm(_estimatedDistance.toStringAsFixed(1)),
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_couponDiscount > 0)
                Text(
                  '฿${_estimatedPrice.ceil()}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                '฿${_finalParcelPrice.ceil()}',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: jdc.successInk),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // _buildBookButton replaced by sticky bottom bar (Wave 1.5 b2ride)
  // ignore: unused_element
  Widget _buildBookButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _bookParcel,
        style: ElevatedButton.styleFrom(
          backgroundColor: jdc.infoInk,
          foregroundColor: jdc.onCta,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: jdc.onCta, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_shipping, size: 22),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.parcelBookButton,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
      ),
    );
  }
}
