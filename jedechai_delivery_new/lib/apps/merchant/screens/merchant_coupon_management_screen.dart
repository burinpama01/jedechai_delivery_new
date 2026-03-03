import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/models/coupon.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/coupon_service.dart';
import '../../../common/utils/platform_adaptive.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class MerchantCouponManagementScreen extends StatefulWidget {
  final String? targetMerchantId;
  final bool managedByAdmin;
  final String? merchantDisplayName;

  const MerchantCouponManagementScreen({
    super.key,
    this.targetMerchantId,
    this.managedByAdmin = false,
    this.merchantDisplayName,
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

  Future<void> _openAdminCreateCouponDialog() async {
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
                          AppLocalizations.of(context)!.couponAdminDialogTitle,
                          style: TextStyle(
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
            merchantGpChargeRate: _discountType == 'free_delivery' ? 0.25 : 0,
            merchantGpSystemRate: _discountType == 'free_delivery' ? 0.10 : 0,
            merchantGpDriverRate: _discountType == 'free_delivery' ? 0.15 : 0,
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
            backgroundColor: Colors.green,
          ),
        );
        onSuccess?.call();
        _loadCoupons();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.couponCreateFailed),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.managedByAdmin
              ? (widget.merchantDisplayName != null
                  ? AppLocalizations.of(context)!.couponAdminTitle(widget.merchantDisplayName!)
                  : AppLocalizations.of(context)!.couponAdminTitleNoName)
              : AppLocalizations.of(context)!.couponTitle,
        ),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCoupons,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUsageGuide(),
            const SizedBox(height: 12),
            if (widget.managedByAdmin)
              _buildAdminCreateButton()
            else
              _buildCreateForm(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.couponListTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppTheme.accentOrange,
                  ),
                ),
              )
            else if (_coupons.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
                ),
                child: Text(
                  AppLocalizations.of(context)!.couponEmpty,
                  style: TextStyle(color: colorScheme.onSurface),
                ),
              )
            else
              ..._coupons.map(_buildCouponCard),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageGuide() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final step3 = l10n.couponGuideStep3;
    final step4 = widget.managedByAdmin
        ? l10n.couponGuideStep4Admin
        : l10n.couponGuideStep4Merchant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colorScheme.outline.withOpacity(0.18)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.couponGuideTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.managedByAdmin
                ? AppLocalizations.of(context)!.couponGuideStep1Admin
                : AppLocalizations.of(context)!.couponGuideStep1Merchant,
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.85)),
          ),
          Text(
            widget.managedByAdmin
                ? AppLocalizations.of(context)!.couponGuideStep2Admin
                : AppLocalizations.of(context)!.couponGuideStep2Merchant,
            style: TextStyle(color: colorScheme.onSurface.withOpacity(0.85)),
          ),
          Text(step3, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.85))),
          Text(step4, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.85))),
        ],
      ),
    );
  }

  Widget _buildAdminCreateButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
      ),
      child: OutlinedButton.icon(
        onPressed: _openAdminCreateCouponDialog,
        icon: Icon(
          PlatformAdaptive.icon(
            android: Icons.edit_note,
            ios: CupertinoIcons.pencil,
          ),
        ),
        label: Text(AppLocalizations.of(context)!.couponAdminOpenForm),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accentOrange,
          side: const BorderSide(color: AppTheme.accentOrange),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCreateForm({VoidCallback? onCreated}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
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
                    if (picked != null) setState(() => _startDate = picked);
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
                    if (picked != null) setState(() => _endDate = picked);
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
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
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

  Widget _buildCouponCard(Coupon coupon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.code,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  coupon.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
                Text(
                  coupon.discountText,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: coupon.isActive,
            onChanged: (_) => _toggleCoupon(coupon),
          ),
        ],
      ),
    );
  }
}
