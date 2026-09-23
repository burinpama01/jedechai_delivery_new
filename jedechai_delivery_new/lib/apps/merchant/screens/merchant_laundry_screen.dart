import 'package:flutter/material.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/services/laundry_service.dart';

class MerchantLaundryScreen extends StatefulWidget {
  const MerchantLaundryScreen({super.key});

  @override
  State<MerchantLaundryScreen> createState() => _MerchantLaundryScreenState();
}

class _MerchantLaundryScreenState extends State<MerchantLaundryScreen> {
  final LaundryService _laundryService = LaundryService();

  bool _isLoading = true;
  int _quoteExpiryMinutes = 60;
  bool _quoteSoundEnabled = true;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _packages = [];
  // filter index: 0=ทั้งหมด, 1=รอเสนอราคา, 2=เสร็จแล้ว
  int _filterIndex = 0;

  @override
  void initState() {
    super.initState();
    // _loadOrders อ่าน context (AppLocalizations) ระหว่างทาง จึงต้องรอเฟรมแรก
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOrders();
    });
  }

  Future<void> _loadOrders({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      // ยิงพร้อมกันแล้วรอด้วย Future.wait — ถ้า await ทีละตัวแล้วตัวแรก throw
      // อีกสองตัวจะกลายเป็น unhandled async error (เจอจริงตอนไม่มี session)
      final results = await Future.wait<dynamic>([
        _laundryService.fetchMerchantLaundryOrders(),
        _laundryService.fetchMyMerchantPackages(),
        _laundryService.fetchMerchantLaundrySettings(),
      ]);
      final orders = results[0] as List<Map<String, dynamic>>;
      final packages = results[1] as List<Map<String, dynamic>>;
      final settings = results[2] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _packages = packages;
        _quoteExpiryMinutes =
            (settings['laundry_quote_expiry_minutes'] as num?)?.toInt() ?? 60;
        _quoteSoundEnabled =
            (settings['laundry_quote_sound_enabled'] as bool?) ?? true;
      });
    } catch (e) {
      _showMessage('โหลดคำขอซักผ้าไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openLaundrySettingsDialog() async {
    final expiryController =
        TextEditingController(text: _quoteExpiryMinutes.toString());
    var soundEnabled = _quoteSoundEnabled;
    var isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('ตั้งค่า quote ซักผ้า'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: expiryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'หมดอายุ default (นาที)',
                      helperText: 'รับได้ 5-1440 นาที',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: soundEnabled,
                    onChanged: (value) {
                      setDialogState(() => soundEnabled = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('เสียงแจ้งเตือนคำขอใหม่'),
                    subtitle: const Text('ใช้กับ notification quote request'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final expiry =
                              int.tryParse(expiryController.text.trim());
                          if (expiry == null || expiry < 5 || expiry > 1440) {
                            _showMessage('กรุณากรอกเวลา 5-1440 นาที');
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            await _laundryService.saveMerchantLaundrySettings(
                              quoteExpiryMinutes: expiry,
                              quoteSoundEnabled: soundEnabled,
                            );
                            if (!mounted) return;
                            setState(() {
                              _quoteExpiryMinutes = expiry;
                              _quoteSoundEnabled = soundEnabled;
                            });
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (e) {
                            _showMessage('บันทึกตั้งค่าไม่สำเร็จ: $e');
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    expiryController.dispose();

    if (saved == true) {
      _showMessage('บันทึกตั้งค่าซักผ้าแล้ว');
    }
  }

  Future<void> _openPackageDialog([Map<String, dynamic>? package]) async {
    final nameController =
        TextEditingController(text: (package?['name'] ?? '') as String);
    final descriptionController =
        TextEditingController(text: (package?['description'] ?? '') as String);
    final priceController = TextEditingController(
      text: package?['base_price'] == null
          ? ''
          : (package!['base_price'] as num).toStringAsFixed(0),
    );
    final sortController = TextEditingController(
      text: ((package?['sort_order'] as num?)?.toInt() ?? 0).toString(),
    );
    var isActive = (package?['is_active'] as bool?) ?? true;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(package == null ? 'เพิ่มแพ็กเกจซักผ้า' : 'แก้แพ็กเกจ'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อแพ็กเกจ',
                        hintText: 'เช่น ซักอบพับ, ซักแห้ง, รีดผ้า',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ราคาเริ่มต้น',
                        prefixText: '฿',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sortController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ลำดับแสดงผล',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                      title: const Text('เปิดให้ลูกค้าเลือก'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text.trim());
                    final sortOrder =
                        int.tryParse(sortController.text.trim()) ?? 0;
                    if (name.isEmpty) {
                      _showMessage('กรุณากรอกชื่อแพ็กเกจ');
                      return;
                    }

                    try {
                      await _laundryService.saveMerchantPackage(
                        packageId: package?['id'] as String?,
                        name: name,
                        description: descriptionController.text,
                        startingPrice: price,
                        sortOrder: sortOrder,
                        isActive: isActive,
                      );
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (e) {
                      _showMessage('บันทึกแพ็กเกจไม่สำเร็จ: $e');
                    }
                  },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    sortController.dispose();

    if (saved == true) {
      _showMessage('บันทึกแพ็กเกจแล้ว');
      await _loadOrders();
    }
  }

  Future<void> _disablePackage(Map<String, dynamic> package) async {
    try {
      await _laundryService.disableMerchantPackage(package['id'] as String);
      _showMessage('ปิดใช้งานแพ็กเกจแล้ว');
      await _loadOrders();
    } catch (e) {
      _showMessage('ปิดใช้งานแพ็กเกจไม่สำเร็จ: $e');
    }
  }

  Future<void> _openQuoteDialog(Map<String, dynamic> order) async {
    final amountController = TextEditingController(
      text: (order['laundry_amount'] as num?)?.toStringAsFixed(0) ?? '',
    );
    final deliveryController = TextEditingController(
      text: (order['delivery_fee_outbound'] as num?)?.toStringAsFixed(0) ?? '0',
    );
    final messageController = TextEditingController(
      text: (order['quote_message'] ?? '') as String,
    );
    final expiryController =
        TextEditingController(text: _quoteExpiryMinutes.toString());

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ส่ง quote ซักผ้า'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ค่าซัก',
                    prefixText: '฿',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deliveryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ค่าส่งขาไป',
                    prefixText: '฿',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expiryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'หมดอายุในกี่นาที',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ข้อความถึงลูกค้า',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                final delivery =
                    double.tryParse(deliveryController.text.trim()) ?? 0;
                final expiry = int.tryParse(expiryController.text.trim());
                if (amount == null || amount <= 0) {
                  _showMessage('กรุณากรอกค่าซักให้ถูกต้อง');
                  return;
                }

                try {
                  final result = await _laundryService.sendMerchantQuote(
                    laundryOrderId: order['id'] as String,
                    laundryAmount: amount,
                    deliveryFeeOutbound: delivery,
                    quoteExpiresMinutes: expiry,
                    quoteMessage: messageController.text.trim().isEmpty
                        ? null
                        : messageController.text.trim(),
                  );

                  if (result['success'] == true) {
                    if (context.mounted) Navigator.of(context).pop(true);
                  } else {
                    _showMessage(
                        'ส่ง quote ไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
                  }
                } catch (e) {
                  _showMessage('ส่ง quote ไม่สำเร็จ: $e');
                }
              },
              child: const Text('ส่ง quote'),
            ),
          ],
        );
      },
    );

    amountController.dispose();
    deliveryController.dispose();
    messageController.dispose();
    expiryController.dispose();

    if (sent == true) {
      _showMessage('ส่ง quote แล้ว');
      await _loadOrders();
    }
  }

  Future<void> _openReturnBookingDialog(Map<String, dynamic> order) async {
    // self_pickup orders have no return driver leg; the RPC only flips the
    // order to ready_for_return, so skip the delivery fee dialog entirely.
    if ((order['return_mode'] as String?) == 'self_pickup') {
      try {
        final result = await _laundryService.createReturnBooking(
          laundryOrderId: order['id'] as String,
        );
        if (result['success'] == true) {
          _showMessage('บันทึกซักเสร็จแล้ว รอลูกค้ามารับผ้า');
          await _loadOrders();
        } else {
          _showMessage(
              'บันทึกซักเสร็จไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
        }
      } catch (e) {
        _showMessage('บันทึกซักเสร็จไม่สำเร็จ: $e');
      }
      return;
    }

    final deliveryController = TextEditingController(
      text: (order['delivery_fee_return'] as num?)?.toStringAsFixed(0) ?? '0',
    );
    var paymentMethod = (order['return_payment_method'] as String?) ?? 'cash';

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('สร้าง booking ขากลับ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: deliveryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ค่าส่งขากลับ',
                      prefixText: '฿',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'วิธีชำระค่าส่งขากลับ',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('เงินสด')),
                      DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => paymentMethod = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: () async {
                    final delivery =
                        double.tryParse(deliveryController.text.trim()) ?? 0;
                    try {
                      final result = await _laundryService.createReturnBooking(
                        laundryOrderId: order['id'] as String,
                        deliveryFeeReturn: delivery,
                        returnPaymentMethod: paymentMethod,
                      );
                      if (result['success'] == true) {
                        if (context.mounted) Navigator.of(context).pop(true);
                      } else {
                        _showMessage(
                            'สร้าง booking ขากลับไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
                      }
                    } catch (e) {
                      _showMessage('สร้าง booking ขากลับไม่สำเร็จ: $e');
                    }
                  },
                  child: const Text('สร้างงานขากลับ'),
                ),
              ],
            );
          },
        );
      },
    );

    deliveryController.dispose();

    if (created == true) {
      _showMessage('สร้าง booking ขากลับแล้ว');
      await _loadOrders();
    }
  }

  Future<void> _completeSelfPickup(Map<String, dynamic> order) async {
    try {
      final result = await _laundryService.updateMerchantLaundryStatus(
        laundryOrderId: order['id'] as String,
        status: 'completed',
      );
      if (result['success'] == true) {
        _showMessage('ปิดงานซักผ้าแล้ว');
        await _loadOrders();
      } else {
        _showMessage('ปิดงานไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
      }
    } catch (e) {
      _showMessage('ปิดงานไม่สำเร็จ: $e');
    }
  }

  Future<void> _startWashing(Map<String, dynamic> order) async {
    try {
      final result = await _laundryService.updateMerchantLaundryStatus(
        laundryOrderId: order['id'] as String,
        status: 'washing',
      );
      if (result['success'] == true) {
        _showMessage('เริ่มซักแล้ว');
        await _loadOrders();
      } else {
        _showMessage('เริ่มซักไม่สำเร็จ: ${result['error'] ?? 'unknown'}');
      }
    } catch (e) {
      _showMessage('เริ่มซักไม่สำเร็จ: $e');
    }
  }

  Future<void> _openQuoteChat(Map<String, dynamic> order) async {
    final orderId = order['id'] as String?;
    if (orderId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _QuoteChatSheet(
        laundryService: _laundryService,
        laundryOrderId: orderId,
        title: 'Chat คำขอ #${orderId.substring(0, 8)}',
        hintText: 'พิมพ์ข้อความถึงลูกค้า',
      ),
    );
    if (mounted) await _loadOrders();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── computed stats ──────────────────────────────────────────────────────────

  int get _pendingCount => _orders
      .where((o) =>
          !const {'completed', 'cancelled'}.contains(o['status'] as String?))
      .length;

  int get _quoteCount => _orders
      .where((o) => (o['status'] as String?) == 'quote_requested')
      .length;

  List<Map<String, dynamic>> get _filteredOrders {
    if (_filterIndex == 1) {
      return _orders
          .where((o) => (o['status'] as String?) == 'quote_requested')
          .toList();
    }
    if (_filterIndex == 2) {
      return _orders
          .where((o) =>
              const {'completed', 'cancelled'}
                  .contains(o['status'] as String?))
          .toList();
    }
    return _orders;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasQuoteExpiry = _quoteCount > 0;

    return Scaffold(
      body: Column(
        children: [
          // ── Panel header (dark green) ────────────────────────────────────
          Container(
            color: jdc.panel,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + JdcSpacing.sm,
              left: JdcSpacing.xl,
              right: JdcSpacing.xl,
              bottom: JdcSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: JdcSpacing.md),
                          decoration: BoxDecoration(
                            color: jdc.panelSoft2,
                            borderRadius: BorderRadius.circular(JdcRadius.small),
                            border: Border.all(color: jdc.panelLine),
                          ),
                          child: Icon(Icons.chevron_left,
                              color: jdc.onPanel, size: 24),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.merchantLaundryTitle,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: jdc.onPanel,
                                  fontFamily: 'IBMPlexSansThai')),
                          if (_packages.isNotEmpty)
                            Text(
                              _packages
                                  .map((p) => p['name'] ?? '')
                                  .take(2)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: jdc.panelDim),
                            ),
                        ],
                      ),
                    ),
                    // settings access
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.merchantLaundrySettingsTooltip,
                      onPressed: _openLaundrySettingsDialog,
                      icon: Icon(Icons.tune_rounded, color: jdc.onPanel),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.merchantLaundryAddPackageTooltip,
                      onPressed: () => _openPackageDialog(),
                      icon: Icon(Icons.add_rounded, color: jdc.onPanel),
                    ),
                  ],
                ),
                const SizedBox(height: JdcSpacing.lg),
                // stats row
                Row(
                  children: [
                    _StatChip(
                      value: '$_pendingCount',
                      label: l10n.merchantLaundryStatPending,
                      jdc: jdc,
                    ),
                    const SizedBox(width: JdcSpacing.md),
                    _StatChip(
                      value: '$_quoteCount',
                      label: l10n.merchantLaundryStatQuoteWaiting,
                      jdc: jdc,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          if (_isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadOrders(showLoading: false),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.xl),
                  children: [
                    // filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label:
                                '${l10n.merchantLaundryFilterAll} ${_orders.length}',
                            selected: _filterIndex == 0,
                            onTap: () => setState(() => _filterIndex = 0),
                            jdc: jdc,
                          ),
                          const SizedBox(width: JdcSpacing.sm),
                          _FilterChip(
                            label:
                                '${l10n.merchantLaundryFilterQuote} $_quoteCount',
                            selected: _filterIndex == 1,
                            onTap: () => setState(() => _filterIndex = 1),
                            jdc: jdc,
                          ),
                          const SizedBox(width: JdcSpacing.sm),
                          _FilterChip(
                            label: l10n.merchantLaundryFilterDone,
                            selected: _filterIndex == 2,
                            onTap: () => setState(() => _filterIndex = 2),
                            jdc: jdc,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: JdcSpacing.md),

                    // quote expiry banner
                    if (hasQuoteExpiry) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: JdcSpacing.lg,
                            vertical: JdcSpacing.md),
                        decoration: BoxDecoration(
                          color: jdc.brandSoft,
                          borderRadius:
                              BorderRadius.circular(JdcRadius.card),
                          border: Border.all(color: jdc.brandLine),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.access_time_outlined,
                                color: jdc.brandOnSoft, size: 18),
                            const SizedBox(width: JdcSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.merchantLaundryQuoteExpiryBanner(
                                    _quoteExpiryMinutes ~/ 60 > 0
                                        ? _quoteExpiryMinutes ~/ 60
                                        : 1),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: jdc.brandOnSoft,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: JdcSpacing.md),
                    ],

                    // order cards
                    if (_filteredOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(JdcSpacing.xxl),
                        alignment: Alignment.center,
                        child: Text(l10n.merchantLaundryEmptyOrders,
                            style: TextStyle(color: jdc.muted)),
                      )
                    else
                      for (final order in _filteredOrders) ...[
                        _LaundryOrderCard(
                          order: order,
                          onQuote: () => _openQuoteDialog(order),
                          onChat: () => _openQuoteChat(order),
                          onStartWashing: () => _startWashing(order),
                          onCreateReturn: () =>
                              _openReturnBookingDialog(order),
                          onCompleteSelfPickup: () =>
                              _completeSelfPickup(order),
                        ),
                        const SizedBox(height: JdcSpacing.md),
                      ],

                    // packages manager + settings (accessible below orders)
                    const SizedBox(height: JdcSpacing.xl),
                    _LaundrySettingsCard(
                      expiryMinutes: _quoteExpiryMinutes,
                      soundEnabled: _quoteSoundEnabled,
                      onEdit: _openLaundrySettingsDialog,
                    ),
                    const SizedBox(height: JdcSpacing.md),
                    _LaundryPackageManagerCard(
                      packages: _packages,
                      onAdd: () => _openPackageDialog(),
                      onEdit: _openPackageDialog,
                      onDisable: _disablePackage,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Private helper widgets ─────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    required this.jdc,
  });
  final String value;
  final String label;
  final JdcColors jdc;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: JdcSpacing.md, vertical: 11),
        decoration: BoxDecoration(
          color: jdc.panelSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: jdc.onPanel,
                    fontFamily: 'IBMPlexSansThai')),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: jdc.panelDim)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.jdc,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final JdcColors jdc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: JdcSpacing.lg, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? jdc.panel : jdc.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: jdc.line),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? jdc.onPanel : jdc.muted),
        ),
      ),
    );
  }
}

