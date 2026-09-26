// Dev-only preview ของ AI Menu Import (ไม่ถูก import จาก lib/)
// เลือกหน้าด้วย ?screen=Start|Processing|Review|Templates|Publish|History&theme=dark&lang=en
// ใช้ service จำลอง — ไม่เรียก Supabase/AI จริง
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_history_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_publish_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_review_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_start_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/ai_menu_import/ai_menu_import_templates_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/common/services/ai_menu_import_service.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.client');
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
  final params = Uri.base.queryParameters;
  runApp(MultiProvider(
    providers: [ChangeNotifierProvider(create: (_) => LanguageProvider())],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: jdcTextScaleGuard,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: params['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(params['lang'] ?? 'th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _screen(params['screen'] ?? 'Review'),
    ),
  ));
}

final _fake = _FakeService(processing: Uri.base.queryParameters['screen'] == 'Processing');

Widget _screen(String name) => switch (name) {
      'Start' => AiMenuImportStartScreen(service: _fake),
      'Processing' || 'Review' => AiMenuImportReviewScreen(jobId: 'job-1', service: _fake),
      'Templates' => AiMenuImportTemplatesScreen(
          job: _job('review_required'), items: _confirmedItems(), service: _fake),
      'Publish' => AiMenuImportPublishScreen(
          job: _job('review_required'),
          items: _confirmedItems(),
          selections: [_sweetness()..selected = true],
          service: _fake),
      _ => AiMenuImportHistoryScreen(service: _fake),
    };

AiImportJob _job(String status) => AiImportJob.fromJson({
      'id': 'job-1',
      'mode': 'append',
      'status': status,
      'store_type': 'cafe',
      'store_type_guess': 'cafe',
      'total_files': 3,
      'total_items': 7,
      'attempts': 1,
      'unreadable_regions': ['มุมขวาล่างของรูปที่ 2 เลือนราง'],
      'created_at': DateTime.now().toIso8601String(),
    });

Map<String, dynamic> _item(String id, String name, num? price,
        {String category = 'กาแฟ',
        List<String> issues = const [],
        String status = 'draft',
        String match = 'new',
        String action = 'create',
        num? matched,
        List<Map<String, dynamic>> variants = const [],
        List<Map<String, dynamic>> addons = const [],
        String? raw,
        List<num>? conflict,
        bool newCat = false}) =>
    {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'issues': issues,
      'status': status,
      'match_type': match,
      'action': action,
      'matched_price': matched,
      'variants_json': variants,
      'addons_json': addons,
      'variant_group': variants.isEmpty ? null : 'แบบ',
      'price_text_raw': raw ?? (price == null ? null : '$price'),
      'conflict_json': conflict == null ? null : {'prices': conflict},
      'is_new_category': newCat,
    };

List<AiImportItem> _items() => [
      _item('i1', 'ชาไทย', 50,
          category: 'ชา',
          newCat: true,
          raw: 'เย็น 50 / ปั่น 60',
          variants: [
            {'label': 'เย็น', 'price': 50},
            {'label': 'ปั่น', 'price': 60}
          ],
          addons: [
            {'group': 'ท็อปปิ้ง', 'label': 'ไข่มุก', 'price_delta': 10}
          ]),
      _item('i2', 'มัทฉะลาเต้', 65, category: 'ชา', newCat: true, issues: ['check_price']),
      _item('i3', 'โกโก้', 50, issues: ['price_conflict'], conflict: [50, 55]),
      _item('i4', 'อเมริกาโน่', null, issues: ['missing_price', 'low_price_conf']),
      _item('i5', 'ลาเต้', 55, match: 'exact_dup', action: 'skip', matched: 55),
      _item('i6', 'มอคค่า', 65, match: 'price_changed', action: 'skip', matched: 60),
      _item('i7', 'เอสเพรสโซ่เย็น', 55, status: 'approved'),
    ].map(AiImportItem.fromJson).toList();

List<AiImportItem> _confirmedItems() => [
      _item('i1', 'ชาไทย', 50, category: 'ชา', status: 'approved', variants: [
        {'label': 'เย็น', 'price': 50},
        {'label': 'ปั่น', 'price': 60}
      ]),
      _item('i2', 'มัทฉะลาเต้', 65, category: 'ชา', status: 'edited'),
      _item('i3', 'โกโก้', 55, status: 'edited'),
      _item('i7', 'เอสเพรสโซ่เย็น', 55, status: 'approved'),
    ].map(AiImportItem.fromJson).toList();

