import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_publish_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_review_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_start_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_templates_screen.dart';
import 'package:jedechai_delivery_new/common/services/ai_menu_import_service.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';

/// service จำลอง — บันทึกการเรียกไว้ตรวจ ไม่ต่อ Supabase
class _FakeService extends AiMenuImportService {
  final calls = <String>[];
  List<AiTemplateSuggestion>? savedSelections;
  Map<String, dynamic> publishResult = {'ok': true, 'created_items': 2};
  String jobStatus = 'review_required';

  @override
  Future<AiImportStatus> fetchStatus() async => AiImportStatus.fromJson({
        'allowed': true,
        'mode': 'append',
        'quota_used': 1,
        'quota_limit': 5,
        'max_files': 8,
      });

  @override
  Future<AiImportJob?> fetchJob(String jobId) async => _job(jobStatus);

  @override
  Future<List<AiImportItem>> fetchItems(String jobId) async => [
        _item('i1', 'ชาไทย', 50),
        _item('i2', 'โกโก้', 50, issues: ['price_conflict'], conflict: [50, 55]),
        _item('i3', 'ลาเต้', 55, action: 'skip', match: 'exact_dup', matched: 55),
      ];

  @override
  Future<void> reviewItem(String itemId, String action,
      [Map<String, dynamic> patch = const {}]) async {
    calls.add('review:$itemId:$action:${patch['price'] ?? ''}');
  }

  @override
  Future<int> bulkApprove(String jobId) async {
    calls.add('bulk');
    return 1;
  }

