import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_option_group_detail_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/common/models/menu_option.dart';

void main() {
  for (final width in <double>[320, 390, 640]) {
    testWidgets('Option group create form remains usable at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(
        locale: Locale('th'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MerchantOptionGroupDetailScreen(merchantId: 'merchant-test'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(5));
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  }

  testWidgets('existing option price can be edited in the form',
      (tester) async {
    final now = DateTime(2026, 9, 23);
    final group = MenuOptionGroup(
      id: 'group-test',
      merchantId: 'merchant-test',
      name: 'Spice',
      minSelection: 0,
      maxSelection: 1,
      createdAt: now,
      updatedAt: now,
      options: [
        MenuOption(
            id: 'option-test',
            groupId: 'group-test',
            name: 'Mild',
            price: 10,
            isAvailable: true,
            createdAt: now,
            updatedAt: now)
      ],
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MerchantOptionGroupDetailScreen(
          merchantId: 'merchant-test', group: group),
    ));

    expect(find.text('Mild'), findsOneWidget);
    final priceField = find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.initialValue == '10');
    expect(priceField, findsOneWidget);
    await tester.enterText(priceField, '25');
    await tester.pump();
    expect(find.text('25'), findsOneWidget);
    expect(group.options!.single.price, 10,
        reason: 'Edits must not mutate the original options before save');
    await tester.ensureVisible(find.byIcon(Icons.remove_circle));
    await tester.tap(find.byIcon(Icons.remove_circle));
    await tester.pump();
    expect(group.options!.single.id, 'option-test',
        reason: 'Removed options must remain in the original save snapshot');
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding an option keeps the new price editable', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MerchantOptionGroupDetailScreen(merchantId: 'merchant-test'),
    ));
    await tester.enterText(find.byType(TextFormField).at(3), 'Extra rice');
    await tester.enterText(find.byType(TextFormField).at(4), '15');
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Extra rice'), findsOneWidget);
    final priceField = find.byWidgetPredicate(
        (widget) => widget is TextFormField && widget.initialValue == '15');
    expect(priceField, findsOneWidget);
    await tester.enterText(priceField, '20');
    await tester.pump();
    expect(find.text('20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'existing choices stay reachable before the add form on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 9, 25);
    final group = MenuOptionGroup(
      id: 'group-test',
      merchantId: 'merchant-test',
      name: 'Spice',
      minSelection: 0,
      maxSelection: 1,
      createdAt: now,
      updatedAt: now,
      options: [
        MenuOption(
          id: 'option-test',
          groupId: 'group-test',
          name: 'Mild',
          price: 10,
          isAvailable: true,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MerchantOptionGroupDetailScreen(
        merchantId: 'merchant-test',
        group: group,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Mild'));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byIcon(Icons.add));
    expect(tester.getTopLeft(find.text('Mild')).dy,
        lessThan(tester.getTopLeft(find.byIcon(Icons.add)).dy));
    expect(tester.takeException(), isNull);
  });
}
