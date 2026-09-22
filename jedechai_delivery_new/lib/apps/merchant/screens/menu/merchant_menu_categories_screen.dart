import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';

class MerchantMenuCategoriesScreen extends StatefulWidget {
  const MerchantMenuCategoriesScreen({super.key});

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
    final controller = TextEditingController(
      text: category?['name']?.toString() ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'เพิ่มหมวดหมู่' : 'แก้ไขหมวดหมู่'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.menuMgmtCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('บันทึก'),
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

  Future<void> _moveCategory(int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= _categories.length) return;
    final current = _categories[index];
    final other = _categories[target];
    try {
      await Future.wait([
        _client.from('menu_categories').update({
          'sort_order': other['sort_order'] ?? target,
        }).eq('id', current['id']),
        _client.from('menu_categories').update({
          'sort_order': current['sort_order'] ?? index,
        }).eq('id', other['id']),
      ]);
    } catch (e) {
      _showError(e);
      return;
    }
    await _loadCategories();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('จัดการหมวดหมู่ไม่สำเร็จ: $error'),
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
                      'หมวดหมู่เมนู',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.text, 17, w: 700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ลากเพื่อจัดลำดับที่ลูกค้าเห็น',
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
              Text('ยังไม่มีหมวดหมู่', style: _txt(jdc.muted, 16, w: 600)),
            ],
          ),
        ),
      );
    }

    return JdcContentFrame(
      child: ListView.separated(
        padding: const EdgeInsets.only(top: JdcSpacing.md, bottom: JdcSpacing.xl),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: JdcSpacing.md),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryCard(category, index);
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

  /// การ์ดหมวดหมู่ 1 แถวตาม artboard —
  /// คอลัมน์ปุ่มย้ายลำดับ (ขึ้น/ลง ตามพฤติกรรมเดิม แทน drag handle ใน artboard),
  /// ชื่อหมวด + ลำดับ, สวิตช์เปิดใช้งาน (พฤติกรรมเดิม), ปุ่มแก้ไข 44x44
  Widget _buildCategoryCard(Map<String, dynamic> category, int index) {
    final jdc = JdcColors.of(context);
    final isActive = category['is_active'] == true;
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
          // ปุ่มย้ายลำดับขึ้น/ลง — พฤติกรรม _moveCategory เดิม
          SizedBox(
            width: JdcSpacing.xxxl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMoveButton(
                  icon: Icons.keyboard_arrow_up,
                  onPressed:
                      index == 0 ? null : () => _moveCategory(index, -1),
                ),
                _buildMoveButton(
                  icon: Icons.keyboard_arrow_down,
                  onPressed: index == _categories.length - 1
                      ? null
                      : () => _moveCategory(index, 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: JdcSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _txt(
                      isActive ? jdc.text : jdc.dim, 14, w: 700),
                ),
                const SizedBox(height: 2),
                Text(
                  'ลำดับ ${index + 1}',
                  style: _txt(jdc.muted, 12),
                ),
              ],
            ),
          ),
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
          _buildEditButton(category),
        ],
      ),
    );
  }

  Widget _buildMoveButton({required IconData icon, VoidCallback? onPressed}) {
    final jdc = JdcColors.of(context);
    return SizedBox(
      width: JdcTouch.minTarget,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 20,
        icon: Icon(icon,
            color: onPressed != null ? jdc.muted : jdc.offTrack),
        onPressed: onPressed,
        tooltip: onPressed == null ? null : 'จัดลำดับ',
      ),
    );
  }

  Widget _buildEditButton(Map<String, dynamic> category) {
    final jdc = JdcColors.of(context);
    final name = category['name']?.toString() ?? '';
    return Tooltip(
      message: 'แก้ไขหมวด $name',
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

  /// แถบล่าง — ปุ่มเพิ่มหมวดหมู่ (cta) ตาม artboard แทน FAB เดิม
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
                onTap: () => _saveCategory(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 19, color: jdc.onCta),
                    const SizedBox(width: JdcSpacing.sm),
                    Text('เพิ่มหมวดหมู่', style: _txt(jdc.onCta, 15, w: 700)),
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
