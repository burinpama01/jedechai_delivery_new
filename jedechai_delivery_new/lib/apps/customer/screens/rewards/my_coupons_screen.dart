import 'package:flutter/material.dart';

import '../../../../theme/jdc_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/models/coupon.dart';
import '../../../../common/services/coupon_service.dart';

class MyCouponsScreen extends StatefulWidget {
  final bool isSelectingMode;

  const MyCouponsScreen({Key? key, this.isSelectingMode = false})
      : super(key: key);

  @override
  State<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends State<MyCouponsScreen>
    with SingleTickerProviderStateMixin {
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
        _cachedClaimedCouponIds = null;
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
        SnackBar(
            content: Text(AppLocalizations.of(context)!.couponClaimSuccess)),
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
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(l10n.couponScreenTitle),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(color: jdc.text),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: jdc.line)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: jdc.text,
          unselectedLabelColor: jdc.muted,
          indicatorColor: jdc.cta,
          tabs: [
            Tab(text: l10n.couponTabMine),
            Tab(text: l10n.couponTabDiscover),
            Tab(text: l10n.couponTabHistory),
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
      return Center(
          child: Text(AppLocalizations.of(context)!.couponEmptyWallet));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _myCouponGroups.length,
      itemBuilder: (context, index) {
        final group = _myCouponGroups[index];
        final coupon = group.coupon;
        return GestureDetector(
          onTap: widget.isSelectingMode
              ? () => Navigator.pop(context, coupon)
              : null,
          child:
              _buildCouponCard(coupon, isMine: true, quantity: group.quantity),
        );
      },
    );
  }

  Widget _buildDiscoverCouponsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discoverCoupons.isEmpty) {
      return Center(
          child: Text(AppLocalizations.of(context)!.couponEmptyDiscover));
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
      return Center(
          child: Text(AppLocalizations.of(context)!.couponEmptyHistory));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _usageHistory.length,
      itemBuilder: (context, index) {
        final item = _usageHistory[index];
        final coupon = item['coupon'];
        final couponName = (coupon is Map && coupon['name'] != null)
            ? coupon['name'].toString()
            : '-';
        final couponCode = (coupon is Map && coupon['code'] != null)
            ? coupon['code'].toString()
            : '-';
        final discountAmount =
            (item['discount_amount'] as num?)?.toDouble() ?? 0;
        final usedAt = _formatDate(item['created_at']?.toString() ?? '');

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: ListTile(
            title: Text(
              couponName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(AppLocalizations.of(context)!
                .couponHistoryCode(couponCode, usedAt)),
            trailing: Text(
              '-฿${discountAmount.toStringAsFixed(0)}',
              style: TextStyle(
                color: JdcColors.of(context).danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d/$m/${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  Set<String>? _cachedClaimedCouponIds;

  Set<String> get _claimedCouponIds {
    _cachedClaimedCouponIds ??= _myCouponGroups.map((g) => g.coupon.id).toSet();
    return _cachedClaimedCouponIds!;
  }

  Widget _buildCouponCard(Coupon coupon,
      {required bool isMine, int? quantity}) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final alreadyClaimed = _claimedCouponIds.contains(coupon.id);
    final isFreeDelivery = coupon.discountType == 'free_delivery';
    final isFixed = coupon.discountType == 'fixed';
    final value = isFreeDelivery
        ? l10n.couponTypeFreeDelivery
        : isFixed
            ? '฿${coupon.discountValue.toStringAsFixed(0)}'
            : '${coupon.discountValue.toStringAsFixed(0)}%';
    final unit = isFreeDelivery
        ? ''
        : isFixed
            ? l10n.couponTypeFixed
            : l10n.couponTypePercentage;
    final accent = isFreeDelivery
        ? jdc.successInk
        : isFixed
            ? jdc.brandOnSoft
            : jdc.infoInk;
    final accentBg = isFreeDelivery
        ? jdc.successSoft
        : isFixed
            ? jdc.brandSoft
            : jdc.infoSoft;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border.all(color: jdc.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 86,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
              color: accentBg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: accent,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  if (unit.isNotEmpty)
                    Text(unit,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coupon.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: jdc.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (coupon.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(coupon.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: jdc.muted, fontSize: 12)),
                    ],
                    if (isMine && quantity != null && quantity > 1) ...[
                      const SizedBox(height: 6),
                      Text(l10n.couponRemainingUses(quantity.toString()),
                          style: TextStyle(color: jdc.muted, fontSize: 12)),
                    ],
                    if (coupon.endDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                          l10n.couponExpiry(
                              coupon.endDate.toString().split(' ').first),
                          style: TextStyle(color: accent, fontSize: 11)),
                    ],
                    if (!isMine) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed:
                              (alreadyClaimed || _claimingCouponId == coupon.id)
                                  ? null
                                  : () => _claimCoupon(coupon),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: jdc.cta,
                            foregroundColor: jdc.onCta,
                          ),
                          child: alreadyClaimed
                              ? Text(l10n.couponClaimed)
                              : (_claimingCouponId == coupon.id
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: jdc.onCta),
                                    )
                                  : Text(l10n.couponClaim)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
