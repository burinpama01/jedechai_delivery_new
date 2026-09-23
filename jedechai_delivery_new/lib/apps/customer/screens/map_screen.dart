import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import '../../../theme/jdc_colors.dart';
import '../../customer/map_dark_style.dart';
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
  MapType _mapType = MapType.normal;

  // Bangkok coordinates (fallback)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(13.7563, 100.5018),
    zoom: 14.0,
  );

  List<Map<String, dynamic>> _getServices(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return [
      {
        'title': l10n.mapSvcRide,
        'icon': Icons.motorcycle,
        'color': jdc.cta,
        'screen': const RideServiceScreen(),
      },
      {
        'title': l10n.mapSvcFood,
        'icon': Icons.fastfood,
        'color': jdc.brand,
        'screen': FoodServiceScreen(),
      },
      {
        'title': l10n.mapSvcParcel,
        'icon': Icons.local_shipping,
        'color': jdc.infoInk,
        'screen': const ParcelServiceScreen(),
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
        if (mounted) setState(() => _isLoadingLocation = false);
        _showLocationServiceDialog();
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) {
          if (mounted) setState(() => _isLoadingLocation = false);
          return;
        }
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLoadingLocation = false);
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLoadingLocation = false);
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
      if (mounted) setState(() => _isLoadingLocation = false);
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
          title: Text(AppLocalizations.of(context)!.mapLocServiceTitle),
          content: Text(AppLocalizations.of(context)!.mapLocServiceBody),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try opening location settings
                Geolocator.openLocationSettings();
              },
              child: Text(AppLocalizations.of(context)!.mapLocOpenSettings),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.mapLocCancel),
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
          title: Text(AppLocalizations.of(context)!.mapLocPermTitle),
          content: Text(AppLocalizations.of(context)!.mapLocPermDenied),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _determinePosition(); // Try again
              },
              child: Text(AppLocalizations.of(context)!.mapLocRetry),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.mapLocCancel),
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
          title: Text(AppLocalizations.of(context)!.mapLocPermTitle),
          content: Text(AppLocalizations.of(context)!.mapLocPermForever),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: Text(AppLocalizations.of(context)!.mapLocOpenSettings),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.mapLocCancel),
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
          title: Text(AppLocalizations.of(context)!.mapLocErrorTitle),
          content: Text(AppLocalizations.of(context)!.mapLocErrorBody(error)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context)!.mapLocOk),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userEmail = AuthService.userEmail ?? AppLocalizations.of(context)!.mapUserFallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JDC Delivery'),
        backgroundColor: jdc.panel,
        foregroundColor: jdc.onPanel,
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
            tooltip: AppLocalizations.of(context)!.mapLogout,
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
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: _mapType,
            compassEnabled: true,
            trafficEnabled: false,
            buildingsEnabled: true,
            style: isDark ? kMapDarkStyle : null,
            padding: const EdgeInsets.only(bottom: 120),
          ),
          
          // Loading indicators
          if (!_isMapReady)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(jdc.cta),
              ),
            ),

          // Location loading indicator
          if (_isLoadingLocation)
            Positioned(
              top: 80,
              left: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(jdc.cta),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.mapFindingLocation),
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
                    backgroundColor: jdc.surface,
                    child: Icon(Icons.layers, color: jdc.cta),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: "currentLocation",
                    mini: true,
                    onPressed: _currentPosition != null ? _moveToCurrentLocation : _determinePosition,
                    backgroundColor: jdc.surface,
                    child: _isLoadingLocation
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(jdc.cta),
                            ),
                          )
                        : Icon(Icons.my_location, color: jdc.cta),
                  ),
                ],
              ),
            ),

          // Layer 3: Floating Location Button (above Service Menu)
          if (_isMapReady)
            Positioned(
              right: 16,
              bottom: 160,
              child: FloatingActionButton(
                heroTag: "centerLocation",
                onPressed: _currentPosition != null ? _moveToCurrentLocation : _determinePosition,
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                child: _isLoadingLocation
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(jdc.onCta),
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

  /// Build the floating service menu card — Wave 1.5 b2ride style
  Widget _buildServiceMenuCard() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: jdc.shadowSheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: jdc.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 14),

          // Service title
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.mapSelectService,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: jdc.text,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Service buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _getServices(context).map((service) {
              return _buildServiceButton(
                title: service['title'] as String,
                icon: service['icon'] as IconData,
                color: service['color'] as Color,
                onTap: () =>
                    _navigateToService(service['screen'] as Widget),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
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
    final jdc = JdcColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: jdc.text,
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
            content: Text(AppLocalizations.of(context)!.mapLogoutError(e.toString())),
            backgroundColor: JdcColors.of(context).danger,
          ),
        );
      }
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
    debugLog('🗺️ Map type toggled to: $_mapType');
  }
}
