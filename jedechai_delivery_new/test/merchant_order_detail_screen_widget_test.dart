import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/order_detail_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  group('MerchantOrderDetailScreen widget', () {
    Map<String, dynamic> _baseOrder({
      Map<String, dynamic>? overrides,
    }) {
      return {
        'id': 'booking_1',
        'status': 'completed',
        'service_type': 'food',
        'customer_name': 'ลูกค้า',
        'driver_id': null,
        'price': 100,
        'delivery_fee': 20,
        'distance_km': 3,
        'created_at': '2026-01-01T00:00:00.000Z',
        'pickup_address': 'ร้าน A',
        'destination_address': 'บ้าน B',
        ...?overrides,
      };
    }

    testWidgets('does not show delivery fee row/text (ค่าส่ง) in merchant view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MerchantOrderDetailScreen(
            order: _baseOrder(),
            loadRemoteData: false,
            enableRealtimeListener: false,
            enableAutoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('ค่าส่ง'), findsNothing);
    });

    testWidgets('does not show coupon/discount breakdown text in merchant view', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MerchantOrderDetailScreen(
            order: _baseOrder(overrides: {
              'coupon_code': 'WELCOME20',
              'coupon_discount': 20,
              'discount_amount': 20,
            }),
            loadRemoteData: false,
            enableRealtimeListener: false,
            enableAutoRefresh: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('คูปอง'), findsNothing);
      expect(find.textContaining('ส่วนลด'), findsNothing);
      expect(find.textContaining('discount'), findsNothing);
      expect(find.textContaining('coupon'), findsNothing);
    });
  });
}
