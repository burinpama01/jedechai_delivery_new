import 'dart:convert';

String formatAddressValue(
  dynamic address, {
  required String unknownLabel,
  required String currentLocationLabel,
}) {
  if (address == null) return unknownLabel;

  if (address is Map) {
    return _formatAddressMap(address, unknownLabel: unknownLabel);
  }

  if (address is String) {
    final coordPattern = RegExp(r'ตำแหน่ง:\s*[\d.]+,\s*[\d.]+');
    if (coordPattern.hasMatch(address)) {
      final cleaned = address
          .replaceAll(coordPattern, '')
          .replaceAll(RegExp(r'\s*[—\-]\s*$'), '')
          .trim();
      return cleaned.isNotEmpty ? cleaned : currentLocationLabel;
    }

    final trimmed = address.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return _formatAddressMap(decoded, unknownLabel: address);
        }
      } catch (_) {
        return address;
      }
    }

    if (address.contains('Instance of')) return unknownLabel;
    return address;
  }

  if (address.toString().contains('AddressPlacemark')) return unknownLabel;
  return address.toString();
}

String _formatAddressMap(
  Map<dynamic, dynamic> address, {
  required String unknownLabel,
}) {
  final parts = <String>[];
  void addPart(String key) {
    final value = address[key]?.toString().trim();
    if (value != null && value.isNotEmpty) parts.add(value);
  }

  final addressValue = address['address']?.toString().trim();
  if (addressValue != null && addressValue.isNotEmpty) {
    addPart('address');
  } else {
    addPart('street');
  }
  addPart('subLocality');
  addPart('locality');
  addPart('administrativeArea');
  addPart('country');

  return parts.isNotEmpty ? parts.join(', ') : unknownLabel;
}
