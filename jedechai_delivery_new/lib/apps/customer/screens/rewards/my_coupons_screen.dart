import 'package:flutter/material.dart';
import '../../../../common/models/coupon.dart';
import '../../../../common/services/coupon_service.dart';
import '../../../../theme/app_theme.dart';

class MyCouponsScreen extends StatefulWidget {
  final bool isSelectingMode;
  
  const MyCouponsScreen({Key? key, this.isSelectingMode = false}) : super(key: key);

  @override
  State<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends State<MyCouponsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final CouponService _couponService = CouponService();
  bool _isLoading = false;
  String? _claimingCouponId;
  List<Coupon> _myCoupons = [];
  List<Coupon> _discoverCoupons = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCoupons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _couponService.getMyWalletCoupons(),
        _couponService.getClaimableCoupons(),
      ]);

      if (!mounted) return;
      setState(() {
        _myCoupons = results[0] as List<Coupon>;
        _discoverCoupons = results[1] as List<Coupon>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _claimCoupon(Coupon coupon) async {
    if (_claimingCouponId != null) return;

    setState(() => _claimingCouponId = coupon.id);
    try {
      await _couponService.claimCouponByCode(coupon.code);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เก็บคูปองสำเร็จ!')),
      );
      await _loadCoupons();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() => _claimingCouponId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('คูปองของฉัน'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          tabs: const [
            Tab(text: 'คูปองของฉัน'),
            Tab(text: 'เก็บคูปองเพิ่ม'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCouponsTab(),
          _buildDiscoverCouponsTab(),
        ],
      ),
    );
  }

  Widget _buildMyCouponsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_myCoupons.isEmpty) {
      return const Center(child: Text('ไม่มีคูปองในกระเป๋า'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myCoupons.length,
      itemBuilder: (context, index) {
        final coupon = _myCoupons[index];
        return GestureDetector(
          onTap: widget.isSelectingMode ? () => Navigator.pop(context, coupon) : null,
          child: _buildCouponCard(coupon, isMine: true),
        );
      },
    );
  }

  Widget _buildDiscoverCouponsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discoverCoupons.isEmpty) {
      return const Center(child: Text('ไม่มีคูปองใหม่ให้เก็บในขณะนี้'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _discoverCoupons.length,
      itemBuilder: (context, index) {
        final coupon = _discoverCoupons[index];
        return _buildCouponCard(coupon, isMine: false);
      },
    );
  }

  Widget _buildCouponCard(Coupon coupon, {required bool isMine}) {
    final colorScheme = Theme.of(context).colorScheme;

    final claimedCouponIds = _myCoupons.map((c) => c.id).toSet();
    final alreadyClaimed = claimedCouponIds.contains(coupon.id);

    IconData icon;
    Color iconColor;

    switch (coupon.discountType) {
      case 'free_delivery':
        icon = Icons.local_shipping;
        iconColor = Colors.green;
        break;
      case 'fixed':
        icon = Icons.storefront;
        iconColor = Colors.orange;
        break;
      default:
        icon = Icons.local_offer;
        iconColor = AppTheme.primaryGreen;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coupon.description ?? '-',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หมดอายุ: ${coupon.endDate.toString().split(' ').first}',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isMine)
              ElevatedButton(
                onPressed: (alreadyClaimed || _claimingCouponId == coupon.id)
                    ? null
                    : () => _claimCoupon(coupon),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: alreadyClaimed
                    ? const Text('เก็บแล้ว')
                    : (_claimingCouponId == coupon.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('เก็บ')),
              ),
          ],
        ),
      ),
    );
  }
}
