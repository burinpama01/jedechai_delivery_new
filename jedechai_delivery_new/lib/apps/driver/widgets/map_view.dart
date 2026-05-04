import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';

/// Google Map widget with overlay controls for the driver navigation screen.
class MapView extends StatelessWidget {
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Position? currentPosition;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final String serviceType;
  final double distanceKm;
  final int? etaMinutes;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onMyLocation;
  final VoidCallback onFitMarkers;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapView({
    super.key,
    required this.markers,
    required this.polylines,
    required this.onMapCreated,
    required this.onMyLocation,
    required this.onFitMarkers,
    required this.onZoomIn,
    required this.onZoomOut,
    this.currentPosition,
    this.pickupLocation,
    this.destinationLocation,
    required this.serviceType,
    required this.distanceKm,
    this.etaMinutes,
  });

  String _getServiceTypeName() {
    switch (serviceType) {
      case 'food':
        return 'ส่งอาหาร';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return 'รับ-ส่ง';
    }
  }

  IconData _getServiceTypeIcon() {
    switch (serviceType) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'parcel':
        return Icons.inventory_2_rounded;
      default:
        return Icons.directions_car_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final distanceText = distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : '—';

    final initialTarget = currentPosition != null
        ? LatLng(currentPosition!.latitude, currentPosition!.longitude)
        : pickupLocation ?? destinationLocation ?? const LatLng(7.8804, 98.3923);

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: onMapCreated,
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14),
          markers: markers,
          polylines: polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          padding: const EdgeInsets.only(bottom: 60),
        ),

        // Zoom + My Location (top right)
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _MapButton(icon: Icons.my_location, onPressed: onMyLocation),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.zoom_out_map, onPressed: onFitMarkers),
            ],
          ),
        ),

        // Zoom +/- (bottom right)
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              _MapButton(icon: Icons.add, onPressed: onZoomIn),
              const SizedBox(height: 4),
              _MapButton(icon: Icons.remove, onPressed: onZoomOut),
            ],
          ),
        ),

        // Info chips (top left)
        Positioned(
          left: 12,
          right: 72,
          top: 12,
          child: Row(
            children: [
              Expanded(child: _InfoChip(
                icon: _getServiceTypeIcon(),
                label: 'ประเภท',
                value: _getServiceTypeName(),
                color: AppTheme.accentBlue,
              )),
              const SizedBox(width: 8),
              Expanded(child: _InfoChip(
                icon: Icons.route_rounded,
                label: 'ระยะทาง',
                value: distanceText,
                color: colorScheme.tertiary,
              )),
              if (etaMinutes != null) ...[
                const SizedBox(width: 8),
                Expanded(child: _InfoChip(
                  icon: Icons.access_time_rounded,
                  label: 'ETA',
                  value: '$etaMinutes นาที',
                  color: Colors.orange.shade700,
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
