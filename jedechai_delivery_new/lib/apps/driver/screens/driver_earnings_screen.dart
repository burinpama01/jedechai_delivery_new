import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/jdc_layout.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import 'driver_wallet_screen.dart';
import 'driver_job_detail_screen.dart';
import '../../../common/models/booking.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/services/merchant_food_config_service.dart';
import '../../../common/utils/driver_amount_calculator.dart';
import '../../../common/utils/order_code_formatter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Driver Earnings Screen
///
/// แสดงรายได้และประวัติงาน พร้อมสรุปยอด (รูปแบบเดียวกับหน้ารายงานร้านค้า)
class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _isLoading = true;
  String? _error;

  // Date filter
  int _selectedPeriod = 0; // 0=วันนี้, 1=สัปดาห์นี้, 2=เดือนนี้, 3=ทั้งหมด, 4=ระบุวันที่
  List<String> _getPeriodLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [l10n.earnPeriodToday, l10n.earnPeriodWeek, l10n.earnPeriodMonth, l10n.earnPeriodAll, l10n.earnPeriodCustom];
  }
  DateTimeRange? _customDateRange;

  // Service type filter
  String? _selectedServiceType; // null = ทั้งหมด

  // Weekly chart data
  Map<String, double> _weeklyEarnings = {};

  // Stats
  double _totalEarnings = 0;
  int _totalJobs = 0;
  int _completedJobs = 0;
  int _cancelledJobs = 0;
  double _avgEarnings = 0;

  // Job history
  List<Map<String, dynamic>> _jobHistory = [];
  Map<String, double> _couponDiscountByBookingId = {};
  Map<String, Map<String, dynamic>> _merchantProfilesById = {};
  double _defaultMerchantSystemRate = 0.10;
  double _defaultMerchantDriverRate = 0.0;
  double _defaultDeliverySystemRate = 0.15;
  double _standardCommissionRate = 15.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// fontVariations คู่กับ fontWeight ตามกฎธีม (NotoSansThai เป็น variable font)
  static List<FontVariation> _w(FontWeight weight) => [
        FontVariation(
          'wght',
          weight == FontWeight.w700
              ? 700
              : weight == FontWeight.w600
                  ? 600
                  : weight == FontWeight.w500
                      ? 500
                      : 400,
        ),
      ];

  /// ตัวเลขเงินสไตล์ display ตาม artboard (`.dsp` = IBM Plex Sans Thai)
  TextStyle _money({double size = 14, Color? color}) {
    final jdc = context.jdc;
    return TextStyle(
      fontFamily: 'IBMPlexSansThai',
      fontSize: size,
      fontWeight: FontWeight.w700,
      fontVariations: _w(FontWeight.w700),
      color: color ?? jdc.text,
    );
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: return DateTime(now.year, now.month, now.day);
      case 1: return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      case 2: return DateTime(now.year, now.month, 1);
      case 4: return _customDateRange?.start ?? DateTime(now.year, now.month, now.day);
      default: return DateTime(2020, 1, 1);
    }
  }

  DateTime _getEndDate() {
    if (_selectedPeriod == 4 && _customDateRange != null) {
      final end = _customDateRange!.end;
      return DateTime(end.year, end.month, end.day, 23, 59, 59);
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: now,
      ),
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
        final jdc = context.jdc;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: jdc.cta,
              onPrimary: jdc.onCta,
              surface: jdc.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 4;
      });
      _loadData();
    }
  }

  Future<Map<String, double>> _loadWeeklyEarnings() async {
    final userId = AuthService.userId;
    if (userId == null) return {};

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final response = await Supabase.instance.client
        .from('bookings')
        .select('updated_at, driver_earnings, service_type, merchant_id, price, delivery_fee')
        .eq('driver_id', userId)
        .eq('status', 'completed')
        .gte('updated_at', sevenDaysAgo.toIso8601String());

    final Map<String, double> byDay = {};
    for (final row in response) {
      final updatedAt = row['updated_at'] as String?;
      if (updatedAt == null) continue;
      final date = DateTime.parse(updatedAt).toLocal();
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final earnings = (row['driver_earnings'] as num?)?.toDouble() ?? 0;
      byDay[key] = (byDay[key] ?? 0) + earnings;
    }
    return byDay;
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('User not found');

      final startStr = _getStartDate().toIso8601String();
      final endStr = _getEndDate().toIso8601String();
      final hasEndFilter = _selectedPeriod == 4 && _customDateRange != null;

      // Fetch completed bookings in period
      var completedQuery = Supabase.instance.client
          .from('bookings')
          .select('*')
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .gte('updated_at', startStr);
      if (hasEndFilter) completedQuery = completedQuery.lte('updated_at', endStr);
      if (_selectedServiceType != null) completedQuery = completedQuery.eq('service_type', _selectedServiceType!);
      final completedResponse = await completedQuery.order('updated_at', ascending: false);

      // Fetch cancelled bookings in period
      var cancelledQuery = Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('driver_id', userId)
          .eq('status', 'cancelled')
          .gte('updated_at', startStr);
      if (hasEndFilter) cancelledQuery = cancelledQuery.lte('updated_at', endStr);
      if (_selectedServiceType != null) cancelledQuery = cancelledQuery.eq('service_type', _selectedServiceType!);
      final cancelledResponse = await cancelledQuery;

      // Fetch all jobs in period for history
      var allQuery = Supabase.instance.client
          .from('bookings')
          .select('*')
          .eq('driver_id', userId)
          .inFilter('status', [
            'completed',
            'cancelled',
            'accepted',
            'driver_accepted',
            'matched',
            'arrived',
            'arrived_at_merchant',
            'ready_for_pickup',
            'picking_up_order',
            'in_transit',
          ])
          .gte('created_at', startStr);
      if (hasEndFilter) allQuery = allQuery.lte('created_at', endStr);
      if (_selectedServiceType != null) allQuery = allQuery.eq('service_type', _selectedServiceType!);
      final allJobsResponse = await allQuery.order('created_at', ascending: false).limit(50);

      final bookingIds = allJobsResponse
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      Map<String, double> couponDiscountMap = {};
      if (bookingIds.isNotEmpty) {
        try {
          final usages = await Supabase.instance.client
              .from('coupon_usages')
              .select('booking_id, discount_amount')
              .inFilter('booking_id', bookingIds);

          for (final usage in (usages as List)) {
            final bookingId = usage['booking_id']?.toString();
            if (bookingId == null || bookingId.isEmpty) continue;

            final discount = (usage['discount_amount'] as num?)?.toDouble() ?? 0.0;
            couponDiscountMap[bookingId] = discount;
          }
        } catch (e) {
          debugLog('⚠️ Error loading coupon usages for driver earnings screen: $e');
        }
      }

      final configService = SystemConfigService();
      await configService.fetchSettings();
      double? driverDeliverySystemRateOverride;
      try {
        final driverProfile = await Supabase.instance.client
            .from('profiles')
            .select('driver_delivery_system_rate')
            .eq('id', userId)
            .maybeSingle();
        final raw = driverProfile?['driver_delivery_system_rate'];
        if (raw != null) {
          final rate = (raw as num).toDouble();
          if (rate >= 0 && rate <= 1) driverDeliverySystemRateOverride = rate;
        }
      } catch (e) {
        debugLog('⚠️ Error loading driver delivery fee override: $e');
      }
      final foodMerchantIds = <String>{
        ...completedResponse
            .where((job) => job['service_type'] == 'food')
            .map((job) => job['merchant_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty),
        ...allJobsResponse
            .where((job) => job['service_type'] == 'food')
            .map((job) => job['merchant_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      }.toList();

      final merchantProfiles = <String, Map<String, dynamic>>{};
      if (foodMerchantIds.isNotEmpty) {
        try {
          final profiles = await Supabase.instance.client
              .from('profiles')
              .select(
                'id, gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_base_fare, custom_base_distance, custom_per_km, custom_delivery_fee',
              )
              .inFilter('id', foodMerchantIds);
          for (final profile in (profiles as List)) {
            final id = profile['id']?.toString();
            if (id != null && id.isNotEmpty) {
              merchantProfiles[id] = Map<String, dynamic>.from(profile);
            }
          }
        } catch (e) {
          debugLog('⚠️ Error loading merchant finance profiles: $e');
        }
      }

      // Calculate stats
      double totalEarn = 0;
      for (final job in completedResponse) {
        totalEarn += _driverEarningsForJob(
          job,
          merchantProfiles: merchantProfiles,
          defaultMerchantSystemRate: configService.merchantGpSystemRateDefault,
          defaultMerchantDriverRate: configService.merchantGpDriverRateDefault,
          defaultDeliverySystemRate:
              driverDeliverySystemRateOverride ?? configService.platformFeeRate,
          standardCommissionRate: configService.commissionRate,
        );
      }

      final weeklyData = await _loadWeeklyEarnings();

      if (mounted) {
        setState(() {
          _totalEarnings = totalEarn;
          _totalJobs = completedResponse.length + cancelledResponse.length;
          _completedJobs = completedResponse.length;
          _cancelledJobs = cancelledResponse.length;
          _avgEarnings = _completedJobs > 0 ? totalEarn / _completedJobs : 0;
          _jobHistory = List<Map<String, dynamic>>.from(allJobsResponse);
          _couponDiscountByBookingId = couponDiscountMap;
          _merchantProfilesById = merchantProfiles;
          _defaultMerchantSystemRate = configService.merchantGpSystemRateDefault;
          _defaultMerchantDriverRate = configService.merchantGpDriverRateDefault;
          _defaultDeliverySystemRate =
              driverDeliverySystemRateOverride ?? configService.platformFeeRate;
          _standardCommissionRate = configService.commissionRate;
          _weeklyEarnings = weeklyData;
          _isLoading = false;
        });
      }

      debugLog('📊 Earnings loaded: Total=$_totalEarnings, Jobs=$_completedJobs');
    } catch (e) {
      debugLog('❌ Error loading earnings: $e');
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  double _driverEarningsForJob(
    Map<String, dynamic> job, {
    required Map<String, Map<String, dynamic>> merchantProfiles,
    required double defaultMerchantSystemRate,
    required double defaultMerchantDriverRate,
    required double defaultDeliverySystemRate,
    required double standardCommissionRate,
  }) {
    final saved = (job['driver_earnings'] as num?)?.toDouble();
    final serviceType = job['service_type']?.toString() ?? '';

    if (serviceType == 'food') {
      final merchantId = job['merchant_id']?.toString();
      final config = MerchantFoodConfigService.resolve(
        merchantProfile: merchantId == null ? null : merchantProfiles[merchantId],
        defaultMerchantSystemRate: defaultMerchantSystemRate,
        defaultMerchantDriverRate: defaultMerchantDriverRate,
        defaultDeliverySystemRate: defaultDeliverySystemRate,
      );
      final settlement = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: (job['price'] as num?)?.toDouble() ?? 0,
        deliveryFee: (job['delivery_fee'] as num?)?.toDouble() ?? 0,
        deliverySystemRate: config.deliverySystemRate,
        merchantGpSystemRate: config.merchantGpSystemRate,
        merchantGpDriverRate: config.merchantGpDriverRate,
      );
      return DriverAmountCalculator.shouldUseFoodSettlementFallback(
        savedAmount: saved,
        fallbackAmount: settlement.driverNetIncome,
      )
          ? settlement.driverNetIncome
          : (saved ?? 0);
    }

    final price = (job['price'] as num?)?.toDouble() ?? 0;
    final fallback = (price - (price * (standardCommissionRate / 100)).ceilToDouble())
        .clamp(0.0, double.infinity)
        .toDouble();
    if (saved == null || (saved <= 0 && fallback > 0)) return fallback;
    return saved;
  }

  double _appEarningsForJob(Map<String, dynamic> job) {
    final saved = (job['app_earnings'] as num?)?.toDouble();
    final serviceType = job['service_type']?.toString() ?? '';

    if (serviceType == 'food') {
      final merchantId = job['merchant_id']?.toString();
      final config = MerchantFoodConfigService.resolve(
        merchantProfile:
            merchantId == null ? null : _merchantProfilesById[merchantId],
        defaultMerchantSystemRate: _defaultMerchantSystemRate,
        defaultMerchantDriverRate: _defaultMerchantDriverRate,
        defaultDeliverySystemRate: _defaultDeliverySystemRate,
      );
      final settlement = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: (job['price'] as num?)?.toDouble() ?? 0,
        deliveryFee: (job['delivery_fee'] as num?)?.toDouble() ?? 0,
        deliverySystemRate: config.deliverySystemRate,
        merchantGpSystemRate: config.merchantGpSystemRate,
        merchantGpDriverRate: config.merchantGpDriverRate,
      );
      return DriverAmountCalculator.shouldUseFoodSettlementFallback(
        savedAmount: saved,
        fallbackAmount: settlement.appEarnings,
      )
          ? settlement.appEarnings
          : (saved ?? 0);
    }

    final price = (job['price'] as num?)?.toDouble() ?? 0;
    final fallback = (price * (_standardCommissionRate / 100)).ceilToDouble();
    if (saved == null || (saved <= 0 && fallback > 0)) return fallback;
    return saved;
  }

  String _formatCurrency(double amount) {
    return AppLocalizations.of(context)!
        .driverEarningsBaht(NumberFormat('#,##0.00').format(amount));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (_) { return '-'; }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed': return AppLocalizations.of(context)!.earnStatusCompleted;
      case 'cancelled': return AppLocalizations.of(context)!.earnStatusCancelled;
      case 'picked_up': return AppLocalizations.of(context)!.earnStatusPickedUp;
      case 'delivering': return AppLocalizations.of(context)!.earnStatusDelivering;
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    final jdc = context.jdc;
    switch (status) {
      case 'completed': return jdc.successInk;
      case 'cancelled': return jdc.dangerInk;
      case 'picked_up': return jdc.infoInk;
      case 'delivering': return jdc.infoInk;
      default: return jdc.muted;
    }
  }

  String _getServiceIcon(String serviceType) {
    switch (serviceType) {
      case 'ride': return '🚗';
      case 'food': return '🍔';
      case 'parcel': return '📦';
      default: return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = context.jdc;
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.earnTitle,
            style: TextStyle(
              fontFamily: 'IBMPlexSansThai',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontVariations: _w(FontWeight.w700),
              color: jdc.text,
            )),
        backgroundColor: jdc.surface,
        foregroundColor: jdc.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: jdc.line)),
        iconTheme: IconThemeData(color: jdc.text),
        actionsIconTheme: IconThemeData(color: jdc.text),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletScreen())),
            tooltip: AppLocalizations.of(context)!.earnWalletTooltip,
          ),
          IconButton(icon: const Icon(Icons.download), onPressed: _exportCsv, tooltip: AppLocalizations.of(context)!.driverEarningsExportCsv),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: AppLocalizations.of(context)!.earnRefresh),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: jdc.cta,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodFilter(),
                        _buildServiceTypeFilter(),
                        _buildRevenueSummary(),
                        _buildWeeklyChart(),
                        _buildStatsGrid(),
                        const SizedBox(height: 8),
                        _buildWalletCard(),
                        _buildJobHistorySection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    final jdc = context.jdc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: jdc.danger),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.earnLoadError,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontVariations: _w(FontWeight.w700),
                    color: jdc.text)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style: TextStyle(color: jdc.muted, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.earnRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Period Filter (same as merchant)
  // ============================================================

  Widget _buildPeriodFilter() {
    final jdc = context.jdc;
    return Container(
      color: jdc.sunken,
      padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.lg, vertical: JdcSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_getPeriodLabels(context).length, (index) {
            final isSelected = _selectedPeriod == index;
            String chipLabel = _getPeriodLabels(context)[index];
            if (index == 4 && _customDateRange != null && isSelected) {
              final fmt = DateFormat('d/M/yy');
              chipLabel = '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 4) ...[
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(chipLabel),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    if (index == 4) {
                      _pickCustomDateRange();
                    } else {
                      setState(() => _selectedPeriod = index);
                      _loadData();
                    }
                  }
                },
                selectedColor: jdc.cta,
                labelStyle: TextStyle(
                  color: isSelected ? jdc.onCta : jdc.text,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontVariations: _w(isSelected ? FontWeight.w600 : FontWeight.w400),
                ),
                backgroundColor: jdc.surface,
                side: BorderSide(color: isSelected ? jdc.cta : jdc.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.chip)),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================
  // Revenue Summary (same style as merchant)
  // ============================================================

  Widget _buildRevenueSummary() {
    final jdc = context.jdc;
    return Container(
      margin: EdgeInsets.fromLTRB(context.gutter, JdcSpacing.lg, context.gutter, 0),
      padding: const EdgeInsets.all(JdcSpacing.xl),
      decoration: BoxDecoration(
        gradient: jdc.hero2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: jdc.onPanel, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.earnRevenueLabel(_getPeriodLabels(context)[_selectedPeriod]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: jdc.panelDim, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(_totalEarnings),
            style: _money(size: 32, color: jdc.onPanel),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.earnAvgPerJob(_formatCurrency(_avgEarnings)),
            style: TextStyle(color: jdc.panelDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Stats Grid (same style as merchant)
  // ============================================================

  Widget _buildStatsGrid() {
    final jdc = context.jdc;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.gutter),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(AppLocalizations.of(context)!.earnTotalJobs, '$_totalJobs', Icons.work, jdc.infoInk)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard(AppLocalizations.of(context)!.earnCompleted, '$_completedJobs', Icons.check_circle, jdc.successInk)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard(AppLocalizations.of(context)!.earnCancelled, '$_cancelledJobs', Icons.cancel, jdc.dangerInk)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final jdc = context.jdc;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: _money(size: 22, color: color)),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: jdc.muted),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Wallet Card (compact)
  // ============================================================

  Widget _buildWalletCard() {
    final jdc = context.jdc;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.gutter, vertical: 8),
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: jdc.brandSoft,
              borderRadius: BorderRadius.circular(JdcRadius.small),
            ),
            child: Icon(Icons.account_balance_wallet, color: jdc.brandOnSoft, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.earnWalletTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontVariations: _w(FontWeight.w600),
                    color: jdc.muted,
                  ),
                ),
                const SizedBox(height: 2),
                FutureBuilder<double>(
                  // session อาจหมดอายุหลังหน้าโหลดเสร็จ ถ้า force-unwrap จะ crash กลางหน้า
                  future: WalletService().getBalance(AuthService.userId ?? ''),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text(
                        AppLocalizations.of(context)!.earnWalletLoading,
                        style: TextStyle(
                          fontSize: 12,
                          color: jdc.muted,
                        ),
                      );
                    }
                    final balance = snapshot.data ?? 0.0;
                    return Text(
                      AppLocalizations.of(context)!.earnWalletBaht(balance.toStringAsFixed(2)),
                      style: _money(
                          size: 20,
                          color: balance >= 50 ? jdc.successInk : jdc.brandOnSoft),
                    );
                  },
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletScreen())),
            child: Text(AppLocalizations.of(context)!.earnViewAll,
                style: TextStyle(
                    color: jdc.link,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontVariations: _w(FontWeight.w600))),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Job History (same style as merchant order history)
  // ============================================================

  Widget _buildJobHistorySection() {
    final jdc = context.jdc;
    return Padding(
      padding: EdgeInsets.all(context.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.earnJobHistory,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontVariations: _w(FontWeight.w700),
              color: jdc.text,
            ),
          ),
          const SizedBox(height: 12),
          if (_jobHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(JdcSpacing.xxxl),
              decoration: BoxDecoration(
                color: jdc.surface,
                borderRadius: BorderRadius.circular(JdcRadius.card),
                border: Border.all(color: jdc.line),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 48,
                    color: jdc.muted.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)!.earnNoJobs,
                    style: TextStyle(color: jdc.muted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_jobHistory.length, (index) => _buildJobCard(_jobHistory[index])),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final jdc = context.jdc;
    final status = job['status'] as String? ?? 'unknown';
    final driverEarnings = status == 'completed'
        ? _driverEarningsForJob(
            job,
            merchantProfiles: _merchantProfilesById,
            defaultMerchantSystemRate: _defaultMerchantSystemRate,
            defaultMerchantDriverRate: _defaultMerchantDriverRate,
            defaultDeliverySystemRate: _defaultDeliverySystemRate,
            standardCommissionRate: _standardCommissionRate,
          )
        : 0.0;
    final appEarnings = status == 'completed' ? _appEarningsForJob(job) : 0.0;
    // final price = (job['price'] as num?)?.toDouble() ?? 0;
    // final deliveryFee = (job['delivery_fee'] as num?)?.toDouble() ?? 0;
    final serviceType = job['service_type'] as String? ?? 'unknown';
    final jobId = OrderCodeFormatter.formatByServiceType(
      job['id']?.toString(),
      serviceType: serviceType,
    );
    final createdAt = _formatDate(job['created_at']);
    final bookingId = job['id']?.toString();
    final couponDiscount = bookingId == null ? 0.0 : (_couponDiscountByBookingId[bookingId] ?? 0.0);

    Booking? booking;
    double netCollect = 0.0;
    try {
      booking = Booking.fromJson(job);
      netCollect = DriverAmountCalculator.netCollect(
        booking: booking,
        couponDiscountAmount: couponDiscount,
      );
    } catch (_) {
      booking = null;
      netCollect = 0.0;
    }

    final statusColor = _getStatusColor(status);

    return GestureDetector(
      onTap: () => _showJobDetail(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(JdcSpacing.lg),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(color: jdc.line),
          boxShadow: jdc.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(JdcRadius.small),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontVariations: _w(FontWeight.w600),
                        color: statusColor),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_getServiceIcon(serviceType)} ${serviceType == 'ride' ? AppLocalizations.of(context)!.earnSvcRide : serviceType == 'food' ? AppLocalizations.of(context)!.earnSvcFood : serviceType == 'parcel' ? AppLocalizations.of(context)!.earnSvcParcel : AppLocalizations.of(context)!.earnSvcOther}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: jdc.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  jobId,
                  style: TextStyle(
                    fontSize: 12,
                    color: jdc.muted,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Earnings and date
            Row(
              children: [
                Flexible(
                  child: Text(
                    _formatCurrency(driverEarnings),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _money(size: 18, color: jdc.cta),
                  ),
                ),
                if (appEarnings > 0) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                        AppLocalizations.of(context)!.earnAppFee(_formatCurrency(appEarnings)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: jdc.dangerInk)),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(Icons.access_time, size: 14, color: jdc.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    createdAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: jdc.muted),
                  ),
                ),
              ],
            ),

            // Route info
            if (job['pickup_address'] != null || job['destination_address'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: jdc.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${job['pickup_address'] ?? '?'} → ${job['destination_address'] ?? '?'}',
                      style: TextStyle(fontSize: 12, color: jdc.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (booking != null && status == 'completed') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: jdc.sunken,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(AppLocalizations.of(context)!.earnCollectCustomer,
                            style: TextStyle(fontSize: 12, color: jdc.muted)),
                        Text(
                          _formatCurrency(netCollect),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontVariations: _w(FontWeight.w700),
                              color: jdc.text),
                        ),
                      ],
                    ),
                    if (couponDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalizations.of(context)!.earnCouponDiscount,
                              style: TextStyle(fontSize: 12, color: jdc.muted)),
                          Text(
                            '-${_formatCurrency(couponDiscount)}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontVariations: _w(FontWeight.w600),
                                color: jdc.successInk),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showJobDetail(Map<String, dynamic> job) {
    try {
      final booking = Booking.fromJson(job);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverJobDetailScreen(booking: booking),
        ),
      );
    } catch (e) {
      debugLog('❌ Error opening job detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.earnOpenDetailError)),
      );
    }
  }

  // ============================================================
  // Service Type Filter
  // ============================================================

  Widget _buildServiceTypeFilter() {
    final jdc = context.jdc;
    final l10n = AppLocalizations.of(context)!;
    final types = <String?>[null, 'food', 'ride', 'parcel'];
    final labels = [
      l10n.activityFilterAll,
      l10n.driverEarningsFilterFood,
      l10n.driverEarningsFilterRide,
      l10n.driverEarningsFilterParcel,
    ];
    return Container(
      color: jdc.sunken,
      padding: const EdgeInsets.fromLTRB(JdcSpacing.lg, 0, JdcSpacing.lg, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(types.length, (i) {
            final isSelected = _selectedServiceType == types[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedServiceType = types[i]);
                  _loadData();
                },
                selectedColor: jdc.cta,
                labelStyle: TextStyle(
                  color: isSelected ? jdc.onCta : jdc.text,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontVariations: _w(isSelected ? FontWeight.w600 : FontWeight.w400),
                  fontSize: 13,
                ),
                backgroundColor: jdc.surface,
                side: BorderSide(color: isSelected ? jdc.cta : jdc.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JdcRadius.chip)),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================
  // Weekly Bar Chart
  // ============================================================

  Widget _buildWeeklyChart() {
    final jdc = context.jdc;
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)),
    );
    final dayLabels = [
      l10n.driverEarningsWeekdayMon,
      l10n.driverEarningsWeekdayTue,
      l10n.driverEarningsWeekdayWed,
      l10n.driverEarningsWeekdayThu,
      l10n.driverEarningsWeekdayFri,
      l10n.driverEarningsWeekdaySat,
      l10n.driverEarningsWeekdaySun,
    ];

    final values = days.map((d) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return _weeklyEarnings[key] ?? 0.0;
    }).toList();

    final maxVal = values.fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      margin: EdgeInsets.fromLTRB(context.gutter, JdcSpacing.md, context.gutter, 0),
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.driverEarningsWeeklyChartTitle,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontVariations: _w(FontWeight.w600),
                color: jdc.text),
          ),
          const SizedBox(height: 12),
          // สูง 132 พอสำหรับ label บน (~13) + gap 2 + แท่งสูงสุด 88 + gap 4 +
          // label วัน (~15) — เดิม 120 ทำให้ล้น 5px เมื่อมีข้อมูลจริง
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final val = values[i];
                final barHeight = maxVal > 0 ? (val / maxVal * 88).clamp(4.0, 88.0) : 4.0;
                final isToday = days[i].day == now.day && days[i].month == now.month;
                final dayOfWeek = days[i].weekday - 1;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (val > 0)
                        Text(
                          val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.toInt().toString(),
                          style: TextStyle(fontSize: 9, color: jdc.muted),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isToday ? jdc.brand : jdc.trackEmpty,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayLabels[dayOfWeek],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                          fontVariations: _w(isToday ? FontWeight.w700 : FontWeight.w400),
                          color: isToday ? jdc.cta : jdc.muted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Export CSV
  // ============================================================

  Future<void> _exportCsv() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final buf = StringBuffer();
      buf.writeln(l10n.driverEarningsCsvHeader);
      for (final job in _jobHistory) {
        final status = job['status']?.toString() ?? '';
        final serviceType = job['service_type']?.toString() ?? '';
        final createdAt = _formatDate(job['created_at']);
        final jobId = OrderCodeFormatter.formatByServiceType(
          job['id']?.toString(),
          serviceType: serviceType,
        );
        final driverEarnings = status == 'completed'
            ? _driverEarningsForJob(
                job,
                merchantProfiles: _merchantProfilesById,
                defaultMerchantSystemRate: _defaultMerchantSystemRate,
                defaultMerchantDriverRate: _defaultMerchantDriverRate,
                defaultDeliverySystemRate: _defaultDeliverySystemRate,
                standardCommissionRate: _standardCommissionRate,
              )
            : 0.0;
        final appEarnings = status == 'completed' ? _appEarningsForJob(job) : 0.0;
        buf.writeln('$createdAt,$serviceType,$status,$jobId,${driverEarnings.toStringAsFixed(2)},${appEarnings.toStringAsFixed(2)}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/driver_earnings_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString(), flush: true);
      await Share.shareXFiles([XFile(file.path)], subject: l10n.driverEarningsCsvShareSubject);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.driverEarningsExportError(e.toString()))),
        );
      }
    }
  }

}
