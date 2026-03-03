import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
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
  List<WalletCouponGroup> _myCouponGroups = [];
  List<Coupon> _discoverCoupons = [];
  List<Map<String, dynamic>> _usageHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        _couponService.getMyWalletCouponGroups(),
        _couponService.getClaimableCoupons(),
        _couponService.getMyCouponUsageHistory(),
      ]);

      if (!mounted) return;
      setState(() {
        _myCouponGroups = results[0] as List<WalletCouponGroup>;
        _discoverCoupons = results[1] as List<Coupon>;
        _usageHistory = results[2] as List<Map<String, dynamic>>;
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
        SnackBar(content: Text(AppLocalizations.of(context)!.couponClaimSuccess)),
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
        title: Text(AppLocalizations.of(context)!.couponScreenTitle),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.couponTabMine),
            Tab(text: AppLocalizations.of(context)!.couponTabDiscover),
            Tab(text: AppLocalizations.of(context)!.couponTabHistory),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCouponsTab(),
          _buildDiscoverCouponsTab(),
          _buildUsageHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildMyCouponsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_myCouponGroups.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.couponEmptyWallet));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myCouponGroups.length,
      itemBuilder: (context, index) {
        final group = _myCouponGroups[index];
        final coupon = group.coupon;
        return GestureDetector(
          onTap: widget.isSelectingMode ? () => Navigator.pop(context, coupon) : null,
          child: _buildCouponCard(coupon, isMine: true, quantity: group.quantity),
        );
      },
    );
  }

  Widget _buildDiscoverCouponsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discoverCoupons.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.couponEmptyDiscover));
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

  Widget _buildUsageHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_usageHistory.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.couponEmptyHistory));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _usageHistory.length,
      itemBuilder: (context, index) {
        final item = _usageHistory[index];
        final coupon = item['coupon'];
        final couponName = (coupon is Map && coupon['name'] != null) ? coupon['name'].toString() : '-';
        final couponCode = (coupon is Map && coupon['code'] != null) ? coupon['code'].toString() : '-';
        final discountAmount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
        final createdAt = item['created_at']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: ListTile(
            title: Text(
              couponName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(AppLocalizations.of(context)!.couponHistoryCode(couponCode, createdAt)),
            trailing: Text(
              '-฿${discountAmount.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCouponCard(Coupon coupon, {required bool isMine, int? quantity}) {
    final colorScheme = Theme.of(context).colorScheme;

    final claimedCouponIds = _myCouponGroups.map((g) => g.coupon.id).toSet();
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          coupon.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isMine && quantity != null && quantity > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'x$quantity',
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coupon.description ?? '-',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  if (isMine && quantity != null && quantity > 1) ...[
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)!.couponRemainingUses(quantity.toString()),
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.75),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.couponExpiry(coupon.endDate.toString().split(' ').first),
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
                    ? Text(AppLocalizations.of(context)!.couponClaimed)
                    : (_claimingCouponId == coupon.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(AppLocalizations.of(context)!.couponClaim)),
              ),
          ],
        ),
      ),
    );
  }
}
