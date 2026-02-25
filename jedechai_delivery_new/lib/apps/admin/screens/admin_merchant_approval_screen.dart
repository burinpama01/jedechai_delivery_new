import 'package:flutter/material.dart';
import '../../merchant/screens/merchant_coupon_management_screen.dart';
import '../../../common/services/admin_service.dart';
import '../../../common/utils/platform_adaptive.dart';
import '../../../utils/debug_logger.dart';

/// Admin Merchant Approval Screen
///
/// แสดงรายชื่อร้านค้ารอการอนุมัติ + ร้านค้าทั้งหมด
class AdminMerchantApprovalScreen extends StatefulWidget {
  const AdminMerchantApprovalScreen({super.key});

  @override
  State<AdminMerchantApprovalScreen> createState() =>
      _AdminMerchantApprovalScreenState();
}

class _AdminMerchantApprovalScreenState
    extends State<AdminMerchantApprovalScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  static const List<String> _weekdayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
  static const Map<String, String> _weekdayThai = {
    'mon': 'จ',
    'tue': 'อ',
    'wed': 'พ',
    'thu': 'พฤ',
    'fri': 'ศ',
    'sat': 'ส',
    'sun': 'อา',
  };

  List<Map<String, dynamic>> _pendingMerchants = [];
  List<Map<String, dynamic>> _allMerchants = [];
  bool _isLoading = true;

  TimeOfDay _parseTimeString(String value,
      {TimeOfDay fallback = const TimeOfDay(hour: 8, minute: 0)}) {
    final parts = value.split(':');
    if (parts.length < 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return fallback;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeString(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  List<String> _extractShopOpenDays(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .map((e) => e.toString().toLowerCase().trim())
          .where((e) => _weekdayKeys.contains(e))
          .toSet()
          .toList();
    }
    return [];
  }

  String _formatOpenDaysText(List<String> days) {
    if (days.isEmpty) return 'ทุกวัน';
    final labels = days.map((d) => _weekdayThai[d] ?? d).toList();
    return labels.join(' ');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMerchants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchants() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _adminService.getPendingMerchants();
      final all = await _adminService.getAllMerchants();
      if (mounted) {
        setState(() {
          _pendingMerchants = pending;
          _allMerchants = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading merchants: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editMerchantLocation(Map<String, dynamic> merchant) async {
    final merchantId = merchant['id'] as String;
    final latController = TextEditingController(
      text: ((merchant['latitude'] as num?)?.toDouble())?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: ((merchant['longitude'] as num?)?.toDouble())?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: (merchant['shop_address'] as String?) ?? '',
    );

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('แก้ไขตำแหน่งร้าน'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'ที่อยู่ร้าน',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: latController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lngController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                final lat = double.tryParse(latController.text.trim());
                final lng = double.tryParse(lngController.text.trim());
                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('กรุณากรอกพิกัดให้ถูกต้อง'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop({
                  'lat': lat,
                  'lng': lng,
                  'address': addressController.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0)),
              child:
                  const Text('บันทึก', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (payload == null) return;

    final lat = payload['lat'] as double;
    final lng = payload['lng'] as double;
    final address = payload['address'] as String?;

    final success = await _adminService.updateMerchantLocation(
      merchantId: merchantId,
      latitude: lat,
      longitude: lng,
      shopAddress: address,
    );

    if (!mounted) return;
    if (success) {
      _showSnackBar('อัปเดตตำแหน่งร้านสำเร็จ', Colors.green);
      _loadMerchants();
    } else {
      _showSnackBar('อัปเดตตำแหน่งร้านไม่สำเร็จ', Colors.red);
    }
  }

  Future<void> _manageMerchantCoupons(Map<String, dynamic> merchant) async {
    final merchantId = merchant['id'] as String;
    final merchantName = (merchant['full_name'] as String?)?.trim();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog.fullscreen(
          child: MerchantCouponManagementScreen(
            targetMerchantId: merchantId,
            managedByAdmin: true,
            merchantDisplayName: merchantName,
          ),
        );
      },
    );
  }

  Future<void> _editMerchantShopHours(Map<String, dynamic> merchant) async {
    final merchantId = merchant['id'] as String;
    TimeOfDay selectedOpen = _parseTimeString(
      (merchant['shop_open_time'] as String?) ?? '08:00',
      fallback: const TimeOfDay(hour: 8, minute: 0),
    );
    TimeOfDay selectedClose = _parseTimeString(
      (merchant['shop_close_time'] as String?) ?? '22:00',
      fallback: const TimeOfDay(hour: 22, minute: 0),
    );
    final selectedDays =
        _extractShopOpenDays(merchant['shop_open_days']).toSet();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
            Future<void> pickTime({required bool isOpen}) async {
              final picked = await PlatformAdaptive.pickTime(
                context: context,
                initialTime: isOpen ? selectedOpen : selectedClose,
                title: isOpen ? 'เวลาเปิดร้าน' : 'เวลาปิดร้าน',
              );
              if (picked == null) return;
              setDialogState(() {
                if (isOpen) {
                  selectedOpen = picked;
                } else {
                  selectedClose = picked;
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('ตั้งเวลาเปิด-ปิดร้าน'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.wb_sunny_outlined,
                          color: Color(0xFFF57C00)),
                      title: const Text('เวลาเปิดร้าน'),
                      trailing: Text(
                        _formatTimeString(selectedOpen),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => pickTime(isOpen: true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.nightlight_round,
                          color: Color(0xFF1565C0)),
                      title: const Text('เวลาปิดร้าน'),
                      trailing: Text(
                        _formatTimeString(selectedClose),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () => pickTime(isOpen: false),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'วันที่เปิดร้าน',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _weekdayKeys.map((day) {
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(_weekdayThai[day] ?? day),
                          selected: isSelected,
                          selectedColor:
                              const Color(0xFF1565C0).withValues(alpha: 0.18),
                          checkmarkColor: const Color(0xFF1565C0),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF0D47A1)
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF1565C0)
                                : Colors.grey.shade300,
                          ),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedDays.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณาเลือกวันเปิดร้านอย่างน้อย 1 วัน'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0)),
                  child: const Text('บันทึก',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final openTime = _formatTimeString(selectedOpen);
    final closeTime = _formatTimeString(selectedClose);
    final success = await _adminService.updateMerchantShopHours(
      merchantId: merchantId,
      shopOpenTime: openTime,
      shopCloseTime: closeTime,
      shopOpenDays: selectedDays.toList(),
    );

    if (!mounted) return;
    if (success) {
      _showSnackBar('อัปเดตเวลาเปิด-ปิดร้านสำเร็จ ($openTime - $closeTime)',
          Colors.green);
      _loadMerchants();
    } else {
      _showSnackBar('อัปเดตเวลาเปิด-ปิดร้านไม่สำเร็จ', Colors.red);
    }
  }

  Future<void> _approveMerchant(String merchantId) async {
    final confirmed = await _showConfirmDialog(
      'อนุมัติร้านค้า',
      'ต้องการอนุมัติร้านค้านี้หรือไม่?',
    );
    if (confirmed != true) return;

    final success = await _adminService.approveMerchant(merchantId);
    if (success) {
      _showSnackBar('อนุมัติร้านค้าสำเร็จ', Colors.green);
      _loadMerchants();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _rejectMerchant(String merchantId) async {
    final reason = await _showReasonDialog('ปฏิเสธร้านค้า');
    if (reason == null || reason.isEmpty) return;

    final success = await _adminService.rejectMerchant(merchantId, reason);
    if (success) {
      _showSnackBar('ปฏิเสธร้านค้าสำเร็จ', Colors.orange);
      _loadMerchants();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _suspendMerchant(String merchantId) async {
    final reason = await _showReasonDialog('ระงับบัญชีร้านค้า');
    if (reason == null || reason.isEmpty) return;

    final success = await _adminService.suspendUser(merchantId, reason);
    if (success) {
      _showSnackBar('ระงับบัญชีร้านค้าสำเร็จ', Colors.orange);
      _loadMerchants();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _toggleMerchantShopStatus(
    String merchantId, {
    required bool currentlyOpen,
  }) async {
    final makeOpen = !currentlyOpen;
    final confirmed = await _showConfirmDialog(
      makeOpen ? 'เปิดร้าน' : 'ปิดร้าน',
      makeOpen
          ? 'ต้องการเปิดร้านนี้ให้ลูกค้าเห็นและสั่งซื้อได้หรือไม่?'
          : 'ต้องการปิดร้านนี้ชั่วคราว (ระงับการเปิดร้าน) หรือไม่?',
    );
    if (confirmed != true) return;

    final success = await _adminService.updateMerchantShopStatus(
      merchantId: merchantId,
      isOpen: makeOpen,
    );
    if (success) {
      _showSnackBar(makeOpen ? 'เปิดร้านสำเร็จ' : 'ปิดร้านสำเร็จ', Colors.blue);
      _loadMerchants();
    } else {
      _showSnackBar('อัปเดตสถานะร้านไม่สำเร็จ', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.store_rounded, color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 12),
                const Text('จัดการร้านค้า', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Spacer(),
                IconButton(onPressed: _loadMerchants, icon: const Icon(Icons.refresh_rounded), tooltip: 'รีเฟรช'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1565C0),
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: const Color(0xFF64748B),
              tabs: [
                Tab(text: 'รออนุมัติ (${_pendingMerchants.length})'),
                Tab(text: 'ทั้งหมด (${_allMerchants.length})'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMerchantList(_pendingMerchants, isPending: true),
                      _buildMerchantList(_allMerchants, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantList(List<Map<String, dynamic>> merchants,
      {required bool isPending}) {
    if (merchants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isPending ? 'ไม่มีร้านค้ารออนุมัติ' : 'ยังไม่มีร้านค้าในระบบ',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMerchants,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: merchants.length,
        itemBuilder: (context, index) =>
            _buildMerchantCard(merchants[index], isPending),
      ),
    );
  }

  Widget _buildMerchantCard(Map<String, dynamic> merchant, bool isPending) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = merchant['full_name'] ?? 'ไม่ระบุชื่อ';
    final phone = merchant['phone_number'] ?? '-';
    final status = merchant['approval_status'] ?? 'pending';
    final shopAddress = merchant['shop_address'] ?? '-';
    final lat = (merchant['latitude'] as num?)?.toDouble();
    final lng = (merchant['longitude'] as num?)?.toDouble();
    final shopOpenTime = (merchant['shop_open_time'] as String?) ?? '08:00';
    final shopCloseTime = (merchant['shop_close_time'] as String?) ?? '22:00';
    final shopOpenDays = _extractShopOpenDays(merchant['shop_open_days']);
    final isShopOpen = merchant['shop_status'] == true ||
        merchant['shop_status'] == 1 ||
        merchant['shop_status'] == 'true';
    final merchantId = merchant['id'] as String;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'ปฏิเสธ';
        break;
      case 'suspended':
        statusColor = Colors.orange;
        statusText = 'ระงับ';
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'รออนุมัติ';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.green[50],
                  child: const Icon(Icons.store, color: Colors.green, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(phone,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(shopAddress,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.pin_drop_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lat != null && lng != null
                        ? 'พิกัด: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
                        : 'ยังไม่ได้ปักพิกัดร้าน',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'เวลาเปิด-ปิด: $shopOpenTime - $shopCloseTime',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'วันเปิดร้าน: ${_formatOpenDaysText(shopOpenDays)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            if (merchant['shop_license_url'] != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.green[400]),
                  const SizedBox(width: 4),
                  Text('มีใบอนุญาตร้านค้า',
                      style: TextStyle(fontSize: 12, color: Colors.green[600])),
                ],
              ),
            ],
            if (merchant['rejection_reason'] != null &&
                status == 'rejected') ...[
              const SizedBox(height: 8),
              Text(
                'เหตุผล: ${merchant['rejection_reason']}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editMerchantLocation(merchant),
                    icon:
                        const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: const Text('ตำแหน่งร้าน'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _manageMerchantCoupons(merchant),
                    icon: const Icon(Icons.local_offer_outlined, size: 18),
                    label: const Text('คูปองร้าน'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF57C00),
                      side: const BorderSide(color: Color(0xFFF57C00)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isShopOpen ? Colors.green : Colors.grey)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isShopOpen ? 'ร้านเปิด' : 'ร้านปิด',
                    style: TextStyle(
                        color: isShopOpen ? Colors.green : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editMerchantShopHours(merchant),
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('เวลาเปิด-ปิดร้าน'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00897B),
                  side: const BorderSide(color: Color(0xFF00897B)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectMerchant(merchantId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ปฏิเสธ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveMerchant(merchantId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('อนุมัติ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleMerchantShopStatus(
                        merchantId,
                        currentlyOpen: isShopOpen,
                      ),
                      icon: Icon(
                        isShopOpen ? Icons.storefront_outlined : Icons.store,
                        size: 18,
                      ),
                      label: Text(isShopOpen ? 'ระงับ(ปิดร้าน)' : 'เปิดร้าน'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isShopOpen ? const Color(0xFF6D4C41) : Colors.blue,
                        side: BorderSide(
                          color: isShopOpen
                              ? const Color(0xFF6D4C41)
                              : Colors.blue,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _suspendMerchant(merchantId),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('ระงับบัญชี'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showReasonDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'ระบุเหตุผล',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
