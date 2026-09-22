import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'jdc_colors.dart';
import 'jdc_layout.dart';

/// หน้าตรวจ token ของธีม — ใช้ตอนพัฒนาเท่านั้น (route `/dev/theme`)
///
/// ใช้ยืนยันว่า token ครบและสลับโหมดสว่าง/มืดได้ถูกต้อง ก่อนเริ่มย้ายหน้าจอจริง
/// หน้านี้ override ธีมเฉพาะตัวเอง ไม่กระทบธีมของทั้งแอป
class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({super.key});

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

enum _Preview { light, dark, system }

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  _Preview _preview = _Preview.light;

  ThemeData _themeFor(BuildContext context) {
    switch (_preview) {
      case _Preview.light:
        return AppTheme.lightTheme;
      case _Preview.dark:
        return AppTheme.darkTheme;
      case _Preview.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeFor(context);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final c = JdcColors.of(context);
          return Scaffold(
            backgroundColor: c.paper,
            appBar: AppBar(
              title: const Text('JDC Theme Gallery'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: JdcSpacing.md),
                  child: Center(
                    child: Text(
                      '${context.windowClass.name} · '
                      '${context.screenSize.width.round()}px',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: c.panelDim),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: context.gutter,
                  vertical: JdcSpacing.lg,
                ),
                children: [
                  _modeSwitch(c),
                  const SizedBox(height: JdcSpacing.xl),
                  _section(context, 'พื้นผิวและเส้น', [
                    _Swatch('paper', c.paper),
                    _Swatch('surface', c.surface),
                    _Swatch('sunken', c.sunken),
                    _Swatch('line', c.line),
                  ]),
                  _section(context, 'ตัวอักษร', [
                    _Swatch('text', c.text),
                    _Swatch('muted', c.muted),
                    _Swatch('dim', c.dim),
                  ]),
                  _section(context, 'แถบเข้ม', [
                    _Swatch('panel', c.panel),
                    _Swatch('onPanel', c.onPanel),
                    _Swatch('panelDim', c.panelDim),
                    _Swatch('panelLine', c.panelLine),
                  ]),
                  _section(context, 'แบรนด์และปุ่ม', [
                    _Swatch('brand', c.brand),
                    _Swatch('brandHi', c.brandHi),
                    _Swatch('cta', c.cta),
                    _Swatch('link', c.link),
                    _Swatch('brandSoft', c.brandSoft),
                    _Swatch('brandLine', c.brandLine),
                    _Swatch('brandOnSoft', c.brandOnSoft),
                  ]),
                  _section(context, 'สถานะ', [
                    _Swatch('successInk', c.successInk),
                    _Swatch('successSoft', c.successSoft),
                    _Swatch('successFill', c.successFill),
                    _Swatch('infoInk', c.infoInk),
                    _Swatch('infoSoft', c.infoSoft),
                    _Swatch('danger', c.danger),
                    _Swatch('dangerSoft', c.dangerSoft),
                  ]),
                  _section(context, 'ตัวควบคุมและแผนที่', [
                    _Swatch('offTrack', c.offTrack),
                    _Swatch('knob', c.knob),
                    _Swatch('trackEmpty', c.trackEmpty),
                    _Swatch('mapBg', c.mapBg),
                    _Swatch('mapRoad', c.mapRoad),
                    _Swatch('route', c.route),
                  ]),
                  _heroRow(context, c),
                  _typography(context, theme, c),
                  _components(context, c),
                  const SizedBox(height: JdcSpacing.xxxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _modeSwitch(JdcColors c) {
    return SegmentedButton<_Preview>(
      segments: const [
        ButtonSegment(value: _Preview.light, label: Text('สว่าง')),
        ButtonSegment(value: _Preview.dark, label: Text('มืด')),
        ButtonSegment(value: _Preview.system, label: Text('ตามระบบ')),
      ],
      selected: {_preview},
      onSelectionChanged: (v) => setState(() => _preview = v.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        selectedBackgroundColor: c.brandSoft,
        selectedForegroundColor: c.brandOnSoft,
        side: BorderSide(color: c.line),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<_Swatch> swatches) {
    final c = JdcColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: JdcSpacing.md),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = context.isCompact ? 2 : context.gridColumns + 1;
            final width = (constraints.maxWidth -
                    (columns - 1) * JdcSpacing.md) /
                columns;
            return Wrap(
              spacing: JdcSpacing.md,
              runSpacing: JdcSpacing.md,
              children: [
                for (final s in swatches)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius:
                                BorderRadius.circular(JdcRadius.small),
                            border: Border.all(color: c.line),
                          ),
                        ),
                        const SizedBox(height: JdcSpacing.xs),
                        Text(s.name,
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: JdcSpacing.xl),
      ],
    );
  }

  Widget _heroRow(BuildContext context, JdcColors c) {
    Widget hero(String label, Gradient g) => Expanded(
          child: Container(
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: g,
              borderRadius: BorderRadius.circular(JdcRadius.small),
            ),
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.onPanel),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ไล่สีหัวเรื่อง',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: JdcSpacing.md),
        Row(
          children: [
            hero('hero', c.hero),
            const SizedBox(width: JdcSpacing.md),
            hero('hero2', c.hero2),
            const SizedBox(width: JdcSpacing.md),
            hero('hero3', c.hero3),
          ],
        ),
        const SizedBox(height: JdcSpacing.xl),
      ],
    );
  }

  Widget _typography(BuildContext context, ThemeData theme, JdcColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ตัวอักษร', style: theme.textTheme.titleMedium),
        const SizedBox(height: JdcSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(JdcSpacing.lg),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(JdcRadius.card),
            boxShadow: c.shadowCard,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('หัวเรื่องใหญ่ ครัวป้าน้อย',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: JdcSpacing.sm),
              Text('หัวเรื่องรอง ยอดขายวันนี้',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: JdcSpacing.sm),
              Text(
                'เนื้อหา ข้าวกะเพราหมูสับไข่ดาว เผ็ดน้อย ไม่ใส่ถั่วฝักยาว '
                'ส่งถึง ถ.หน้าเมือง ซ.3 ภายใน 25 นาที',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: JdcSpacing.sm),
              Text('ข้อความรอง #JD-2841 · 20 ก.ย. 2569',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: JdcSpacing.xl),
      ],
    );
  }

  Widget _components(BuildContext context, JdcColors c) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('องค์ประกอบ', style: theme.textTheme.titleMedium),
        const SizedBox(height: JdcSpacing.md),
        Wrap(
          spacing: JdcSpacing.md,
          runSpacing: JdcSpacing.md,
          children: [
            ElevatedButton(onPressed: () {}, child: const Text('ปุ่มหลัก')),
            OutlinedButton(onPressed: () {}, child: const Text('ปุ่มรอง')),
            TextButton(onPressed: () {}, child: const Text('ลิงก์ข้อความ')),
          ],
        ),
        const SizedBox(height: JdcSpacing.md),
        const TextField(
          decoration: InputDecoration(labelText: 'ชื่อเมนู', hintText: 'พิมพ์ที่นี่'),
        ),
        const SizedBox(height: JdcSpacing.md),
        Row(
          children: [
            Switch(value: true, onChanged: (_) {}),
            const SizedBox(width: JdcSpacing.md),
            Switch(value: false, onChanged: (_) {}),
            const SizedBox(width: JdcSpacing.lg),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: JdcSpacing.md,
                  vertical: JdcSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: c.successSoft,
                  border: Border.all(color: c.successLine),
                  borderRadius: BorderRadius.circular(JdcRadius.chip),
                ),
                child: Text(
                  'ส่งสำเร็จ',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: c.successInk),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Swatch {
  const _Swatch(this.name, this.color);
  final String name;
  final Color color;
}