// ── Laundry Settings Card ───────────────────────────────────────────────────────

class _LaundrySettingsCard extends StatelessWidget {
  const _LaundrySettingsCard({
    required this.expiryMinutes,
    required this.soundEnabled,
    required this.onEdit,
  });

  final int expiryMinutes;
  final bool soundEnabled;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, color: JdcColors.of(context).cta),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ตั้งค่า quote ซักผ้า',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'หมดอายุ $expiryMinutes นาที · เสียงแจ้งเตือน ${soundEnabled ? 'เปิด' : 'ปิด'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'แก้ตั้งค่า',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteChatSheet extends StatefulWidget {
  const _QuoteChatSheet({
    required this.laundryService,
    required this.laundryOrderId,
    required this.title,
    required this.hintText,
  });

  final LaundryService laundryService;
  final String laundryOrderId;
  final String title;
  final String hintText;

  @override
  State<_QuoteChatSheet> createState() => _QuoteChatSheetState();
}

class _QuoteChatSheetState extends State<_QuoteChatSheet> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final rows =
          await widget.laundryService.fetchQuoteMessages(widget.laundryOrderId);
      if (!mounted) return;
      setState(() {
        _messages = rows;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final result = await widget.laundryService.sendQuoteMessage(
        laundryOrderId: widget.laundryOrderId,
        body: body,
      );
      if (result['success'] == true) {
        _messageController.clear();
        await _loadMessages();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? const Center(child: Text('ยังไม่มีข้อความ'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final role =
                                  (message['sender_role'] as String?) ?? '-';
                              final body = (message['body'] as String?) ?? '';
                              return ListTile(
                                dense: true,
                                title: Text(body),
                                subtitle: Text(role),
                                leading: Icon(
                                  role == 'customer'
                                      ? Icons.person_rounded
                                      : Icons.storefront_rounded,
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
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
}

class _LaundryPackageManagerCard extends StatelessWidget {
  const _LaundryPackageManagerCard({
    required this.packages,
    required this.onAdd,
    required this.onEdit,
    required this.onDisable,
  });

  final List<Map<String, dynamic>> packages;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDisable;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_rounded,
                    color: JdcColors.of(context).cta),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'แพ็กเกจซักผ้า',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)!.merchantLaundryAddPackageTooltip,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'แพ็กเกจเป็นแม่แบบให้ลูกค้าเลือกก่อนส่งคำขอประเมินราคา ยังไม่ใช่ราคาจองทันที',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (packages.isEmpty)
              const Text('ยังไม่มีแพ็กเกจ')
            else
              for (final package in packages) ...[
                _LaundryPackageRow(
                  package: package,
                  onEdit: () => onEdit(package),
                  onDisable: () => onDisable(package),
                ),
                const Divider(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class _LaundryPackageRow extends StatelessWidget {
  const _LaundryPackageRow({
    required this.package,
    required this.onEdit,
    required this.onDisable,
  });

  final Map<String, dynamic> package;
  final VoidCallback onEdit;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final name = (package['name'] ?? 'แพ็กเกจ') as String;
    final price = (package['base_price'] as num?)?.toDouble();
    final isActive = (package['is_active'] as bool?) ?? true;
    final description = (package['description'] ?? '') as String;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
          color: isActive ? JdcColors.of(context).successInk : JdcColors.of(context).muted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (price != null) Text('เริ่ม ฿${price.toStringAsFixed(0)}'),
              if (description.isNotEmpty)
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              if (!isActive)
                Text('ปิดใช้งาน',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: JdcColors.of(context).muted)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'แก้แพ็กเกจ',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
        ),
        IconButton(
          tooltip: 'ปิดใช้งาน',
          onPressed: isActive ? onDisable : null,
          icon: const Icon(Icons.visibility_off_rounded),
        ),
      ],
    );
  }
}

class _LaundryOrderCard extends StatelessWidget {
  const _LaundryOrderCard({
    required this.order,
    required this.onQuote,
    required this.onChat,
    required this.onStartWashing,
    required this.onCreateReturn,
    required this.onCompleteSelfPickup,
  });

  final Map<String, dynamic> order;
  final VoidCallback onQuote;
  final VoidCallback onChat;
  final VoidCallback onStartWashing;
  final VoidCallback onCreateReturn;
  final VoidCallback onCompleteSelfPickup;

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] ?? '-') as String;
    final customer = order['customer'] is Map
        ? Map<String, dynamic>.from(order['customer'] as Map)
        : <String, dynamic>{};
    final customerName = (customer['full_name'] ??
        customer['phone_number'] ??
        'ลูกค้า') as String;
    final canQuote = status == 'quote_requested' ||
        status == 'quoted' ||
        status == 'quote_expired';
    final returnMode = (order['return_mode'] as String?) ?? 'delivery';
    final canStartWashing = status == 'at_merchant';
    final selfPickupReady =
        returnMode == 'self_pickup' && status == 'ready_for_return';
    final canCreateReturn = order['return_booking_id'] == null &&
        !selfPickupReady &&
        const {
          'washing',
          'ready_for_return',
        }.contains(status);
    final laundryAmount = (order['laundry_amount'] as num?)?.toDouble();
    final deliveryFee =
        (order['delivery_fee_outbound'] as num?)?.toDouble() ?? 0;
    final returnFee = (order['delivery_fee_return'] as num?)?.toDouble() ?? 0;
    final attachmentSignedUrls = order['_attachment_signed_urls'] is List
        ? (order['_attachment_signed_urls'] as List)
            .whereType<String>()
            .toList()
        : const <String>[];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_laundry_service_rounded,
                    color: JdcColors.of(context).cta),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        'สถานะ: $status · #${order['id'].toString().substring(0, 8)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('ที่อยู่รับผ้า: ${order['pickup_address'] ?? '-'}'),
            if (order['customer_note'] != null) ...[
              const SizedBox(height: 6),
              Text('หมายเหตุ: ${order['customer_note']}'),
            ],
            const SizedBox(height: 12),
            Text(
              laundryAmount == null
                  ? 'ยังไม่ได้ส่งราคา'
                  : 'ค่าซัก ฿${laundryAmount.toStringAsFixed(0)} · ค่าส่งขาไป ฿${deliveryFee.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (returnFee > 0) ...[
              const SizedBox(height: 6),
              Text('ค่าส่งขากลับ ฿${returnFee.toStringAsFixed(0)}'),
            ],
            if (attachmentSignedUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'รูปแนบจากลูกค้า',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: attachmentSignedUrls
                    .map(
                      (url) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canQuote ? onQuote : null,
                icon: const Icon(Icons.request_quote_rounded),
                label: Text(switch (status) {
                  'quoted' => 'แก้ quote',
                  'quote_expired' => 'ส่ง quote ใหม่',
                  _ => 'ส่ง quote',
                }),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat กับลูกค้า'),
              ),
            ),
            if (!canQuote) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canStartWashing ? onStartWashing : null,
                  icon: const Icon(Icons.local_laundry_service_rounded),
                  label: const Text('เริ่มซัก'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: canCreateReturn ? onCreateReturn : null,
                  icon: const Icon(Icons.assignment_return_rounded),
                  label: Text(_returnButtonLabel(
                    returnMode: returnMode,
                    status: status,
                    hasReturnBooking: order['return_booking_id'] != null,
                  )),
                ),
              ),
              if (selfPickupReady) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onCompleteSelfPickup,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('ลูกค้ารับผ้าแล้ว / ปิดงาน'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _returnButtonLabel({
    required String returnMode,
    required String status,
    required bool hasReturnBooking,
  }) {
    if (hasReturnBooking) return 'สร้างงานขากลับแล้ว';
    if (returnMode == 'self_pickup' && status == 'ready_for_return') {
      return 'รอลูกค้ามารับ';
    }
    if (returnMode == 'self_pickup') return 'ซักเสร็จ / รอลูกค้ามารับ';
    return 'ซักเสร็จ / สร้างงานขากลับ';
  }
}
