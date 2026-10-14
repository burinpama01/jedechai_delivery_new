import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../apps/customer/screens/customer_wallet_screen.dart';
import '../../apps/customer/screens/rewards/my_coupons_screen.dart';
import '../../apps/customer/screens/rewards/referral_screen.dart';
import '../../apps/customer/screens/services/food_home_screen.dart';
import '../../apps/driver/screens/driver_performance_screen.dart';
import '../../apps/driver/screens/driver_shift_screen.dart';
import '../../apps/driver/screens/driver_wallet_screen.dart';
import '../../apps/driver/screens/wallet_topup_screen.dart';
import '../../apps/merchant/screens/menu_management_screen.dart';
import '../../apps/merchant/screens/merchant_coupon_management_screen.dart';
import '../../apps/merchant/screens/merchant_gp_plan_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/jdc_colors.dart';
import '../../theme/jdc_layout.dart';
import '../services/app_ad_service.dart';
import 'app_network_image.dart';

/// หน้าในแอพที่โฆษณาเปิดได้ (allowlist ต่อฝั่ง)
/// ต้องตรงกับ AD_SCREENS ใน supabase/functions/_shared/banner-ads.ts
final Map<String, Map<String, WidgetBuilder>> _adScreens = {
  'customer': {
    'referral': (_) => const ReferralScreen(),
    'my_coupons': (_) => const MyCouponsScreen(),
    'wallet': (_) => const CustomerWalletScreen(),
    'food': (_) => const FoodHomeScreen(),
  },
  'driver': {
    'referral': (_) => const ReferralScreen(forDriver: true),
    'wallet': (_) => const DriverWalletScreen(),
    'topup': (_) => const WalletTopUpScreen(),
    'shift': (_) => const DriverShiftScreen(),
    'performance': (_) => const DriverPerformanceScreen(),
  },
  'merchant': {
    'gp_plan': (_) => const MerchantGpPlanScreen(),
    'coupons': (_) => const MerchantCouponManagementScreen(),
    'menu': (_) => const MenuManagementScreen(),
  },
};

String _audienceOf(String page) {
  if (page.startsWith('driver_')) return 'driver';
  if (page.startsWith('merchant_')) return 'merchant';
  return 'customer';
}

/// กดโฆษณา: โชว์คูปอง / เปิดลิงก์ / เปิดหน้าในแอพ
Future<void> handleAppAdTap(BuildContext context, AppAd ad) async {
  switch (ad.action) {
    case AppAdAction.none:
      return;
    case AppAdAction.coupon:
      final code = ad.couponCode;
      if (code == null || code.isEmpty) return;
      await _showCouponDialog(context, code, ad.title);
      return;
    case AppAdAction.url:
      if (!isSafeAdUrl(ad.actionValue)) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final failText = AppLocalizations.of(context)!.appAdOpenLinkFailed;
      var ok = false;
      try {
        ok = await launchUrl(Uri.parse(ad.actionValue!.trim()),
            mode: LaunchMode.externalApplication);
      } catch (e) {
        debugLog('⚠️ Error opening ad link: $e');
      }
      if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failText)));
      return;
    case AppAdAction.screen:
      final builder = _adScreens[_audienceOf(ad.page)]?[ad.actionValue];
      if (builder == null) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: builder));
      return;
  }
}

Future<void> _showCouponDialog(
    BuildContext context, String code, String title) {
  final l10n = AppLocalizations.of(context)!;
  final jdc = JdcColors.of(context);
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.confirmation_number, color: jdc.cta, size: 28),
          const SizedBox(width: 8),
          Expanded(
              child: Text(l10n.customerHomeDiscountCode,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(title,
                  style: TextStyle(fontSize: 14, color: jdc.muted)),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: jdc.cta.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: jdc.cta.withValues(alpha: 0.3)),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: jdc.cta,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.customerHomePromoCodeHint,
              style: TextStyle(fontSize: 12, color: jdc.muted)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.customerHomeClose),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.pop(ctx);
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(
                content: Text(l10n.customerHomeCopiedCode(code)),
                backgroundColor: jdc.cta,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          icon: const Icon(Icons.copy, size: 16),
          label: Text(l10n.customerHomeCopyCode),
          style: ElevatedButton.styleFrom(
            backgroundColor: jdc.cta,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    ),
  );
}

/// สไลด์/การ์ดโฆษณาของตำแหน่งหนึ่ง — ไม่มีโฆษณา = ไม่กินที่เลย
///
/// การ์ด (AppAdPlacement.*Card*) ใช้ widget เดียวกัน แค่ความสูงต่ำกว่า
class AppAdCarousel extends StatefulWidget {
  const AppAdCarousel({
    super.key,
    required this.placement,
    this.height = 140,
    this.title,
    this.padding = EdgeInsets.zero,
    this.autoPlay = const Duration(seconds: 5),
  });

