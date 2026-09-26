import 'package:flutter/material.dart';
import '../../../common/services/services.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

/// Bottom sheet widget สำหรับให้คนขับเลือกประเภทงานที่จะรับ
class DriverServiceTypeSettings extends StatefulWidget {
  final List<String>? initialServiceTypes;
  final String driverId;

  const DriverServiceTypeSettings({
    super.key,
    required this.initialServiceTypes,
    required this.driverId,
  });

  @override
  State<DriverServiceTypeSettings> createState() =>
      _DriverServiceTypeSettingsState();
}

class _DriverServiceTypeSettingsState extends State<DriverServiceTypeSettings> {
  late Set<String> _selected;
  bool _isSaving = false;
  bool _shopEnabled = false;
  bool _shopFlagLoaded = false;

  static const _baseServiceTypes = ['food', 'ride', 'parcel', 'laundry'];
  List<String> get _serviceTypes => [
        ..._baseServiceTypes,
        if (_shopEnabled) 'shop',
      ];

  /// ชื่อและคำอธิบายแต่ละประเภท แปลตาม locale (ห้าม hardcode ไทย — จะทำให้
  /// ผู้ใช้ที่ตั้งเครื่องเป็นอังกฤษเห็นภาษาผสม)
  String _label(AppLocalizations l10n, String type) => switch (type) {
        'food' => l10n.driverServiceTypeFood,
        'ride' => l10n.driverServiceTypeRide,
        'parcel' => l10n.driverServiceTypeParcel,
        'shop' => l10n.driverServiceTypeShop,
        _ => l10n.driverServiceTypeLaundry,
      };

  String _subtitle(AppLocalizations l10n, String type) => switch (type) {
        'food' => l10n.driverServiceTypeFoodDesc,
        'ride' => l10n.driverServiceTypeRideDesc,
        'parcel' => l10n.driverServiceTypeParcelDesc,
        'shop' => l10n.driverServiceTypeShopDesc,
        _ => l10n.driverServiceTypeLaundryDesc,
      };
  static const _icons = {
    'food': Icons.restaurant_rounded,
    'ride': Icons.directions_car_rounded,
    'parcel': Icons.inventory_2_rounded,
    'laundry': Icons.local_laundry_service_rounded,
    'shop': Icons.shopping_basket_rounded,
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.initialServiceTypes != null
        ? Set<String>.from(widget.initialServiceTypes!)
        : Set<String>.from(_baseServiceTypes);
    _loadShopEnabled();
  }

  Future<void> _loadShopEnabled() async {
    final enabled = await ShopService().isEnabled();
    if (!mounted) return;
    setState(() {
      _shopEnabled = enabled;
      _shopFlagLoaded = true;
      if (enabled && widget.initialServiceTypes == null) {
        _selected.add('shop');
      } else if (!enabled) {
        _selected.remove('shop');
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final types = _shopEnabled &&
              _selected.containsAll(_serviceTypes) &&
              _selected.length == _serviceTypes.length
          ? null
          : _selected.where(_serviceTypes.contains).toList();
      await SupabaseService.client
          .from('profiles')
          .update({'accepted_service_types': types}).eq('id', widget.driverId);

      if (mounted) {
        Navigator.of(context).pop(types ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .driverServiceTypeSaveError(e.toString())),
            backgroundColor: context.jdc.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// สร้าง TextStyle พร้อม fontVariations คู่กับ fontWeight ตามกฎดีไซน์
  TextStyle _txt(
    Color color,
    double size, {
    double w = 400,
    double? height,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: jdc.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: jdc.line,
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                ),
              ),
              const SizedBox(height: JdcSpacing.lg),
              // เนื้อหายาวเกินความสูงที่ sheet ได้ (มือถือแนวนอน/ฟอนต์ใหญ่)
              // ต้องเลื่อนได้ — คง drag handle ไว้ด้านบนไม่ให้เลื่อนหาย
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.driverServiceTypeTitle,
                          style: _txt(jdc.text, 17, w: 700)),
                      const SizedBox(height: JdcSpacing.xs),
                      Text(
                        l10n.driverServiceTypeSubtitle,
                        style: _txt(jdc.muted, 12),
                      ),
                      const SizedBox(height: JdcSpacing.lg),
                      for (final type in _serviceTypes) _buildTypeRow(type),
                      const SizedBox(height: JdcSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        height: JdcTouch.button,
                        child: ElevatedButton(
                          onPressed:
                              _isSaving || !_shopFlagLoaded ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: jdc.cta,
                            foregroundColor: jdc.onCta,
                            disabledBackgroundColor: jdc.brandSoft2,
                            disabledForegroundColor: jdc.brandOnSoft,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.field),
                            ),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: jdc.brandOnSoft,
                                  ),
                                )
                              : Text(l10n.driverServiceTypeSave,
                                  style: _txt(jdc.onCta, 15, w: 700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// แถวเลือกประเภทงานสไตล์ artboard — ไอคอนในกล่อง sunken + Switch สีเขียว
  Widget _buildTypeRow(String type) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selected = _selected.contains(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: JdcSpacing.sm),
      child: Material(
        color: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          side: BorderSide(color: jdc.line),
        ),
        child: InkWell(
          onTap: () {
            setState(() {
              if (selected) {
                _selected.remove(type);
              } else {
                _selected.add(type);
              }
            });
          },
          borderRadius: BorderRadius.circular(JdcRadius.field),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: JdcSpacing.md,
              vertical: 13,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: jdc.sunken,
                    borderRadius: BorderRadius.circular(JdcRadius.small),
                  ),
                  child: Icon(_icons[type], size: 19, color: jdc.text),
                ),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label(l10n, type),
                          style: _txt(jdc.text, 14, w: 700)),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(l10n, type),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _txt(jdc.muted, 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: JdcSpacing.md),
                Switch(
                  value: selected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked) {
                        _selected.add(type);
                      } else {
                        _selected.remove(type);
                      }
                    });
                  },
                  activeTrackColor: jdc.successFill,
                  inactiveTrackColor: jdc.offTrack,
                  thumbColor: WidgetStatePropertyAll(jdc.knob),
                  trackOutlineColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
