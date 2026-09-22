import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';
import 'menu/merchant_add_edit_menu_screen.dart';
import 'menu/merchant_menu_categories_screen.dart';
import 'menu/merchant_option_library_screen.dart';
import '../../../common/widgets/app_network_image.dart';

/// ค่าพิเศษของตัวกรองหมวด — แสดงเฉพาะเมนูที่ปิดขาย (ตาม artboard: ชิป "หมด N")
const String _kSoldOutFilter = '__soldout__';

/// Menu Management Screen
///
/// Allows merchants to manage their food menu items
/// Features: Add, Edit, Delete menu items
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  String? _error;

  /// คำค้น + ตัวกรองหมวด (UI state ภายในหน้า — กรองจากข้อมูลที่โหลดแล้ว)
  String _searchQuery = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    // loader อ้าง AppLocalizations.of(context) ในเส้นทาง error
    // จึงต้องรอให้ initState จบก่อน ไม่งั้นชน assertion ของ Flutter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchMenuItems();
    });
  }

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

  Future<void> _fetchMenuItems() async {
    // ดึงข้อความไว้ก่อนเริ่มงาน async — ถ้าอ่านทีหลังตอน widget ถูก
    // deactivate แล้ว จะได้ error "deactivated widget's ancestor"
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception(l10n.menuMgmtUserNotFound);
      }

      final response = await Supabase.instance.client
          .from('menu_items')
          .select('*')
          .eq('merchant_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _menuItems = List<Map<String, dynamic>>.from(response);
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

  void _showMenuItemDialog({Map<String, dynamic>? item}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => MerchantAddEditMenuScreen(item: item),
      ),
    )
        .then((result) {
      if (result == true) {
        _fetchMenuItems();
      }
    });
  }

  Future<void> _deleteMenuItem(String itemId, String itemName) async {
    final jdc = JdcColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.menuMgmtDeleteConfirmTitle),
        content: Text(
            AppLocalizations.of(context)!.menuMgmtDeleteConfirmBody(itemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.menuMgmtNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.menuMgmtYes),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('menu_items')
            .delete()
            .eq('id', itemId);

        _fetchMenuItems();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.menuMgmtDeleteSuccess),
              backgroundColor: jdc.panel,
            ),
          );
        }
      } catch (e) {
        // FK constraint: menu item has been ordered → offer to hide instead
        final errStr = e.toString();
        if (errStr.contains('violates foreign key') ||
            errStr.contains('RESTRICT') ||
            errStr.contains('referenced') ||
            errStr.contains('23503')) {
          if (mounted) {
            final hideInstead = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(
                    AppLocalizations.of(context)!.menuMgmtCannotDeleteTitle),
                content: Text(
                  AppLocalizations.of(context)!.menuMgmtCannotDeleteBody,
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child:
                          Text(AppLocalizations.of(context)!.menuMgmtCancel)),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(AppLocalizations.of(context)!.menuMgmtHideMenu,
                        style: TextStyle(color: jdc.cta)),
                  ),
                ],
              ),
            );
            if (hideInstead == true) {
              await Supabase.instance.client
                  .from('menu_items')
                  .update({'is_available': false}).eq('id', itemId);
              _fetchMenuItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(AppLocalizations.of(context)!.menuMgmtHideSuccess),
                    backgroundColor: jdc.panel,
                  ),
                );
              }
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .menuMgmtDeleteFailed(e.toString())),
                backgroundColor: jdc.danger,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleMenuAvailability(String itemId, bool currentValue) async {
    final jdc = JdcColors.of(context);
    final newValue = !currentValue;
    try {
      // Optimistic UI update
      setState(() {
        final index = _menuItems.indexWhere((m) => m['id'] == itemId);
        if (index != -1) {
          _menuItems[index]['is_available'] = newValue;
        }
      });

      await Supabase.instance.client
          .from('menu_items')
          .update({'is_available': newValue}).eq('id', itemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? AppLocalizations.of(context)!.menuMgmtToggleOn
                : AppLocalizations.of(context)!.menuMgmtToggleOff),
            backgroundColor: newValue ? jdc.successFill : jdc.panel,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _menuItems.indexWhere((m) => m['id'] == itemId);
        if (index != -1) {
          _menuItems[index]['is_available'] = currentValue;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .menuMgmtToggleFailed(e.toString())),
            backgroundColor: jdc.danger,
          ),
        );
      }
    }
  }

  String _formatPrice(double price) {
    return '฿${price.ceil()}';
  }

  void _navigateToOptionLibrary() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.menuMgmtUserNotFound),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MerchantOptionLibraryScreen(merchantId: userId),
      ),
    );
  }

  /// หมวดที่มีจริงในเมนู (distinct) สำหรับปุ่มตัวกรอง — ผูกข้อมูลจริง
  List<String> _distinctCategories() {
    final Set<String> seen = {};
    for (final item in _menuItems) {
      final cat = item['category']?.toString() ?? '';
      if (cat.isNotEmpty) seen.add(cat);
    }
    return seen.toList();
  }

  /// เมนูที่แสดงหลังผ่านคำค้น + ตัวกรองหมวด (กรองในหน้า ไม่เรียก service ใหม่)
  List<Map<String, dynamic>> _visibleItems() {
    var items = _menuItems;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items
          .where((m) => (m['name']?.toString() ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_categoryFilter == _kSoldOutFilter) {
      items = items.where((m) => m['is_available'] != true).toList();
    } else if (_categoryFilter != null) {
      items = items
          .where((m) => (m['category']?.toString() ?? '') == _categoryFilter)
          .toList();
    }
    return items;
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
              onRefresh: _fetchMenuItems,
              color: jdc.cta,
              child: _buildBody(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// แถบหัวเรื่องตาม artboard Merchant-Menu —
  /// พื้น surface + ไทต์เติล 19px + ปุ่ม "ตัวเลือกเสริม" outline +
  /// ช่องค้นหา 44px + แถวชิปตัวกรอง (ทั้งหมด/หมวดจริง/หมด)
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
              JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.md + 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.menuMgmtTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.text, 19, w: 700),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.menuMgmtRetry,
                    icon: Icon(Icons.refresh, size: 20, color: jdc.muted),
                    onPressed: _fetchMenuItems,
                  ),
                  const SizedBox(width: JdcSpacing.xs),
                  _buildOptionLibraryButton(),
                ],
              ),
              const SizedBox(height: JdcSpacing.md + 2),
              _buildSearchField(),
              const SizedBox(height: JdcSpacing.md + 2),
              _buildFilterChips(),
            ],
          ),
        ),
      ),
    );
  }

  /// ปุ่ม outline "ตัวเลือกเสริม" สูง 40 ตาม artboard
  Widget _buildOptionLibraryButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: 40,
      child: Material(
        color: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JdcRadius.small),
          side: BorderSide(color: jdc.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(JdcRadius.small),
          onTap: _navigateToOptionLibrary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13),
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.menuMgmtOptionTooltip,
                style: _txt(jdc.text, 12, w: 700),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: JdcTouch.minTarget,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.md + 2),
        decoration: BoxDecoration(
          color: jdc.paper,
          borderRadius: BorderRadius.circular(JdcRadius.small),
          border: Border.all(color: jdc.line),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: jdc.muted),
            const SizedBox(width: JdcSpacing.sm + 2),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: _txt(jdc.text, 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'ค้นหาเมนูในร้าน',
                  hintStyle: _txt(jdc.muted, 14),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final categories = _distinctCategories();
    final soldOutCount =
        _menuItems.where((m) => m['is_available'] != true).length;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            label: 'ทั้งหมด ${_menuItems.length}',
            selected: _categoryFilter == null,
            onTap: () => setState(() => _categoryFilter = null),
          ),
          const SizedBox(width: JdcSpacing.sm),
          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: JdcSpacing.sm),
                child: _buildFilterChip(
                  label: cat,
                  selected: _categoryFilter == cat,
                  onTap: () => setState(() =>
                      _categoryFilter = _categoryFilter == cat ? null : cat),
                ),
              )),
          if (soldOutCount > 0) _buildSoldOutChip(count: soldOutCount),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final jdc = JdcColors.of(context);
    return Material(
      color: selected ? jdc.panel : jdc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JdcRadius.chip),
        side: BorderSide(color: selected ? jdc.panel : jdc.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(JdcRadius.chip),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(selected ? jdc.onPanel : jdc.muted, 12,
                w: selected ? 700 : 600),
          ),
        ),
      ),
    );
  }

  /// ชิป "หมด N" สไตล์อันตรายตาม artboard
  Widget _buildSoldOutChip({required int count}) {
    final jdc = JdcColors.of(context);
    final selected = _categoryFilter == _kSoldOutFilter;
    return Material(
      color: jdc.dangerSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JdcRadius.chip),
        side: BorderSide(color: jdc.dangerLine),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(JdcRadius.chip),
        onTap: () =>
            setState(() => _categoryFilter = selected ? null : _kSoldOutFilter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            '${AppLocalizations.of(context)!.menuMgmtSoldOut} $count',
            style: _txt(jdc.dangerInk, 12, w: 700),
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

    if (_error != null) {
      return JdcContentFrame(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: JdcSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: jdc.danger),
                const SizedBox(height: JdcSpacing.lg),
                Text(
                  AppLocalizations.of(context)!.menuMgmtError,
                  style: _txt(jdc.danger, 18, w: 700),
                ),
                const SizedBox(height: JdcSpacing.sm),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: _txt(jdc.muted, 14),
                ),
                const SizedBox(height: JdcSpacing.xl),
                _buildRetryButton(),
              ],
            ),
          ),
        ),
      );
    }

    if (_menuItems.isEmpty) {
      return JdcContentFrame(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: JdcSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: jdc.dim),
                const SizedBox(height: JdcSpacing.lg),
                Text(
                  AppLocalizations.of(context)!.menuMgmtEmpty,
                  style: _txt(jdc.text, 18, w: 500),
                ),
                const SizedBox(height: JdcSpacing.sm),
                Text(
                  AppLocalizations.of(context)!.menuMgmtEmptyHint,
                  textAlign: TextAlign.center,
                  style: _txt(jdc.muted, 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final visible = _visibleItems();
    return JdcContentFrame(
      child: ListView.builder(
        padding:
            const EdgeInsets.only(top: JdcSpacing.lg, bottom: JdcSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: visible.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSectionHeader(visible.length);
          }
          final item = visible[index - 1];
          return _buildMenuItemCard(item);
        },
      ),
    );
  }

  Widget _buildRetryButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: JdcTouch.button,
      child: FilledButton(
        onPressed: _fetchMenuItems,
        style: FilledButton.styleFrom(
          backgroundColor: jdc.cta,
          foregroundColor: jdc.onCta,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.card),
          ),
        ),
        child: Text(AppLocalizations.of(context)!.menuMgmtRetry,
            style: _txt(jdc.onCta, 15, w: 700)),
      ),
    );
  }

  /// หัวข้อส่วน "หมวดปัจจุบัน · N เมนู" + ลิงก์ "จัดลำดับ" ไปหน้าหมวดหมู่
  Widget _buildSectionHeader(int visibleCount) {
    final jdc = JdcColors.of(context);
    final label = _categoryFilter == null
        ? '${AppLocalizations.of(context)!.menuMgmtTitle} · $visibleCount'
        : '$_categoryFilter · $visibleCount';
    return Padding(
      padding: const EdgeInsets.only(
          left: JdcSpacing.xs, right: JdcSpacing.xs, bottom: JdcSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _txt(jdc.muted, 13, w: 700),
            ),
          ),
          SizedBox(
            height: JdcTouch.minTarget,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MerchantMenuCategoriesScreen(),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.sm),
                minimumSize: Size.zero,
              ),
              child: Text('จัดลำดับ', style: _txt(jdc.link, 12, w: 700)),
            ),
          ),
        ],
      ),
    );
  }

  /// การ์ดเมนู 1 แถวตาม artboard Merchant-Menu —
  /// รูปจริง (หรือกล่องอักษรย่อ brand-soft เมื่อไม่มีรูป), ชื่อ+คำโปรย,
  /// ราคา, สวิตช์เปิดขาย 46x28, เมนูแก้ไข/ลบ (พฤติกรรมเดิม) — แตะการ์ด = แก้ไข
  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final jdc = JdcColors.of(context);
    final isAvailable = item['is_available'] == true;
    final hasImage =
        item['image_url'] != null && item['image_url'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: JdcSpacing.sm + 2),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Material(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(JdcRadius.card),
          onTap: () => _showMenuItemDialog(item: item),
          child: Padding(
            padding: const EdgeInsets.all(JdcSpacing.md),
            child: Row(
              children: [
                _buildMenuThumb(item, hasImage: hasImage),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ??
                            AppLocalizations.of(context)!.menuMgmtNoName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            _txt(isAvailable ? jdc.text : jdc.dim, 14, w: 700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _buildMenuMeta(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _txt(jdc.muted, 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: JdcSpacing.md),
                Text(
                  _formatPrice(item['price']?.toDouble() ?? 0.0),
                  style: _txt(isAvailable ? jdc.text : jdc.dim, 14, w: 700),
                ),
                const SizedBox(width: JdcSpacing.sm),
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: isAvailable,
                    onChanged: (_) => _toggleMenuAvailability(
                      item['id'],
                      isAvailable,
                    ),
                    activeTrackColor: jdc.successFill,
                    inactiveTrackColor: jdc.offTrack,
                    thumbColor: WidgetStatePropertyAll(jdc.knob),
                    trackOutlineColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                  ),
                ),
                _buildCardMenu(item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// รูปเมนู 46x46 — ถ้ามีรูปจริงใช้รูป ถ้าไม่มีใช้โลโก้ระบบสีเทา (มาตรฐานทุกช่องรูป ห้ามใช้ตัวย่อ)
  Widget _buildMenuThumb(Map<String, dynamic> item, {required bool hasImage}) {
    final jdc = JdcColors.of(context);
    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(JdcRadius.small),
        child: SizedBox(
          width: 46,
          height: 46,
          child: AppNetworkImage(
            imageUrl: item['image_url']?.toString(),
            fit: BoxFit.cover,
            backgroundColor: jdc.sunken,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(JdcRadius.small),
      child: GrayscaleLogoPlaceholder(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(5),
        backgroundColor: jdc.sunken,
      ),
    );
  }

  /// บรรทัด meta ของการ์ด — คำอธิบาย/หมวด และสถานะหมดเมื่อปิดขาย
  String _buildMenuMeta(Map<String, dynamic> item) {
    final parts = <String>[];
    final desc = item['description']?.toString() ?? '';
    if (desc.isNotEmpty) parts.add(desc);
    final cat = item['category']?.toString() ?? '';
    if (cat.isNotEmpty) parts.add(cat);
    if (item['is_available'] != true) {
      parts.add(AppLocalizations.of(context)!.menuMgmtSoldOut);
    }
    return parts.join(' · ');
  }

  /// เมนูแก้ไข/ลบ (พฤติกรรมเดิมจาก PopupMenuButton)
  Widget _buildCardMenu(Map<String, dynamic> item) {
    final jdc = JdcColors.of(context);
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      iconSize: 20,
      icon: Icon(Icons.more_vert, color: jdc.muted),
      onSelected: (value) {
        if (value == 'edit') {
          _showMenuItemDialog(item: item);
        } else if (value == 'delete') {
          _deleteMenuItem(item['id'],
              item['name'] ?? AppLocalizations.of(context)!.menuMgmtNoName);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: jdc.text),
              const SizedBox(width: JdcSpacing.sm),
              Text(AppLocalizations.of(context)!.menuMgmtEdit),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: jdc.danger),
              const SizedBox(width: JdcSpacing.sm),
              Text(AppLocalizations.of(context)!.menuMgmtDelete,
                  style: TextStyle(color: jdc.danger)),
            ],
          ),
        ),
      ],
    );
  }

  /// แถบล่าง — ปุ่มเพิ่มเมนูใหม่พื้นแถบเข้ม (panel/onPanel) ตาม artboard แทน FAB เดิม
  Widget _buildBottomBar() {
    final jdc = JdcColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(top: BorderSide(color: jdc.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.md),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Material(
              color: jdc.panel,
              borderRadius: BorderRadius.circular(JdcRadius.card),
              child: InkWell(
                borderRadius: BorderRadius.circular(JdcRadius.card),
                onTap: () => _showMenuItemDialog(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 20, color: jdc.onPanel),
                    const SizedBox(width: JdcSpacing.sm),
                    Text(
                      AppLocalizations.of(context)!.menuEditTitleAdd,
                      style: _txt(jdc.onPanel, 15, w: 700),
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
