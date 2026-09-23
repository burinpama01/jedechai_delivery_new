import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';

class MerchantMenuCategoriesScreen extends StatefulWidget {
  const MerchantMenuCategoriesScreen({super.key, this.fixtureCategories});

  /// Dev-preview only — null ใน production
  final List<Map<String, dynamic>>? fixtureCategories;

  @override
  State<MerchantMenuCategoriesScreen> createState() =>
      _MerchantMenuCategoriesScreenState();
}

class _MerchantMenuCategoriesScreenState
    extends State<MerchantMenuCategoriesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // loader อ้าง AppLocalizations.of(context) ในเส้นทาง error
    // จึงต้องรอให้ initState จบก่อน ไม่งั้นชน assertion ของ Flutter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCategories();
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

  Future<void> _loadCategories() async {
    // Dev-preview shortcut
    final fixtureData = widget.fixtureCategories;
    if (fixtureData != null) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(fixtureData);
        _isLoading = false;
      });
      return;
    }
    // ดึงข้อความไว้ก่อนเริ่มงาน async — ถ้าอ่านทีหลังตอน widget ถูก
    // deactivate แล้ว จะได้ error "deactivated widget's ancestor"
    final l10n = AppLocalizations.of(context)!;
    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) {
      setState(() {
        _error = l10n.merchantUserNotFound;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await _client
          .from('menu_categories')
          .select()
          .eq('merchant_id', merchantId)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCategory({Map<String, dynamic>? category}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: category?['name']?.toString() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? l10n.mchCatAddDialog : l10n.mchCatEditDialog),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.mchCatNameField),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.menuMgmtCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.mchCatSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    final merchantId = _client.auth.currentUser?.id;
    if (merchantId == null) return;
    try {
      if (category == null) {
        await _client.from('menu_categories').insert({
          'merchant_id': merchantId,
          'name': name,
          'sort_order': _categories.length,
          'is_active': true,
        });
      } else {
        await _client
            .from('menu_categories')
            .update({'name': name}).eq('id', category['id']);
      }
    } catch (e) {
      _showError(e);
      return;
    }
    await _loadCategories();
  }

  Future<void> _toggleCategory(Map<String, dynamic> category) async {
    try {
      await _client.from('menu_categories').update({
        'is_active': category['is_active'] != true,
      }).eq('id', category['id']);
    } catch (e) {
      _showError(e);
      return;
    }
    await _loadCategories();
  }

  /// จัดลำดับใหม่ผ่าน drag-and-drop — อัปเดต sort_order ทุกรายการ
  Future<void> _reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    // Optimistic update
    final updated = List<Map<String, dynamic>>.from(_categories);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() => _categories = updated);

    try {
      await Future.wait(
        List.generate(updated.length, (i) => _client
            .from('menu_categories')
            .update({'sort_order': i})
            .eq('id', updated[i]['id'])),
      );
    } catch (e) {
      _showError(e);
      // Reload to restore correct state on failure
      if (mounted) await _loadCategories();
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.mchCatSaveFailed(error.toString())),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
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
              onRefresh: _loadCategories,
              color: jdc.cta,
              child: _buildBody(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// แถบหัวเรื่องตาม artboard Merchant-MenuCategories —
  /// พื้น surface + เส้นแบ่งล่าง + ปุ่มย้อนกลับ 44x44 + ไทต์เติล 17px + คำโปรย
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
              _buildBackButton(),
              const SizedBox(width: JdcSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mchCatTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.text, 17, w: 700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.mchCatSubtitle,
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
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(Icons.chevron_left, size: 20, color: jdc.text),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: jdc.cta));
    }

    if (_error != null) {
      return JdcContentFrame(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: jdc.danger),
              const SizedBox(height: JdcSpacing.md),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: _txt(jdc.muted, 14),
              ),
              const SizedBox(height: JdcSpacing.lg),
              _buildRetryButton(),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return JdcContentFrame(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 48, color: jdc.dim),
              const SizedBox(height: JdcSpacing.md),
              Text(l10n.mchCatEmpty, style: _txt(jdc.muted, 16, w: 600)),
            ],
          ),
        ),
      );
    }

    // ใช้ ReorderableListView ตาม artboard (drag handle)
    return JdcContentFrame(
      child: ReorderableListView.builder(
        padding: const EdgeInsets.only(top: JdcSpacing.md, bottom: JdcSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        onReorder: _reorderCategories,
        // ใช้ handle ของเราเอง — ปิด handle อัตโนมัติที่ซ้อนทับปุ่มแก้ไขบนเว็บ/เดสก์ท็อป
        buildDefaultDragHandles: false,
        itemCount: _categories.length,
        proxyDecorator: (child, index, animation) => Material(
          elevation: 4,
          color: Colors.transparent,
          child: child,
        ),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Padding(
            key: ValueKey(category['id'] ?? index),
            padding: const EdgeInsets.only(bottom: JdcSpacing.md),
            child: _buildCategoryCard(category, index),
          );
        },
      ),
    );
  }

  Widget _buildRetryButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: JdcTouch.button,
      child: FilledButton(
        onPressed: _loadCategories,
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

  /// การ์ดหมวดหมู่ 1 แถวตาม artboard Merchant-MenuCategories —
  /// drag handle (3-line) + ชื่อหมวด + sort order, สวิตช์เปิดใช้งาน (feature เดิม), ปุ่มแก้ไข 44x44
  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = category['is_active'] == true;
    final categoryName = category['name']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md, vertical: JdcSpacing.md),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        children: [
          // Drag handle — ลากเพื่อจัดลำดับตาม artboard (3 เส้นแนวนอน)
          Tooltip(
            message: l10n.mchCatReorderTooltip,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: JdcSpacing.sm, vertical: JdcSpacing.sm),
              child: ReorderableDragStartListener(
                index: index,
                child: _DragHandle(color: jdc.offTrack),
              ),
            ),
          ),
          const SizedBox(width: JdcSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _txt(isActive ? jdc.text : jdc.dim, 14, w: 700),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.mchCatSortOrder(index + 1),
                  style: _txt(jdc.muted, 12),
                ),
              ],
            ),
          ),
          // Switch เปิด/ปิดหมวด (feature เดิม ไม่มีใน artboard แต่เก็บไว้)
          SizedBox(
            height: 28,
            child: Switch(
              value: isActive,
              onChanged: (_) => _toggleCategory(category),
              activeTrackColor: jdc.successFill,
              inactiveTrackColor: jdc.offTrack,
              thumbColor: WidgetStatePropertyAll(jdc.knob),
              trackOutlineColor:
                  const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
          const SizedBox(width: JdcSpacing.sm),
          _buildEditButton(category, categoryName),
        ],
      ),
    );
  }

  Widget _buildEditButton(Map<String, dynamic> category, String categoryName) {
    final jdc = JdcColors.of(context);
    return Tooltip(
      message: AppLocalizations.of(context)!.mchCatEditTooltip(categoryName),
      child: SizedBox(
        width: JdcTouch.minTarget,
        height: JdcTouch.minTarget,
        child: Material(
          color: jdc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JdcRadius.field),
            side: BorderSide(color: jdc.line),
          ),
          child: InkWell(
            onTap: () => _saveCategory(category: category),
            child: Icon(Icons.edit_outlined, size: 18, color: jdc.text),
          ),
        ),
      ),
    );
  }

  /// แถบล่าง — ปุ่มเพิ่มหมวดหมู่ (cta) ตาม artboard
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
                onTap: () => _saveCategory(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 19, color: jdc.onCta),
                    const SizedBox(width: JdcSpacing.sm),
                    Text(l10n.mchCatAddCategory, style: _txt(jdc.onCta, 15, w: 700)),
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

/// Drag handle widget — 3 เส้นแนวนอน ตาม artboard
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Line(color: color),
        const SizedBox(height: 3),
        _Line(color: color),
        const SizedBox(height: 3),
        _Line(color: color),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
