import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/report_export_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/services/merchant_food_config_service.dart';
import '../../../common/utils/driver_amount_calculator.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import 'order_detail_screen.dart';

/// Merchant Sales Report Screen (JDC design)
///
/// แสดงรายงานและประวัติการขาย พร้อมสรุปยอดขาย — โครงตาม artboard
/// Merchant-Dashboard.dc.html: หัวเข้ม + สถิติ 3 ช่อง, ชิปช่วงเวลา,
/// การ์ดกราฟ 7 วัน, การ์ด GP/ยอดโอน, เมนูขายดี และประวัติออเดอร์
class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  // Date filter
  int _selectedPeriod =
      0; // 0=วันนี้, 1=สัปดาห์นี้, 2=เดือนนี้, 3=ทั้งหมด, 4=ระบุวันที่
  List<String> _periodLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.mchDashPeriodToday,
      l10n.mchDashPeriodWeek,
      l10n.mchDashPeriodMonth,
      l10n.mchDashPeriodAll,
      l10n.mchDashPeriodCustom
    ];
  }

  DateTimeRange? _customDateRange;

  // Stats
  double _totalRevenue = 0;
  double _grossRevenue = 0;
  double _systemGP = 0;
  double _vsLastPeriod = 0;
  int _totalOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;
  double _avgOrderValue = 0;
  double _merchantSystemRate = 0.10;
  double _merchantDriverRate = 0.0;
  double _deliverySystemRate = 0.02;

  // Order history
  List<Map<String, dynamic>> _orderHistory = [];
  List<_DailySalesPoint> _salesChart = [];
  List<_TopItemReport> _topItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // วันนี้
        return DateTime(now.year, now.month, now.day);
      case 1: // สัปดาห์นี้
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case 2: // เดือนนี้
        return DateTime(now.year, now.month, 1);
      case 4: // ระบุวันที่
        return _customDateRange?.start ??
            DateTime(now.year, now.month, now.day);
      default: // ทั้งหมด
        return DateTime(2020, 1, 1);
    }
  }

  DateTime _getEndDate() {
    if (_selectedPeriod == 4 && _customDateRange != null) {
      // สิ้นสุดวันที่เลือก (23:59:59)
      final end = _customDateRange!.end;
      return DateTime(end.year, end.month, end.day, 23, 59, 59);
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _pickCustomDateRange() async {
    final jdc = JdcColors.of(context);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day)
                .subtract(const Duration(days: 7)),
            end: now,
          ),
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final merchantId = AuthService.userId;
      if (merchantId == null) throw Exception('User not found');

      final startStr = _getStartDate().toIso8601String();
      final endStr = _getEndDate().toIso8601String();
      final hasDateFilter = _selectedPeriod != 3;
      final periodStart = _getStartDate();
      final periodEnd = _getEndDate();

      // Fetch completed orders in period
      var completedQuery = Supabase.instance.client
          .from('bookings')
          .select(
              'id, price, delivery_fee, status, created_at, updated_at, notes')
          .eq('merchant_id', merchantId)
          .eq('service_type', 'food')
          .eq('status', 'completed')
          .gte('updated_at', startStr);
      if (hasDateFilter) {
        completedQuery = completedQuery.lte('updated_at', endStr);
      }
      final completedResponse =
          await completedQuery.order('updated_at', ascending: false);

      // Fetch cancelled orders in period
      var cancelledQuery = Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('merchant_id', merchantId)
          .eq('service_type', 'food')
          .eq('status', 'cancelled')
          .gte('updated_at', startStr);
      if (hasDateFilter) {
        cancelledQuery = cancelledQuery.lte('updated_at', endStr);
      }
      final cancelledResponse = await cancelledQuery;

      // Fetch all orders in period for history
      var allQuery = Supabase.instance.client
          .from('bookings')
          .select(
              'id, price, delivery_fee, status, created_at, updated_at, notes, customer_id')
          .eq('merchant_id', merchantId)
          .eq('service_type', 'food')
          .inFilter('status', [
        'completed',
        'cancelled',
        'pending_merchant',
        'preparing',
        'driver_accepted',
        'matched',
        'arrived_at_merchant',
        'ready_for_pickup',
        'picking_up_order',
        'in_transit',
      ]).gte('created_at', startStr);
      if (hasDateFilter) allQuery = allQuery.lte('created_at', endStr);
      final allOrdersResponse =
          await allQuery.order('created_at', ascending: false).limit(50);

      final configService = SystemConfigService();
      await configService.fetchSettings();

      Map<String, dynamic>? merchantProfile;
      try {
        merchantProfile = await Supabase.instance.client
            .from('profiles')
            .select(
              'gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_base_fare, custom_base_distance, custom_per_km, custom_delivery_fee',
            )
            .eq('id', merchantId)
            .maybeSingle();
      } catch (_) {}
      final merchantConfig = MerchantFoodConfigService.resolve(
        merchantProfile: merchantProfile,
        defaultMerchantSystemRate: configService.merchantGpSystemRateDefault,
        defaultMerchantDriverRate: configService.merchantGpDriverRateDefault,
        defaultDeliverySystemRate: configService.platformFeeRate,
      );

      // Calculate stats — แยก gross / GP / net revenue
      double grossRevenue = 0;
      double systemGP = 0;
      double netRevenue = 0;
      final chartBuckets = _buildEmptySalesBuckets();
      for (final order in completedResponse) {
        final foodPrice = (order['price'] as num?)?.toDouble() ?? 0;
        final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
        final settlement = DriverAmountCalculator.foodOrderSettlement(
          foodPrice: foodPrice,
          deliveryFee: deliveryFee,
          deliverySystemRate: merchantConfig.deliverySystemRate,
          merchantGpSystemRate: merchantConfig.merchantGpSystemRate,
          merchantGpDriverRate: merchantConfig.merchantGpDriverRate,
        );
        grossRevenue += foodPrice;
        systemGP += settlement.merchantGP;
        netRevenue += settlement.merchantReceives;
        _addOrderToSalesBuckets(
            chartBuckets, order, settlement.merchantReceives);
      }
      final vsLastPeriod = await _loadRevenueDelta(
        merchantId: merchantId,
        periodStart: periodStart,
        periodEnd: periodEnd,
        hasDateFilter: hasDateFilter,
        config: merchantConfig,
        currentRevenue: netRevenue,
      );
      final topItems = await _loadTopItems(
        merchantId: merchantId,
        start: periodStart,
        end: periodEnd,
        hasDateFilter: hasDateFilter,
      );

      if (mounted) {
        setState(() {
          _totalRevenue = netRevenue;
          _grossRevenue = grossRevenue;
          _systemGP = systemGP;
          _vsLastPeriod = vsLastPeriod;
          _totalOrders = completedResponse.length + cancelledResponse.length;
          _completedOrders = completedResponse.length;
          _cancelledOrders = cancelledResponse.length;
          _avgOrderValue =
              _completedOrders > 0 ? netRevenue / _completedOrders : 0;
          _merchantSystemRate = merchantConfig.merchantGpSystemRate;
          _merchantDriverRate = merchantConfig.merchantGpDriverRate;
          _deliverySystemRate = merchantConfig.deliverySystemRate;
          _orderHistory = List<Map<String, dynamic>>.from(allOrdersResponse);
          _salesChart = chartBuckets;
          _topItems = topItems;
          _isLoading = false;
        });
      }

      debugLog(
          '📊 Sales report loaded: Revenue=$_totalRevenue, Orders=$_completedOrders');
    } catch (e) {
      debugLog('❌ Error loading sales data: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return '฿${NumberFormat('#,##0').format(amount.ceil())}';
  }

  Future<void> _exportCsv() async {
    await ReportExportService().exportMerchantBookingsCSV(
      context,
      startDate: _selectedPeriod == 3 ? null : _getStartDate(),
      endDate: _selectedPeriod == 3 ? null : _getEndDate(),
    );
  }

  List<_DailySalesPoint> _buildEmptySalesBuckets() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - index));
      return _DailySalesPoint(date: date, revenue: 0, orders: 0);
    });
  }

  void _addOrderToSalesBuckets(
    List<_DailySalesPoint> buckets,
    Map<String, dynamic> order,
    double revenue,
  ) {
    final rawDate =
        order['updated_at']?.toString() ?? order['created_at']?.toString();
    if (rawDate == null) return;
    final date = DateTime.tryParse(rawDate)?.toLocal();
    if (date == null) return;
    final day = DateTime(date.year, date.month, date.day);
    final index = buckets.indexWhere((point) => _isSameDay(point.date, day));
    if (index == -1) return;
    buckets[index] = buckets[index].copyWith(
      revenue: buckets[index].revenue + revenue,
      orders: buckets[index].orders + 1,
    );
  }

  Future<double> _loadRevenueDelta({
    required String merchantId,
    required DateTime periodStart,
    required DateTime periodEnd,
    required bool hasDateFilter,
    required MerchantFoodConfig config,
    required double currentRevenue,
  }) async {
    if (!hasDateFilter) return 0;
    final duration = periodEnd.difference(periodStart);
    if (duration.inSeconds <= 0) return 0;
    final previousEnd = periodStart;
    final previousStart = periodStart.subtract(duration);

    var query = Supabase.instance.client
        .from('bookings')
        .select('price, delivery_fee, updated_at')
        .eq('merchant_id', merchantId)
        .eq('service_type', 'food')
        .eq('status', 'completed')
        .gte('updated_at', previousStart.toIso8601String())
        .lte('updated_at', previousEnd.toIso8601String());
    final rows = await query;
    double previousRevenue = 0;
    for (final row in rows) {
      final foodPrice = (row['price'] as num?)?.toDouble() ?? 0;
      final deliveryFee = (row['delivery_fee'] as num?)?.toDouble() ?? 0;
      previousRevenue += DriverAmountCalculator.foodOrderSettlement(
        foodPrice: foodPrice,
        deliveryFee: deliveryFee,
        deliverySystemRate: config.deliverySystemRate,
        merchantGpSystemRate: config.merchantGpSystemRate,
        merchantGpDriverRate: config.merchantGpDriverRate,
      ).merchantReceives;
    }
    if (previousRevenue <= 0) return currentRevenue > 0 ? 100 : 0;
    return ((currentRevenue - previousRevenue) / previousRevenue) * 100;
  }

  Future<List<_TopItemReport>> _loadTopItems({
    required String merchantId,
    required DateTime start,
    required DateTime end,
    required bool hasDateFilter,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_merchant_top_items',
        params: {
          'p_merchant_id': merchantId,
          'p_start_date': hasDateFilter ? start.toIso8601String() : null,
          'p_end_date': hasDateFilter ? end.toIso8601String() : null,
        },
      );
      return (response as List)
          .map((row) => _TopItemReport.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugLog('⚠️ Unable to load merchant top items: $e');
      return const [];
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (_) {
      return '-';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return AppLocalizations.of(context)!.mchDashStatusCompleted;
      case 'cancelled':
        return AppLocalizations.of(context)!.mchDashStatusCancelled;
      case 'preparing':
        return AppLocalizations.of(context)!.mchDashStatusPreparing;
      case 'ready':
        return AppLocalizations.of(context)!.mchDashStatusReady;
      case 'picked_up':
        return AppLocalizations.of(context)!.mchDashStatusPickedUp;
      case 'delivering':
        return AppLocalizations.of(context)!.mchDashStatusDelivering;
      default:
        return status;
    }
  }

  /// สีชิปสถานะตาม token ของ JDC — (พื้น, ตัวอักษร)
  (Color, Color) _statusChipColors(String status, JdcColors jdc) {
    switch (status) {
      case 'completed':
        return (jdc.successSoft, jdc.successInk);
      case 'cancelled':
        return (jdc.dangerSoft, jdc.dangerInk);
      case 'preparing':
        return (jdc.brandSoft, jdc.brandOnSoft);
      case 'ready':
      case 'delivering':
        return (jdc.infoSoft, jdc.infoInk);
      case 'picked_up':
        return (jdc.brandSoft2, jdc.cta);
      default:
        return (jdc.sunken, jdc.muted);
    }
  }

  /// TextStyle พร้อม fontVariations คู่กันตามกฎดีไซน์
  TextStyle _txt(
    Color color,
    double size, {
    double w = 400,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
      fontFeatures: fontFeatures,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        color: jdc.cta,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: JdcContentFrame(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: JdcSpacing.lg,
                                bottom: JdcSpacing.xxl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Period Filter
                                  _buildPeriodFilter(),

                                  // Sales chart card
                                  _buildSalesChart(),

                                  // GP / payout cards
                                  _buildPayoutCards(),

                                  // Best sellers
                                  _buildTopItemsSection(),

                                  // Stats Grid
                                  _buildStatsGrid(),

                                  // Order History
                                  _buildOrderHistorySection(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// ส่วนหัวสีเข้มตาม artboard Merchant-Dashboard —
  /// ไทต์เติล + วันที่ + ไอคอนส่งออก/รีเฟรช + สถิติ 3 ช่องบนพื้น panel
  /// (หน้านี้เป็นแท็บใน shell จึงไม่มีปุ่มย้อนกลับ)
  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat.yMMMd(locale).format(DateTime.now());

    return Container(
      color: jdc.panel,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.mchDashTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _txt(jdc.onPanel, 18, w: 700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _txt(jdc.panelDim, 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.driverEarningsExportCsv,
                    icon: Icon(Icons.download, color: jdc.onPanel),
                    onPressed: _exportCsv,
                  ),
                  IconButton(
                    tooltip: l10n.mchDashRefresh,
                    icon: Icon(Icons.refresh, color: jdc.onPanel),
                    onPressed: _loadData,
                  ),
                ],
              ),
              const SizedBox(height: JdcSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderStatTile(
                      // TODO(l10n): mchDashHeaderSales — "ยอดขาย{period}"
                      'ยอดขาย${_periodLabels(context)[_selectedPeriod]}',
                      _formatCurrency(_grossRevenue),
                    ),
                  ),                  const SizedBox(width: JdcSpacing.sm + 2),
                  Expanded(
                    child: _buildHeaderStatTile(
                      // TODO(l10n): mchDashHeaderOrders — "ออเดอร์"
                      'ออเดอร์',
                      '$_totalOrders',
                    ),
                  ),
                  const SizedBox(width: JdcSpacing.sm + 2),
                  Expanded(
                    child: _buildHeaderStatTile(
                      // TODO(l10n): mchDashHeaderAvgPerBill — "เฉลี่ย/บิล"
                      'เฉลี่ย/บิล',
                      _formatCurrency(_avgOrderValue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStatTile(String label, String value) {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JdcSpacing.md,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: jdc.panelSoft,
        borderRadius: BorderRadius.circular(JdcRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(
              jdc.onPanel,
              18,
              w: 700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(jdc.panelDim, 11),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: jdc.danger),
            const SizedBox(height: JdcSpacing.lg),
            Text(l10n.mchDashLoadError, style: _txt(jdc.text, 16, w: 700)),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              _error ?? '',
              style: _txt(jdc.muted, 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JdcSpacing.xl),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.mchDashRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ชิปช่วงเวลาตาม artboard — ชิปที่เลือกพื้น panel ตัวอักษร onPanel
  Widget _buildPeriodFilter() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final labels = _periodLabels(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(labels.length, (index) {
              final isSelected = _selectedPeriod == index;
              String chipLabel = labels[index];
              if (index == 4 && _customDateRange != null && isSelected) {
                final fmt = DateFormat('d/M/yy');
                chipLabel =
                    '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
              }
              return Padding(
                padding: const EdgeInsets.only(right: JdcSpacing.sm),
                child: Material(
                  color: isSelected ? jdc.panel : jdc.surface,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected ? jdc.panel : jdc.line,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () {
                      if (index == 4) {
                        _pickCustomDateRange();
                      } else {
                        setState(() => _selectedPeriod = index);
                        _loadData();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (index == 4) ...[
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: isSelected ? jdc.onPanel : jdc.muted,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            chipLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _txt(
                              isSelected ? jdc.onPanel : jdc.muted,
                              13,
                              w: isSelected ? 700 : 600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: JdcSpacing.sm + 2),
        Wrap(
          spacing: JdcSpacing.sm,
          runSpacing: JdcSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: _pickCustomDateRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text(l10n.mchDashPickDateRange),
              style: OutlinedButton.styleFrom(
                foregroundColor: jdc.cta,
                side: BorderSide(color: jdc.brandLine),
                minimumSize: const Size(0, JdcTouch.minTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.chip),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: JdcSpacing.md,
                  vertical: 0,
                ),
              ),
            ),
            if (_selectedPeriod == 4 && _customDateRange != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _customDateRange = null;
                    _selectedPeriod = 0;
                  });
                  _loadData();
                },
                icon: const Icon(Icons.clear, size: 18),
                label: Text(l10n.mchDashClearDateFilter),
                style: TextButton.styleFrom(
                  foregroundColor: jdc.dangerInk,
                  minimumSize: const Size(0, JdcTouch.minTarget),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: JdcSpacing.md,
                    vertical: 0,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// การ์ดกราฟยอดขาย 7 วันตาม artboard — หัวการ์ด (ชื่อ+ยอดรวม+ชิปเทียบช่วงก่อน)
  /// ตามด้วยแท่งกราฟบนราง sunken ป้ายวันย่อทุกแท่ง
  Widget _buildSalesChart() {
    final jdc = JdcColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    final maxRevenue = _salesChart.fold<double>(
      0,
      (max, point) => point.revenue > max ? point.revenue : max,
    );
    final weekTotal =
        _salesChart.fold<double>(0, (sum, p) => sum + p.revenue);
    final showDelta = _selectedPeriod != 3;

    return Container(
      margin: const EdgeInsets.only(top: JdcSpacing.lg),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO(l10n): mchDashSalesChartTitle — "ยอดขาย 7 วันล่าสุด"
                    Text('ยอดขาย 7 วันล่าสุด', style: _txt(jdc.muted, 12)),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(weekTotal),
                      style: _txt(
                        jdc.text,
                        24,
                        w: 700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (showDelta) ...[
                const SizedBox(width: JdcSpacing.sm + 2),
                _buildDeltaPill(),
              ],
            ],
          ),
          const SizedBox(height: JdcSpacing.md + 2),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _salesChart.map((point) {
                final ratio =
                    maxRevenue <= 0 ? 0.0 : point.revenue / maxRevenue;
                return Expanded(
                  child: Tooltip(
                    message:
                        '${DateFormat('d/M', locale).format(point.date)}\n${_formatCurrency(point.revenue)} '
                        // TODO(l10n): ใช้ key จำนวนออเดอร์ ({count} ออเดอร์)
                        '(${point.orders} ออเดอร์)',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: JdcSpacing.xs + 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 78,
                            decoration: BoxDecoration(
                              color: jdc.sunken,
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.small),
                            ),
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: ratio.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: point.revenue > 0
                                      ? jdc.brand
                                      : jdc.trackEmpty,
                                  borderRadius:
                                      BorderRadius.circular(JdcRadius.small),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: JdcSpacing.sm - 2),
                          Text(
                            DateFormat('E', locale).format(point.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _txt(jdc.muted, 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// ชิปเทียบยอดกับช่วงก่อนหน้า — เขียวเมื่อเติบโต แดงเมื่อลดลง
  Widget _buildDeltaPill() {
    final jdc = JdcColors.of(context);
    final up = _vsLastPeriod >= 0;
    final fg = up ? jdc.successInk : jdc.dangerInk;
    final bg = up ? jdc.successSoft : jdc.dangerSoft;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JdcSpacing.sm + 2,
        vertical: JdcSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(JdcRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 13, color: fg),
          const SizedBox(width: JdcSpacing.xs + 1),
          Text(
            '${_vsLastPeriod >= 0 ? '+' : ''}${_vsLastPeriod.toStringAsFixed(1)}%',
            style: _txt(fg, 12, w: 700, fontFeatures: [
              FontFeature.tabularFigures(),
            ]),
          ),
        ],
      ),
    );
  }

  /// การ์ดคู่ "หัก GP" กับ "ยอดโอนเข้าร้าน" ตาม artboard
  Widget _buildPayoutCards() {
    final gpPct = ((_merchantSystemRate + _merchantDriverRate) * 100)
        .toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(top: JdcSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            child: _buildPayoutCard(
              // TODO(l10n): mchDashGpDeducted — "หัก GP {rate}%"
              'หัก GP $gpPct%',
              _formatCurrency(_systemGP),
            ),
          ),
          const SizedBox(width: JdcSpacing.sm + 2),
          Expanded(
            child: _buildPayoutCard(
              // TODO(l10n): mchDashPayoutLabel — "ยอดโอนเข้าร้าน"
              'ยอดโอนเข้าร้าน',
              _formatCurrency(_totalRevenue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard(String label, String value) {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JdcSpacing.md + 2,
        vertical: 13,
      ),
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
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(jdc.muted, 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(
              jdc.text,
              17,
              w: 700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItemsSection() {
    final jdc = JdcColors.of(context);
    if (_topItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: JdcSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO(l10n): mchDashTopItemsTitle — "เมนูขายดี"
          Text('เมนูขายดี', style: _txt(jdc.text, 14, w: 700)),
          const SizedBox(height: JdcSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: JdcSpacing.lg,
              vertical: JdcSpacing.md + 2,
            ),
            decoration: BoxDecoration(
              color: jdc.surface,
              borderRadius: BorderRadius.circular(JdcRadius.card),
              border: Border.all(color: jdc.line),
              boxShadow: jdc.shadowCard,
            ),
            child: Column(
              children: [
                for (var i = 0; i < _topItems.take(10).length; i++) ...[
                  if (i > 0) const SizedBox(height: JdcSpacing.md + 2),
                  _buildTopItemRow(_topItems[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopItemRow(_TopItemReport item) {
    final jdc = JdcColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _txt(jdc.text, 14, w: 700),
              ),
              const SizedBox(height: 2),
              Text(
                // TODO(l10n): mchDashOrderCount — "{count} ออเดอร์"
                '${item.orderCount} ออเดอร์',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _txt(jdc.muted, 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: JdcSpacing.md),
        Text(
          _formatCurrency(item.revenue),
          style: _txt(jdc.text, 14, w: 700, fontFeatures: [
            FontFeature.tabularFigures(),
          ]),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: JdcSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
                l10n.mchDashTotalOrders,
                '$_totalOrders',
                Icons.receipt_long,
                jdc.infoInk),
          ),
          const SizedBox(width: JdcSpacing.sm + 2),
          Expanded(
            child: _buildStatCard(
                l10n.mchDashCompleted,
                '$_completedOrders',
                Icons.check_circle,
                jdc.successInk),
          ),
          const SizedBox(width: JdcSpacing.sm + 2),
          Expanded(
            child: _buildStatCard(
                l10n.mchDashCancelled,
                '$_cancelledOrders',
                Icons.cancel,
                jdc.dangerInk),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.md + 2),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: JdcSpacing.sm),
          Text(
            value,
            style: _txt(
              color,
              22,
              w: 700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: JdcSpacing.xs),
          Text(
            title,
            style: _txt(jdc.muted, 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistorySection() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: JdcSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mchDashOrderHistory, style: _txt(jdc.text, 14, w: 700)),
          const SizedBox(height: JdcSpacing.md),
          if (_orderHistory.isEmpty)
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
                    Icons.receipt_long,
                    size: 48,
                    color: jdc.dim,
                  ),
                  const SizedBox(height: JdcSpacing.md),
                  Text(l10n.mchDashNoOrders, style: _txt(jdc.muted, 13)),
                ],
              ),
            )
          else
            ...List.generate(_orderHistory.length, (index) {
              final order = _orderHistory[index];
              return _buildOrderCard(order);
            }),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final status = order['status'] as String? ?? 'unknown';
    final price = (order['price'] as num?)?.toDouble() ?? 0;
    final deliveryFee = (order['delivery_fee'] as num?)?.toDouble() ?? 0;
    final settlement = DriverAmountCalculator.foodOrderSettlement(
      foodPrice: price,
      deliveryFee: deliveryFee,
      deliverySystemRate: _deliverySystemRate,
      merchantGpSystemRate: _merchantSystemRate,
      merchantGpDriverRate: _merchantDriverRate,
    );
    final displayAmount =
        status == 'completed' ? settlement.merchantReceives : price;
    final orderId = OrderCodeFormatter.formatByServiceType(
      order['id']?.toString(),
      serviceType: order['service_type']?.toString(),
    );
    final createdAt = _formatDate(order['created_at']);
    final notes = order['notes'] as String?;
    final (chipBg, chipFg) = _statusChipColors(status, jdc);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MerchantOrderDetailScreen(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(JdcRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: JdcSpacing.md),
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
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: JdcSpacing.sm + 2,
                      vertical: JdcSpacing.xs + 1,
                    ),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(JdcRadius.chip),
                    ),
                    child: Text(
                      _getStatusText(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(chipFg, 11, w: 600),
                    ),
                  ),
                ),
                const SizedBox(width: JdcSpacing.sm + 2),
                Expanded(
                  child: Text(
                    '#$orderId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: _txt(jdc.muted, 12, fontFeatures: [
                      FontFeature.tabularFigures(),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: JdcSpacing.sm + 2),

            // Price and date
            Row(
              children: [
                Flexible(
                  child: Text(
                    _formatCurrency(displayAmount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _txt(
                      jdc.text,
                      18,
                      w: 700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (status == 'completed') ...[
                  const SizedBox(width: JdcSpacing.sm),
                  Flexible(
                    child: Text(
                      l10n.orderDetailCompletionAfterGP(
                        ((_merchantSystemRate + _merchantDriverRate) * 100)
                            .toStringAsFixed(0),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.muted, 11),
                    ),
                  ),
                ],
                const SizedBox(width: JdcSpacing.sm),
                Icon(Icons.access_time, size: 14, color: jdc.muted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    createdAt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _txt(jdc.muted, 12),
                  ),
                ),
              ],
            ),

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: JdcSpacing.sm),
              Row(
                children: [
                  Icon(Icons.note, size: 14, color: jdc.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.muted, 12),
                    ),
                  ),
                ],
              ),
            ],

            // Tap hint
            const SizedBox(height: JdcSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l10n.mchDashViewDetail,
                  style: _txt(jdc.link, 12, w: 500),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 16, color: jdc.link),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailySalesPoint {
  const _DailySalesPoint({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  final DateTime date;
  final double revenue;
  final int orders;

  _DailySalesPoint copyWith({
    double? revenue,
    int? orders,
  }) {
    return _DailySalesPoint(
      date: date,
      revenue: revenue ?? this.revenue,
      orders: orders ?? this.orders,
    );
  }
}

class _TopItemReport {
  const _TopItemReport({
    required this.name,
    required this.orderCount,
    required this.revenue,
  });

  final String name;
  final int orderCount;
  final double revenue;

  factory _TopItemReport.fromJson(Map<String, dynamic> json) {
    return _TopItemReport(
      name: json['name']?.toString() ?? '-',
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}
