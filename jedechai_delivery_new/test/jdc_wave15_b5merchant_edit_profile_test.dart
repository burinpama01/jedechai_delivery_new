import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/profile/edit_merchant_profile_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';

void main() {
  for (final size in <Size>[
    const Size(390, 844),
    const Size(360, 640),
    const Size(834, 1112),
    const Size(844, 390),
  ]) {
    testWidgets('merchant edit profile keeps save reachable at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EditMerchantProfileScreen(
          currentName: 'Test shop',
          currentEmail: 'shop@example.test',
        ),
      ));
      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byType(ElevatedButton).hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(find.byType(ElevatedButton)).dy,
          lessThanOrEqualTo(size.height));
    });
  }
}
