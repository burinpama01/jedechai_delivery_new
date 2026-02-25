import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../common/config/env_config.dart';
import '../../../../theme/app_theme.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';

/// Delivery Map Picker Screen — หน้าปักหมุดเลือกตำแหน่งจัดส่ง
///
/// ผู้ใช้สามารถลากแผนที่เพื่อเลื่อนหมุดไปยังตำแหน่งที่ต้องการ
/// จะแสดงชื่อที่อยู่จาก Google Geocoding API
class DeliveryMapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const DeliveryMapPickerScreen({super.key, this.initialPosition});

  @override
  State<DeliveryMapPickerScreen> createState() => _DeliveryMapPickerScreenState();
}

class _DeliveryMapPickerScreenState extends State<DeliveryMapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(13.7563, 100.5018); // Default: Bangkok
  String _addressText = 'กำลังโหลดที่อยู่...';
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = true;

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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedPosition));
      _reverseGeocode(_selectedPosition);
    } catch (e) {
      debugLog('❌ Error getting current location: $e');
      setState(() => _isLoadingLocation = false);
      _reverseGeocode(_selectedPosition);
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
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
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
        final results = data['results'] as List;
        // ใช้ผลลัพธ์แรกที่เป็นที่อยู่ที่อ่านง่าย
        String address = results[0]['formatted_address'] as String? ?? '';
        // ตัดส่วนที่ไม่จำเป็นออก (เช่น รหัสไปรษณีย์ ประเทศ)
        if (address.isNotEmpty) {
          setState(() => _addressText = address);
        } else {
          setState(() => _addressText = 'ตำแหน่ง: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
        }
      } else {
        setState(() => _addressText = 'ตำแหน่ง: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
      }
    } catch (e) {
      debugLog('❌ Reverse geocode error: $e');
      setState(() => _addressText = 'ตำแหน่ง: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
    } finally {
      setState(() => _isLoadingAddress = false);
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

  void _confirmLocation() {
    Navigator.of(context).pop({
      'lat': _selectedPosition.latitude,
      'lng': _selectedPosition.longitude,
      'address': _addressText,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกตำแหน่งจัดส่ง'),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingLocation
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPosition,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // Center pin (fixed in the middle of the map)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_pin,
                      size: 48,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),

                // Address card at the bottom
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    children: [
                      // Address info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'ตำแหน่งจัดส่ง',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _isLoadingAddress
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('กำลังค้นหาที่อยู่...', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                    ],
                                  )
                                : Text(
                                    _addressText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoadingAddress ? null : _confirmLocation,
                                icon: const Icon(Icons.check, size: 20),
                                label: const Text('ยืนยันตำแหน่งนี้', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
