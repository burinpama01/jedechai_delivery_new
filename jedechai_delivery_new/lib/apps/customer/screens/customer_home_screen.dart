import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../theme/app_theme.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/profile_service.dart';
import '../../../common/models/booking.dart';
import '../../../common/services/supabase_service.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/widgets/app_network_image.dart';
import 'ride/ride_home_screen.dart';
import 'services/food_home_screen.dart';
import 'services/parcel_service_screen.dart';
import 'services/customer_order_detail_screen.dart';
import 'activity_screen.dart';
import 'services/saved_addresses_screen.dart';

/// Customer Home Screen
/// 
/// Service selector dashboard for customer app
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final currentUser = AuthService.currentUser;
  final ProfileService _profileService = ProfileService();
  Map<String, dynamic>? _userProfile;
  // ignore: unused_field - set during loading but UI checks _userProfile != null instead
  bool _isLoadingProfile = true;
  List<Booking> _activeBookings = [];
  bool _isLoadingBookings = true;
  Map<String, Map<String, dynamic>> _couponUsageByBookingId = {};
  Timer? _autoRefreshTimer;
  List<Map<String, dynamic>> _banners = [];
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  Future<Map<String, Map<String, dynamic>>> _fetchCouponUsageMap(List<String> bookingIds) async {
    if (bookingIds.isEmpty) return {};

    try {
      final usageRows = await SupabaseService.client
          .from('coupon_usages')
          .select('booking_id, coupon_id, discount_amount')
          .inFilter('booking_id', bookingIds);

      if (usageRows.isEmpty) return {};

      final couponIds = <String>{};
      for (final row in usageRows) {
        final couponId = row['coupon_id'] as String?;
        if (couponId != null && couponId.isNotEmpty) {
          couponIds.add(couponId);
        }
      }

      final couponCodeMap = <String, String>{};
      if (couponIds.isNotEmpty) {
        final couponRows = await SupabaseService.client
            .from('coupons')
            .select('id, code')
            .inFilter('id', couponIds.toList());

        for (final row in couponRows) {
          final id = row['id'] as String?;
          final code = row['code'] as String?;
          if (id != null && code != null) {
            couponCodeMap[id] = code;
          }
        }
      }

      final result = <String, Map<String, dynamic>>{};
      for (final row in usageRows) {
        final bookingId = row['booking_id'] as String?;
        if (bookingId == null || bookingId.isEmpty) continue;
        final couponId = row['coupon_id'] as String?;
        result[bookingId] = {
          'discount_amount': row['discount_amount'],
          'coupon_code': couponId != null ? couponCodeMap[couponId] : null,
        };
      }

      return result;
    } catch (e) {
      debugLog('❌ Error loading coupon usage for home active bookings: $e');
      return {};
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadActiveBookings();
    _setupBookingsStream();
    _startAutoRefresh();
    _loadBanners();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadBanners() async {
    try {
      final response = await SupabaseService.client
          .from('banners')
          .select('*')
          .eq('is_active', true)
          .or('page.is.null,page.eq.home')
          .order('sort_order');
      if (mounted) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(response);
        });
        _bannerTimer?.cancel();
        if (_banners.length > 1) {
          _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            if (!mounted || _banners.isEmpty) return;
            final next = (_currentBannerIndex + 1) % _banners.length;
            _bannerController.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
          });
        }
      }
    } catch (e) {
      debugLog('⚠️ Error loading banners: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadActiveBookings() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        setState(() {
          _isLoadingBookings = false;
        });
        return;
      }

      final response = await SupabaseService.client
          .from('bookings')
          .select()
          .eq('customer_id', userId)
          .neq('status', 'completed')
          .neq('status', 'cancelled')
          .order('created_at', ascending: false)
          .limit(5);

      final bookings = (response as List)
          .map((json) => Booking.fromJson(json))
          .toList();
      final couponUsageByBookingId = await _fetchCouponUsageMap(
        bookings.map((b) => b.id).toList(),
      );

      if (mounted) {
        setState(() {
          _activeBookings = bookings;
          _couponUsageByBookingId = couponUsageByBookingId;
          _isLoadingBookings = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading active bookings: $e');
      if (mounted) {
        setState(() {
          _isLoadingBookings = false;
        });
      }
    }
  }

  void _setupBookingsStream() {
    final userId = AuthService.userId;
    if (userId == null) return;

    SupabaseService.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false)
        .listen((data) async {
      final activeBookings = data
          .where((item) {
            final status = item['status'] as String? ?? '';
            return [
              'pending',
              'searching',
              'confirmed',
              'accepted',
              'pending_merchant',
              'preparing',
              'ready_for_pickup',
              'driver_assigned',
              'driver_accepted',
              'matched',
              'arrived_at_merchant',
              'picking_up_order',
              'in_progress',
              'in_transit',
              'arrived',
            ].contains(status);
          })
          .map((json) => Booking.fromJson(json))
          .toList();

      final couponUsageByBookingId = await _fetchCouponUsageMap(
        activeBookings.map((b) => b.id).toList(),
      );

      if (mounted) {
        setState(() {
          _activeBookings = activeBookings;
          _couponUsageByBookingId = couponUsageByBookingId;
        });
      }
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      
      debugLog('🔄 Auto refreshing customer active bookings...');
      
      // Focus only on active bookings - skip cancelled/completed
      await _loadActiveBookings();
      
      debugLog('🔄 Customer bookings refresh completed');
    });
    
    debugLog('✅ Auto refresh started (30 seconds interval - active bookings only)');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = _userProfile?['full_name'] ?? 'Guest';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroHeader(displayName),
              const SizedBox(height: 18),
              _buildActiveOrdersPanel(),
              const SizedBox(height: 22),
              Text(
                'บริการยอดนิยม',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildServiceGrid(context),
              const SizedBox(height: 24),
              _buildQuickActionsStrip(),
              const SizedBox(height: 20),
              _buildPromoBanner(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(String displayName) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF114B5F), Color(0xFF1A936F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF114B5F).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.near_me, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สวัสดี',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ยังไม่มีการแจ้งเตือนใหม่')),
                  );
                },
                icon: const Icon(Icons.notifications, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'อยากให้เราช่วยอะไรวันนี้',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildHeroChip('พร้อมให้บริการ 24/7'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeroChip('ติดตามงานแบบเรียลไทม์'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActiveOrdersPanel() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ออเดอร์ที่ค้างอยู่',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (_isLoadingBookings)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_activeBookings.length} งาน',
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isLoadingBookings && _activeBookings.isNotEmpty) ...[
            ..._activeBookings.take(2).map((booking) => _buildActiveOrderCard(booking)),
          ] else if (!_isLoadingBookings)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'ตอนนี้ยังไม่มีงานค้างอยู่ เริ่มต้นบริการใหม่ได้เลย',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildServiceCard(
                icon: Icons.directions_car,
                title: 'เรียกรถ',
                subtitle: 'รวดเร็ว ปลอดภัย',
                color: AppTheme.accentBlue,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => RideHomeScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceCard(
                icon: Icons.restaurant,
                title: 'สั่งอาหาร',
                subtitle: 'สั่งจากร้านใกล้คุณ',
                color: AppTheme.accentOrange,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FoodHomeScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildServiceCard(
          icon: Icons.local_shipping,
          title: 'ส่งพัสดุ',
          subtitle: 'ส่งของถึงปลายทาง',
          color: AppTheme.primaryGreen,
          isFullWidth: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ParcelServiceScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionsStrip() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ตัวช่วยด่วน',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.history,
                title: 'ประวัติ',
                subtitle: 'การจอง',
                color: Colors.blueGrey,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.favorite,
                title: 'ที่บันทึก',
                subtitle: 'สถานที่',
                color: Colors.red,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.support_agent,
                title: 'ช่วยเหลือ',
                subtitle: 'ติดต่อเรา',
                color: const Color(0xFF6C63FF),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ระบบช่วยเหลือกำลังพัฒนา')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    // Hide banner section entirely if no banners
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'โปรโมชั่น',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentBannerIndex = i),
            itemBuilder: (_, i) {
              final b = _banners[i];
              final imageUrl = b['image_url'] as String?;
              final couponCode = b['coupon_code'] as String?;
              return GestureDetector(
                onTap: couponCode != null && couponCode.isNotEmpty
                    ? () => _showBannerPromoCode(couponCode, b['title'] as String?)
                    : null,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey('banner_$i'),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: imageUrl == null
                          ? const LinearGradient(
                              colors: [Color(0xFFFF9F1C), Color(0xFFFF4E50)],
                            )
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl != null
                        ? AppNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 150,
                            backgroundColor: Colors.grey[200],
                          )
                        : Center(
                            child: Text(
                              b['title'] ?? 'โปรโมชั่น',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _currentBannerIndex ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _currentBannerIndex ? AppTheme.primaryGreen : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ],
    );
  }

  void _showBannerPromoCode(String code, String? title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.confirmation_number, color: AppTheme.primaryGreen, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('โค้ดส่วนลด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('นำโค้ดนี้ไปใช้ตอนสั่งซื้อเพื่อรับส่วนลด', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ปิด'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('คัดลอกโค้ด "$code" แล้ว'),
                  backgroundColor: AppTheme.primaryGreen,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('คัดลอกโค้ด'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isFullWidth ? double.infinity : null,
        height: isFullWidth ? 130 : 130,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 8,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getTotalPrice(Booking booking) {
    final couponDiscount = (_couponUsageByBookingId[booking.id]?['discount_amount'] as num?)?.toDouble() ?? 0.0;

    // For food orders, include delivery fee
    if (booking.serviceType == 'food') {
      final total = booking.price + (booking.deliveryFee ?? 0.0) - couponDiscount;
      return total < 0 ? 0 : total;
    }

    final total = booking.price - couponDiscount;
    return total < 0 ? 0 : total;
  }

  Widget _buildActiveOrderCard(Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        // Navigate to order detail screen for all active orders
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CustomerOrderDetailScreen(booking: booking),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with service type and status
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _getServiceColor(booking.serviceType).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getServiceColor(booking.serviceType),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getServiceIcon(booking.serviceType),
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getServiceTypeText(booking.serviceType),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _getServiceColor(booking.serviceType),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ออเดอร์ ${OrderCodeFormatter.formatByServiceType(booking.id, serviceType: booking.serviceType)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(booking.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(booking.status),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'จุดหมายปลายทาง',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatAddress(booking.destinationAddress),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Pickup location (if available)
                  if (booking.pickupAddress != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.pin_drop,
                            size: 16,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'จุดรับ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatAddress(booking.pickupAddress),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Price and details row
                  Row(
                    children: [
                      // Distance
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${booking.distanceKm.toStringAsFixed(1)} กม.',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '฿${_getTotalPrice(booking).ceil()}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'สั่งเมื่อ: ${_formatDateTime(booking.createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return Icons.directions_car;
      case 'food':
        return Icons.restaurant;
      case 'parcel':
        return Icons.local_shipping;
      default:
        return Icons.receipt;
    }
  }

  String _getServiceTypeText(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return 'เรียกรถ';
      case 'food':
        return 'สั่งอาหาร';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return serviceType;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return AppTheme.accentBlue;
      case 'food':
        return AppTheme.accentOrange;
      case 'parcel':
        return AppTheme.primaryGreen;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'searching':
        return Colors.orange;
      case 'accepted':
      case 'confirmed':
      case 'driver_assigned':
      case 'driver_accepted':
      case 'matched':
        return Colors.blue;
      case 'in_progress':
      case 'in_transit':
      case 'preparing':
      case 'ready_for_pickup':
      case 'arrived_at_merchant':
      case 'picking_up_order':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'searching':
        return 'รอดำเนินการ';
      case 'pending_merchant':
        return 'รอร้านค้ายืนยัน';
      case 'preparing':
        return 'กำลังเตรียมอาหาร';
      case 'ready_for_pickup':
        return 'อาหารพร้อมรับ';
      case 'driver_assigned':
      case 'driver_accepted':
        return 'คนขับรับออเดอร์แล้ว';
      case 'accepted':
      case 'confirmed':
        return 'ยืนยันแล้ว';
      case 'arrived':
        return 'ถึงจุดรับแล้ว';
      case 'arrived_at_merchant':
        return 'คนขับถึงร้านแล้ว';
      case 'matched':
        return 'จับคู่คนขับแล้ว';
      case 'picking_up_order':
        return 'กำลังรับอาหาร';
      case 'in_progress':
      case 'in_transit':
        return 'กำลังจัดส่ง';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  String _formatAddress(dynamic address) {
    if (address == null) {
      return 'ไม่ระบุที่อยู่';
    }
    
    final addressStr = address.toString().trim();
    if (addressStr.isEmpty) return 'ไม่ระบุที่อยู่';
    
    // Clean up coordinate-only patterns like "ตำแหน่ง: 19.16282, 100.84155"
    final coordPattern = RegExp(r'ตำแหน่ง:\s*[\d.]+,\s*[\d.]+');
    if (coordPattern.hasMatch(addressStr)) {
      // Remove the coordinate part, keep the name part if any (e.g. "ดดเ — ตำแหน่ง: ...")
      final cleaned = addressStr.replaceAll(coordPattern, '').replaceAll(RegExp(r'\s*[—\-]\s*$'), '').trim();
      if (cleaned.isNotEmpty) return cleaned;
      return 'ตำแหน่งปัจจุบัน';
    }
    
    // Handle AddressPlacemark object
    if (addressStr.contains('AddressPlacemark')) {
      try {
        if (address is Map) {
          final parts = <String>[];
          if (address['name'] != null && address['name'].toString().isNotEmpty) {
            parts.add(address['name'].toString());
          }
          if (address['street'] != null && address['street'].toString().isNotEmpty) {
            parts.add(address['street'].toString());
          }
          if (address['subLocality'] != null && address['subLocality'].toString().isNotEmpty) {
            parts.add(address['subLocality'].toString());
          }
          if (address['locality'] != null && address['locality'].toString().isNotEmpty) {
            parts.add(address['locality'].toString());
          }
          return parts.isNotEmpty ? parts.join(', ') : 'ไม่ระบุที่อยู่';
        }
      } catch (e) {
        debugLog('❌ Error parsing address: $e');
      }
      if (addressStr != 'Instance of AddressPlacemark') return addressStr;
      return 'ไม่ระบุที่อยู่';
    }
    
    return addressStr;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
