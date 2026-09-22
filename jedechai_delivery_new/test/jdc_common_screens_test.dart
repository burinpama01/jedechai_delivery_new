// T1.F — widget test หน้าจอ/วิดเจ็ตที่ใช้ร่วมกันทุก role หลังย้ายมาใช้ token
// ต้องเปิดได้ไม่พัง layout ทั้งจอเล็กสุด แท็บเล็ต มือถือแนวนอน และโหมดมืด
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/common/screens/notification_center_screen.dart';
import 'package:jedechai_delivery_new/common/screens/profile_screen.dart';
import 'package:jedechai_delivery_new/common/widgets/account_suspended_screen.dart';
import 'package:jedechai_delivery_new/common/widgets/chat_screen.dart';
import 'package:jedechai_delivery_new/common/widgets/pending_approval_screen.dart';
import 'package:jedechai_delivery_new/common/widgets/pending_deletion_screen.dart';
import 'package:jedechai_delivery_new/common/widgets/profile_completion_screen.dart';
import 'package:jedechai_delivery_new/common/widgets/reviews_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _dataErrors = [
  'unauthenticated',
  'not authenticated',
  'User not found',
  'PostgrestException',
  'AuthRetryableFetchException',
  'AuthException',
  'SocketException',
  'Failed host lookup',
  'ClientException',
  'Connection refused',
  'MissingPluginException',
  'Multiple exceptions',
];

const _layoutErrors = [
  'overflowed',
  'RenderFlex',
  'RenderBox was not laid out',
  'Incorrect use of ParentData',
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.invalid
SUPABASE_ANON_KEY=test-anon-key
''');
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(
      url: 'https://test.invalid',
      anonKey: 'test-anon-key',
    );
  });

  const sizes = {
    'จอเล็ก 360x640': Size(360, 640),
    'แท็บเล็ต 834x1112': Size(834, 1112),
  };
  const landscape = Size(640, 360);

  final screens = <String, Widget Function()>{
    'โปรไฟล์ (ใช้ร่วม)': () => const ProfileScreen(),
    'ศูนย์การแจ้งเตือน': () => const NotificationCenterScreen(role: 'customer'),
    'บัญชีถูกระงับ': () => const AccountSuspendedScreen(role: 'customer'),
    'รออนุมัติ': () => const PendingApprovalScreen(role: 'driver'),
    'รอลบบัญชี': () => const PendingDeletionScreen(),
    'รีวิว': () => const ReviewsScreen(targetRole: 'driver', title: 'รีวิว'),
    'กรอกข้อมูลโปรไฟล์': () => ProfileCompletionScreen(
          role: 'customer',
          onCompleted: () {},
        ),
    'แชท': () => const ChatScreen(
          bookingId: 'test-booking',
          chatRoomId: 'test-room',
          otherPartyName: 'ครัวป้าน้อย',
          roomType: 'booking',
        ),
  };

  void expectNoLayoutError(WidgetTester tester) {
    final error = tester.takeException();
    if (error == null) return;
    final text = error.toString();
    if (_layoutErrors.any(text.contains)) {
      fail('เจอปัญหา layout: $text');
    }
    expect(_dataErrors.any(text.contains), isTrue,
        reason: 'เจอ error ที่ไม่ใช่เรื่องข้อมูล: $text');
  }

  Future<void> openAndCheck(
    WidgetTester tester,
    Size size,
    Widget screen, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expectNoLayoutError(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  for (final entry in screens.entries) {
    for (final sizeEntry in sizes.entries) {
      testWidgets('${entry.key} เปิดได้บน${sizeEntry.key}', (tester) async {
        await openAndCheck(tester, sizeEntry.value, entry.value());
      });
    }

    testWidgets('${entry.key} เปิดได้บนมือถือแนวนอน 640x360', (tester) async {
      await openAndCheck(tester, landscape, entry.value());
    });

    testWidgets('${entry.key} เปิดได้ในโหมดมืด', (tester) async {
      await openAndCheck(tester, const Size(390, 844), entry.value(),
          theme: AppTheme.darkTheme);
    });
  }
}
