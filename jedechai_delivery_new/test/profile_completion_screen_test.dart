import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/widgets/profile_completion_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('merchant profile completion requires a service type choice',
      (tester) async {
    await tester.pumpWidget(
      wrapWithApp(
        ProfileCompletionScreen(
          role: 'merchant',
          existingProfile: const {
            'full_name': 'ร้านทดสอบ',
            'phone_number': '0812345678',
            'shop_address': '123 Test Road',
          },
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ประเภทร้าน'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Laundry'), findsOneWidget);
  });
}
