class OrderCodeFormatter {
  static const String _defaultPrefix = 'JD';

  static const Map<String, String> _servicePrefixes = {
    'food': 'FD',
    'ride': 'RD',
    'parcel': 'PC',
  };

  static String format(
    String? rawId, {
    String prefix = _defaultPrefix,
    int length = 8,
  }) {
    final cleaned = (rawId ?? '').trim().replaceAll('-', '').toUpperCase();
    if (cleaned.isEmpty) {
      return '$prefix-UNKNOWN';
    }

    final clipped = cleaned.length > length
        ? cleaned.substring(0, length)
        : cleaned;
    return '$prefix-$clipped';
  }

  static String formatByServiceType(
    String? rawId, {
    String? serviceType,
    int length = 8,
  }) {
    final prefix = _servicePrefixes[(serviceType ?? '').trim().toLowerCase()] ??
        _defaultPrefix;
    return format(rawId, prefix: prefix, length: length);
  }
}
