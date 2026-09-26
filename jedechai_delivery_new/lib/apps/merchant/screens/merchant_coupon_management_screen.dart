import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import 'package:intl/intl.dart';
import '../../../common/models/coupon.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/coupon_service.dart';
import '../../../common/utils/platform_adaptive.dart';
import '../../../l10n/app_localizations.dart';

class MerchantCouponManagementScreen extends StatefulWidget {
  final String? targetMerchantId;
  final bool managedByAdmin;
  final String? merchantDisplayName;
  /// Fixture สำหรับ dev_preview เท่านั้น — ไม่กระทบ production เพราะ default null
  final List<Coupon>? fixtureCoupons;

  const MerchantCouponManagementScreen({
    super.key,
    this.targetMerchantId,
    this.managedByAdmin = false,
    this.merchantDisplayName,
    this.fixtureCoupons,
  });

  @override
  State<MerchantCouponManagementScreen> createState() =>
      _MerchantCouponManagementScreenState();
}

class _MerchantCouponManagementScreenState
    extends State<MerchantCouponManagementScreen> {
  final CouponService _couponService = CouponService();
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _discountController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _maxDiscountController = TextEditingController();
  final _usageLimitController = TextEditingController(text: '0');
  final _perUserLimitController = TextEditingController(text: '1');

  bool _isCreating = false;
  bool _isLoading = true;
  List<Coupon> _coupons = [];
  String _discountType = 'percentage';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  String _formatDate(DateTime value) {
    return DateFormat('dd/MM/yyyy', 'th_TH').format(value);
  }

  String? get _merchantId => widget.targetMerchantId ?? AuthService.userId;

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _discountController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _usageLimitController.dispose();
    _perUserLimitController.dispose();
    super.dispose();
  }

  Future<void> _loadCoupons() async {
    // Fixture override สำหรับ dev_preview
    if (widget.fixtureCoupons != null) {
      setState(() {
        _coupons = widget.fixtureCoupons!;
        _isLoading = false;
      });
      return;
    }
    final merchantId = _merchantId;
    if (merchantId == null) return;
    setState(() => _isLoading = true);
    final rows = await _couponService.getMerchantCoupons(merchantId);
    if (mounted) {
      setState(() {
        _coupons = rows;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateCouponDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.merchantCouponCreateDialogTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(
                          PlatformAdaptive.icon(
                            android: Icons.close,
                            ios: CupertinoIcons.clear,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: _buildCreateForm(
                      onCreated: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createCoupon({VoidCallback? onSuccess}) async {
    if (!_formKey.currentState!.validate()) return;

    final merchantId = _merchantId;
    if (merchantId == null) return;

    setState(() => _isCreating = true);

    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final description = _descController.text.trim().isEmpty
        ? null
        : _descController.text.trim();
    final discountValue = _discountType == 'free_delivery'
        ? 0.0
        : (double.tryParse(_discountController.text.trim()) ?? 0.0);
    final minOrderAmount = _minOrderController.text.trim().isEmpty
        ? null
        : double.tryParse(_minOrderController.text.trim());
    final maxDiscountAmount = _discountType == 'percentage' &&
            _maxDiscountController.text.trim().isNotEmpty
        ? double.tryParse(_maxDiscountController.text.trim())
        : null;
    final usageLimit = int.tryParse(_usageLimitController.text.trim()) ?? 0;
    final perUserLimit = int.tryParse(_perUserLimitController.text.trim()) ?? 1;

    final coupon = widget.managedByAdmin
        ? await _couponService.createCoupon(
            code: code,
            name: name,
            description: description,
            discountType: _discountType,
            discountValue: discountValue,
            minOrderAmount: minOrderAmount,
            maxDiscountAmount: maxDiscountAmount,
            serviceType: 'food',
            merchantId: merchantId,
            usageLimit: usageLimit,
            perUserLimit: perUserLimit,
            createdByRole: 'admin',
            merchantGpChargeRate: _discountType == 'free_delivery' ? kMerchantGpChargeRate : 0,
            merchantGpSystemRate: _discountType == 'free_delivery' ? kMerchantGpSystemRate : 0,
            merchantGpDriverRate: _discountType == 'free_delivery' ? kMerchantGpDriverRate : 0,
            startDate: _startDate,
            endDate: _endDate,
          )
        : await _couponService.createMerchantCoupon(
            merchantId: merchantId,
            code: code,
            name: name,
            description: description,
            discountType: _discountType,
            discountValue: discountValue,
            minOrderAmount: minOrderAmount,
            maxDiscountAmount: maxDiscountAmount,
            usageLimit: usageLimit,
            perUserLimit: perUserLimit,
            startDate: _startDate,
            endDate: _endDate,
          );

    if (mounted) {
      setState(() => _isCreating = false);
      if (coupon != null) {
        _formKey.currentState?.reset();
        _codeController.clear();
        _nameController.clear();
        _descController.clear();
        _discountController.clear();
        _minOrderController.clear();
        _maxDiscountController.clear();
        _usageLimitController.text = '0';
        _perUserLimitController.text = '1';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couponCreateSuccess),
            backgroundColor: JdcColors.of(context).successFill,
          ),
        );
        onSuccess?.call();
        _loadCoupons();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couponCreateFailed),
            backgroundColor: JdcColors.of(context).danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleCoupon(Coupon coupon) async {
    final ok = await _couponService.toggleCouponActive(
      coupon.id,
      !coupon.isActive,
    );
    if (!mounted) return;
    if (ok) {
      _loadCoupons();
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  TextStyle _txt(Color color, double size, {double w = 400, double? height}) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
    );
  }

  // ─── layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCoupons,
              color: jdc.cta,
              child: _buildBody(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(bottom: BorderSide(color: jdc.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.lg, JdcSpacing.lg, JdcSpacing.lg, JdcSpacing.md),
          child: Row(
            children: [
              // ปุ่มย้อนกลับ 44×44 ตาม artboard
              SizedBox(
                width: JdcTouch.minTarget,
                height: JdcTouch.minTarget,
                child: Material(
                  color: jdc.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                    side: BorderSide(color: jdc.line),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                    child: Icon(Icons.chevron_left, size: 20, color: jdc.text),
                  ),
                ),
              ),
              const SizedBox(width: JdcSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.managedByAdmin
                          ? (widget.merchantDisplayName != null
                              ? l10n.couponAdminTitle(widget.merchantDisplayName!)
                              : l10n.couponAdminTitleNoName)
                          : l10n.merchantCouponTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.text, 17, w: 700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.merchantCouponSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.muted, 12),
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

  Widget _buildBody() {
    final jdc = JdcColors.of(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: jdc.cta));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildInfoBanner(),
        const SizedBox(height: JdcSpacing.md),
        if (_coupons.isEmpty)
          _buildEmpty()
        else
          ..._coupons.map(_buildCouponCard),
      ],
    );
  }

  /// แบนเนอร์ข้อมูลสี teal ตาม artboard
  Widget _buildInfoBanner() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md, vertical: JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.infoSoft,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: jdc.infoInk),
          const SizedBox(width: JdcSpacing.sm),
          Expanded(
            child: Text(
              l10n.merchantCouponInfoNote,
              style: _txt(jdc.infoInk, 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: JdcSpacing.xxxl),
      child: Column(
        children: [
          Icon(Icons.local_offer_outlined, size: 48, color: jdc.dim),
          const SizedBox(height: JdcSpacing.md),
          Text(l10n.couponEmpty, style: _txt(jdc.muted, 14)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(top: BorderSide(color: jdc.line)),
        boxShadow: jdc.shadowSheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.xl),
          child: SizedBox(
            width: double.infinity,
            height: JdcTouch.button,
            child: Material(
              color: jdc.cta,
              borderRadius: BorderRadius.circular(JdcRadius.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(JdcRadius.card),
                onTap: _openCreateCouponDialog,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 19, color: jdc.onCta),
                    const SizedBox(width: JdcSpacing.sm),
                    Text(l10n.merchantCouponCreateBtn,
                        style: _txt(jdc.onCta, 15, w: 700)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── coupon card ─────────────────────────────────────────────────────────────

  /// สร้างข้อความเงื่อนไขย่อ เช่น "ซื้อครบ ฿150 · ใช้ได้ถึง 31 ธ.ค."
  String _buildConditionText(Coupon coupon) {
    final parts = <String>[];
    if ((coupon.minOrderAmount ?? 0) > 0) {
      parts.add(AppLocalizations.of(context)!.merchantCouponMinSpend(coupon.minOrderAmount!.toStringAsFixed(0)));
    }
    if (coupon.endDate != null) {
      parts.add(AppLocalizations.of(context)!.merchantCouponValidUntil(_formatDate(coupon.endDate!)));
    }
    if (parts.isEmpty && coupon.description != null) {
      return coupon.description!;
    }
    return parts.join(' · ');
  }

  Widget _buildCouponCard(Coupon coupon) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    final String statusLabel;
    final Color statusBg;
    final Color statusText;
    if (coupon.isExpired) {
      statusLabel = l10n.merchantCouponExpiredStatus;
      statusBg = jdc.sunken;
      statusText = jdc.muted;
    } else if (coupon.isUsedUp) {
      statusLabel = l10n.merchantCouponUsedUpStatus;
      statusBg = jdc.sunken;
      statusText = jdc.muted;
    } else if (!coupon.isActive) {
      statusLabel = l10n.merchantCouponDisabledStatus;
      statusBg = jdc.sunken;
      statusText = jdc.muted;
    } else {
      statusLabel = l10n.merchantCouponActiveStatus;
      statusBg = jdc.successSoft;
      statusText = jdc.successInk;
    }

    final usageText = coupon.usageLimit == 0
        ? l10n.merchantCouponUnlimitedUsage
        : l10n.merchantCouponUsageCount(
            coupon.usedCount.toString(),
            coupon.usageLimit.toString(),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // แถวบน: icon + ชื่อ/เงื่อนไข + status badge
          Padding(
            padding: const EdgeInsets.fromLTRB(
                JdcSpacing.lg, JdcSpacing.md, JdcSpacing.lg, JdcSpacing.sm),
            child: Row(
              children: [
                // icon กล่อง brand-soft 38×38
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: jdc.brandSoft,
                    borderRadius: BorderRadius.circular(JdcRadius.small),
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    size: 19,
                    color: jdc.brandOnSoft,
                  ),
                ),
                const SizedBox(width: JdcSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _txt(jdc.text, 15, w: 700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _buildConditionText(coupon),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _txt(jdc.muted, 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: JdcSpacing.sm),
                // status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: JdcSpacing.sm + 2, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                  child: Text(statusLabel,
                      style: _txt(statusText, 11, w: 700)),
                ),
              ],
            ),
          ),
          // เส้นแบ่ง
          Divider(height: 1, color: jdc.line),
          // แถวล่าง: usage text + toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(
                JdcSpacing.lg, JdcSpacing.sm, JdcSpacing.md, JdcSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    usageText,
                    style: _txt(jdc.muted, 12),
                  ),
                ),
                // toggle switch — ใช้ Switch เดิม ห้ามแตะ logic
                Switch(
                  value: coupon.isActive,
                  onChanged: (_) => _toggleCoupon(coupon),
                  activeThumbColor: jdc.surface,
                  activeTrackColor: jdc.successFill,
                  inactiveThumbColor: jdc.surface,
                  inactiveTrackColor: jdc.offTrack,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── form (ใช้ใน dialog) ─────────────────────────────────────────────────────

  Widget _buildCreateForm({VoidCallback? onCreated}) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: JdcColors.of(context).surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: JdcColors.of(context).line),
        ),
        child: Column(
          children: [
            TextFormField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.couponCodeLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.couponCodeRequired : null,
            ),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.couponNameLabel),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppLocalizations.of(context)!.couponNameRequired : null,
            ),
            TextFormField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.couponDescLabel,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _discountType,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 'percentage',
                  child: Text(AppLocalizations.of(context)!.couponTypePercentage),
                ),
                DropdownMenuItem(
                  value: 'fixed',
                  child: Text(AppLocalizations.of(context)!.couponTypeFixed),
                ),
                DropdownMenuItem(value: 'free_delivery', child: Text(AppLocalizations.of(context)!.couponTypeFreeDelivery)),
              ],
              onChanged: (v) =>
                  setState(() => _discountType = v ?? 'percentage'),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.couponTypeLabel),
            ),
            if (_discountType != 'free_delivery')
              TextFormField(
                controller: _discountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _discountType == 'percentage'
                      ? AppLocalizations.of(context)!.couponDiscountPercent
                      : AppLocalizations.of(context)!.couponDiscountBaht,
                ),
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  if (value == null || value <= 0) {
                    return AppLocalizations.of(context)!.couponDiscountRequired;
                  }
                  return null;
                },
              ),
            if (_discountType == 'percentage')
              TextFormField(
                controller: _maxDiscountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.couponMaxDiscount,
                ),
              ),
            TextFormField(
              controller: _minOrderController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.couponMinOrder,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _usageLimitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.couponUsageLimit,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _perUserLimitController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: AppLocalizations.of(context)!.couponPerUserLimit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(AppLocalizations.of(context)!.couponStartDate(_formatDate(_startDate)))),
                TextButton(
                  onPressed: () async {
                    final picked = await PlatformAdaptive.pickDate(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('th', 'TH'),
                      title: AppLocalizations.of(context)!.couponPickStartDate,
                    );
                    if (picked != null && mounted) setState(() => _startDate = picked);
                  },
                  child: Text(AppLocalizations.of(context)!.couponPick),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text(AppLocalizations.of(context)!.couponEndDate(_formatDate(_endDate)))),
                TextButton(
                  onPressed: () async {
                    final picked = await PlatformAdaptive.pickDate(
                      context: context,
                      initialDate: _endDate,
                      firstDate: _startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('th', 'TH'),
                      title: AppLocalizations.of(context)!.couponPickEndDate,
                    );
                    if (picked != null && mounted) setState(() => _endDate = picked);
                  },
                  child: Text(AppLocalizations.of(context)!.couponPick),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating
                    ? null
                    : () => _createCoupon(onSuccess: onCreated),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JdcColors.of(context).cta,
                  foregroundColor: JdcColors.of(context).onCta,
                ),
                child: _isCreating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: JdcColors.of(context).onCta,
                        ),
                      )
                    : Text(AppLocalizations.of(context)!.couponCreateBtn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
