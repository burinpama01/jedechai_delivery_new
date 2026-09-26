import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jedechai_delivery_new/common/services/notification_consent_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unknown consent does not authorize notification setup', () async {
    SharedPreferences.setMockInitialValues({});
    final store = NotificationConsentStore('user-a');
    expect(await store.decision(), isNull);
    expect(await store.isAllowed(), isFalse);
  });

  test('only explicit acceptance authorizes setup', () async {
    SharedPreferences.setMockInitialValues({});
    final store = NotificationConsentStore('user-a');
    await store.saveDecision(false);
    expect(await store.isAllowed(), isFalse);
    await store.saveDecision(true);
    expect(await store.isAllowed(), isTrue);
  });
}
