const validMerchantServiceTypes = {'food', 'laundry'};

String? normalizeMerchantServiceType(dynamic value) {
  final raw = value is Iterable && value.length == 1 ? value.first : value;
  final serviceType = raw?.toString().trim().toLowerCase();
  if (validMerchantServiceTypes.contains(serviceType)) {
    return serviceType;
  }
  return null;
}

bool hasValidMerchantServiceType(dynamic value) {
  return normalizeMerchantServiceType(value) != null;
}

bool isProfileCompleteForRole(Map<String, dynamic> profile) {
  final role = profile['role'] as String? ?? '';
  final fullName = (profile['full_name'] as String? ?? '').trim();
  final phone = (profile['phone_number'] as String? ?? '').trim();

  if (fullName.isEmpty || phone.isEmpty) return false;

  if (role == 'driver') {
    final licensePlate = (profile['license_plate'] as String? ?? '').trim();
    if (licensePlate.isEmpty) return false;
  }

  if (role == 'merchant') {
    final shopAddress = (profile['shop_address'] as String? ?? '').trim();
    if (shopAddress.isEmpty) return false;
    if (!hasValidMerchantServiceType(profile['merchant_service_types'])) {
      return false;
    }
  }

  return true;
}