  final String placement;
  final double height;

  /// หัวข้อเหนือสไลด์ (null = ไม่มี)
  final String? title;
  final EdgeInsetsGeometry padding;
  final Duration autoPlay;

  @override
  State<AppAdCarousel> createState() => _AppAdCarouselState();
}

class _AppAdCarouselState extends State<AppAdCarousel> {
  final PageController _controller = PageController();
  List<AppAd> _ads = const [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AppAdCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement) _load();
  }

  Future<void> _load() async {
    final ads = await AppAdService.fetch(widget.placement);
    if (!mounted) return;
    setState(() {
      _ads = ads;
      _index = 0;
    });
    if (_controller.hasClients) _controller.jumpToPage(0);
    _timer?.cancel();
    if (ads.length > 1) {
      _timer = Timer.periodic(widget.autoPlay, (_) {
        if (!mounted || _ads.length < 2 || !_controller.hasClients) return;
        _controller.animateToPage((_index + 1) % _ads.length,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) return const SizedBox.shrink();
    final jdc = JdcColors.of(context);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title != null) ...[
            Text(widget.title!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _controller,
              itemCount: _ads.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final ad = _ads[i];
                return Padding(
                  padding: EdgeInsets.only(right: _ads.length > 1 ? 6 : 0),
                  child: Semantics(
                    button: ad.isTappable,
                    label: ad.title,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(JdcRadius.card),
                      child: Material(
                        color: jdc.sunken,
                        child: InkWell(
                          onTap: ad.isTappable
                              ? () => handleAppAdTap(context, ad)
                              : null,
                          child: AppNetworkImage(
                            imageUrl: ad.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: widget.height,
                            backgroundColor: jdc.sunken,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_ads.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _ads.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: i == _index ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index ? jdc.cta : jdc.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ป๊อปอัปโฆษณาตอนเปิดแอพ — เรียกจาก main screen ของแต่ละฝั่งหลังเฟรมแรก
/// แสดงไม่เกิน 1 ตัว/ตำแหน่ง/การเปิดแอพ และเคารพความถี่ที่แอดมินตั้ง
class AppAdPopup {
  AppAdPopup._();

  static final Set<String> _shownThisSession = {};

  static Future<void> maybeShow(BuildContext context, String placement) async {
    if (_shownThisSession.contains(placement)) return;
    _shownThisSession.add(placement);

    final ad = await AppAdService.nextPopup(placement);
    if (ad == null || !context.mounted) return;

    // รอรูปโหลดก่อน จะได้ไม่โชว์กรอบว่าง
    try {
      await precacheImage(NetworkImage(ad.imageUrl), context)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugLog('⚠️ Ad popup image not ready ($placement): $e');
      return;
    }
    if (!context.mounted) return;

    // บันทึกว่าแสดงแล้ว หลัง dialog ถูกเปิดจริง (ไม่ใช่ก่อน) — once จะไม่หายไปเงียบ ๆ
    final dialog = showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AppAdPopupDialog(ad: ad),
    );
    await AppAdService.markPopupShown(ad.id);
    final tapped = await dialog;
    if (tapped == true && context.mounted) {
      await handleAppAdTap(context, ad);
    }
  }
}

/// ครอบ main screen ของแต่ละฝั่ง — เช็กป๊อปอัปโฆษณาหลังเฟรมแรก
class AppAdPopupHost extends StatefulWidget {
  const AppAdPopupHost({
    super.key,
    required this.placement,
    required this.child,
  });

  final String placement;
  final Widget child;

  @override
  State<AppAdPopupHost> createState() => _AppAdPopupHostState();
}

class _AppAdPopupHostState extends State<AppAdPopupHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // หน่วงนิดให้หน้าแรกขึ้นก่อน ไม่เด้งทับ splash/transition
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) AppAdPopup.maybeShow(context, widget.placement);
      });
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppAdPopupDialog extends StatelessWidget {
  const _AppAdPopupDialog({required this.ad});

  final AppAd ad;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final jdc = JdcColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.xxl, vertical: JdcSpacing.xxxl),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(false),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
            const SizedBox(height: JdcSpacing.sm),
            Flexible(
              child: Semantics(
                button: ad.isTappable,
                label: ad.title,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(JdcRadius.sheet),
                  child: Material(
                    color: jdc.sunken,
                    child: InkWell(
                      onTap: ad.isTappable
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      child: Image.network(
                        ad.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