  @override
  Future<List<AiTemplateSuggestion>> suggestTemplates(
      String jobId, String storeType) async {
    calls.add('suggest:$storeType');
    return [
        AiTemplateSuggestion.fromJson({
          'template_id': 't1',
          'name': 'ระดับความหวาน',
          'min_selection': 1,
          'max_selection': 1,
          'options': [
            {'label': 'หวานน้อย', 'price': 0},
            {'label': 'หวานปกติ', 'price': 0},
          ],
          'item_ids': ['i1'],
          'skipped_item_ids': [],
        }),
        AiTemplateSuggestion.fromJson({
          'template_id': 't2',
          'name': 'ท็อปปิ้ง',
          'min_selection': 0,
          'max_selection': 2,
          'options': [
            {'label': 'ไข่มุก', 'price': 10},
          ],
          'item_ids': ['i1'],
          'skipped_item_ids': [],
        }),
      ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSavedSelections(String jobId) async => [];

  @override
  Future<void> saveTemplateSelections(String jobId, String storeType,
      List<AiTemplateSuggestion> selected) async {
    savedSelections = selected;
    calls.add('save:$storeType:${selected.length}');
  }

  @override
  Future<Map<String, dynamic>> publish(String jobId,
      {required bool live, required bool confirmed}) async {
    calls.add('publish:${live ? 'live' : 'hidden'}:$confirmed');
    return publishResult;
  }
}

AiImportJob _job(String status) => AiImportJob.fromJson({
      'id': 'job-1',
      'mode': 'append',
      'status': status,
      'store_type': 'cafe',
      'store_type_guess': 'cafe',
      'total_files': 2,
      'total_items': 3,
      'attempts': 1,
      'unreadable_regions': [],
    });

AiImportItem _item(String id, String name, num price,
        {List<String> issues = const [],
        String status = 'draft',
        String action = 'create',
        String match = 'new',
        num? matched,
        List<num>? conflict}) =>
    AiImportItem.fromJson({
      'id': id,
      'name': name,
      'price': price,
      'category': 'เครื่องดื่ม',
      'issues': issues,
      'status': status,
      'action': action,
      'match_type': match,
      'matched_price': matched,
      'conflict_json': conflict == null ? null : {'prices': conflict},
      'price_text_raw': '$price',
    });

Widget _app(Widget home, {String locale = 'th'}) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _phone(WidgetTester tester, [double width = 390]) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in <double>[320, 390]) {
    testWidgets('start screen renders quota + disabled start at ${width.toInt()}px',
        (tester) async {
      _phone(tester, width);
      await tester.pumpWidget(_app(AiMenuImportStartScreen(service: _FakeService())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('เพิ่มเมนูด้วย AI'), findsOneWidget);
      expect(find.text('เดือนนี้ใช้ไปแล้ว 1/5 ครั้ง'), findsOneWidget);
      expect(find.text('เพิ่มรูปก่อน'), findsOneWidget);
    });

    testWidgets('review screen lists items without overflow at ${width.toInt()}px',
        (tester) async {
      _phone(tester, width);
      await tester.pumpWidget(_app(AiMenuImportReviewScreen(jobId: 'job-1', service: _FakeService())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('ชาไทย'), findsOneWidget);
      expect(find.text('มีอยู่แล้ว'), findsOneWidget);
      // ยังมีรายการรอยืนยัน → ปุ่มถัดไปยังไม่เปิด
      expect(find.text('เหลือรอยืนยัน 2'), findsOneWidget);
    });
  }

  testWidgets('review: เลือกราคาเมื่อขัดกัน และยืนยันทั้งหมดที่พร้อม', (tester) async {
    _phone(tester);
    final fake = _FakeService();
    await tester.pumpWidget(_app(AiMenuImportReviewScreen(jobId: 'job-1', service: fake)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, '฿55'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('review:i2:choose_price:55.0'));

    await tester.tap(find.text('ยืนยันที่พร้อม (1)'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('bulk'));
  });

  testWidgets('templates: ไม่ติ๊กล่วงหน้า (D11) และบันทึกเฉพาะที่ร้านติ๊ก', (tester) async {
    _phone(tester);
    final fake = _FakeService();
    final items = [_item('i1', 'ชาไทย', 50, status: 'approved')];
    await tester.pumpWidget(_app(AiMenuImportTemplatesScreen(
        job: _job('review_required'), items: items, service: fake)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(boxes.length, 2);
    expect(boxes.every((b) => b.value == false), isTrue);
    // D10: ชุดที่มีราคาติดป้ายให้ตรวจ
    expect(find.text('ราคาจากแม่แบบ ตรวจก่อน'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('ใช้ 1 ชุด · ดูตัวอย่าง'), findsOneWidget);

    await tester.tap(find.text('ใช้ 1 ชุด · ดูตัวอย่าง'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('save:cafe:1'));
    expect(fake.savedSelections!.single.name, 'ระดับความหวาน');
    // ไปหน้า Preview แล้ว
    expect(find.text('ตัวอย่างหน้าร้าน'), findsOneWidget);
  });

  testWidgets('templates: เปลี่ยนประเภทร้าน — ไม่มีติ๊ก โหลดทันที, มีติ๊ก ถามก่อน', (tester) async {
    _phone(tester);
    final fake = _FakeService();
    final items = [_item('i1', 'ชาไทย', 50, status: 'approved')];
    await tester.pumpWidget(_app(AiMenuImportTemplatesScreen(
        job: _job('review_required'), items: items, service: fake)));
    await tester.pumpAndSettle();
    expect(fake.calls, ['suggest:cafe']);

    Future<void> pick(String label) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    // ยังไม่ติ๊ก → เปลี่ยนแล้วโหลดใหม่เลย
    await pick('ก๋วยเตี๋ยว');
    expect(fake.calls.last, 'suggest:noodle');

    // ติ๊กแล้ว → ถาม · กดยกเลิก = ไม่โหลด ประเภทเดิมยังอยู่
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await pick('ของหวาน / เบเกอรี่');
    expect(find.text('เปลี่ยนประเภทร้าน?'), findsOneWidget);
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'suggest:noodle');
    expect(find.text('ก๋วยเตี๋ยว'), findsOneWidget);

    // กดเปลี่ยน = โหลดแม่แบบประเภทใหม่
    await pick('ของหวาน / เบเกอรี่');
    await tester.tap(find.text('เปลี่ยน'));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'suggest:dessert');
  });

  testWidgets('publish: ค่าเริ่มต้นซ่อนไว้ก่อน (D8) และต้องติ๊กยืนยันก่อนกด', (tester) async {
    _phone(tester);
    final fake = _FakeService();
    final items = [_item('i1', 'ชาไทย', 50, status: 'approved')];
    await tester.pumpWidget(_app(AiMenuImportPublishScreen(
        job: _job('review_required'), items: items, selections: const [], service: fake)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // ยังไม่ติ๊กยืนยัน → กดแล้วไม่ publish
    await tester.tap(find.text('บันทึก 1 เมนู'));
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('publish')), isEmpty);

    await tester.tap(find.text('ฉันตรวจชื่อและราคาทุกรายการแล้ว'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก 1 เมนู'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('publish:hidden:true'));
  });

  testWidgets('publish: เจอเมนูซ้ำ → แจ้งและกลับไปตรวจ', (tester) async {
    _phone(tester);
    final fake = _FakeService()
      ..publishResult = {'ok': false, 'reason': 'duplicates_found', 'names': ['ชาไทย']};
    final items = [_item('i1', 'ชาไทย', 50, status: 'approved')];
    await tester.pumpWidget(_app(AiMenuImportPublishScreen(
        job: _job('review_required'), items: items, selections: const [], service: fake)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ฉันตรวจชื่อและราคาทุกรายการแล้ว'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก 1 เมนู'));
    // ปุ่มแสดง spinner ระหว่าง dialog เปิด → ใช้ pump แทน pumpAndSettle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('พบเมนูซ้ำ'), findsOneWidget);
  });

  testWidgets('english locale renders review screen', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(
        AiMenuImportReviewScreen(jobId: 'job-1', service: _FakeService()),
        locale: 'en'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Review menu items'), findsOneWidget);
  });
}