AiTemplateSuggestion _sweetness() => AiTemplateSuggestion.fromJson({
      'template_id': 't1',
      'name': 'ระดับความหวาน',
      'min_selection': 1,
      'max_selection': 1,
      'options': [
        {'label': 'ไม่หวาน', 'price': 0},
        {'label': 'หวานน้อย', 'price': 0},
        {'label': 'หวานปกติ', 'price': 0},
        {'label': 'หวานมาก', 'price': 0},
      ],
      'item_ids': ['i1', 'i2', 'i3'],
      'skipped_item_ids': [],
    });

class _FakeService extends AiMenuImportService {
  _FakeService({required this.processing});
  final bool processing;

  @override
  Future<AiImportStatus> fetchStatus() async => AiImportStatus.fromJson({
        'allowed': true,
        'mode': 'append',
        'quota_used': 1,
        'quota_limit': 5,
        'max_files': 8,
      });

  @override
  Future<AiImportJob?> fetchJob(String jobId) async =>
      _job(processing ? 'processing' : 'review_required');

  @override
  Future<List<AiImportItem>> fetchItems(String jobId) async => _items();

  @override
  Future<List<AiTemplateSuggestion>> suggestTemplates(
      String jobId, String storeType) async {
    // จำลองตาม seed จริง: แต่ละประเภทได้แม่แบบต่างกัน
    Map<String, dynamic> tpl(String id, String name, int min, int max,
            List<List<Object>> opts, List<String> items) =>
        {
          'template_id': id,
          'name': name,
          'min_selection': min,
          'max_selection': max,
          'options': [
            for (final o in opts) {'label': o[0], 'price': o[1]}
          ],
          'item_ids': items,
          'skipped_item_ids': <String>[],
        };
    final byType = <String, List<Map<String, dynamic>>>{
      'made_to_order': [
        tpl('m1', 'ระดับเผ็ด', 1, 1, [['ไม่เผ็ด', 0], ['เผ็ดน้อย', 0], ['เผ็ดกลาง', 0], ['เผ็ดมาก', 0]], []),
        tpl('m2', 'ไข่', 0, 1, [['ไข่ดาว', 10], ['ไข่เจียว', 15]], []),
      ],
      'noodle': [
        tpl('n1', 'เส้น', 1, 1, [['เส้นเล็ก', 0], ['เส้นใหญ่', 0], ['บะหมี่', 0]], []),
        tpl('n2', 'แบบน้ำ', 1, 1, [['น้ำใส', 0], ['ต้มยำ', 0], ['แห้ง', 0]], []),
      ],
      'isan': [tpl('i1', 'พริก', 1, 1, [['ไม่ใส่พริก', 0], ['พริก 3 เม็ด', 0]], [])],
      'dessert': [tpl('d1', 'ท็อปปิ้งเพิ่ม', 0, 1, [['ท็อปปิ้งเพิ่ม', 10]], [])],
      'other': [tpl('o1', 'ระดับเผ็ด', 1, 1, [['ไม่เผ็ด', 0], ['เผ็ดมาก', 0]], [])],
    };
    if (storeType != 'cafe') {
      return (byType[storeType] ?? const [])
          .map(AiTemplateSuggestion.fromJson)
          .toList();
    }
    return [
        _sweetness(),
        AiTemplateSuggestion.fromJson({
          'template_id': 't2',
          'name': 'ท็อปปิ้ง',
          'min_selection': 0,
          'max_selection': 3,
          'options': [
            {'label': 'ไข่มุก', 'price': 10},
            {'label': 'บุก', 'price': 10},
            {'label': 'วิปครีม', 'price': 10},
          ],
          'item_ids': ['i2', 'i3'],
          'skipped_item_ids': ['i1'],
        }),
      ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSavedSelections(String jobId) async => [];

  @override
  Future<List<AiImportJob>> fetchJobs({int limit = 30}) async => [
        _job('review_required'),
        AiImportJob.fromJson({
          'id': 'job-0',
          'mode': 'append',
          'status': 'published',
          'visibility': 'live',
          'total_files': 2,
          'total_items': 12,
          'created_at': DateTime.now().subtract(const Duration(days: 9)).toIso8601String(),
        }),
      ];
}
