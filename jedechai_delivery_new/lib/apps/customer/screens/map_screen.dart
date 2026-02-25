import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import '../../../theme/app_theme.dart';
import 'services/ride_service_screen.dart';
import 'services/food_service_screen.dart';
import 'services/parcel_service_screen.dart';

/// Map Screen
/// 
/// Super App interface with Google Map background and floating service menu
/// Similar to Grab/Lineman interface
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  bool _isMapReady = false;
  Position? _currentPosition;
  bool _isLoadingLocation = false;

  // Bangkok coordinates (fallback)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(13.7563, 100.5018),
    zoom: 14.0,
  );

  // Service data
  final List<Map<String, dynamic>> _services = [
    {
      'title': 'เรียกรถ',
      'icon': Icons.motorcycle,
      'color': AppTheme.primaryGreen,
      'screen': const RideServiceScreen(),
    },
    {
      'title': 'สั่งอาหาร',
      'icon': Icons.fastfood,
      'color': AppTheme.accentOrange,
      'screen': FoodServiceScreen(),
    },
    {
      'title': 'ส่งของ',
      'icon': Icons.local_shipping,
      'color': AppTheme.accentBlue,
      'screen': const ParcelServiceScreen(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  /// Determine and request location permissions
  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled don't continue
        _showLocationServiceDialog();
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) return;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedForeverDialog();
        return;
      }

      // When permissions are granted, get the current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      // Move camera to current location if map is ready
      if (_mapController != null) {
        _moveToCurrentLocation();
      }

      debugLog('✅ Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      debugLog('❌ Error getting location: $e');
      _showLocationErrorDialog(e.toString());
    }
  }

  /// Move camera to current location
  void _moveToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15.0,
          ),
        ),
      );
      debugLog('📍 Moved to current location');
    }
  }

  /// Show dialog to enable location services
  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('บริการตำแหน่ง'),
          content: const Text('บริการตำแหน่งถูกปิดใช้งานอยู่ กรุณาเปิดใช้งานบริการตำแหน่ง'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try opening location settings
                Geolocator.openLocationSettings();
              },
              child: const Text('เปิดการตั้งค่า'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );
  }

  /// Show permission denied dialog
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('สิทธิ์การเข้าถึงตำแหน่ง'),
          content: const Text('การอนุญาตให้เข้าถึงตำแหน่งถูกปฏิเสธ กรุณาอนุญาตให้เข้าถึงตำแหน่งเพื่อใช้งานแผนที่'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _determinePosition(); // Try again
              },
              child: const Text('ลองใหม่'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );
  }

  /// Show permission denied forever dialog
  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('สิทธิ์การเข้าถึงตำแหน่ง'),
          content: const Text('การอนุญาตให้เข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดการตั้งค่าแอปเพื่ออนุญาตสิทธิ์'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('เปิดการตั้งค่า'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ยกเลิก'),
            ),
          ],
        );
      },
    );
  }

  /// Show location error dialog
  void _showLocationErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ข้อผิดพลาดตำแหน่ง'),
          content: Text('ไม่สามารถดึงตำแหน่งได้: $error'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = AuthService.userEmail ?? 'ผู้ใช้';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jedechai Delivery'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          // User info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                userEmail,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Layer 1: Google Map (Background)
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              setState(() {
                _isMapReady = true;
              });
              // Move to current location when map is ready
              if (_currentPosition != null) {
                _moveToCurrentLocation();
              }
            },
            initialCameraPosition: _currentPosition != null
                ? CameraPosition(
                    target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    zoom: 15.0,
                  )
                : _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Disable default button, we'll add custom
            zoomControlsEnabled: false, // Disable default controls, we'll add custom
            mapType: MapType.normal,
            compassEnabled: true,
            trafficEnabled: false,
            buildingsEnabled: true,
            // Add padding to prevent Google logo from being hidden
            padding: const EdgeInsets.only(bottom: 120),
          ),
          
          // Loading indicators
          if (!_isMapReady)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              ),
            ),
          
          // Location loading indicator
          if (_isLoadingLocation)
            const Positioned(
              top: 80,
              left: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('กำลังหาตำแหน่ง...'),
                    ],
                  ),
                ),
              ),
            ),
          
          // Layer 2: Map controls overlay
          if (_isMapReady)
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                children: [
                  // Map type button
                  FloatingActionButton(
                    heroTag: "mapType",
                    mini: true,
                    onPressed: _toggleMapType,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.layers, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(height: 8),
                  // Current location button
                  FloatingActionButton(
                    heroTag: "currentLocation",
                    mini: true,
                    onPressed: _currentPosition != null ? _moveToCurrentLocation : _determinePosition,
                    backgroundColor: Colors.white,
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                            ),
                          )
                        : const Icon(Icons.my_location, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
            ),

          // Layer 3: Floating Location Button (above Service Menu)
          if (_isMapReady)
            Positioned(
              right: 16,
              bottom: 160, // Above service menu (120px + 40px margin)
              child: FloatingActionButton(
                heroTag: "centerLocation",
                onPressed: _currentPosition != null ? _moveToCurrentLocation : _determinePosition,
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                child: _isLoadingLocation
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.gps_fixed),
              ),
            ),

          // Layer 3: Service Menu Card (Floating at bottom)
          if (_isMapReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildServiceMenuCard(),
            ),
        ],
      ),
    );
  }

  /// Build the floating service menu card
  Widget _buildServiceMenuCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Service title
          Text(
            'เลือกบริการ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Service buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _services.map((service) {
              return _buildServiceButton(
                title: service['title'] as String,
                icon: service['icon'] as IconData,
                color: service['color'] as Color,
                onTap: () => _navigateToService(service['screen'] as Widget),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Build individual service button
  Widget _buildServiceButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular button with icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          // Service title
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to service screen
  void _navigateToService(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _logout() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleMapType() async {
    if (_mapController != null) {
      // Simple zoom toggle instead of map type change
      final currentZoom = await _mapController!.getZoomLevel();
      _mapController!.animateCamera(
        CameraUpdate.zoomTo(currentZoom + 1),
      );
      
      debugLog('🗺️ Zoom level changed to: ${currentZoom + 1}');
    }
  }
}
