import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/debug_logger.dart';
import '../theme/admin_theme.dart';

/// Admin Driver Map Screen
///
/// แสดงแผนที่คนขับออนไลน์แบบ real-time (ไม่ใช้ Google Maps —
/// ใช้ list + coordinate view เพื่อรองรับ web โดยไม่ต้อง Maps SDK)
class AdminDriverMapScreen extends StatefulWidget {
  const AdminDriverMapScreen({super.key});

  @override
  State<AdminDriverMapScreen> createState() => _AdminDriverMapScreenState();
}

class _AdminDriverMapScreenState extends State<AdminDriverMapScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _onlineDrivers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  String _filter = 'online'; // online, all, pending

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadDrivers());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      // ดึงคนขับทั้งหมด (ทุก approval_status)
      final response = await _client
          .from('profiles')
          .select('id, full_name, phone_number, vehicle_type, vehicle_plate, '
              'latitude, longitude, is_online, approval_status, created_at, updated_at')
          .eq('role', 'driver')
          .order('is_online', ascending: false);

      final drivers = (response as List).cast<Map<String, dynamic>>();

      if (mounted) {
        setState(() {
          _allDrivers = drivers;
          _onlineDrivers = drivers
              .where((d) => _isOnline(d['is_online']))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading drivers for map: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    switch (_filter) {
      case 'online':
        return _onlineDrivers;
      case 'pending':
        return _allDrivers.where((d) => d['approval_status'] == 'pending').toList();
      case 'approved':
        return _allDrivers.where((d) => d['approval_status'] == 'approved').toList();
      default:
        return _allDrivers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDrivers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              const Icon(Icons.map_rounded, color: AdminTheme.primary, size: 28),
              const SizedBox(width: 12),
              const Text(
                'แผนที่คนขับ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // Auto-refresh indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AdminTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ออนไลน์ ${_onlineDrivers.length} คน',
                      style: const TextStyle(
                        color: AdminTheme.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadDrivers,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'รีเฟรช',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            children: [
              _buildFilterChip('online', 'ออนไลน์ (${_onlineDrivers.length})'),
              _buildFilterChip('approved', 'อนุมัติแล้ว (${_allDrivers.where((d) => d['approval_status'] == 'approved').length})'),
              _buildFilterChip('pending', 'รออนุมัติ (${_allDrivers.where((d) => d['approval_status'] == 'pending').length})'),
              _buildFilterChip('all', 'ทั้งหมด (${_allDrivers.length})'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Driver list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_rounded, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'ไม่พบคนขับ',
                            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : _buildDriverGrid(filtered),
        ),
      ],
    );
  }

  /// Handle is_online as bool or string from Supabase
  static bool _isOnline(dynamic val) {
    if (val is bool) return val;
    if (val is String) return val.toLowerCase() == 'true';
    return false;
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AdminTheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AdminTheme.primary : AdminTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AdminTheme.primary : AdminTheme.divider,
        ),
      ),
    );
  }

  Widget _buildDriverGrid(List<Map<String, dynamic>> drivers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossCount = width > 1200 ? 4 : width > 800 ? 3 : width > 500 ? 2 : 1;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: drivers.length,
          itemBuilder: (context, index) => _buildDriverCard(drivers[index]),
        );
      },
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final name = driver['full_name'] ?? 'ไม่ระบุชื่อ';
    final phone = driver['phone_number'] ?? '-';
    final vehicleType = driver['vehicle_type'] ?? '-';
    final plate = driver['vehicle_plate'] ?? '-';
    final isOnline = _isOnline(driver['is_online']);
    final status = driver['approval_status'] ?? 'pending';
    final lat = driver['latitude'];
    final lng = driver['longitude'];
    final hasLocation = lat != null && lng != null && lat != 0.0 && lng != 0.0;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
        statusColor = AdminTheme.success;
        statusText = 'อนุมัติ';
        break;
      case 'rejected':
        statusColor = AdminTheme.danger;
        statusText = 'ปฏิเสธ';
        break;
      case 'suspended':
        statusColor = AdminTheme.warning;
        statusText = 'ระงับ';
        break;
      default:
        statusColor = AdminTheme.info;
        statusText = 'รออนุมัติ';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(AdminTheme.radiusMd),
        border: Border.all(
          color: isOnline ? AdminTheme.success.withValues(alpha: 0.4) : AdminTheme.divider,
          width: isOnline ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Online dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isOnline ? AdminTheme.success : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.phone, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 12),
              Icon(Icons.directions_car, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('$vehicleType $plate',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          const SizedBox(height: 4),
          if (hasLocation)
            Row(
              children: [
                Icon(Icons.location_on, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.location_off, size: 13, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('ไม่มีตำแหน่ง', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
        ],
      ),
    );
  }
}
