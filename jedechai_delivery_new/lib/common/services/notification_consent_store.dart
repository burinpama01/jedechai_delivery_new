import 'package:shared_preferences/shared_preferences.dart';

class NotificationConsentStore {
  NotificationConsentStore(this.userId);

  final String userId;
  String get _key => 'jdc_notification_consent_v1_$userId';

  Future<bool?> decision() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key);
  }

  Future<bool> isAllowed() async => await decision() == true;

  Future<void> saveDecision(bool allowed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, allowed);
  }
}
