import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../common/config/env_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../customer/map_dark_style.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';

/// Delivery Map Picker Screen — หน้าปักหมุดเลือกตำแหน่งจัดส่ง
///
/// UI ตาม Design: Customer-MapPicker.dc.html
/// แผนที่เต็มจอ + หมุดตรงกลาง + ช่องค้นหาด้านบน + card ยืนยันตำแหน่งด้านล่าง
class DeliveryMapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const DeliveryMapPickerScreen({super.key, this.initialPosition});

  @override
  State<DeliveryMapPickerScreen> createState() =>
      _DeliveryMapPickerScreenState();
}

class _DeliveryMapPickerScreenState extends State<DeliveryMapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition =
      const LatLng(13.7563, 100.5018); // Default: Bangkok
  String _addressText = '';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;
  LatLng? _lastGeocodedPosition;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition!;
      _isLoadingLocation = false;
      _reverseGeocode(_selectedPosition);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
        _reverseGeocode(_selectedPosition);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedPosition));
      _reverseGeocode(_selectedPosition);
    } catch (e) {
      debugLog('❌ Error getting current location: $e');
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _reverseGeocode(_selectedPosition);
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    if (!mounted) return;
    if (_lastGeocodedPosition != null) {
      final dist = Geolocator.distanceBetween(
        _lastGeocodedPosition!.latitude,
        _lastGeocodedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (dist < 50) return;
    }
    _lastGeocodedPosition = position;
    setState(() => _isLoadingAddress = true);
    try {
      final apiKey = EnvConfig.googleMapsApiKey;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=${position.latitude},${position.longitude}'
        '&language=th'
        '&key=$apiKey',
      );

      final response = await http.get(url);
      if (!mounted) return;
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final results = data['results'] as List;
        String address = results[0]['formatted_address'] as String? ?? '';
        if (address.isNotEmpty) {
          setState(() => _addressText = address);
        } else {
          if (mounted) {
            setState(() => _addressText = AppLocalizations.of(context)!
                .mapPickerPosition(position.latitude.toStringAsFixed(5),
                    position.longitude.toStringAsFixed(5)));
          }
        }
      } else {
        if (mounted) {
          setState(() => _addressText = AppLocalizations.of(context)!
              .mapPickerPosition(position.latitude.toStringAsFixed(5),
                  position.longitude.toStringAsFixed(5)));
        }
      }
    } catch (e) {
      debugLog('❌ Reverse geocode error: $e');
      if (mounted) {
        setState(() => _addressText = AppLocalizations.of(context)!
            .mapPickerPosition(position.latitude.toStringAsFixed(5),
                position.longitude.toStringAsFixed(5)));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  void _onCameraIdle() {
    _reverseGeocode(_selectedPosition);
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedPosition = position.target;
    });
  }

  /// ค้นหาที่อยู่แล้วเลื่อนแผนที่ไปยังผลลัพธ์แรก
  Future<void> _searchAddress(String query) async {
    final text = query.trim();
    if (text.isEmpty || _isSearching) return;
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(text)}'
        '&language=th&region=th'
        '&key=${EnvConfig.googleMapsApiKey}',
      );
      final response = await http.get(url);
      if (!mounted) return;
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final loc = data['results'][0]['geometry']['location'];
        final target = LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
        setState(() {
          _selectedPosition = target;
          _addressText =
              data['results'][0]['formatted_address'] as String? ?? _addressText;
          _lastGeocodedPosition = target;
        });
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(target, 16),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.mapPickerSearchNotFound)),
        );
      }
    } catch (e) {
      debugLog('❌ Address search error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _confirmLocation() {
    final detail = _detailController.text.trim();
    Navigator.of(context).pop({
      'lat': _selectedPosition.latitude,
      'lng': _selectedPosition.longitude,
      // ต่อรายละเอียดที่ผู้ใช้พิมพ์เข้ากับที่อยู่ เพื่อไม่ให้ข้อมูลหาย
      'address': detail.isEmpty ? _addressText : '$_addressText ($detail)',
      'address_detail': detail,
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _detailController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: jdc.paper,
      body: _isLoadingLocation
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : Stack(
              children: [
                // แผนที่เต็มจอ
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedPosition,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) => _mapController = controller,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    style: isDark ? kMapDarkStyle : null,
                  ),
                ),

                // หมุดกลางแผนที่
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: jdc.cta,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(22),
                              topRight: Radius.circular(22),
                              bottomRight: Radius.circular(22),
                              bottomLeft: Radius.circular(2),
                            ),
                            border: Border.all(
                              color: jdc.surface,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: jdc.surface,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 4,
                          decoration: BoxDecoration(
                            color: jdc.text.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(JdcRadius.chip),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // toolbar ด้านบน — ย้อนกลับ + ช่องค้นหา
                Positioned(
                  top: MediaQuery.of(context).padding.top + JdcSpacing.lg,
                  left: JdcSpacing.xl,
                  right: JdcSpacing.xl,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: JdcTouch.minTarget,
                          height: JdcTouch.minTarget,
                          decoration: BoxDecoration(
                            color: jdc.surface,
                            borderRadius: BorderRadius.circular(JdcRadius.small),
                            boxShadow: [
                              BoxShadow(
                                color: jdc.text.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(Icons.chevron_left, color: jdc.text, size: 26),
                        ),
                      ),
                      const SizedBox(width: JdcSpacing.sm),
                      Expanded(
                        child: Container(
                          height: JdcTouch.minTarget,
                          padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.lg),
                          decoration: BoxDecoration(
                            color: jdc.surface,
                            borderRadius: BorderRadius.circular(JdcRadius.small),
                            boxShadow: [
                              BoxShadow(
                                color: jdc.text.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: jdc.muted, size: 18),
                              const SizedBox(width: JdcSpacing.sm),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _searchAddress,
                                  style: TextStyle(fontSize: 13, color: jdc.text),
                                  decoration: InputDecoration(
                                    hintText: l10n.mapPickerSearchHint,
                                    hintStyle: TextStyle(color: jdc.muted, fontSize: 13),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ปุ่มตำแหน่งปัจจุบัน
                Positioned(
                  right: JdcSpacing.xl,
                  bottom: 220,
                  child: GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: jdc.surface,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: jdc.text.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(Icons.my_location, color: jdc.text, size: 22),
                    ),
                  ),
                ),

                // Card ยืนยันตำแหน่ง (bottom sheet)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      JdcSpacing.xl,
                      JdcSpacing.xl,
                      JdcSpacing.xl,
                      JdcSpacing.xl + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: jdc.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(JdcRadius.sheet),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: jdc.text.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mapPickerConfirmLocation,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: jdc.text,
                          ),
                        ),
                        const SizedBox(height: JdcSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(JdcSpacing.lg),
                          decoration: BoxDecoration(
                            color: jdc.paper,
                            borderRadius: BorderRadius.circular(JdcRadius.card),
                            border: Border.all(color: jdc.line),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on, color: jdc.link, size: 20),
                              const SizedBox(width: JdcSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isLoadingAddress) ...[
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: jdc.muted,
                                            ),
                                          ),
                                          const SizedBox(width: JdcSpacing.sm),
                                          Text(
                                            l10n.mapPickerSearching,
                                            style: TextStyle(color: jdc.muted, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Text(
                                        _addressText.isNotEmpty
                                            ? _addressText.split(',').first.trim()
                                            : l10n.mapPickerDeliveryLocation,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: jdc.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_addressText.contains(','))
                                        Text(
                                          _addressText.substring(
                                              _addressText.indexOf(',') + 1).trim(),
                                          style: TextStyle(fontSize: 12, color: jdc.muted),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: JdcSpacing.lg),
                        // ช่องรายละเอียดเพิ่มเติม
                        TextField(
                          controller: _detailController,
                          decoration: InputDecoration(
                            labelText: l10n.mapPickerDetailLabel,
                            hintText: l10n.mapPickerDetailHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(JdcRadius.small),
                              borderSide: BorderSide(color: jdc.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(JdcRadius.small),
                              borderSide: BorderSide(color: jdc.line),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: JdcSpacing.lg,
                              vertical: JdcSpacing.md,
                            ),
                          ),
                          style: TextStyle(fontSize: 13, color: jdc.text),
                        ),
                        const SizedBox(height: JdcSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          height: JdcTouch.button,
                          child: ElevatedButton(
                            onPressed: _isLoadingAddress ? null : _confirmLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: jdc.cta,
                              foregroundColor: jdc.onCta,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(JdcRadius.card),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              l10n.mapPickerConfirm,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
