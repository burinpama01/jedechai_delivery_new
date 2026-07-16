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
    // ร้านอาหารที่ยังไม่ผ่านการอนุมัติต้องเลือกแพ็กเกจ GP ก่อน
    // (กัน state ค้างเมื่อบันทึกโปรไฟล์สำเร็จแต่เลือกแพลนไม่สำเร็จ)
    // ร้านซักรีดใช้อัตรา GP ฝั่ง laundry ที่แอดมินตั้ง ไม่ต้องเลือกแพลน
    final approvalStatus = (profile['approval_status'] as String? ?? '').trim();
    final serviceType =
        normalizeMerchantServiceType(profile['merchant_service_types']);
    if (approvalStatus != 'approved' &&
        serviceType == 'food' &&
        (profile['gp_plan_id']?.toString().trim().isNotEmpty != true)) {
      return false;
    }
  }

  return true;
}
