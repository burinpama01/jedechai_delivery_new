import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/models/menu_option.dart';
import '../../../../l10n/app_localizations.dart';
import 'merchant_option_group_detail_screen.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';

/// Merchant Option Library Screen
///
/// Allows merchants to manage their reusable option groups
/// Features: List, Create, Edit, Delete option groups
class MerchantOptionLibraryScreen extends StatefulWidget {
  final String merchantId;
  /// Fixture สำหรับ dev_preview เท่านั้น — ไม่กระทบ production เพราะ default null
  final List<MenuOptionGroup>? fixtureGroups;

  const MerchantOptionLibraryScreen({
    super.key,
    required this.merchantId,
    this.fixtureGroups,
  });

  @override
  State<MerchantOptionLibraryScreen> createState() =>
      _MerchantOptionLibraryScreenState();
}

class _MerchantOptionLibraryScreenState
    extends State<MerchantOptionLibraryScreen> {
  List<MenuOptionGroup> _optionGroups = [];
  bool _isLoading = true;
  String? _error;

  /// สร้าง TextStyle พร้อม fontVariations คู่กับ fontWeight ตามกฎดีไซน์
  TextStyle _txt(Color color, double size, {double w = 400, double? height}) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOptionGroups();
  }

  Future<void> _loadOptionGroups() async {
    // Fixture override สำหรับ dev_preview
    if (widget.fixtureGroups != null) {
      setState(() {
        _optionGroups = widget.fixtureGroups!;
        _isLoading = false;
        _error = null;
      });
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groups =
          await MenuOptionService().getOptionGroupsForMerchant(widget.merchantId);

      if (mounted) {
        setState(() {
          _optionGroups = groups;
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
    }
  }

  Future<void> _deleteOptionGroup(MenuOptionGroup group) async {
    final confirmed = await _showDeleteConfirmation(group);
    if (!confirmed) return;

    try {
      await MenuOptionService().deleteOptionGroup(group.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .optLibDeleteSuccess(group.name)),
            backgroundColor: JdcColors.of(context).successFill,
          ),
        );
        _loadOptionGroups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.optLibDeleteFailed(e.toString())),
            backgroundColor: JdcColors.of(context).danger,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(MenuOptionGroup group) async {
    final jdc = JdcColors.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.optLibDeleteConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!
                    .optLibDeleteConfirmBody(group.name)),
                const SizedBox(height: 8),
                if (group.options != null && group.options!.isNotEmpty)
                  Text(
                    AppLocalizations.of(context)!.optLibDeleteNote(
                        group.options!.length.toString()),
                    style: _txt(jdc.dangerInk, 12),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.optLibCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: jdc.danger,
                  foregroundColor: jdc.dangerSoft,
                ),
                child: Text(AppLocalizations.of(context)!.optLibDeleteBtn),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _navigateToDetailScreen({MenuOptionGroup? group}) {
    debugLog('🔍 Navigating to detail screen:');
    if (group != null) {
      debugLog('📋 Edit mode - Group: ${group.name}');
      debugLog('📊 Options count: ${group.options?.length ?? 0}');
      if (group.options != null) {
        for (int i = 0; i < group.options!.length; i++) {
          final option = group.options![i];
          debugLog('   └─ Option $i: ${option.name} (฿${option.price})');
        }
      }
    } else {
      debugLog('➕ Create mode - New group');
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => MerchantOptionGroupDetailScreen(
          merchantId: widget.merchantId,
          group: group,
        ),
      ),
    )
        .then((_) => _loadOptionGroups());
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOptionGroups,
              color: jdc.cta,
              child: _buildBody(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// แถบหัวเรื่องตาม artboard Merchant-OptionLibrary —
  /// พื้น surface + เส้นแบ่งล่าง + ปุ่มย้อนกลับ 44x44 + ไทต์เติล 17px + คำโปรย
  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
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
              _buildBackButton(),
              const SizedBox(width: JdcSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.optLibPageTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.text, 17, w: 700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppLocalizations.of(context)!.optLibSubtitle,
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

  Widget _buildBackButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      width: JdcTouch.minTarget,
      height: JdcTouch.minTarget,
      child: Material(
        color: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          side: BorderSide(color: jdc.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(JdcRadius.field),
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(Icons.chevron_left, size: 20, color: jdc.text),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final jdc = JdcColors.of(context);
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: jdc.cta));
    }

    if (_error != null) {
      return JdcContentFrame(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: jdc.danger),
              const SizedBox(height: JdcSpacing.lg),
              Text(
                _error!,
                style: _txt(jdc.muted, 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: JdcSpacing.lg),
              _buildCtaButton(
                onPressed: _loadOptionGroups,
                label: AppLocalizations.of(context)!.optLibRetry,
              ),
            ],
          ),
        ),
      );
    }

    if (_optionGroups.isEmpty) {
      return JdcContentFrame(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 64, color: jdc.dim),
              const SizedBox(height: JdcSpacing.lg),
              Text(
                AppLocalizations.of(context)!.optLibEmpty,
                style: _txt(jdc.text, 16, w: 600),
              ),
              const SizedBox(height: JdcSpacing.sm),
              Text(
                AppLocalizations.of(context)!.optLibEmptyHint,
                style: _txt(jdc.muted, 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: JdcSpacing.lg),
              _buildCtaButton(
                onPressed: () => _navigateToDetailScreen(),
                icon: Icons.add,
                label: AppLocalizations.of(context)!.optLibCreateNew,
              ),
            ],
          ),
        ),
      );
    }

    return JdcContentFrame(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: JdcSpacing.md, bottom: JdcSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _optionGroups.length,
        itemBuilder: (context, index) {
          final group = _optionGroups[index];
          return OptionGroupCard(
            group: group,
            onTap: () => _navigateToDetailScreen(group: group),
            onDelete: () => _deleteOptionGroup(group),
          );
        },
      ),
    );
  }

  Widget _buildCtaButton({
    required VoidCallback onPressed,
    required String label,
    IconData? icon,
  }) {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: JdcTouch.button,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 19, color: jdc.onCta) : null,
        label: Text(label, style: _txt(jdc.onCta, 15, w: 700)),
        style: FilledButton.styleFrom(
          backgroundColor: jdc.cta,
          foregroundColor: jdc.onCta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card),
          ),
        ),
      ),
    );
  }

  /// แถบล่าง — ปุ่มสร้างกลุ่มตัวเลือก (cta) ตาม artboard แทน FAB เดิม
  Widget _buildBottomBar() {
    final jdc = JdcColors.of(context);
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
                onTap: () => _navigateToDetailScreen(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 19, color: jdc.onCta),
                    const SizedBox(width: JdcSpacing.sm),
                    Text(
                      AppLocalizations.of(context)!.optGroupBtnCreate,
                      style: _txt(jdc.onCta, 15, w: 700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// การ์ดกลุ่มตัวเลือกตาม artboard Merchant-OptionLibrary —
/// radius 18 + ขอบ line + เงา card, แถวบนชื่อกลุ่ม + กติกาการเลือก + chevron,
/// แถวล่างสรุปรายชื่อตัวเลือกคั่น " · " พร้อมราคาเพิ่มจากข้อมูลจริง
class OptionGroupCard extends StatelessWidget {
  final MenuOptionGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const OptionGroupCard({
    super.key,
    required this.group,
    required this.onTap,
    required this.onDelete,
  });

  String _getSelectionText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final min = group.minSelection;
    final max = group.maxSelection;

    if (min == 0 && max == 1) {
      return l10n.optLibSelectMax1;
    } else if (min == 0 && max > 1) {
      return l10n.optLibSelectMaxN(max.toString());
    } else if (min == max) {
      return l10n.optLibSelectExact(min.toString());
    } else {
      return l10n.optLibSelectRange(min.toString(), max.toString());
    }
  }

  /// สรุปรายชื่อตัวเลือกเป็นบรรทัดเดียว เช่น "ไข่ดาว +฿10 · ไข่เจียว +฿15"
  String _buildOptionsSummary() {
    final options = group.options ?? const <MenuOption>[];
    return options
        .map((o) => o.price > 0 ? '${o.name} +฿${o.price}' : o.name)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.md),
      child: Dismissible(
        key: Key(group.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: JdcSpacing.xl),
          decoration: BoxDecoration(
            color: jdc.dangerSoft,
            borderRadius: BorderRadius.circular(JdcRadius.card),
            border: Border.all(color: jdc.dangerLine),
          ),
          child: Icon(Icons.delete, color: jdc.danger, size: 24),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            onDelete();
            return false; // We handle deletion ourselves
          }
          return false;
        },
        child: Material(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(JdcRadius.card),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: JdcSpacing.lg, vertical: JdcSpacing.md + 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(JdcRadius.card),
                border: Border.all(color: jdc.line),
                boxShadow: jdc.shadowCard,
              ),
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
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cardTxt(jdc.text, 14, w: 700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getSelectionText(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cardTxt(jdc.muted, 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: jdc.muted),
                    ],
                  ),
                  if ((group.options?.isNotEmpty) ?? false) ...[
                    const SizedBox(height: JdcSpacing.sm),
                    Text(
                      _buildOptionsSummary(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _cardTxt(jdc.dim, 12, height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// TextStyle ของการ์ด แยกจาก state หลัก — ใส่ fontVariations คู่กับ fontWeight
  TextStyle _cardTxt(Color color, double size,
      {double w = 400, double? height}) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
    );
  }
}
