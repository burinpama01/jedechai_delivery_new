bool isShopOpenNow(Map<String, dynamic> merchant, {DateTime? nowUtc}) {
  final autoEnabled = merchant['shop_auto_schedule_enabled'] == true;
  final rawStatus = merchant['shop_status'];
  final statusOpen = rawStatus == true || rawStatus == 1 || rawStatus == 'true';

  if (!autoEnabled) {
    return statusOpen;
  }

  final openStr = (merchant['shop_open_time'] as String?)?.trim();
  final closeStr = (merchant['shop_close_time'] as String?)?.trim();
  if (openStr == null || closeStr == null) {
    return statusOpen;
  }

  final openParts = openStr.split(':');
  final closeParts = closeStr.split(':');
  if (openParts.length < 2 || closeParts.length < 2) {
    return statusOpen;
  }

  final openHour = int.tryParse(openParts[0]);
  final openMinute = int.tryParse(openParts[1]);
  final closeHour = int.tryParse(closeParts[0]);
  final closeMinute = int.tryParse(closeParts[1]);
  if (openHour == null ||
      openMinute == null ||
      closeHour == null ||
      closeMinute == null) {
    return statusOpen;
  }

  // Shop schedules are configured in Bangkok time.
  final bangkokNow =
      (nowUtc ?? DateTime.now().toUtc()).add(const Duration(hours: 7));
  final nowMinutes = bangkokNow.hour * 60 + bangkokNow.minute;
  final openMinutes = openHour * 60 + openMinute;
  final closeMinutes = closeHour * 60 + closeMinute;

  final withinHours = openMinutes <= closeMinutes
      ? nowMinutes >= openMinutes && nowMinutes < closeMinutes
      : nowMinutes >= openMinutes || nowMinutes < closeMinutes;

  final rawDays = merchant['shop_open_days'];
  if (rawDays is List && rawDays.isNotEmpty) {
    const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final todayKey = weekdayKeys[bangkokNow.weekday - 1];
    final allowedDays = rawDays
        .map((e) => e.toString().toLowerCase().trim())
        .where((e) => weekdayKeys.contains(e))
        .toSet();
    if (allowedDays.isNotEmpty && !allowedDays.contains(todayKey)) {
      return false;
    }
  }

  return withinHours;
}
