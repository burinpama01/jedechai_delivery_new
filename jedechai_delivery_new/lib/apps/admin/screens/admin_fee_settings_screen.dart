import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/debug_logger.dart';

/// Admin Fee Settings Screen
/// 
/// จัดการการตั้งค่าค่าธรรมเนียมสำหรับ Food Delivery:
/// - Platform Fee (% ของค่าส่ง)
/// - Merchant GP (% ของราคาอาหาร)
/// - Driver Minimum Wallet (ยอดเงินขั้นต่ำ)
/// - Standard Commission (% สำหรับ Ride/Parcel)
class AdminFeeSettingsScreen extends StatefulWidget {
  const AdminFeeSettingsScreen({super.key});

  @override
  State<AdminFeeSettingsScreen> createState() => _AdminFeeSettingsScreenState();
}

class _AdminFeeSettingsScreenState extends State<AdminFeeSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final SystemConfigService _configService = SystemConfigService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Controllers
  final _platformFeeController = TextEditingController();
  final _merchantGpController = TextEditingController();
  final _minWalletController = TextEditingController();
  final _commissionController = TextEditingController();
  final _maxRadiusController = TextEditingController();
  final _promptPayController = TextEditingController();

  // Service rates
  List<Map<String, dynamic>> _serviceRates = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _platformFeeController.dispose();
    _merchantGpController.dispose();
    _minWalletController.dispose();
    _commissionController.dispose();
    _maxRadiusController.dispose();
    _promptPayController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _configService.fetchSettings(forceRefresh: true);

      // Load service rates
      final ratesResponse = await Supabase.instance.client
          .from('service_rates')
          .select()
          .order('service_type');

      // Load promptpay number
      String promptPay = '';
      try {
        final config = await Supabase.instance.client
            .from('system_config')
            .select('promptpay_number')
            .maybeSingle();
        promptPay = config?['promptpay_number'] as String? ?? '';
      } catch (_) {}
      
      if (mounted) {
        setState(() {
          _platformFeeController.text = (_configService.platformFeeRate * 100).toStringAsFixed(1);
          _merchantGpController.text = (_configService.merchantGpRate * 100).toStringAsFixed(1);
          _minWalletController.text = _configService.driverMinWallet.toString();
          _commissionController.text = _configService.commissionRate.toStringAsFixed(1);
          _maxRadiusController.text = _configService.maxDeliveryRadius.toStringAsFixed(1);
          _promptPayController.text = promptPay;
          _serviceRates = List<Map<String, dynamic>>.from(ratesResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
      debugLog('❌ Error loading fee settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final platformFeeRate = double.parse(_platformFeeController.text) / 100;
      final merchantGpRate = double.parse(_merchantGpController.text) / 100;
      final minWallet = int.parse(_minWalletController.text);
      final commissionRate = double.parse(_commissionController.text) / 100;
      final maxRadius = double.parse(_maxRadiusController.text);

      // Validate ranges
      if (platformFeeRate < 0 || platformFeeRate > 1) {
        throw Exception('Platform Fee ต้องอยู่ระหว่าง 0-100%');
      }
      if (merchantGpRate < 0 || merchantGpRate > 1) {
        throw Exception('Merchant GP ต้องอยู่ระหว่าง 0-100%');
      }
      if (commissionRate < 0 || commissionRate > 1) {
        throw Exception('Commission ต้องอยู่ระหว่าง 0-100%');
      }
      if (minWallet < 0) {
        throw Exception('Minimum Wallet ต้องมากกว่าหรือเท่ากับ 0');
      }
      if (maxRadius <= 0) {
        throw Exception('รัศมีจัดส่งต้องมากกว่า 0');
      }

      // Update system_config table
      final configUpdate = {
        'platform_fee_rate': platformFeeRate,
        'merchant_gp_rate': merchantGpRate,
        'driver_min_wallet': minWallet,
        'commission_rate': commissionRate,
        'max_delivery_radius': maxRadius,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (_promptPayController.text.trim().isNotEmpty) {
        configUpdate['promptpay_number'] = _promptPayController.text.trim();
      }
      await Supabase.instance.client
          .from('system_config')
          .update(configUpdate)
          .eq('id', 1);

      // Update service rates
      for (final rate in _serviceRates) {
        if (rate['_modified'] == true) {
          await Supabase.instance.client
              .from('service_rates')
              .update({
                'base_price': rate['base_price'],
                'base_distance': rate['base_distance'],
                'price_per_km': rate['price_per_km'],
              })
              .eq('service_type', rate['service_type']);
        }
      }

      // Clear cache to force refresh
      _configService.clearCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ บันทึกการตั้งค่าสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        // ไม่ pop กลับ — อยู่หน้าเดิมเพื่อให้แก้ไขต่อได้
        // ถ้ามี navigator route ให้ pop ได้ ไม่งั้นจอดำ
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ไม่สามารถบันทึกได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugLog('❌ Error saving fee settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : _error != null
              ? _buildErrorState()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Page header
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Color(0xFF1565C0), size: 28),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('ตั้งค่าค่าธรรมเนียม', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ),
                          IconButton(onPressed: _loadSettings, icon: const Icon(Icons.refresh_rounded), tooltip: 'รีเฟรช'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Food Delivery Fees Section
                      _buildSectionHeader('ค่าธรรมเนียม Food Delivery'),
                      const SizedBox(height: 16),
                      
                      _buildFeeCard(
                        title: 'Platform Fee',
                        subtitle: '% ของค่าส่ง (ค่าบริการที่ได้รับจากลูกค้า)',
                        controller: _platformFeeController,
                        icon: Icons.delivery_dining,
                        color: AppTheme.accentOrange,
                        suffix: '%',
                      ),
                      const SizedBox(height: 12),
                      
                      _buildFeeCard(
                        title: 'Merchant GP',
                        subtitle: '% ของราคาอาหาร (ส่วนแบ่งให้ร้านค้า)',
                        controller: _merchantGpController,
                        icon: Icons.store,
                        color: AppTheme.primaryGreen,
                        suffix: '%',
                      ),
                      const SizedBox(height: 24),

                      // General Settings Section
                      _buildSectionHeader('การตั้งค่าทั่วไป'),
                      const SizedBox(height: 16),
                      
                      _buildFeeCard(
                        title: 'Minimum Wallet',
                        subtitle: 'ยอดเงินขั้นต่ำที่คนขับต้องมีในกระเป๋า',
                        controller: _minWalletController,
                        icon: Icons.account_balance_wallet,
                        color: Colors.blue,
                        suffix: '฿',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      
                      _buildFeeCard(
                        title: 'Standard Commission',
                        subtitle: '% ของราคางาน (สำหรับ Ride/Parcel)',
                        controller: _commissionController,
                        icon: Icons.percent,
                        color: Colors.purple,
                        suffix: '%',
                      ),
                      const SizedBox(height: 12),

                      _buildFeeCard(
                        title: 'รัศมีจัดส่งสูงสุด',
                        subtitle: 'ระยะทางเริ่มต้น (ถ้าลูกค้าสั่งเกินรัศมีนี้ จะแจ้งเตือนและคิดค่าส่งตามระยะทาง)',
                        controller: _maxRadiusController,
                        icon: Icons.radar,
                        color: Colors.deepOrange,
                        suffix: 'กม.',
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 24),

                      // PromptPay Section
                      _buildSectionHeader('PromptPay สำหรับเติมเงิน'),
                      const SizedBox(height: 16),
                      _buildFeeCard(
                        title: 'เบอร์ PromptPay',
                        subtitle: 'เบอร์โทรสำหรับรับเงินเติมเงินคนขับ',
                        controller: _promptPayController,
                        icon: Icons.qr_code,
                        color: Colors.teal,
                        suffix: '',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),

                      // Service Rates Section
                      _buildSectionHeader('อัตราค่าบริการแต่ละประเภท'),
                      const SizedBox(height: 16),
                      ..._serviceRates.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final rate = entry.value;
                        return _buildServiceRateCard(idx, rate);
                      }),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'บันทึกการตั้งค่า',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info Card
                      _buildInfoCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text('ไม่สามารถโหลดข้อมูลได้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFeeCard({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
    required String suffix,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: keyboardType ?? TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'จำนวน',
                suffixText: suffix,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาระบุจำนวน';
                }
                if (double.tryParse(value) == null) {
                  return 'กรุณาระบุตัวเลขที่ถูกต้อง';
                }
                if (suffix == '%' && (double.parse(value) < 0 || double.parse(value) > 100)) {
                  return 'ต้องอยู่ระหว่าง 0-100';
                }
                if (suffix == '฿' && double.parse(value) < 0) {
                  return 'ต้องมากกว่าหรือเท่ากับ 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceRateCard(int index, Map<String, dynamic> rate) {
    final type = rate['service_type'] as String? ?? '';
    final typeLabels = {
      'ride': '🚗 เรียกรถ (Ride)',
      'food': '🍔 อาหาร (Food Delivery)',
      'parcel': '📦 พัสดุ (Parcel)',
      'ride_motorcycle': '🏍️ มอเตอร์ไซค์',
      'ride_car': '🚗 รถยนต์',
      'ride_van': '🚐 รถตู้',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              typeLabels[type] ?? type,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniField(
                    label: 'ราคาเริ่มต้น (฿)',
                    value: rate['base_price']?.toString() ?? '0',
                    onChanged: (v) {
                      _serviceRates[index]['base_price'] = int.tryParse(v) ?? 0;
                      _serviceRates[index]['_modified'] = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniField(
                    label: 'ระยะเริ่มต้น (กม.)',
                    value: rate['base_distance']?.toString() ?? '0',
                    onChanged: (v) {
                      _serviceRates[index]['base_distance'] = int.tryParse(v) ?? 0;
                      _serviceRates[index]['_modified'] = true;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniField(
                    label: 'ราคา/กม. (฿)',
                    value: rate['price_per_km']?.toString() ?? '0',
                    onChanged: (v) {
                      _serviceRates[index]['price_per_km'] = int.tryParse(v) ?? 0;
                      _serviceRates[index]['_modified'] = true;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      onChanged: onChanged,
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'คำนวณค่าธรรมเนียม',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'สำหรับ Food Delivery:\n'
            '• Platform Fee = ค่าส่ง × Platform Fee%\n'
            '• Merchant GP = ราคาอาหาร × Merchant GP%\n'
            '• Total Deduction = Platform Fee + Merchant GP\n'
            '• Driver Net Income = ค่าส่ง - Platform Fee',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
