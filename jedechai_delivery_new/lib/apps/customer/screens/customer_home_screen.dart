import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';

import '../../../theme/jdc_colors.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../l10n/app_localizations.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/profile_service.dart';
import '../../../common/services/notification_service.dart';
import '../../../common/models/booking.dart';
import '../../../common/services/supabase_service.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/utils/role_amount_calculator.dart';
import '../../../common/widgets/app_network_image.dart';
import 'ride/ride_home_screen.dart';
import 'services/food_home_screen.dart';
import 'services/laundry_service_screen.dart';
import 'services/parcel_service_screen.dart';
import 'services/customer_order_detail_screen.dart';
import 'services/tracking_screen.dart';
import 'services/saved_addresses_screen.dart';
import 'customer_wallet_screen.dart';
import '../../../common/screens/notification_center_screen.dart';

/// Customer Home Screen
/// 
/// Service selector dashboard for customer app
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with WidgetsBindingObserver {
  final currentUser = AuthService.currentUser;
  final ProfileService _profileService = ProfileService();
  final WalletService _walletService = WalletService();
  Map<String, dynamic>? _userProfile;
  // ignore: unused_field - set during loading but UI checks _userProfile != null instead
  bool _isLoadingProfile = true;
  List<Booking> _activeBookings = [];
  bool _isLoadingBookings = true;
  bool _isLoadingWallet = true;
  double _walletBalance = 0;
  Map<String, Map<String, dynamic>> _couponUsageByBookingId = {};
  StreamSubscription? _bookingsStreamSubscription;
  List<Map<String, dynamic>> _banners = [];
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;

  bool _didCheckReferralRewardDialog = false;

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
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _loadWalletSummary();
    _loadActiveBookings();
    _setupBookingsStream();
    _loadBanners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowReferralRewardDialogIfAny();
    });
  }

  Future<void> _checkAndShowReferralRewardDialogIfAny() async {
    if (!mounted) return;
    if (_didCheckReferralRewardDialog) return;
    _didCheckReferralRewardDialog = true;

    final userId = AuthService.userId;
    if (userId == null) return;

    final unread = await NotificationService.getUnreadByTypes(
      userId,
      const ['referral_reward_referee', 'welcome_coupon_general'],
      limit: 1,
    );
    if (!mounted) return;
    if (unread.isEmpty) return;

    final n = unread.first;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title),
        content: Text(n.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(context)!.customerHomeOk),
          ),
        ],
      ),
    );

    await NotificationService.markAsRead(n.id);
  }

  // Realtime events cover live updates while foregrounded, but the socket can
  // drop while backgrounded — refetch so orders placed/status changes made in
  // between still appear on the home list.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadActiveBookings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bookingsStreamSubscription?.cancel();
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

  Future<void> _loadWalletSummary() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) {
        if (mounted) {
          setState(() => _isLoadingWallet = false);
        }
        return;
      }
      final balance = await _walletService.getBalance(userId);
      if (mounted) {
        setState(() {
          _walletBalance = balance;
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading customer wallet summary: $e');
      if (mounted) {
        setState(() => _isLoadingWallet = false);
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

    _bookingsStreamSubscription = SupabaseService.client
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

  // ─── Wave 1.5 / b1food: new build follows Main artboard ─────────────────────
  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          _buildB1HeroHeader(),
          Expanded(
            child: RefreshIndicator(
              color: jdc.brand,
              onRefresh: _b1RefreshAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildB1WalletCard(),
                    const SizedBox(height: 16),
                    _buildB1ServiceIcons(),
                    if (!_isLoadingBookings && _activeBookings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildB1ActiveTrackCard(_activeBookings.first),
                    ],
                    const SizedBox(height: 22),
                    _buildB1RestaurantSection(),
                    if (_banners.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPromoBanner(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _b1RefreshAll() async {
    await Future.wait([_loadWalletSummary(), _loadActiveBookings(), _loadBanners()]);
  }

  // ── Hero header (full-bleed gradient, no rounded corners at top) ─────────
  Widget _buildB1HeroHeader() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final address = _userProfile?['default_address'] as String? ??
        _userProfile?['address'] as String? ??
        '—';
    return Container(
      decoration: BoxDecoration(
        gradient: jdc.hero,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: jdc.brandHi, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.customerHomeDeliverTo,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.9,
                                    color: jdc.brandHi,
                                  ),
                                ),
                                Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: jdc.onPanel,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, color: jdc.onPanel, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationCenterScreen(role: 'customer')),
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(color: jdc.panelLine),
                        borderRadius: BorderRadius.circular(14),
                        color: jdc.panelSoft2,
                      ),
                      child: Icon(Icons.notifications_none_rounded, color: jdc.onPanel, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: jdc.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: jdc.muted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.customerHomeSearchHint,
                        style: TextStyle(fontSize: 14, color: jdc.dim),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Wallet summary card ───────────────────────────────────────────────────
  Widget _buildB1WalletCard() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerWalletScreen()),
        );
        if (mounted) _loadWalletSummary();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: jdc.surface,
          border: Border.all(color: jdc.line),
          borderRadius: BorderRadius.circular(16),
          boxShadow: jdc.shadowCard,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: jdc.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance_wallet_outlined, color: jdc.brandOnSoft, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JDC Wallet',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: jdc.muted),
                  ),
                  Text(
                    _isLoadingWallet ? '...' : '฿${_walletBalance.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: jdc.text),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 44,
              decoration: BoxDecoration(
                color: jdc.brandSoft2,
                border: Border.all(color: jdc.brandLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  l10n.customerHomeTopUp,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: jdc.link),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4-icon service row ────────────────────────────────────────────────────
  Widget _buildB1ServiceIcons() {
    final l10n = AppLocalizations.of(context)!;
    final jdc = JdcColors.of(context);
    return Row(
      children: [
        _b1ServiceIcon(
          icon: Icons.restaurant_rounded,
          label: l10n.customerHomeServiceFood,
          bgColor: jdc.brandSoft,
          iconColor: jdc.link,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
        ),
        const SizedBox(width: 10),
        _b1ServiceIcon(
          icon: Icons.directions_car_rounded,
          label: l10n.customerHomeCallRide,
          bgColor: jdc.infoSoft,
          iconColor: jdc.infoInk,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RideHomeScreen())),
        ),
        const SizedBox(width: 10),
        _b1ServiceIcon(
          icon: Icons.inventory_2_rounded,
          label: l10n.customerHomeSendParcel,
          bgColor: jdc.successSoft,
          iconColor: jdc.successInk,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ParcelServiceScreen())),
        ),
        const SizedBox(width: 10),
        _b1ServiceIcon(
          icon: Icons.local_laundry_service_rounded,
          label: l10n.customerHomeServiceLaundry,
          bgColor: jdc.sunken,
          iconColor: jdc.text,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LaundryServiceScreen())),
        ),
      ],
    );
  }

  Widget _b1ServiceIcon({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final jdc = JdcColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: jdc.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: jdc.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: jdc.text),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Active order tracking card (dark panel) ───────────────────────────────
  Widget _buildB1ActiveTrackCard(Booking booking) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final trackingStatuses = {
      'driver_assigned', 'driver_accepted', 'arrived_at_merchant',
      'picking_up_order', 'in_transit', 'arrived',
    };
    final isTracking = trackingStatuses.contains(booking.status);
    // ยอดสุทธิที่ลูกค้าต้องจ่าย (หักคูปองแล้ว) — เดิมการ์ดนี้เดาจำนวนรายการจากราคา ซึ่งไม่ใช่ข้อมูลจริง
    final couponDiscount = (_couponUsageByBookingId[booking.id]?['discount_amount'] as num?)?.toDouble() ?? 0;
    final netTotal = RoleAmountCalculator.netDisplayTotalForService(
      serviceType: booking.serviceType,
      price: booking.price,
      deliveryFee: booking.deliveryFee,
      couponDiscountAmount: couponDiscount,
    );
    final orderId = OrderCodeFormatter.formatByServiceType(booking.id, serviceType: booking.serviceType);

    return GestureDetector(
      onTap: () {
        if (isTracking) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackingScreen(booking: booking)));
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerOrderDetailScreen(booking: booking)));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jdc.panel,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: jdc.brandHi, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(booking.status),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jdc.onPanel),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: jdc.panelSoft2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isTracking ? l10n.customerHomeTrack : _getStatusText(booking.status),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: jdc.brandHi),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(4, (i) {
                final filled = i <= _statusProgress(booking.status);
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                    decoration: BoxDecoration(
                      color: filled ? jdc.brand : jdc.panelLine,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '฿${netTotal.ceil()} · #$orderId',
                    style: TextStyle(fontSize: 12, color: jdc.panelDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  l10n.customerHomeTrack,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: jdc.onPanel),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: jdc.onPanel, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _statusProgress(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'searching':
      case 'pending_merchant':
        return 0;
      case 'confirmed':
      case 'accepted':
      case 'matched':
      case 'preparing':
        return 1;
      case 'driver_assigned':
      case 'driver_accepted':
      case 'ready_for_pickup':
      case 'arrived_at_merchant':
      case 'picking_up_order':
        return 2;
      case 'in_transit':
      case 'in_progress':
        return 3;
      default:
        return 0;
    }
  }

  // ── Restaurant recommendations section ────────────────────────────────────
  Widget _buildB1RestaurantSection() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Show limited restaurants from the food home service (reuse existing data if available)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.customerHomeRecommendedNearby,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: jdc.text),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
              child: Text(
                l10n.customerHomeSeeAll,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: jdc.link),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildB1RestaurantCard(
          name: 'ร้านอาหารใกล้คุณ',
          category: 'ตามสั่ง',
          isPlaceholder: true,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoodHomeScreen())),
        ),
      ],
    );
  }

  Widget _buildB1RestaurantCard({
    required String name,
    required String category,
    bool isPlaceholder = false,
    required VoidCallback onTap,
  }) {
    final jdc = JdcColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: jdc.surface,
          border: Border.all(color: jdc.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: jdc.brandSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.restaurant_rounded, color: jdc.brandOnSoft, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jdc.text)),
                  const SizedBox(height: 3),
                  Text(category, style: TextStyle(fontSize: 12, color: jdc.muted)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 13, color: jdc.brandOnSoft),
                      const SizedBox(width: 4),
                      Text('4.5', style: TextStyle(fontSize: 12, color: jdc.brandOnSoft, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Text('15–25 นาที', style: TextStyle(fontSize: 12, color: jdc.muted)),
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

  Widget _buildPromoBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    // Hide banner section entirely if no banners
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.customerHomePromotions,
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
                          ? LinearGradient(
                              colors: [JdcColors.of(context).brand, JdcColors.of(context).danger],
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
                            backgroundColor: JdcColors.of(context).sunken,
                          )
                        : Center(
                            child: Text(
                              b['title'] ?? AppLocalizations.of(context)!.customerHomePromotions,
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
                  color: i == _currentBannerIndex ? JdcColors.of(context).cta : JdcColors.of(context).line,
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
            Icon(Icons.confirmation_number, color: JdcColors.of(context).cta, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(AppLocalizations.of(context)!.customerHomeDiscountCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                color: JdcColors.of(context).cta.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: JdcColors.of(context).cta.withValues(alpha: 0.3), style: BorderStyle.solid),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: JdcColors.of(context).cta,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.customerHomePromoCodeHint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.customerHomeClose),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.customerHomeCopiedCode(code)),
                  backgroundColor: JdcColors.of(context).cta,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(AppLocalizations.of(context)!.customerHomeCopyCode),
            style: ElevatedButton.styleFrom(
              backgroundColor: JdcColors.of(context).cta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'searching':
        return AppLocalizations.of(context)!.customerHomeStatusPending;
      case 'pending_merchant':
        return AppLocalizations.of(context)!.customerHomeStatusPendingMerchant;
      case 'preparing':
        return AppLocalizations.of(context)!.customerHomeStatusPreparing;
      case 'ready_for_pickup':
        return AppLocalizations.of(context)!.customerHomeStatusReadyPickup;
      case 'driver_assigned':
      case 'driver_accepted':
        return AppLocalizations.of(context)!.customerHomeStatusDriverAccepted;
      case 'accepted':
      case 'confirmed':
        return AppLocalizations.of(context)!.customerHomeStatusConfirmed;
      case 'arrived':
        return AppLocalizations.of(context)!.customerHomeStatusArrived;
      case 'arrived_at_merchant':
        return AppLocalizations.of(context)!.customerHomeStatusArrivedMerchant;
      case 'matched':
        return AppLocalizations.of(context)!.customerHomeStatusMatched;
      case 'picking_up_order':
        return AppLocalizations.of(context)!.customerHomeStatusPickingUp;
      case 'in_progress':
      case 'in_transit':
        return AppLocalizations.of(context)!.customerHomeStatusInTransit;
      case 'completed':
        return AppLocalizations.of(context)!.customerHomeStatusCompleted;
      case 'cancelled':
        return AppLocalizations.of(context)!.customerHomeStatusCancelled;
      default:
        return status;
    }
  }

}
