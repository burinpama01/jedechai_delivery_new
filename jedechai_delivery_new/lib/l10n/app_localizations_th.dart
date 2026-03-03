// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appName => 'JDC Delivery';

  @override
  String get language => 'ภาษา';

  @override
  String get useSystemLanguage => 'ใช้ภาษาระบบ';

  @override
  String get thai => 'ไทย';

  @override
  String get english => 'อังกฤษ';

  @override
  String get commonOk => 'ตกลง';

  @override
  String get loginWelcomeTitle => 'ยินดีต้อนรับ';

  @override
  String get loginWelcomeSubtitle => 'เข้าสู่ระบบเพื่อเริ่มใช้งาน';

  @override
  String get loginEmailLabel => 'อีเมล';

  @override
  String get loginPasswordLabel => 'รหัสผ่าน';

  @override
  String get loginForgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get loginButton => 'เข้าสู่ระบบ';

  @override
  String get loginNoAccountPrefix => 'ยังไม่มีบัญชี? ';

  @override
  String get loginRegisterButton => 'สมัครสมาชิก';

  @override
  String get loginSuccessSnack => 'เข้าสู่ระบบสำเร็จ';

  @override
  String get loginBackPressToExit => 'กดอีกครั้งเพื่อออกจากแอป';

  @override
  String get loginErrorDialogTitle => 'เข้าสู่ระบบไม่สำเร็จ';

  @override
  String get loginValidationEmailRequired => 'กรุณากรอกอีเมล';

  @override
  String get loginValidationEmailInvalid => 'อีเมลไม่ถูกต้อง';

  @override
  String get loginValidationPasswordRequired => 'กรุณากรอกรหัสผ่าน';

  @override
  String get loginValidationPasswordMinLength => 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';

  @override
  String get loginErrorInvalidCredentials => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง\nกรุณาตรวจสอบแล้วลองใหม่อีกครั้ง';

  @override
  String get loginErrorEmailNotConfirmed => 'อีเมลยังไม่ได้ยืนยัน\nกรุณาตรวจสอบอีเมลของคุณ';

  @override
  String get loginErrorUserNotFound => 'ไม่พบบัญชีผู้ใช้นี้\nกรุณาสมัครสมาชิกก่อน';

  @override
  String get loginErrorTooManyRequests => 'คุณลองเข้าสู่ระบบบ่อยเกินไป\nกรุณารอสักครู่แล้วลองใหม่';

  @override
  String get loginErrorCannotConnect => 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบอินเทอร์เน็ตของคุณ';

  @override
  String get loginErrorNetwork => 'เกิดปัญหาด้านเครือข่าย\nกรุณาลองใหม่อีกครั้ง';

  @override
  String get loginErrorGeneric => 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

  @override
  String get registerTitle => 'สมัครสมาชิก';

  @override
  String get registerHeader => 'สร้างบัญชีใหม่';

  @override
  String get registerSubheader => 'กรุณากรอกข้อมูลเพื่อสมัครสมาชิก';

  @override
  String get registerSelectRole => 'เลือกประเภทบัญชี';

  @override
  String get registerFullNameLabel => 'ชื่อ-นามสกุล';

  @override
  String get registerShopNameLabel => 'ชื่อร้าน';

  @override
  String get registerPhoneLabel => 'เบอร์โทรศัพท์';

  @override
  String get registerEmailLabel => 'อีเมล';

  @override
  String get registerReferralCodeLabel => 'โค้ดแนะนำจากเพื่อน (ถ้ามี)';

  @override
  String get registerPasswordLabel => 'รหัสผ่าน';

  @override
  String get registerConfirmPasswordLabel => 'ยืนยันรหัสผ่าน';

  @override
  String get registerButton => 'สมัครสมาชิก';

  @override
  String get registerHaveAccountPrefix => 'มีบัญชีแล้ว? ';

  @override
  String get registerGoToLogin => 'เข้าสู่ระบบ';

  @override
  String get registerValidationFullNameRequired => 'กรุณากรอกชื่อ-นามสกุล';

  @override
  String get registerValidationShopNameRequired => 'กรุณากรอกชื่อร้าน';

  @override
  String get registerValidationPhoneRequired => 'กรุณากรอกเบอร์โทรศัพท์';

  @override
  String get registerValidationPhoneInvalid => 'เบอร์โทรศัพท์ไม่ถูกต้อง';

  @override
  String get registerValidationEmailRequired => 'กรุณากรอกอีเมล';

  @override
  String get registerValidationEmailInvalid => 'อีเมลไม่ถูกต้อง';

  @override
  String get registerValidationPasswordRequired => 'กรุณากรอกรหัสผ่าน';

  @override
  String get registerValidationPasswordMinLength => 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';

  @override
  String get registerValidationConfirmPasswordRequired => 'กรุณายืนยันรหัสผ่าน';

  @override
  String get registerValidationPasswordMismatch => 'รหัสผ่านไม่ตรงกัน';

  @override
  String get registerErrorDialogTitle => 'สมัครไม่สำเร็จ';

  @override
  String get registerErrorPasswordMismatch => 'รหัสผ่านไม่ตรงกัน\nกรุณาตรวจสอบแล้วลองใหม่';

  @override
  String get registerErrorPhoneUsed => 'เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว\nกรุณาใช้เบอร์โทรอื่นหรือเข้าสู่ระบบ';

  @override
  String get registerErrorEmailUsed => 'อีเมลนี้ถูกใช้งานแล้ว\nกรุณาเข้าสู่ระบบหรือใช้อีเมลอื่น';

  @override
  String get registerErrorEmailAlreadyRegistered => 'อีเมลนี้ถูกใช้งานแล้ว\nกรุณาเข้าสู่ระบบหรือใช้อีเมลอื่น';

  @override
  String get registerErrorWeakPassword => 'รหัสผ่านไม่ปลอดภัย\nกรุณาใช้รหัสผ่านที่มีความยาวอย่างน้อย 6 ตัวอักษร';

  @override
  String get registerErrorInvalidEmail => 'รูปแบบอีเมลไม่ถูกต้อง\nกรุณาตรวจสอบอีเมลของคุณ';

  @override
  String get registerErrorCannotConnect => 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบอินเทอร์เน็ตของคุณ';

  @override
  String get registerErrorTooManyRequests => 'คุณลองบ่อยเกินไป\nกรุณารอสักครู่แล้วลองใหม่';

  @override
  String get registerErrorGeneric => 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

  @override
  String get registerSuccessTitle => 'สมัครสำเร็จ!';

  @override
  String get registerSuccessBody => 'ลงทะเบียนเรียบร้อยแล้ว\nกรุณาเข้าสู่ระบบเพื่อเริ่มใช้งาน';

  @override
  String get registerSuccessGoToLogin => 'เข้าสู่ระบบ';

  @override
  String get forgotPasswordTitle => 'ลืมรหัสผ่าน';

  @override
  String get forgotPasswordHeader => 'ลืมรหัสผ่าน?';

  @override
  String get forgotPasswordSubheader => 'กรุณากรอกอีเมลของคุณเพื่อรับลิงก์รีเซ็ตรหัส';

  @override
  String get forgotPasswordEmailLabel => 'อีเมล';

  @override
  String get forgotPasswordEmailRequired => 'กรุณากรอกอีเมล';

  @override
  String get forgotPasswordEmailInvalid => 'กรุณากรอกอีเมลที่ถูกต้อง';

  @override
  String get forgotPasswordSubmit => 'ส่งอีเมลรีเซ็ตรหัส';

  @override
  String get forgotPasswordBackToLogin => 'กลับไปหน้าเข้าสู่ระบบ';

  @override
  String get forgotPasswordErrorDialogTitle => 'ส่งอีเมลไม่สำเร็จ';

  @override
  String get forgotPasswordSuccessTitle => 'ส่งอีเมลสำเร็จ!';

  @override
  String forgotPasswordSuccessBody(Object email) {
    return 'ลิงก์รีเซ็ตรหัสผ่านถูกส่งไปที่\n$email\n\nกรุณาตรวจสอบอีเมลของคุณ';
  }

  @override
  String forgotPasswordSuccessBodyMock(Object email) {
    return 'โหมดทดสอบ (Mock Mode)\nระบบจำลองการส่งอีเมลไปที่\n$email\n\n*จะไม่มีอีเมลจริงถูกส่ง*';
  }

  @override
  String get forgotPasswordSuccessGoToLogin => 'กลับไปเข้าสู่ระบบ';

  @override
  String get forgotPasswordErrorUserNotFound => 'ไม่พบบัญชีที่ใช้อีเมลนี้\nกรุณาตรวจสอบอีเมลของคุณ';

  @override
  String get forgotPasswordErrorTooManyRequests => 'คุณส่งคำขอบ่อยเกินไป\nกรุณารอสักครู่แล้วลองใหม่';

  @override
  String get forgotPasswordErrorCannotConnect => 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้\nกรุณาตรวจสอบอินเทอร์เน็ตของคุณ';

  @override
  String get forgotPasswordErrorGeneric => 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

  @override
  String get foodCategoryAll => 'ทั้งหมด';

  @override
  String get foodCategoryMadeToOrder => 'อาหารตามสั่ง';

  @override
  String get foodCategoryNoodles => 'ก๋วยเตี๋ยว';

  @override
  String get foodCategoryDrinks => 'เครื่องดื่ม';

  @override
  String get foodCategoryDesserts => 'ของหวาน';

  @override
  String get foodCategoryFastFood => 'ฟาสต์ฟู้ด';

  @override
  String get foodHomeTitle => 'สั่งอาหาร';

  @override
  String get foodHomeSearchHint => 'ค้นหาร้านอาหาร...';

  @override
  String get foodHomeTopSelling => 'สินค้าขายดี';

  @override
  String foodHomeTopCount(Object count) {
    return 'Top $count';
  }

  @override
  String foodHomeSoldCount(Object count) {
    return '$count ขายแล้ว';
  }

  @override
  String get foodHomeNearbyTitle => 'ร้านอาหารใกล้คุณ';

  @override
  String foodHomeRestaurantCount(Object count) {
    return '$count ร้าน';
  }

  @override
  String get foodHomeLoading => 'กำลังโหลดร้านอาหาร...';

  @override
  String get foodHomeErrorTitle => 'ไม่สามารถโหลดข้อมูลได้';

  @override
  String get foodHomeErrorSubtitle => 'กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต';

  @override
  String get foodHomeRetry => 'ลองใหม่';

  @override
  String get foodHomeEmptySearch => 'ไม่พบร้านอาหารที่ค้นหา';

  @override
  String get foodHomeEmptyNoArea => 'ในพื้นที่ของคุณยังไม่มีร้านอาหาร';

  @override
  String get foodHomeEmptyNoneOpen => 'ไม่มีร้านอาหารเปิดให้บริการ';

  @override
  String get foodHomeEmptySearchHint => 'ลองค้นหาด้วยคำอื่น';

  @override
  String foodHomeEmptyNoAreaHint(Object radius) {
    return 'ไม่พบร้านอาหารที่เปิดอยู่ภายในรัศมี $radius กม.';
  }

  @override
  String get foodHomeEmptyTryLater => 'กรุณาลองใหม่ภายหลัง';

  @override
  String get foodHomeRestaurantDefault => 'ร้านอาหาร';

  @override
  String get foodHomeOpenBadge => 'เปิด';

  @override
  String foodHomeDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String get foodHomeEstTime => '20-30 นาที';

  @override
  String get foodPromoCodeTitle => 'โค้ดส่วนลด';

  @override
  String get foodPromoCodeHint => 'นำโค้ดนี้ไปใช้ตอนสั่งซื้อเพื่อรับส่วนลด';

  @override
  String foodPromoCodeCopied(Object code) {
    return 'คัดลอกโค้ด \"$code\" แล้ว';
  }

  @override
  String get foodPromoCodeClose => 'ปิด';

  @override
  String get foodPromoCodeCopy => 'คัดลอกโค้ด';

  @override
  String get foodCartViewCart => 'ดูตะกร้า';

  @override
  String get foodCartTitle => 'ตะกร้าของคุณ';

  @override
  String get foodCartClear => 'ล้าง';

  @override
  String get foodCartEmpty => 'ตะกร้าว่างเปล่า';

  @override
  String get foodCartFoodCost => 'ค่าอาหาร';

  @override
  String get foodCartDeliveryFee => 'ค่าจัดส่ง';

  @override
  String get foodCartDeliveryCalcLater => 'คำนวณเมื่อสั่ง';

  @override
  String get foodCartTotal => 'รวมทั้งหมด';

  @override
  String get foodCartOrderButton => 'สั่งอาหาร';

  @override
  String get foodCheckoutTitle => 'ยืนยันคำสั่งซื้อ';

  @override
  String get foodCheckoutRestaurant => 'ร้านอาหาร';

  @override
  String get foodCheckoutDeliveryAddress => 'ที่อยู่จัดส่ง';

  @override
  String get foodCheckoutCurrentLocation => 'ตำแหน่งปัจจุบัน';

  @override
  String foodCheckoutItemsTitle(Object count) {
    return 'รายการอาหาร ($count รายการ)';
  }

  @override
  String get foodCheckoutNoteTitle => 'หมายเหตุถึงร้าน';

  @override
  String get foodCheckoutNoteHint => 'เช่น ไม่ใส่ผัก, เผ็ดน้อย...';

  @override
  String get foodCheckoutPaymentTitle => 'วิธีชำระเงิน';

  @override
  String get foodCheckoutPayCash => 'เงินสด';

  @override
  String get foodCheckoutPayTransfer => 'โอนเงิน';

  @override
  String get foodCheckoutDeliveryEstimate => 'ค่าจัดส่ง (โดยประมาณ)';

  @override
  String get foodCheckoutConfirmButton => 'ยืนยันสั่งอาหาร';

  @override
  String get foodCheckoutSuccess => 'สั่งอาหารสำเร็จ!';

  @override
  String get foodCheckoutLoginRequired => 'กรุณาเข้าสู่ระบบ';

  @override
  String get foodCheckoutCreateFailed => 'ไม่สามารถสร้างออเดอร์ได้';

  @override
  String foodCheckoutOrderFailed(Object error) {
    return 'ไม่สามารถสั่งอาหารได้: $error';
  }

  @override
  String get foodCheckoutNotifTitle => '🍔 มีออเดอร์ใหม่!';

  @override
  String foodCheckoutNotifBody(Object amount) {
    return 'มีลูกค้าสั่งอาหาร ฿$amount กรุณายืนยันออเดอร์';
  }

  @override
  String get foodScheduleTitle => 'เวลาจัดส่ง';

  @override
  String get foodScheduleNow => 'จัดส่งทันที';

  @override
  String get foodScheduleNowDesc => 'ร้านจะเริ่มเตรียมอาหารทันทีหลังยืนยันออเดอร์';

  @override
  String get foodScheduleLater => 'ตั้งเวลาจัดส่ง';

  @override
  String get foodScheduleLaterDesc => 'เลือกวันและเวลาที่ต้องการรับอาหาร';

  @override
  String foodScheduleLaterSet(Object dateTime) {
    return 'กำหนดไว้: $dateTime';
  }

  @override
  String get foodSchedulePickDate => 'เลือกวันที่จัดส่ง';

  @override
  String get foodSchedulePickTime => 'เลือกเวลาจัดส่ง';

  @override
  String get foodScheduleMinTime => 'กรุณาเลือกเวลาอย่างน้อย 20 นาทีจากเวลาปัจจุบัน';

  @override
  String get foodScheduleRequired => 'กรุณาเลือกวันเวลาจัดส่ง';

  @override
  String get foodDistanceWarningTitle => 'อยู่นอกระยะทางที่กำหนด';

  @override
  String foodDistanceWarningBody(Object distance, Object maxRadius) {
    return 'ตำแหน่งจัดส่งของคุณอยู่ห่างจากร้านค้า $distance กม.\nซึ่งเกินระยะเริ่มต้นที่กำหนดไว้ $maxRadius กม.';
  }

  @override
  String foodDistanceWarningFee(Object fee) {
    return 'ค่าส่งจะคิดตามระยะทางจริง: ฿$fee';
  }

  @override
  String get foodDistanceWarningOk => 'รับทราบ';

  @override
  String get foodAddressCurrentLocation => 'ตำแหน่งปัจจุบัน';

  @override
  String get foodAddressPinOnMap => 'ปักหมุดบนแผนที่';

  @override
  String get foodAddressSaved => 'ที่อยู่ที่บันทึกไว้';

  @override
  String foodAddressDistance(Object km) {
    return 'ระยะทาง: $km กม.';
  }

  @override
  String get foodAddressUnknown => 'ตำแหน่งปัจจุบัน (ไม่สามารถระบุได้)';

  @override
  String foodDeliveryFeeWithDist(Object km) {
    return 'ค่าจัดส่ง ($km กม.)';
  }

  @override
  String get foodCalculating => 'กำลังคำนวณ...';

  @override
  String get foodCouponDiscount => 'ส่วนลดจากคูปอง';

  @override
  String get foodCheckoutLocationRequired => 'ไม่สามารถระบุตำแหน่งจัดส่งได้ กรุณาเลือกตำแหน่ง';

  @override
  String get foodCheckoutNoResponse => 'ไม่ได้รับข้อมูลออเดอร์จากเซิร์ฟเวอร์';

  @override
  String get foodCheckoutFailedTitle => 'สั่งอาหารไม่สำเร็จ';

  @override
  String foodCheckoutSuccessScheduled(Object dateTime) {
    return 'ตั้งเวลาสั่งอาหารสำเร็จ ($dateTime)';
  }

  @override
  String get foodCheckoutSuccessNow => 'สั่งอาหารสำเร็จ! รอร้านค้ายืนยัน';

  @override
  String foodCheckoutNotifScheduledBody(Object amount, Object dateTime) {
    return 'มีลูกค้าสั่งอาหารล่วงหน้า ฿$amount เวลา $dateTime';
  }

  @override
  String get orderDetailScreenTitle => 'รายละเอียดออเดอร์';

  @override
  String get orderDetailCancel => 'ยกเลิก';

  @override
  String orderDetailOrderId(Object code) {
    return 'ออเดอร์ $code';
  }

  @override
  String orderDetailOrderedAt(Object dateTime) {
    return 'สั่งเมื่อ: $dateTime';
  }

  @override
  String get orderDetailLocationTitle => 'สถานที่';

  @override
  String get orderDetailPickup => 'จุดรับ';

  @override
  String get orderDetailDestination => 'จุดหมายปลายทาง';

  @override
  String get orderDetailDriverTitle => 'ข้อมูลคนขับ';

  @override
  String get orderDetailDriverUnnamed => 'ไม่ระบุชื่อ';

  @override
  String get orderDetailTrack => 'ติดตาม';

  @override
  String get orderDetailChat => 'แชท';

  @override
  String get orderDetailCall => 'โทร';

  @override
  String orderDetailCannotCall(Object phone) {
    return 'ไม่สามารถโทรไปที่ $phone ได้';
  }

  @override
  String get orderDetailItemsTitle => 'รายการอาหาร';

  @override
  String get orderDetailNoItems => 'ไม่พบรายการอาหาร';

  @override
  String get orderDetailItemUnnamed => 'ไม่ระบุชื่อ';

  @override
  String orderDetailQuantity(Object qty) {
    return 'จำนวน: $qty';
  }

  @override
  String get orderDetailOptionsLabel => 'เพิ่มเติม:';

  @override
  String get orderDetailOptionDefault => 'ตัวเลือก';

  @override
  String get orderDetailAddressUnknown => 'ไม่ระบุที่อยู่';

  @override
  String get orderDetailAddressCurrent => 'ตำแหน่งปัจจุบัน';

  @override
  String get orderDetailPriceTitle => 'รายละเอียดราคา';

  @override
  String get orderDetailFoodCost => 'ค่าอาหาร';

  @override
  String get orderDetailDeliveryFee => 'ค่าจัดส่ง';

  @override
  String get orderDetailCouponDiscount => 'ส่วนลดจากคูปอง';

  @override
  String orderDetailCouponDiscountCode(Object code) {
    return 'ส่วนลดคูปอง ($code)';
  }

  @override
  String get orderDetailDistance => 'ระยะทาง';

  @override
  String orderDetailDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String get orderDetailTotal => 'รวมทั้งหมด';

  @override
  String get orderDetailServiceRide => 'บริการรถส่ง';

  @override
  String get orderDetailServiceFood => 'สั่งอาหาร';

  @override
  String get orderDetailServiceParcel => 'ส่งพัสดุ';

  @override
  String get orderDetailStatusPending => 'รอการยืนยัน';

  @override
  String get orderDetailStatusPendingMerchant => 'รอร้านค้ายืนยัน';

  @override
  String get orderDetailStatusPreparing => 'กำลังเตรียมอาหาร';

  @override
  String get orderDetailStatusReady => 'อาหารพร้อมรับ';

  @override
  String get orderDetailStatusDriverAccepted => 'คนขับรับงานแล้ว';

  @override
  String get orderDetailStatusConfirmed => 'ยืนยันแล้ว';

  @override
  String get orderDetailStatusArrived => 'ถึงจุดรับแล้ว';

  @override
  String get orderDetailStatusPickingUp => 'คนขับกำลังรับออเดอร์';

  @override
  String get orderDetailStatusInTransit => 'กำลังส่งอาหาร';

  @override
  String get orderDetailStatusCompleted => 'เสร็จสิ้น';

  @override
  String get orderDetailStatusCancelled => 'ถูกปฏิเสธ';

  @override
  String get orderDetailCancelledTitle => 'ร้านค้าปฏิเสธออเดอร์';

  @override
  String get orderDetailCancelledBody => 'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้';

  @override
  String get orderDetailOrderNumber => 'หมายเลขออเดอร์';

  @override
  String get orderDetailCancelledRetry => 'กรุณาลองสั่งใหม่อีกครั้ง หรือเลือกร้านอื่น';

  @override
  String get orderDetailUnderstood => 'เข้าใจแล้ว';

  @override
  String get orderDetailChatError => 'ไม่สามารถเปิดแชทได้';

  @override
  String get orderDetailDriverDefault => 'คนขับ';

  @override
  String get orderDetailCompletedFood => '🎉 จัดส่งสำเร็จแล้ว!';

  @override
  String get orderDetailCompletedRide => '🎉 เดินทางเสร็จสิ้น!';

  @override
  String get orderDetailThankYou => 'ขอบคุณที่ใช้บริการ';

  @override
  String get orderDetailTotalAmount => 'ยอดเงินทั้งหมด';

  @override
  String get orderDetailIncludingDelivery => 'รวมค่าจัดส่ง';

  @override
  String orderDetailCouponUsed(Object code, Object amount) {
    return 'ใช้คูปอง $code ลด ฿$amount';
  }

  @override
  String orderDetailCouponUsedNoCode(Object amount) {
    return 'ใช้คูปอง ลด ฿$amount';
  }

  @override
  String get orderDetailCancelConfirmTitle => 'ยืนยันการยกเลิกออเดอร์';

  @override
  String get orderDetailCancelConfirmBody => 'คุณต้องการยกเลิกออเดอร์นี้ใช่หรือไม่?';

  @override
  String get orderDetailCancelNote => 'หมายเหตุ: ไม่สามารถยกเลิกออเดอร์ที่กำลังดำเนินการได้';

  @override
  String get orderDetailCancelKeep => 'ไม่ยกเลิก';

  @override
  String get orderDetailCancelConfirm => 'ยืนยันยกเลิก';

  @override
  String get orderDetailCancelling => 'กำลังยกเลิกออเดอร์...';

  @override
  String get orderDetailCancelSuccess => 'ออเดอร์ถูกยกเลิกเรียบร้อยแล้ว';

  @override
  String orderDetailCancelError(Object error) {
    return 'ไม่สามารถยกเลิกออเดอร์ได้: $error';
  }

  @override
  String get driverDashTitle => 'แดชบอร์ดคนขับ';

  @override
  String get driverDashOnline => 'ออนไลน์';

  @override
  String get driverDashOffline => 'ออฟไลน์';

  @override
  String get driverDashProfile => 'โปรไฟล์';

  @override
  String get driverDashLogout => 'ออกจากระบบ';

  @override
  String get driverDashJobList => 'รายการงาน';

  @override
  String get driverDashRefreshing => 'กำลังรีเฟรช...';

  @override
  String get driverDashRealtime => 'เรียลไทม์';

  @override
  String get driverDashDriverDefault => 'คนขับ';

  @override
  String get driverDashPendingJobs => 'งานรอรับ';

  @override
  String get driverDashCompletedToday => 'เสร็จวันนี้';

  @override
  String get driverDashEarningsToday => 'รายได้วันนี้';

  @override
  String get driverDashNowOnline => 'คุณออนไลน์แล้ว';

  @override
  String get driverDashNowOffline => 'คุณออฟไลน์แล้ว';

  @override
  String get driverDashOfflineTitle => 'คุณอยู่ในโหมดออฟไลน์';

  @override
  String get driverDashNoJobs => 'ไม่มีงานใหม่';

  @override
  String get driverDashOfflineHint => 'เปิดสถานะออนไลน์เพื่อรับงานใหม่';

  @override
  String get driverDashNoJobsHint => 'งานใหม่จะปรากฏที่นี่ทันที';

  @override
  String get driverDashRefresh => 'รีเฟรช';

  @override
  String driverDashNewJob(Object type, Object status) {
    return '🚨 งานใหม่! $type - $status';
  }

  @override
  String get driverDashViewJob => 'ดูงาน';

  @override
  String get driverDashJobFood => 'ส่งอาหาร';

  @override
  String get driverDashJobRide => 'รับส่งผู้โดยสาร';

  @override
  String get driverDashJobParcel => 'ส่งพัสดุ';

  @override
  String get driverDashJobGeneral => 'งานทั่วไป';

  @override
  String get driverDashStatusPending => 'รอคนขับ';

  @override
  String get driverDashStatusPendingMerchant => 'รอร้านค้ารับ';

  @override
  String get driverDashStatusPreparing => 'กำลังทำอาหาร';

  @override
  String get driverDashStatusMatched => 'จับคู่แล้ว';

  @override
  String get driverDashStatusReady => 'อาหารพร้อม';

  @override
  String get driverDashStatusAccepted => 'รับงานแล้ว';

  @override
  String get driverDashStatusDriverAccepted => 'คนขับรับแล้ว';

  @override
  String get driverDashStatusUnknown => 'ไม่ทราบสถานะ';

  @override
  String get driverDashMustOnline => 'กรุณาเปิดสถานะออนไลน์ก่อนรับงาน';

  @override
  String get driverDashNoUser => 'ไม่พบข้อมูลผู้ใช้';

  @override
  String get driverDashPleaseLogin => 'กรุณาเข้าสู่ระบบใหม่';

  @override
  String get driverDashAccepted => 'รับงานแล้ว! กำลังนำทาง...';

  @override
  String get driverDashErrorTitle => 'เกิดข้อผิดพลาด';

  @override
  String driverDashNavError(Object error) {
    return 'ไม่สามารถเปิดหน้านำทางได้: $error';
  }

  @override
  String get driverDashInsufficientBalance => 'ยอดเงินไม่เพียงพอ';

  @override
  String get driverDashClose => 'ปิด';

  @override
  String get driverDashTopUp => 'เติมเงิน';

  @override
  String get driverDashCannotAccept => 'ไม่สามารถรับงานได้';

  @override
  String get driverDashOk => 'ตกลง';

  @override
  String driverDashErrorGeneric(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get driverDashPickupRestaurant => 'ร้านอาหาร';

  @override
  String get driverDashPickupPoint => 'จุดรับ';

  @override
  String get driverDashPickupFoodFallback => 'ตำแหน่งร้านอาหาร';

  @override
  String get driverDashPickupRideFallback => 'ตำแหน่งปัจจุบัน';

  @override
  String get driverDashDestCustomer => 'ตำแหน่งลูกค้า';

  @override
  String get driverDashDestPoint => 'จุดหมาย';

  @override
  String get driverDashDestFallback => 'จุดหมายปลายทาง';

  @override
  String driverDashScheduledFrom(Object dateTime) {
    return 'งานนัดเวลา: รับได้ตั้งแต่ $dateTime';
  }

  @override
  String driverDashScheduledAt(Object dateTime) {
    return 'งานนัดเวลา: $dateTime';
  }

  @override
  String driverDashAcceptAt(Object dateTime) {
    return 'รับได้เวลา $dateTime';
  }

  @override
  String get driverDashAcceptParcel => 'รับงานส่งพัสดุ';

  @override
  String get driverDashAcceptRide => 'รับงานนี้';

  @override
  String get driverDashAcceptFood => 'รับออเดอร์อาหาร';

  @override
  String get driverDashIncompleteJob => 'งานที่ยังไม่เสร็จ';

  @override
  String get driverDashInProgress => 'กำลังดำเนินการ';

  @override
  String get driverDashGoToNav => 'ไปยังหน้านำทาง';

  @override
  String get driverDashNavigating => 'กำลังไปยังหน้านำทาง...';

  @override
  String driverDashCannotNav(Object error) {
    return 'ไม่สามารถนำทางได้: $error';
  }

  @override
  String get driverDashCollectCustomer => 'เก็บเงินลูกค้า';

  @override
  String get driverDashFoodCost => 'ค่าอาหาร';

  @override
  String get driverDashDeliveryFee => 'ค่าส่ง';

  @override
  String get driverDashDistance => 'ระยะทาง';

  @override
  String driverDashDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String driverDashCouponDiscount(Object amount) {
    return 'ส่วนลดจากคูปอง -฿$amount';
  }

  @override
  String driverDashCouponDiscountCode(Object amount) {
    return 'ส่วนลดคูปอง -฿$amount';
  }

  @override
  String get driverDashTimeJustNow => 'เมื่อสักครู่';

  @override
  String driverDashTimeMinutes(Object min) {
    return '$min นาทีที่แล้ว';
  }

  @override
  String driverDashTimeHours(Object hours) {
    return '$hours ชั่วโมงที่แล้ว';
  }

  @override
  String driverDashTimeDays(Object days) {
    return '$days วันที่แล้ว';
  }

  @override
  String get driverDashVehicleMotorcycle => 'มอเตอร์ไซค์';

  @override
  String get driverDashVehicleCar => 'รถยนต์';

  @override
  String get driverDashNotifFoodTitle => '🍔 คนขับรับออเดอร์แล้ว!';

  @override
  String driverDashNotifFoodBody(Object name) {
    return 'คนขับ $name กำลังมารับอาหารของคุณ';
  }

  @override
  String get driverDashNotifFoodBodyDefault => 'คนขับกำลังมารับอาหารของคุณ';

  @override
  String get driverDashNotifParcelTitle => '📦 คนขับรับพัสดุแล้ว!';

  @override
  String driverDashNotifParcelBody(Object name) {
    return 'คนขับ $name กำลังมารับพัสดุของคุณ';
  }

  @override
  String get driverDashNotifParcelBodyDefault => 'คนขับกำลังมารับพัสดุของคุณ';

  @override
  String get driverDashNotifRideTitle => '🚗 คนขับรับทริปแล้ว!';

  @override
  String driverDashNotifRideBody(Object name) {
    return 'คนขับ $name กำลังมารับคุณ';
  }

  @override
  String get driverDashNotifRideBodyDefault => 'คนขับกำลังมารับคุณ';

  @override
  String get driverDashNotifMerchantTitle => '🚗 คนขับรับออเดอร์แล้ว!';

  @override
  String driverDashNotifMerchantBody(Object name, Object code) {
    return 'คนขับ $name กำลังมารับอาหารออเดอร์ $code';
  }

  @override
  String get driverDashNotifMerchantBodyDefault => 'คนขับกำลังมารับอาหารออเดอร์ของคุณ';

  @override
  String get driverNavCustomerDefault => 'ลูกค้า';

  @override
  String get driverNavPhoneUnknown => 'ไม่ระบุ';

  @override
  String get driverNavMerchantDefault => 'ร้านค้า';

  @override
  String get driverNavLocationPermSnack => 'กรุณาอนุญาตการเข้าถึงตำแหน่งเพื่อใช้งานฟีเจอร์นี้';

  @override
  String get driverNavLocationDeniedTitle => 'ไม่สามารถเข้าถึงตำแหน่ง';

  @override
  String get driverNavLocationDeniedBody => 'กรุณาเปิดการเข้าถึงตำแหน่งในการตั้งค่าของเครื่อง เพื่อใช้งานแอปได้ตามปกติ';

  @override
  String get driverNavOk => 'ตกลง';

  @override
  String get driverNavOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get driverNavNoMerchantPhone => 'ไม่พบเบอร์โทรร้านค้า';

  @override
  String get driverNavCannotCall => 'ไม่สามารถโทรออกได้';

  @override
  String get driverNavCallError => 'เกิดข้อผิดพลาดในการโทร';

  @override
  String get driverNavNoCustomerPhone => 'ไม่พบเบอร์โทรลูกค้า';

  @override
  String get driverNavCancelTitle => 'ยกเลิกงาน';

  @override
  String get driverNavCancelSelectReason => 'กรุณาเลือกเหตุผลในการยกเลิก:';

  @override
  String get driverNavCancelReason1 => 'ลูกค้าไม่รับสาย/ติดต่อไม่ได้';

  @override
  String get driverNavCancelReason2 => 'ร้านค้าปิด/ไม่พร้อมให้บริการ';

  @override
  String get driverNavCancelReason3 => 'ระยะทางไกลเกินไป';

  @override
  String get driverNavCancelReason4 => 'เกิดเหตุฉุกเฉินส่วนตัว';

  @override
  String get driverNavCancelReason5 => 'สภาพอากาศไม่ดี/ถนนไม่สะดวก';

  @override
  String get driverNavCancelReason6 => 'อื่นๆ';

  @override
  String get driverNavCancelWarning => 'การยกเลิกงานบ่อยอาจส่งผลต่อคะแนนของคุณ';

  @override
  String get driverNavCancelBack => 'กลับ';

  @override
  String get driverNavCancelConfirm => 'ยืนยันยกเลิก';

  @override
  String get driverNavCancelNotifTitle => '❌ คนขับยกเลิกงาน';

  @override
  String driverNavCancelNotifBody(Object reason) {
    return 'เหตุผล: $reason';
  }

  @override
  String get driverNavCancelSuccess => 'ยกเลิกงานเรียบร้อยแล้ว';

  @override
  String driverNavCancelError(Object error) {
    return 'ไม่สามารถยกเลิกงาน: $error';
  }

  @override
  String get driverNavMarkerPickup => 'จุดรับ';

  @override
  String get driverNavMarkerPickupFallback => 'ตำแหน่งรับ';

  @override
  String get driverNavMarkerDest => 'จุดหมาย';

  @override
  String get driverNavMarkerDestFallback => 'จุดหมายปลายทาง';

  @override
  String get driverNavMarkerDriver => 'ตำแหน่งคนขับ';

  @override
  String get driverNavMarkerYou => 'ตำแหน่งของคุณ';

  @override
  String get driverNavMarkerPosition => 'ตำแหน่ง';

  @override
  String get driverNavNoDriverData => 'ไม่พบข้อมูลคนขับ กรุณาออกจากระบบและเข้าสู่ระบบใหม่';

  @override
  String get driverNavStatusUpdated => 'อัพเดตสถานะเรียบร้อยแล้ว';

  @override
  String get driverNavPermDenied => 'ไม่มีสิทธิ์ กรุณาตรวจสอบสิทธิ์บัญชีของคุณ';

  @override
  String get driverNavBookingNotFound => 'ไม่พบการจอง กรุณารีเฟรชและลองใหม่';

  @override
  String get driverNavDriverInvalid => 'ข้อมูลคนขับไม่ถูกต้อง กรุณาออกจากระบบและเข้าสู่ระบบใหม่';

  @override
  String driverNavStatusUpdateError(Object error) {
    return 'ไม่สามารถอัพเดตสถานะ: $error';
  }

  @override
  String get driverNavCannotOpenMaps => 'ไม่สามารถเปิด Google Maps ได้';

  @override
  String get driverNavMapsError => 'เกิดข้อผิดพลาดในการเปิดแผนที่นำทาง';

  @override
  String get driverNavFoodArrivedMerchant => 'ถึงร้านแล้ว';

  @override
  String get driverNavFoodWaitReady => 'รออาหารพร้อม';

  @override
  String get driverNavFoodPickup => 'รับอาหาร';

  @override
  String get driverNavFoodStartDelivery => 'เริ่มส่งอาหาร';

  @override
  String get driverNavFoodComplete => 'ส่งอาหารเสร็จสิ้น';

  @override
  String get driverNavParcelArrivedPickup => 'ถึงจุดรับพัสดุแล้ว';

  @override
  String get driverNavParcelStartDelivery => 'รับพัสดุ เริ่มส่ง';

  @override
  String get driverNavParcelComplete => 'ส่งพัสดุเสร็จสิ้น';

  @override
  String get driverNavRideArrivedPickup => 'ถึงจุดรับลูกค้าแล้ว';

  @override
  String get driverNavRideStartTrip => 'รับผู้โดยสาร เริ่มเดินทาง';

  @override
  String get driverNavRideComplete => 'ส่งผู้โดยสารเสร็จสิ้น';

  @override
  String get driverNavUpdateStatus => 'อัพเดตสถานะ';

  @override
  String get driverNavWaitMerchantReady => 'กรุณารอร้านค้ากดอาหารพร้อมก่อน';

  @override
  String driverNavInvalidStatus(Object status) {
    return 'สถานะไม่ถูกต้อง: $status';
  }

  @override
  String get driverNavProxCustomerDest => 'จุดหมายลูกค้า';

  @override
  String get driverNavProxMerchant => 'ร้านค้า';

  @override
  String get driverNavProxRidePickup => 'จุดรับผู้โดยสาร';

  @override
  String get driverNavProxParcelPickup => 'จุดรับพัสดุ';

  @override
  String get driverNavTooFarTitle => 'อยู่ไกลเกินไป';

  @override
  String driverNavTooFarBody(Object current, Object allowed) {
    return 'กรุณาเข้าใกล้จุดหมายมากขึ้น\n\nระยะทางปัจจุบัน: $current เมตร\nระยะทางที่อนุญาต: $allowed เมตร';
  }

  @override
  String driverNavCannotCheckLocation(Object error) {
    return 'ไม่สามารถตรวจสอบตำแหน่ง: $error';
  }

  @override
  String get driverNavChatError => 'ไม่สามารถเปิดแชทได้';

  @override
  String get driverNavChatRoomError => 'ไม่สามารถเปิดห้องแชทได้';

  @override
  String get driverNavChatOpenError => 'เกิดข้อผิดพลาดในการเปิดแชท';

  @override
  String get driverNavOrderItemsTitle => 'รายการอาหาร';

  @override
  String get driverNavOrderItemsEmpty => 'ไม่พบรายการอาหาร';

  @override
  String get driverNavItemUnspecified => 'ไม่ระบุ';

  @override
  String get driverNavOptionsLabel => 'ตัวเลือก:';

  @override
  String get driverNavClose => 'ปิด';

  @override
  String get driverNavLoadItemsError => 'ไม่สามารถโหลดรายการอาหาร';

  @override
  String get driverNavStatusFoodGoingMerchant => 'กำลังไปร้านอาหาร';

  @override
  String get driverNavStatusFoodAtMerchant => 'ถึงร้านแล้ว รออาหาร';

  @override
  String get driverNavStatusFoodReady => 'อาหารพร้อมแล้ว';

  @override
  String get driverNavStatusFoodPickedUp => 'รับอาหารแล้ว';

  @override
  String get driverNavStatusFoodDelivering => 'กำลังส่งอาหาร...';

  @override
  String get driverNavStatusParcelGoing => 'กำลังไปรับพัสดุ';

  @override
  String get driverNavStatusParcelArrived => 'ถึงจุดรับพัสดุแล้ว';

  @override
  String get driverNavStatusParcelReady => 'พร้อมส่งพัสดุ';

  @override
  String get driverNavStatusParcelDelivering => 'กำลังส่งพัสดุ...';

  @override
  String get driverNavStatusRideGoing => 'กำลังไปรับผู้โดยสาร';

  @override
  String get driverNavStatusRideArrived => 'ถึงจุดรับลูกค้าแล้ว';

  @override
  String get driverNavStatusRideReady => 'พร้อมรับผู้โดยสาร';

  @override
  String get driverNavStatusRideTraveling => 'กำลังเดินทาง...';

  @override
  String get driverNavStatusAtPickup => 'ถึงจุดรับแล้ว';

  @override
  String get driverNavStatusPickedUp => 'รับของแล้ว';

  @override
  String get driverNavStatusCompleted => 'ส่งเสร็จแล้ว';

  @override
  String get driverNavStatusDefault => 'กำลังดำเนินการ';

  @override
  String get driverNavServiceFood => 'สั่งอาหาร';

  @override
  String get driverNavServiceRide => 'เรียกรถ';

  @override
  String get driverNavServiceParcel => 'ส่งพัสดุ';

  @override
  String get driverNavServiceDefault => 'บริการ';

  @override
  String get driverNavBackTitle => 'ออกจากหน้านำทาง?';

  @override
  String get driverNavBackBody => 'คุณยังมีงานอยู่ งานจะยังคงดำเนินต่อไป';

  @override
  String get driverNavBackStay => 'อยู่ต่อ';

  @override
  String get driverNavBackLeave => 'ย้อนกลับ';

  @override
  String get driverNavLoading => 'กำลังโหลด...';

  @override
  String get driverNavActiveJob => 'งานที่กำลังดำเนินการ';

  @override
  String get driverNavCallCustomer => 'โทรหาลูกค้า';

  @override
  String get driverNavTooltipNav => 'นำทาง';

  @override
  String get driverNavTooltipChat => 'แชทกับลูกค้า';

  @override
  String get driverNavChipType => 'ประเภท';

  @override
  String get driverNavChipDistance => 'ระยะทาง';

  @override
  String get driverNavViewFoodItems => 'ดูรายการอาหาร';

  @override
  String get driverNavReportIssue => 'แจ้งปัญหา';

  @override
  String get driverNavCancelJob => 'ยกเลิกงาน';

  @override
  String get driverNavJobCancelledTitle => 'งานถูกยกเลิก';

  @override
  String get driverNavJobCancelledBody => 'รายการนี้ถูกยกเลิกแล้ว ระบบจะพากลับหน้าหลักคนขับ';

  @override
  String get driverNavGoHome => 'กลับหน้าหลัก';

  @override
  String get driverNavNotifStatusTitle => 'อัปเดตสถานะงาน';

  @override
  String get driverNavNotifAccepted => 'คนขับรับงานแล้ว';

  @override
  String get driverNavNotifArrived => 'คนขับถึงจุดรับแล้ว';

  @override
  String get driverNavNotifPickedUp => 'คนขับรับอาหารแล้ว กำลังจัดส่ง';

  @override
  String get driverNavNotifInTransit => 'คนขับกำลังเดินทางมาหาคุณ';

  @override
  String get driverNavNotifCompleted => 'งานเสร็จสมบูรณ์แล้ว';

  @override
  String get driverNavNotifCancelled => 'งานถูกยกเลิก';

  @override
  String driverNavNotifStatusUpdate(Object status) {
    return 'สถานะงานอัปเดตเป็น $status';
  }

  @override
  String get driverNavMerchantArrivedTitle => 'คนขับถึงร้านแล้ว';

  @override
  String get driverNavMerchantArrivedBody => 'คนขับมาถึงร้านแล้ว กรุณาเตรียมส่งมอบอาหาร';

  @override
  String get driverNavPaymentTitle => '💰 จ่ายเงินร้านค้าสำเร็จ';

  @override
  String get driverNavPaymentBody => 'รับอาหารจากร้านค้าเรียบร้อย\nกรุณาส่งอาหารให้ลูกค้าต่อ';

  @override
  String get driverNavPaymentSales => 'ยอดขาย';

  @override
  String driverNavPaymentDeduction(Object percent) {
    return 'หักร้าน ($percent%)';
  }

  @override
  String get driverNavPaymentToMerchant => 'จ่ายร้านค้า';

  @override
  String get driverNavPaymentDeliver => 'ส่งอาหารให้ลูกค้า';

  @override
  String get driverNavCompletionTitle => '🎉 งานเสร็จสมบูรณ์!';

  @override
  String get driverNavCompletionSuccess => 'ส่งสำเร็จแล้ว!';

  @override
  String get driverNavCompletionCollect => 'เก็บเงินลูกค้า';

  @override
  String get driverNavCompletionFoodCost => '  ค่าอาหาร';

  @override
  String get driverNavCompletionDeliveryFee => '  ค่าส่ง';

  @override
  String get driverNavCompletionCouponPlatform => '  ส่วนลดจากคูปอง';

  @override
  String driverNavCompletionCouponCode(Object code) {
    return '  ส่วนลดคูปอง ($code)';
  }

  @override
  String get driverNavCompletionCoupon => '  ส่วนลดคูปอง';

  @override
  String get driverNavCompletionServiceFee => 'ค่าบริการระบบ';

  @override
  String get driverNavCompletionNetEarnings => 'รายได้สุทธิ';

  @override
  String get driverNavCompletionViewDetails => 'ดูรายละเอียด';

  @override
  String get driverNavFinCardCollect => 'เก็บเงินลูกค้า';

  @override
  String get driverNavFinCardFoodCost => 'ค่าอาหาร';

  @override
  String get driverNavFinCardDeliveryFee => 'ค่าส่ง';

  @override
  String get driverNavFinCardPayMerchant => 'จ่ายร้านค้า';

  @override
  String get walletTitle => 'กระเป๋าเงิน';

  @override
  String get walletBalance => 'ยอดเงินคงเหลือ';

  @override
  String walletBalanceBaht(Object amount) {
    return '$amount บาท';
  }

  @override
  String get walletTopUp => 'เติมเงิน';

  @override
  String get walletTransactionHistory => 'ประวัติการทำรายการ';

  @override
  String get walletLoadError => 'เกิดข้อผิดพลาดในการโหลดข้อมูล';

  @override
  String get walletRetry => 'ลองใหม่';

  @override
  String get walletNoTransactions => 'ยังไม่มีประวัติการทำรายการ';

  @override
  String get walletTypeTopup => 'เติมเงิน';

  @override
  String get walletTypeCommission => 'ค่าบริการระบบ';

  @override
  String get walletTypeFoodCommission => 'ค่าบริการระบบอาหาร';

  @override
  String get walletTypeJobIncome => 'รายได้จากงาน';

  @override
  String get walletTypePenalty => 'ค่าปรับ';

  @override
  String walletToday(Object time) {
    return 'วันนี้ $time';
  }

  @override
  String walletYesterday(Object time) {
    return 'เมื่อวาน $time';
  }

  @override
  String get topupTitle => 'เติมเงิน / ถอนเงิน';

  @override
  String topupMinAmountError(Object amount) {
    return 'กรุณาระบุจำนวนเงินอย่างน้อย $amount บาท';
  }

  @override
  String topupMaxAmountError(Object amount) {
    return 'จำนวนเงินเกินวงเงินต่อครั้ง (สูงสุด ฿$amount)';
  }

  @override
  String get topupOmiseSourceError => 'ไม่สามารถสร้าง PromptPay Source ได้\nกรุณาตรวจสอบ Omise Key ใน .env';

  @override
  String get topupOmiseChargeError => 'ไม่สามารถสร้าง Charge ได้\nกรุณาตรวจสอบ Omise Secret Key';

  @override
  String get topupOmiseQRError => 'ไม่พบ QR Code ใน Charge response\nกรุณาลองใหม่';

  @override
  String topupOmiseError(Object error) {
    return 'เกิดข้อผิดพลาด Omise: $error';
  }

  @override
  String get topupQRExpired => 'QR Code หมดอายุ กรุณาสร้างใหม่';

  @override
  String get topupPaymentFailed => 'การชำระเงินล้มเหลว กรุณาลองใหม่';

  @override
  String get topupCreditError => 'ชำระเงินสำเร็จแล้ว แต่ไม่สามารถเติมเงินเข้ากระเป๋าได้\nกรุณาติดต่อ Admin พร้อมหลักฐานการโอน';

  @override
  String get topupCreditGenericError => 'ชำระเงินสำเร็จแล้ว แต่เกิดข้อผิดพลาด\nกรุณาติดต่อ Admin';

  @override
  String get topupPromptPayNotSet => 'ระบบยังไม่ได้ตั้งค่าเลข PromptPay\nกรุณาติดต่อ Admin เพื่อตั้งค่า';

  @override
  String get topupPromptPayInvalid => 'เลข PromptPay ในระบบไม่ถูกต้อง\nกรุณาติดต่อ Admin';

  @override
  String topupLocalError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get topupDirectError => 'ไม่สามารถเติมเงินเข้ากระเป๋าได้\nกรุณาติดต่อ Admin';

  @override
  String get topupDirectGenericError => 'เกิดข้อผิดพลาดในการเติมเงิน\nกรุณาติดต่อ Admin';

  @override
  String get topupDriverDefault => 'คนขับ';

  @override
  String get topupErrorTitle => 'เกิดข้อผิดพลาด';

  @override
  String get topupOk => 'ตกลง';

  @override
  String get topupRequestSentTitle => 'ส่งคำขอเติมเงินแล้ว';

  @override
  String topupRequestSentBody(Object amount) {
    return 'คำขอเติมเงิน ฿$amount ถูกส่งแล้ว\nรอ Admin ตรวจสอบและยืนยัน';
  }

  @override
  String get topupSuccessTitle => 'เติมเงินสำเร็จ!';

  @override
  String topupSuccessBody(Object amount) {
    return 'เติมเงิน ฿$amount เข้ากระเป๋าเรียบร้อยแล้ว';
  }

  @override
  String get topupWithdrawTitle => 'ถอนเงิน';

  @override
  String topupWithdrawBalance(Object amount) {
    return 'ยอดคงเหลือ: ฿$amount';
  }

  @override
  String get topupWithdrawAmountLabel => 'จำนวนเงินที่ต้องการถอน';

  @override
  String get topupWithdrawBankName => 'ชื่อธนาคาร';

  @override
  String get topupWithdrawBankHint => 'เช่น กสิกรไทย, ไทยพาณิชย์';

  @override
  String get topupWithdrawAccountNum => 'เลขบัญชี';

  @override
  String get topupWithdrawAccountName => 'ชื่อบัญชี';

  @override
  String get topupWithdrawCancel => 'ยกเลิก';

  @override
  String get topupWithdrawAmountRequired => 'กรุณาระบุจำนวนเงิน';

  @override
  String get topupWithdrawInsufficientBalance => 'ยอดเงินไม่เพียงพอ';

  @override
  String get topupWithdrawBankRequired => 'กรุณากรอกข้อมูลธนาคาร';

  @override
  String topupWithdrawError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get topupWithdrawSubmit => 'ส่งคำขอถอนเงิน';

  @override
  String get topupWithdrawBtn => 'ถอนเงิน';

  @override
  String get topupWithdrawHistoryTitle => 'ประวัติถอนเงิน';

  @override
  String get topupWithdrawHistoryEmpty => 'ยังไม่มีประวัติถอนเงิน';

  @override
  String get topupHistoryTitle => 'ประวัติเติมเงิน';

  @override
  String get topupHistoryEmpty => 'ยังไม่มีประวัติเติมเงิน';

  @override
  String get topupStatusCompleted => 'โอนแล้ว';

  @override
  String get topupStatusRejected => 'ปฏิเสธ';

  @override
  String get topupStatusCancelled => 'ยกเลิก';

  @override
  String get topupStatusPending => 'รอดำเนินการ';

  @override
  String get topupStatusApproved => 'อนุมัติแล้ว';

  @override
  String get topupSelectAmount => 'เลือกจำนวนเงิน';

  @override
  String get topupCustomAmount => 'หรือกรอกจำนวนเงินเอง';

  @override
  String get topupScanQR => 'สแกน QR Code เพื่อโอนเงิน';

  @override
  String get topupOmiseScanDesc => 'สแกน QR ผ่านแอปธนาคาร — ระบบตรวจยอดอัตโนมัติ';

  @override
  String get topupManualScanDesc => 'โอนเงินผ่าน PromptPay แล้วกดยืนยัน';

  @override
  String topupAmount(Object amount) {
    return 'จำนวนเงิน: ฿$amount';
  }

  @override
  String get topupOmiseAutoDesc => 'สแกน QR โอนเงิน — ระบบจะตรวจยอดให้อัตโนมัติ';

  @override
  String get topupManualConfirmDesc => 'สแกน QR โอนเงินแล้วกด \"แจ้งโอนเงิน\" ด้านล่าง';

  @override
  String get topupRequestSentCard => 'คำขอเติมเงินถูกส่งแล้ว';

  @override
  String topupRequestSentCardBody(Object amount) {
    return 'จำนวน ฿$amount — รอ Admin ตรวจสอบและยืนยัน';
  }

  @override
  String get topupCheckingPayment => 'กำลังตรวจสอบการชำระเงิน...';

  @override
  String get topupAutoCheckDesc => 'ระบบจะตรวจยอดอัตโนมัติทุก 5 วินาที\nเมื่อชำระเงินสำเร็จจะเติมเงินเข้ากระเป๋าทันที';

  @override
  String get topupCancelNewQR => 'ยกเลิก / สร้าง QR ใหม่';

  @override
  String get topupOmiseSuccessTitle => 'ชำระเงินสำเร็จ!';

  @override
  String topupOmiseSuccessBody(Object amount) {
    return 'เติมเงิน ฿$amount เข้ากระเป๋าเรียบร้อยแล้ว';
  }

  @override
  String get topupOmiseAutoVerified => 'ตรวจยอดอัตโนมัติผ่าน Omise';

  @override
  String get topupGeneratingQR => 'กำลังสร้าง QR...';

  @override
  String get topupPayPromptPay => 'ชำระเงินด้วย PromptPay';

  @override
  String get topupSending => 'กำลังส่ง...';

  @override
  String topupConfirmTransfer(Object amount) {
    return 'แจ้งโอนเงิน ฿$amount';
  }

  @override
  String get topupGenerateNewQR => 'สร้าง QR ใหม่';

  @override
  String get withdrawTitle => 'ถอนเงิน';

  @override
  String get withdrawBalance => 'ยอดเงินคงเหลือ';

  @override
  String get withdrawAmountRequired => 'กรุณาระบุจำนวนเงินที่ต้องการถอน';

  @override
  String withdrawInsufficientBalance(Object amount) {
    return 'ยอดเงินไม่เพียงพอ\nคงเหลือ: ฿$amount';
  }

  @override
  String get withdrawFailed => 'ไม่สามารถแจ้งถอนเงินได้\nกรุณาลองใหม่อีกครั้ง';

  @override
  String get withdrawGenericError => 'เกิดข้อผิดพลาด\nกรุณาลองใหม่อีกครั้ง';

  @override
  String get withdrawErrorTitle => 'เกิดข้อผิดพลาด';

  @override
  String get withdrawOk => 'ตกลง';

  @override
  String get withdrawSuccessTitle => 'แจ้งถอนเงินสำเร็จ';

  @override
  String withdrawSuccessBody(Object amount) {
    return 'ระบบได้รับคำขอถอนเงิน ฿$amount แล้ว\n\nAdmin จะตรวจสอบและโอนเงินภายใน 1-3 วันทำการ';
  }

  @override
  String get withdrawAmountSectionTitle => 'จำนวนเงินที่ต้องการถอน';

  @override
  String get withdrawAmountLabel => 'จำนวนเงิน (บาท)';

  @override
  String get withdrawMinHelper => 'ขั้นต่ำ ฿100';

  @override
  String get withdrawAmountValidation => 'กรุณาระบุจำนวนเงิน';

  @override
  String get withdrawMinValidation => 'ขั้นต่ำ ฿100';

  @override
  String get withdrawBankInfoTitle => 'ข้อมูลบัญชีธนาคาร';

  @override
  String get withdrawBankLabel => 'ธนาคาร';

  @override
  String get withdrawBankValidation => 'กรุณาเลือกธนาคาร';

  @override
  String get withdrawAccountNumLabel => 'เลขบัญชี';

  @override
  String get withdrawAccountNumValidation => 'กรุณาระบุเลขบัญชี';

  @override
  String get withdrawAccountNameLabel => 'ชื่อบัญชี';

  @override
  String get withdrawAccountNameValidation => 'กรุณาระบุชื่อบัญชี';

  @override
  String get withdrawProcessing => 'กำลังดำเนินการ...';

  @override
  String get withdrawSubmitBtn => 'แจ้งถอนเงิน';

  @override
  String get withdrawHistoryTitle => 'ประวัติคำขอถอนเงิน';

  @override
  String get withdrawStatusCompleted => 'โอนแล้ว';

  @override
  String get withdrawStatusRejected => 'ปฏิเสธ';

  @override
  String get withdrawStatusCancelled => 'ยกเลิก';

  @override
  String get withdrawStatusPending => 'รอดำเนินการ';

  @override
  String get withdrawBankKasikorn => 'ธนาคารกสิกรไทย';

  @override
  String get withdrawBankSCB => 'ธนาคารไทยพาณิชย์';

  @override
  String get withdrawBankBangkok => 'ธนาคารกรุงเทพ';

  @override
  String get withdrawBankKrungthai => 'ธนาคารกรุงไทย';

  @override
  String get withdrawBankKrungsri => 'ธนาคารกรุงศรีอยุธยา';

  @override
  String get withdrawBankTTB => 'ธนาคารทหารไทยธนชาต';

  @override
  String get withdrawBankGSB => 'ธนาคารออมสิน';

  @override
  String get withdrawBankKKP => 'ธนาคารเกียรตินาคินภัทร';

  @override
  String get withdrawBankCIMB => 'ธนาคารซีไอเอ็มบีไทย';

  @override
  String get withdrawBankTisco => 'ธนาคารทิสโก้';

  @override
  String get withdrawBankUOB => 'ธนาคารยูโอบี';

  @override
  String get withdrawBankLH => 'ธนาคารแลนด์ แอนด์ เฮ้าส์';

  @override
  String get accountTitle => 'บัญชี';

  @override
  String get accountErrorTitle => 'โหลดข้อมูลไม่สำเร็จ';

  @override
  String get accountRetry => 'ลองใหม่';

  @override
  String get accountPersonalInfoTitle => 'ข้อมูลส่วนตัว';

  @override
  String get accountMenuTitle => 'เมนู';

  @override
  String get accountAppInfoTitle => 'ข้อมูลแอป';

  @override
  String get accountLogout => 'ออกจากระบบ';

  @override
  String get accountLogoutDialogTitle => 'ออกจากระบบ';

  @override
  String get accountLogoutDialogBody => 'คุณต้องการออกจากระบบใช่หรือไม่?';

  @override
  String get accountCancel => 'ยกเลิก';

  @override
  String get accountDelete => 'ลบบัญชี';

  @override
  String get accountDeleteDialogTitle => 'ลบบัญชีผู้ใช้';

  @override
  String get accountDeleteDialogBody => 'เมื่อยืนยันแล้ว คำขอจะถูกส่งไปยังแอดมินเพื่ออนุมัติ\nระหว่างรออนุมัติจะไม่สามารถใช้งานบัญชีได้';

  @override
  String get accountDeleteReasonHint => 'เหตุผลในการลบบัญชี (ไม่บังคับ)';

  @override
  String get accountDeleteConfirm => 'ยืนยันลบบัญชี';

  @override
  String get accountUploadingImage => 'กำลังอัพโหลดรูปภาพ...';

  @override
  String get accountUploadSuccess => 'อัพโหลดรูปโปรไฟล์สำเร็จ!';

  @override
  String accountUploadFailed(Object error) {
    return 'อัพโหลดรูปไม่สำเร็จ: $error';
  }

  @override
  String get accountUpdateSuccess => 'อัปเดตสำเร็จ!';

  @override
  String accountUpdateFailed(Object error) {
    return 'อัปเดตไม่สำเร็จ: $error';
  }

  @override
  String get accountOpenLinkFailed => 'ไม่สามารถเปิดลิงก์ได้';

  @override
  String accountErrorGeneric(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get accountInfoTitle => 'ข้อมูล';

  @override
  String get accountInfoName => 'ชื่อ';

  @override
  String get accountInfoPhone => 'เบอร์โทร';

  @override
  String get accountInfoEmail => 'อีเมล';

  @override
  String get accountNotSet => 'ยังไม่ได้ตั้งค่า';

  @override
  String get accountMenuEditProfile => 'แก้ไขโปรไฟล์';

  @override
  String get accountMenuCoupons => 'คูปองของฉัน';

  @override
  String get accountMenuReferral => 'ชวนเพื่อน';

  @override
  String get accountMenuHelp => 'ช่วยเหลือ';

  @override
  String get accountMenuNotifications => 'การแจ้งเตือน';

  @override
  String get accountMenuPrivacyPolicy => 'นโยบายความเป็นส่วนตัว';

  @override
  String get accountFeatureComingSoon => 'ฟีเจอร์นี้จะมาในเวอร์ชันถัดไป';

  @override
  String get merchantMenuEditShop => 'แก้ไขข้อมูลร้าน';

  @override
  String get merchantMenuCoupons => 'คูปองร้านค้า';

  @override
  String get accountRoleCustomer => 'ลูกค้า';

  @override
  String get accountRoleMerchant => 'ร้านค้า';

  @override
  String get accountRoleDriver => 'คนขับ';

  @override
  String get driverInfoVehicleType => 'ประเภทรถ';

  @override
  String get driverInfoLicensePlate => 'ทะเบียนรถ';

  @override
  String get profileEditTitle => 'แก้ไขโปรไฟล์';

  @override
  String get profileLoadFailedTitle => 'โหลดโปรไฟล์ไม่สำเร็จ';

  @override
  String profileLoadFailedBody(Object error) {
    return 'ไม่สามารถโหลดข้อมูลโปรไฟล์ได้: $error';
  }

  @override
  String get profileSaveSuccess => 'บันทึกโปรไฟล์สำเร็จ';

  @override
  String get profileSaveFailedTitle => 'บันทึกไม่สำเร็จ';

  @override
  String profileSaveFailedBody(Object error) {
    return 'ไม่สามารถบันทึกโปรไฟล์ได้: $error';
  }

  @override
  String get profileBasicInfoSection => 'ข้อมูลพื้นฐาน';

  @override
  String get profileVehicleSection => 'ข้อมูลยานพาหนะ';

  @override
  String get profileMerchantSection => 'ข้อมูลร้านค้า';

  @override
  String get profileSave => 'บันทึก';

  @override
  String get profileUploadingImage => 'กำลังอัพโหลดรูปภาพ...';

  @override
  String get profileVehicleMotorcycle => 'มอเตอร์ไซค์';

  @override
  String get profileVehicleCar => 'รถยนต์';

  @override
  String get profileFullNameLabel => 'ชื่อ-นามสกุล';

  @override
  String get profileFullNameRequired => 'กรุณากรอกชื่อ-นามสกุล';

  @override
  String get profilePhoneLabel => 'เบอร์โทรศัพท์';

  @override
  String get profilePhoneRequired => 'กรุณากรอกเบอร์โทรศัพท์';

  @override
  String get profileLicensePlateRequired => 'กรุณากรอกทะเบียนรถ';

  @override
  String get profileShopNameLabel => 'ชื่อร้าน';

  @override
  String get profileShopNameHint => 'กรอกชื่อร้านค้า';

  @override
  String get profileShopNameRequired => 'กรุณากรอกชื่อร้าน';

  @override
  String get profileShopAddressLabel => 'ที่อยู่ร้าน';

  @override
  String get profileShopAddressHint => 'กรอกที่อยู่ร้านค้า';

  @override
  String get profileShopAddressRequired => 'กรุณากรอกที่อยู่ร้าน';

  @override
  String get profileShopPhoneLabel => 'เบอร์โทรร้าน';

  @override
  String get profileShopPhoneHint => 'กรอกเบอร์โทรศัพท์ร้าน';

  @override
  String get profileShopPhoneRequired => 'กรุณากรอกเบอร์โทรศัพท์ร้าน';

  @override
  String get accountVersionLabel => 'เวอร์ชัน';

  @override
  String get accountDevelopedByLabel => 'พัฒนาโดย';

  @override
  String get accountLoading => 'กำลังโหลด...';

  @override
  String accountDeleteRequestSubmitFailed(Object error) {
    return 'ไม่สามารถส่งคำขอได้: $error';
  }

  @override
  String get merchantCloseShopTitle => 'ปิดร้าน?';

  @override
  String get merchantCloseShopBody => 'เมื่อกดปิดร้านเอง จะปิดการใช้งาน เปิด-ปิด ร้านอัตโนมัติ\nสามารถเปิดใช้งานฟีเจอร์นี้ได้ที่หน้าตั้งค่า';

  @override
  String get merchantCloseShopCancel => 'ยกเลิก';

  @override
  String get merchantCloseShopConfirm => 'ปิดร้าน';

  @override
  String get merchantNewOrderAlert => '🚨 ออเดอร์ใหม่!';

  @override
  String get merchantNewOrderWaiting => 'คุณมีออเดอร์ใหม่รอการยืนยัน!';

  @override
  String get merchantAlarmDesc => 'เสียงจะแจ้งเตือนซ้ำต่อเนื่องจนกว่าคุณกดหยุด';

  @override
  String get merchantStopAlarm => 'หยุดเสียง / รับทราบ';

  @override
  String get merchantUserNotFound => 'ไม่พบข้อมูลผู้ใช้';

  @override
  String get merchantOrderConfirmed => 'ออเดอร์ได้รับการยืนยันแล้ว!';

  @override
  String get merchantShopOpenedAutoOff => 'เปิดร้านแล้ว (ปิดอัตโนมัติถูกปิด)';

  @override
  String get merchantShopOpened => 'เปิดร้านแล้ว';

  @override
  String get merchantShopClosedAutoOff => 'ปิดร้านแล้ว (ปิดอัตโนมัติถูกปิด)';

  @override
  String get merchantShopClosed => 'ปิดร้านแล้ว';

  @override
  String merchantShopStatusError(Object error) {
    return 'ไม่สามารถเปลี่ยนสถานะร้าน: $error';
  }

  @override
  String get merchantDriverStatusWaiting => 'คนขับ: รอคนขับรับงาน...';

  @override
  String merchantDriverStatusComing(Object name) {
    return 'คนขับ: $name กำลังมา';
  }

  @override
  String merchantDriverStatusArrived(Object name) {
    return 'คนขับ: $name ถึงร้านแล้ว';
  }

  @override
  String get merchantDriverStatusPreparing => 'คนขับ: รอร้านทำอาหาร';

  @override
  String get merchantDriverStatusReady => 'คนขับ: รออาหารพร้อม';

  @override
  String get merchantDriverStatusDefault => 'คนขับ: รอดำเนินการ';

  @override
  String get merchantDriverDefault => 'คนขับ';

  @override
  String get merchantStatusNewOrder => 'ออเดอร์ใหม่';

  @override
  String get merchantStatusPending => 'รอยืนยัน';

  @override
  String get merchantStatusPreparing => 'กำลังทำอาหาร';

  @override
  String get merchantStatusDriverAccepted => 'คนขับรับงานแล้ว';

  @override
  String get merchantStatusArrivedAtMerchant => 'คนขับถึงร้านแล้ว';

  @override
  String get merchantStatusMatched => 'จับคู่คนขับแล้ว';

  @override
  String get merchantStatusReadyForPickup => 'อาหารพร้อมแล้ว';

  @override
  String get merchantStatusPickingUp => 'คนขับกำลังรับอาหาร';

  @override
  String get merchantStatusInTransit => 'กำลังจัดส่ง';

  @override
  String get merchantStatusCompleted => 'เสร็จสิ้น';

  @override
  String get merchantStatusCancelled => 'ยกเลิก';

  @override
  String get merchantStatusUnknown => 'ไม่ทราบสถานะ';

  @override
  String get merchantAppBarOrders => 'ออเดอร์';

  @override
  String get merchantAppBarHistory => 'ประวัติออเดอร์';

  @override
  String get merchantTooltipActiveOrders => 'ดูออเดอร์ที่กำลังดำเนินการ';

  @override
  String get merchantTooltipHistory => 'ดูประวัติออเดอร์';

  @override
  String get merchantRefreshed => 'รีเฟรชข้อมูลแล้ว';

  @override
  String get merchantErrorOccurred => 'เกิดข้อผิดพลาด';

  @override
  String get merchantRetry => 'ลองใหม่';

  @override
  String get merchantNoOrders => 'ไม่มีออเดอร์ใหม่';

  @override
  String get merchantOrdersWillAppear => 'ออเดอร์ใหม่จะปรากฏที่นี่ทันที';

  @override
  String get merchantOpenShopToReceive => 'เปิดร้านเพื่อรับออเดอร์';

  @override
  String get merchantShopStatus => 'สถานะร้าน';

  @override
  String get merchantShopOpen => 'ร้านเปิด';

  @override
  String get merchantShopClosed2 => 'ร้านปิด';

  @override
  String get merchantShopOpenDesc => 'ลูกค้าสามารถสั่งอาหารได้';

  @override
  String get merchantShopClosedDesc => 'ร้านปิดให้บริการชั่วคราว';

  @override
  String get merchantAcceptModeAuto => 'รับออเดอร์อัตโนมัติ';

  @override
  String get merchantAcceptModeManual => 'รับออเดอร์ด้วยตนเอง';

  @override
  String get merchantAutoScheduleOn => 'เปิด-ปิดร้านอัตโนมัติ: เปิดใช้งาน';

  @override
  String get merchantAutoScheduleOff => 'เปิด-ปิดร้านอัตโนมัติ: ปิดใช้งาน';

  @override
  String get merchantAcceptOrder => 'รับออเดอร์';

  @override
  String get merchantPreparingFood => 'กำลังเตรียมอาหาร';

  @override
  String get merchantTapForDetails => 'กดเข้าไปดูรายละเอียด';

  @override
  String get merchantDriverAcceptedCard => 'คนขับรับงานแล้ว';

  @override
  String get merchantCookingFood => 'กำลังประกอบอาหาร';

  @override
  String get merchantDriverMatchedCard => 'จับคู่คนขับแล้ว';

  @override
  String get merchantDriverTravelingToShop => 'คนขับกำลังเดินทางมาที่ร้าน';

  @override
  String get merchantPrepareFood => 'กรุณาเตรียมอาหารให้พร้อม';

  @override
  String get merchantDriverArrivedCard => 'คนขับถึงร้านแล้ว';

  @override
  String get merchantDriverPickingUpCard => 'คนขับกำลังรับออเดอร์';

  @override
  String get merchantDeliveringToCustomer => 'กำลังนำส่งให้ลูกค้า';

  @override
  String get merchantDelivering => 'กำลังนำส่งอาหาร';

  @override
  String get merchantOrderEnRoute => 'ออเดอร์กำลังเดินทางถึงลูกค้า';

  @override
  String get merchantDriverPickedUpCard => 'คนขับมารับออเดอร์แล้ว';

  @override
  String get merchantOrderDoneForMerchant => 'ออเดอร์นี้เสร็จสิ้นสำหรับร้านค้า';

  @override
  String get merchantAddressNotSpecified => 'ไม่ระบุ';

  @override
  String get merchantAddressPinLocation => '📍 ตำแหน่งตามหมุดปักของลูกค้า';

  @override
  String merchantScheduledOrder(Object dateTime) {
    return 'ออเดอร์นัดเวลา: $dateTime';
  }

  @override
  String merchantPickupTime(Object dateTime) {
    return 'เวลานัดรับ: $dateTime';
  }

  @override
  String merchantDistance(Object km) {
    return 'ระยะทาง $km กม.';
  }

  @override
  String get merchantTimeJustNow => 'เมื่อสักครู่';

  @override
  String merchantTimeMinutesAgo(Object minutes) {
    return 'เมื่อ $minutes นาทีที่แล้ว';
  }

  @override
  String merchantTimeHoursAgo(Object hours) {
    return 'เมื่อ $hours ชั่วโมงที่แล้ว';
  }

  @override
  String merchantTimeDaysAgo(Object days) {
    return 'เมื่อ $days วันที่แล้ว';
  }

  @override
  String get merchantNotifMerchantDefault => 'ร้านค้า';

  @override
  String get merchantNotifOrderAccepted => '✅ ร้านยืนยันออเดอร์แล้ว!';

  @override
  String merchantNotifPreparingBody(Object merchantName) {
    return '$merchantName กำลังเตรียมอาหารของคุณ';
  }

  @override
  String get merchantNotifFoodReadyCustomer => '🍔 อาหารพร้อมแล้ว!';

  @override
  String merchantNotifFoodReadyCustomerBody(Object merchantName) {
    return '$merchantName เตรียมอาหารเสร็จแล้ว รอคนขับมารับ';
  }

  @override
  String get merchantNotifFoodReadyDriver => '🍔 อาหารพร้อมรับแล้ว!';

  @override
  String merchantNotifFoodReadyDriverBody(Object merchantName) {
    return '$merchantName เตรียมอาหารเสร็จแล้ว พร้อมรับได้เลย';
  }

  @override
  String get merchantViewHistory => 'ดูประวัติออเดอร์';

  @override
  String get merchantViewActive => 'ดูออเดอร์ที่กำลังดำเนินการ';

  @override
  String orderDetailTitle(Object code) {
    return 'ออเดอร์ $code';
  }

  @override
  String get orderDetailDriverPhoneNotFound => 'ไม่พบเบอร์โทรคนขับ';

  @override
  String orderDetailLoadItemsError(Object error) {
    return 'ไม่สามารถโหลดรายการอาหาร: $error';
  }

  @override
  String get orderDetailAccepted => 'ออเดอร์ได้รับการยืนยันแล้ว!';

  @override
  String get orderDetailAcceptFailed => 'รับออเดอร์ไม่สำเร็จ';

  @override
  String orderDetailAcceptError(Object error) {
    return 'ไม่สามารถรับออเดอร์ได้: $error';
  }

  @override
  String get orderDetailOk => 'ตกลง';

  @override
  String get orderDetailDeclined => 'ออเดอร์ถูกปฏิเสธแล้ว';

  @override
  String get orderDetailDeclineFailed => 'ปฏิเสธออเดอร์ไม่สำเร็จ';

  @override
  String orderDetailDeclineError(Object error) {
    return 'ไม่สามารถปฏิเสธออเดอร์ได้: $error';
  }

  @override
  String get orderDetailStatusUpdateFailed => 'ไม่สามารถอัพเดตสถานะได้';

  @override
  String get orderDetailFoodReady => 'อาหารพร้อมแล้ว! รอคนขับมารับ';

  @override
  String get orderDetailUpdateFailed => 'อัพเดตสถานะไม่สำเร็จ';

  @override
  String orderDetailUpdateError(Object error) {
    return 'ไม่สามารถอัพเดตสถานะได้: $error';
  }

  @override
  String get orderDetailAddressNotSpecified => 'ไม่ระบุ';

  @override
  String get orderDetailAddressPinLocation => 'ตำแหน่งตามหมุดปักของลูกค้า';

  @override
  String get orderDetailOrderInfo => 'ข้อมูลออเดอร์';

  @override
  String get orderDetailOrderCode => 'รหัสออเดอร์';

  @override
  String get orderDetailOrderTime => 'เวลาสั่ง';

  @override
  String get orderDetailPayment => 'ชำระเงิน';

  @override
  String get orderDetailPaymentCash => 'เงินสด';

  @override
  String get orderDetailPaymentTransfer => 'โอนเงิน';

  @override
  String get orderDetailDistanceLabel => 'ระยะทาง';

  @override
  String get orderDetailScheduled => 'นัดหมาย';

  @override
  String get orderDetailPriceBreakdown => 'รายละเอียดราคา';

  @override
  String get orderDetailSalesAmount => 'ยอดขาย';

  @override
  String orderDetailGpDeduction(Object percent) {
    return 'หัก GP ($percent%)';
  }

  @override
  String get orderDetailNetReceived => 'ยอดรับจริง';

  @override
  String get orderDetailDeliveryAddress => 'ที่อยู่จัดส่ง';

  @override
  String get orderDetailCustomerNote => 'หมายเหตุจากลูกค้า';

  @override
  String get orderDetailFoodItems => 'รายการอาหาร';

  @override
  String get orderDetailOptions => 'เพิ่มเติม:';

  @override
  String get orderDetailDeclineBtn => 'ปฏิเสธออเดอร์';

  @override
  String get orderDetailAcceptBtn => 'รับออเดอร์';

  @override
  String get orderDetailWaitingDriver => 'รอคนขับรับงาน';

  @override
  String get orderDetailWaitingDriverDesc => 'กรุณารอคนขับรับงานก่อน\nจึงจะสามารถกดอาหารพร้อมได้';

  @override
  String get orderDetailFoodReadyBtn => 'อาหารพร้อม';

  @override
  String orderDetailStatusLabel(Object status) {
    return 'สถานะ: $status';
  }

  @override
  String get orderDetailStatusArrivedMerchant => 'คนขับถึงร้านแล้ว';

  @override
  String get orderDetailStatusReadyPickup => 'อาหารพร้อมส่ง';

  @override
  String get orderDetailStatusUnknown => 'ไม่ทราบสถานะ';

  @override
  String get orderDetailCompletionTitle => '✅ ออเดอร์สำเร็จ';

  @override
  String get orderDetailCompletionBody => 'คนขับได้รับอาหารและกำลังเดินทางไปส่งลูกค้า';

  @override
  String get orderDetailCompletionOrderNum => 'หมายเลขออเดอร์';

  @override
  String get orderDetailCompletionCustomer => 'ชื่อลูกค้า';

  @override
  String get orderDetailCompletionNetReceived => 'ยอดรับจริง';

  @override
  String orderDetailCompletionAfterGP(Object percent) {
    return 'หลังหัก GP $percent%';
  }

  @override
  String get orderDetailCompletionOk => 'เข้าใจแล้ว';

  @override
  String get orderDetailCustomerDefault => 'ลูกค้า';

  @override
  String get orderDetailItemNotSpecified => 'ไม่ระบุ';

  @override
  String get orderDetailNotifRejectTitle => '❌ ร้านค้าปฏิเสธออเดอร์';

  @override
  String get orderDetailNotifRejectBody => 'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้';

  @override
  String get customerHomeOk => 'ตกลง';

  @override
  String get customerHomeGreeting => 'สวัสดี';

  @override
  String get customerHomeNoNewNotifications => 'ยังไม่มีการแจ้งเตือนใหม่';

  @override
  String get customerHomeHelpToday => 'อยากให้เราช่วยอะไรวันนี้';

  @override
  String get customerHomeAvailable247 => 'พร้อมให้บริการ 24/7';

  @override
  String get customerHomeRealtimeTracking => 'ติดตามงานแบบเรียลไทม์';

  @override
  String get customerHomePendingOrders => 'ออเดอร์ที่ค้างอยู่';

  @override
  String customerHomeJobCount(Object count) {
    return '$count งาน';
  }

  @override
  String get customerHomeNoJobs => 'ตอนนี้ยังไม่มีงานค้างอยู่ เริ่มต้นบริการใหม่ได้เลย';

  @override
  String get customerHomePopularServices => 'บริการยอดนิยม';

  @override
  String get customerHomeCallRide => 'เรียกรถ';

  @override
  String get customerHomeCallRideSubtitle => 'รวดเร็ว ปลอดภัย';

  @override
  String get customerHomeOrderFood => 'สั่งอาหาร';

  @override
  String get customerHomeOrderFoodSubtitle => 'สั่งจากร้านใกล้คุณ';

  @override
  String get customerHomeSendParcel => 'ส่งพัสดุ';

  @override
  String get customerHomeSendParcelSubtitle => 'ส่งของถึงปลายทาง';

  @override
  String get customerHomeQuickActions => 'ตัวช่วยด่วน';

  @override
  String get customerHomeHistory => 'ประวัติ';

  @override
  String get customerHomeBookings => 'การจอง';

  @override
  String get customerHomeSaved => 'ที่บันทึก';

  @override
  String get customerHomePlaces => 'สถานที่';

  @override
  String get customerHomeHelp => 'ช่วยเหลือ';

  @override
  String get customerHomeContactUs => 'ติดต่อเรา';

  @override
  String get customerHomeHelpDeveloping => 'ระบบช่วยเหลือกำลังพัฒนา';

  @override
  String get customerHomePromotions => 'โปรโมชั่น';

  @override
  String get customerHomeDiscountCode => 'โค้ดส่วนลด';

  @override
  String get customerHomePromoCodeHint => 'นำโค้ดนี้ไปใช้ตอนสั่งซื้อเพื่อรับส่วนลด';

  @override
  String get customerHomeClose => 'ปิด';

  @override
  String customerHomeCopiedCode(Object code) {
    return 'คัดลอกโค้ด \"$code\" แล้ว';
  }

  @override
  String get customerHomeCopyCode => 'คัดลอกโค้ด';

  @override
  String customerHomeOrderCode(Object code) {
    return 'ออเดอร์ $code';
  }

  @override
  String get customerHomeDestination => 'จุดหมายปลายทาง';

  @override
  String get customerHomePickupPoint => 'จุดรับ';

  @override
  String customerHomeDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String customerHomeOrderedAt(Object datetime) {
    return 'สั่งเมื่อ: $datetime';
  }

  @override
  String get customerHomeStatusPending => 'รอดำเนินการ';

  @override
  String get customerHomeStatusPendingMerchant => 'รอร้านค้ายืนยัน';

  @override
  String get customerHomeStatusPreparing => 'กำลังเตรียมอาหาร';

  @override
  String get customerHomeStatusReadyPickup => 'อาหารพร้อมรับ';

  @override
  String get customerHomeStatusDriverAccepted => 'คนขับรับออเดอร์แล้ว';

  @override
  String get customerHomeStatusConfirmed => 'ยืนยันแล้ว';

  @override
  String get customerHomeStatusArrived => 'ถึงจุดรับแล้ว';

  @override
  String get customerHomeStatusArrivedMerchant => 'คนขับถึงร้านแล้ว';

  @override
  String get customerHomeStatusMatched => 'จับคู่คนขับแล้ว';

  @override
  String get customerHomeStatusPickingUp => 'กำลังรับอาหาร';

  @override
  String get customerHomeStatusInTransit => 'กำลังจัดส่ง';

  @override
  String get customerHomeStatusCompleted => 'เสร็จสิ้น';

  @override
  String get customerHomeStatusCancelled => 'ยกเลิก';

  @override
  String get customerHomeAddressNotSpecified => 'ไม่ระบุที่อยู่';

  @override
  String get customerHomeCurrentLocation => 'ตำแหน่งปัจจุบัน';

  @override
  String get rideStatusTitle => 'สถานะการเดินทาง';

  @override
  String get rideStatusDriver => 'คนขับ';

  @override
  String rideStatusCannotCall(Object phone) {
    return 'ไม่สามารถโทรไปที่ $phone ได้';
  }

  @override
  String get rideStatusCannotOpenChat => 'ไม่สามารถเปิดแชทได้';

  @override
  String get rideStatusEnableLocation => 'กรุณาเปิดใช้งาน Location Service';

  @override
  String get rideStatusAllowLocation => 'กรุณาอนุญาตให้เข้าถึงตำแหน่ง';

  @override
  String get rideStatusLocationDenied => 'ไม่สามารถเข้าถึงตำแหน่ง';

  @override
  String get rideStatusLocationDeniedBody => 'กรุณาเปิดการเข้าถึงตำแหน่งในการตั้งค่าของเครื่อง';

  @override
  String get rideStatusOk => 'ตกลง';

  @override
  String get rideStatusOpenSettings => 'เปิดการตั้งค่า';

  @override
  String rideStatusMerchantMarker(Object address) {
    return 'ร้านค้า: $address';
  }

  @override
  String get rideStatusMerchantDefault => 'ร้านอาหาร';

  @override
  String rideStatusPickupMarker(Object address) {
    return 'จุดรับ: $address';
  }

  @override
  String get rideStatusPickupDefault => 'จุดรับ';

  @override
  String get rideStatusYourLocation => 'ตำแหน่งของคุณ';

  @override
  String rideStatusDestMarker(Object address) {
    return 'จุดหมาย: $address';
  }

  @override
  String get rideStatusDestDefault => 'ปลายทาง';

  @override
  String get rideStatusDriverInfo => 'ข้อมูลคนขับ';

  @override
  String get rideStatusMotorcycle => 'รถจักรยานยนต์';

  @override
  String get rideStatusCall => 'โทร';

  @override
  String get rideStatusChat => 'แชท';

  @override
  String get rideStatusFoodCost => 'ค่าอาหาร';

  @override
  String get rideStatusDeliveryFee => 'ค่าจัดส่ง';

  @override
  String get rideStatusCouponDiscount => 'ส่วนลดคูปอง';

  @override
  String rideStatusCouponDiscountWithCode(Object code) {
    return 'ส่วนลดคูปอง ($code)';
  }

  @override
  String get rideStatusDistance => 'ระยะทาง';

  @override
  String rideStatusDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String get rideStatusGrandTotal => 'รวมทั้งหมด';

  @override
  String get rideStatusServiceFee => 'ค่าบริการ';

  @override
  String get rideStatusTripCompleted => 'เดินทางเสร็จสิ้น';

  @override
  String get rideStatusCancelTrip => 'ยกเลิกการเดินทาง';

  @override
  String get rideStatusAccepted => 'คนขับรับงานแล้ว';

  @override
  String get rideStatusDriverGoingPickup => 'คนขับกำลังไปรับอาหาร';

  @override
  String get rideStatusArrivedPickup => 'คนขับถึงจุดรับแล้ว';

  @override
  String get rideStatusArrivedMerchant => 'คนขับถึงร้านแล้ว';

  @override
  String get rideStatusFoodReady => 'อาหารพร้อม';

  @override
  String get rideStatusPickedUp => 'คนขับรับอาหารแล้ว';

  @override
  String get rideStatusInTransit => 'กำลังเดินทาง';

  @override
  String get rideStatusCompleted => 'เดินทางเสร็จสิ้น';

  @override
  String get rideStatusPending => 'รอดำเนินการ';

  @override
  String get rideStatusDriverComing => 'คนขับกำลังมารับ';

  @override
  String get rideStatusDriverGoingFood => 'คนขับกำลังไปรับอาหาร';

  @override
  String get rideStatusDriverArrivedPickup => 'คนขับถึงจุดรับแล้ว';

  @override
  String get rideStatusDriverAtMerchantWaiting => 'คนขับถึงร้านแล้ว รออาหาร';

  @override
  String get rideStatusFoodReadyDriverPickup => 'อาหารพร้อม คนขับกำลังรับ';

  @override
  String get rideStatusDriverPickedUpDelivering => 'คนขับรับอาหารแล้ว กำลังมาส่ง';

  @override
  String get rideStatusNavigating => 'กำลังนำทางไปปลายทาง';

  @override
  String get rideStatusDriverCompleted => 'เดินทางเสร็จสิ้น';

  @override
  String get rideStatusWaitingDriver => 'รอคนขับ';

  @override
  String get rideStatusMerchantRejected => 'ร้านค้าปฏิเสธออเดอร์';

  @override
  String get rideStatusMerchantRejectedBody => 'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้\n\nกรุณาลองสั่งใหม่อีกครั้ง หรือเลือกร้านอื่น';

  @override
  String get rideStatusUnderstood => 'เข้าใจแล้ว';

  @override
  String get rideStatusDeliverySuccess => '🎉 จัดส่งสำเร็จแล้ว!';

  @override
  String get rideStatusTripSuccess => '🎉 เดินทางเสร็จสิ้น!';

  @override
  String get rideStatusThankYou => 'ขอบคุณที่ใช้บริการ';

  @override
  String get rideStatusOrderNumber => 'หมายเลขออเดอร์';

  @override
  String get rideStatusTotalAmount => 'ยอดเงินทั้งหมด';

  @override
  String get rideStatusIncludingDelivery => 'รวมค่าจัดส่ง';

  @override
  String rideStatusUsedCouponWithCode(Object code, Object amount) {
    return 'ใช้คูปอง $code ลด ฿$amount';
  }

  @override
  String rideStatusUsedCoupon(Object amount) {
    return 'ใช้คูปอง ลด ฿$amount';
  }

  @override
  String get rideStatusCancelTripTitle => 'ยกเลิกการเดินทาง';

  @override
  String get rideStatusCancelConfirm => 'คุณต้องการยกเลิกการเดินทางนี้ใช่หรือไม่?';

  @override
  String get rideStatusNo => 'ไม่';

  @override
  String get rideStatusYes => 'ใช่';

  @override
  String get rideStatusCancelSuccess => 'ยกเลิกการเดินทางสำเร็จ';

  @override
  String get rideStatusCancelFailed => 'ยกเลิกไม่สำเร็จ';

  @override
  String rideStatusCancelError(Object error) {
    return 'เกิดข้อผิดพลาดในการยกเลิก: $error';
  }

  @override
  String get activityTitle => 'ประวัติการใช้งาน';

  @override
  String get activityPaymentCash => 'เงินสด';

  @override
  String get activityPaymentTransfer => 'โอนเงิน';

  @override
  String get activityPaymentCard => 'บัตรเครดิต';

  @override
  String get activityPaymentUnknown => 'ไม่ระบุการชำระ';

  @override
  String get activityDatePickerHelp => 'เลือกช่วงวันที่';

  @override
  String get activityDatePickerConfirm => 'ยืนยัน';

  @override
  String get activityDatePickerCancel => 'ยกเลิก';

  @override
  String get activityFilterToday => 'วันนี้';

  @override
  String get activityFilterLast7Days => '7 วันที่ผ่านมา';

  @override
  String get activityFilterLast7DaysShort => '7 วัน';

  @override
  String get activityFilterThisMonth => 'เดือนนี้';

  @override
  String get activityFilterAll => 'ทั้งหมด';

  @override
  String get activityFilterDateRange => 'ช่วงวันที่';

  @override
  String get activityTimeUnknown => 'ไม่ทราบ';

  @override
  String activityTimeHoursAgo(Object hours) {
    return '$hours ชั่วโมงที่แล้ว';
  }

  @override
  String activityTimeMinutesAgo(Object minutes) {
    return '$minutes นาทีที่แล้ว';
  }

  @override
  String get activityTimeJustNow => 'เมื่อสักครู่';

  @override
  String get activityServiceRide => 'เรียกรถ';

  @override
  String get activityServiceFood => 'สั่งอาหาร';

  @override
  String get activityServiceParcel => 'ส่งพัสดุ';

  @override
  String get activityFilterByDate => 'กรองตามวันที่';

  @override
  String get activityOrderStats => 'สถิติการสั่งซื้อ';

  @override
  String activityTimePeriod(Object period) {
    return 'ช่วงเวลา: $period';
  }

  @override
  String get activityStatTotal => 'ทั้งหมด';

  @override
  String activityStatItems(Object count) {
    return '$count รายการ';
  }

  @override
  String get activityStatCompleted => 'สำเร็จ';

  @override
  String get activityStatCancelled => 'ยกเลิก';

  @override
  String get activityStatTotalSpent => 'ยอดใช้จ่าย';

  @override
  String get activityStatCouponSavings => 'ประหยัดจากคูปอง';

  @override
  String get activityFilteredEmpty => 'ไม่พบรายการในช่วงวันที่ที่เลือก';

  @override
  String get activityFilteredEmptyHint => 'ลองเปลี่ยนตัวกรองวันที่เพื่อดูประวัติการสั่งซื้อเพิ่มเติม';

  @override
  String get activityLoadFailed => 'โหลดข้อมูลไม่สำเร็จ';

  @override
  String get activityNoHistory => 'ยังไม่มีประวัติ';

  @override
  String get activityNoHistoryHint => 'ประวัติการจองของคุณจะแสดงที่นี่';

  @override
  String activityBookingCode(Object code) {
    return 'รหัส $code';
  }

  @override
  String activityDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String activityScheduledService(Object datetime) {
    return 'นัดหมายรับบริการ: $datetime';
  }

  @override
  String activityScheduledOrder(Object datetime) {
    return 'ออเดอร์นัดหมาย: $datetime';
  }

  @override
  String get activityAmountPaid => 'ยอดชำระ';

  @override
  String get activityViewDetails => 'ดูรายละเอียด';

  @override
  String get activityStatusCompleted => 'สำเร็จ';

  @override
  String get activityStatusCancelled => 'ยกเลิก';

  @override
  String get activityStatusConfirmed => 'ยืนยันแล้ว';

  @override
  String get activityStatusDriverAccepted => 'คนขับรับแล้ว';

  @override
  String get activityStatusInTransit => 'กำลังจัดส่ง';

  @override
  String get activityStatusPreparing => 'กำลังเตรียมอาหาร';

  @override
  String get activityStatusReadyPickup => 'อาหารพร้อมรับ';

  @override
  String get activityStatusArrived => 'ถึงจุดหมาย';

  @override
  String get activityStatusPending => 'รอดำเนินการ';

  @override
  String get activityAddressNotSpecified => 'ไม่ระบุ';

  @override
  String get activityAddressFallback => 'ที่อยู่ปลายทาง';

  @override
  String activityUsedCouponWithCode(Object code, Object amount) {
    return 'ใช้คูปอง $code ลด ฿$amount';
  }

  @override
  String activityUsedCoupon(Object amount) {
    return 'ใช้คูปอง ลด ฿$amount';
  }

  @override
  String get parcelTitle => 'ส่งพัสดุ';

  @override
  String get parcelHeaderTitle => 'บริการส่งพัสดุ';

  @override
  String get parcelHeaderSubtitle => 'ส่งของถึงที่ รวดเร็ว ปลอดภัย';

  @override
  String get parcelSizeSmall => 'เล็ก (S)';

  @override
  String get parcelSizeSmallDesc => 'ซองจดหมาย, เอกสาร';

  @override
  String get parcelSizeMedium => 'กลาง (M)';

  @override
  String get parcelSizeMediumDesc => 'กล่องพัสดุ ไม่เกิน 5 กก.';

  @override
  String get parcelSizeLarge => 'ใหญ่ (L)';

  @override
  String get parcelSizeLargeDesc => 'กล่องใหญ่ ไม่เกิน 15 กก.';

  @override
  String get parcelSizeXLarge => 'พิเศษ (XL)';

  @override
  String get parcelSizeXLargeDesc => 'สิ่งของขนาดใหญ่ ไม่เกิน 30 กก.';

  @override
  String parcelPickupCoord(Object lat, Object lng) {
    return 'จุดรับ ($lat, $lng)';
  }

  @override
  String parcelDropoffCoord(Object lat, Object lng) {
    return 'จุดส่ง ($lat, $lng)';
  }

  @override
  String parcelCurrentLocation(Object lat, Object lng) {
    return 'ตำแหน่งปัจจุบัน ($lat, $lng)';
  }

  @override
  String get parcelErrorNoLocation => 'กรุณารอระบุตำแหน่ง\nหรือเปิด GPS แล้วลองใหม่';

  @override
  String parcelErrorNoDrivers(Object radius) {
    return 'ไม่พบคนขับออนไลน์ภายในรัศมี $radius กม.\nกรุณาลองใหม่อีกครั้งภายหลัง';
  }

  @override
  String get parcelErrorCreateBooking => 'ไม่สามารถสร้างการจองได้';

  @override
  String get parcelErrorBookFailed => 'ไม่สามารถจองส่งพัสดุได้\nกรุณาลองใหม่อีกครั้ง';

  @override
  String get parcelErrorTitle => 'เกิดข้อผิดพลาด';

  @override
  String get parcelOk => 'ตกลง';

  @override
  String parcelDriversFound(Object count, Object radius) {
    return 'พบคนขับออนไลน์ใกล้คุณ $count คน (ในรัศมี $radius กม.)';
  }

  @override
  String parcelNoDriversNearby(Object radius) {
    return 'ยังไม่พบคนขับออนไลน์ในรัศมี $radius กม.';
  }

  @override
  String get parcelSenderInfo => 'ข้อมูลผู้ส่ง';

  @override
  String get parcelSenderName => 'ชื่อผู้ส่ง';

  @override
  String get parcelSenderNameRequired => 'กรุณาระบุชื่อผู้ส่ง';

  @override
  String get parcelSenderPhone => 'เบอร์โทรผู้ส่ง';

  @override
  String get parcelSenderPhoneRequired => 'กรุณาระบุเบอร์โทรผู้ส่ง';

  @override
  String get parcelPickupAddress => 'ที่อยู่จุดรับพัสดุ';

  @override
  String get parcelPickupRequired => 'กรุณาระบุจุดรับพัสดุ';

  @override
  String get parcelPinPickup => 'ปักหมุดจุดรับบนแผนที่';

  @override
  String parcelPickupCoords(Object lat, Object lng) {
    return 'พิกัดจุดรับ: $lat, $lng';
  }

  @override
  String get parcelRecipientInfo => 'ข้อมูลผู้รับ';

  @override
  String get parcelSavedAddresses => 'ที่อยู่บันทึก';

  @override
  String get parcelPinDropoff => 'ปักหมุดจุดส่งบนแผนที่';

  @override
  String get parcelRecipientName => 'ชื่อผู้รับ';

  @override
  String get parcelRecipientNameRequired => 'กรุณาระบุชื่อผู้รับ';

  @override
  String get parcelRecipientPhone => 'เบอร์โทรผู้รับ';

  @override
  String get parcelRecipientPhoneRequired => 'กรุณาระบุเบอร์โทรผู้รับ';

  @override
  String get parcelDropoffAddress => 'ที่อยู่จุดส่งพัสดุ';

  @override
  String get parcelDropoffRequired => 'กรุณาระบุจุดส่งพัสดุ';

  @override
  String parcelEstimatedDistance(Object km) {
    return 'ระยะทางโดยประมาณ: $km กม.';
  }

  @override
  String parcelDropoffCoords(Object lat, Object lng) {
    return 'พิกัดจุดส่ง: $lat, $lng';
  }

  @override
  String get parcelSizeTitle => 'ขนาดพัสดุ';

  @override
  String get parcelDetailsTitle => 'รายละเอียดพัสดุ';

  @override
  String get parcelDescriptionLabel => 'อธิบายสิ่งของ (เช่น เอกสาร, อาหาร, เสื้อผ้า)';

  @override
  String get parcelDescriptionRequired => 'กรุณาอธิบายสิ่งของ';

  @override
  String get parcelWeightLabel => 'น้ำหนักโดยประมาณ (กก.) - ไม่บังคับ';

  @override
  String get parcelPhotoTitle => 'รูปภาพพัสดุ';

  @override
  String get parcelPhotoHint => 'ถ่ายรูปพัสดุเพื่อให้คนขับเห็นสิ่งของ (ไม่บังคับ)';

  @override
  String get parcelPhotoTap => 'แตะเพื่อถ่ายรูปหรือเลือกรูป';

  @override
  String get parcelEstimatedFee => 'ค่าบริการโดยประมาณ';

  @override
  String parcelDistanceKm(Object km) {
    return 'ระยะทาง $km กม.';
  }

  @override
  String get parcelBookButton => 'จองส่งพัสดุ';

  @override
  String get waitingSearchingDriver => 'กำลังค้นหาคนขับ...';

  @override
  String get waitingPriceUpdated => 'ราคาอัปเดตใหม่';

  @override
  String waitingPriceAdjustedBody(Object oldPrice, Object newPrice) {
    return 'ราคาถูกปรับใหม่เนื่องจากคนขับที่รับงานอยู่เกินระยะที่กำหนด\n\nราคาเดิม: ฿$oldPrice\nราคาใหม่: ฿$newPrice\n\nต้องการดำเนินการต่อหรือไม่?';
  }

  @override
  String get waitingCancelJob => 'ยกเลิกงาน';

  @override
  String get waitingContinue => 'ดำเนินการต่อ';

  @override
  String get waitingConnectionError => 'การเชื่อมต่อขัดข้อง กำลังลองใหม่...';

  @override
  String get waitingConnectionFailed => 'เชื่อมต่อไม่สำเร็จ';

  @override
  String waitingCannotConnect(Object error) {
    return 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้: $error';
  }

  @override
  String get waitingOk => 'ตกลง';

  @override
  String get waitingDriverFallback => 'คนขับ';

  @override
  String get waitingMotorcycleFallback => 'รถจักรยานยนต์';

  @override
  String get waitingMerchantRejected => 'ร้านค้าปฏิเสธออเดอร์';

  @override
  String get waitingMerchantRejectedBody => 'ขออภัย ร้านค้าไม่สามารถรับออเดอร์ของคุณได้ในขณะนี้\n\nกรุณาลองสั่งใหม่อีกครั้ง หรือเลือกร้านอื่น';

  @override
  String get waitingUnderstood => 'เข้าใจแล้ว';

  @override
  String get waitingForMerchant => 'กำลังรอร้านค้า';

  @override
  String get waitingSearchingForDriver => 'กำลังค้นหาคนขับ';

  @override
  String get waitingMerchantConfirmed => 'ร้านค้ายืนยันคำสั่งซื้อ!';

  @override
  String get waitingDriverFound => 'พบคนขับแล้ว!';

  @override
  String get waitingForMerchantDots => 'กำลังรอร้านค้า...';

  @override
  String get waitingSearchingDriverDots => 'กำลังค้นหาคนขับ...';

  @override
  String get waitingMerchantPreparing => 'ร้านค้ากำลังเตรียมอาหารของคุณ';

  @override
  String get waitingDriverComing => 'คนขับกำลังเดินทางมาหาคุณ';

  @override
  String waitingEstimatedTime(Object minutes) {
    return 'ระบบเวลาโดยประมาณ $minutes นาที';
  }

  @override
  String get waitingRestaurantPreparing => 'ร้านค้ากำลังเตรียมอาหาร';

  @override
  String get waitingPleaseWait => 'โปรดรอสักครู่...';

  @override
  String get waitingAssigned => 'มอบหมายแล้ว';

  @override
  String get waitingContactDriver => 'ติดต่อคนขับ';

  @override
  String get waitingCancelBooking => 'ยกเลิกการจอง';

  @override
  String get waitingPhoneCall => 'โทรศัพท์';

  @override
  String get waitingChatWithDriver => 'แชทกับคนขับ';

  @override
  String get waitingChatInApp => 'ส่งข้อความในแอป';

  @override
  String get waitingClose => 'ปิด';

  @override
  String waitingCannotCall(Object phone) {
    return 'ไม่สามารถโทรไปที่ $phone ได้';
  }

  @override
  String get waitingCannotOpenChat => 'ไม่สามารถเปิดแชทได้';

  @override
  String get waitingCancelBookingTitle => 'ยกเลิกการจอง';

  @override
  String get waitingCancelConfirm => 'คุณแน่ใจว่าต้องการยกเลิกการจองนี้?';

  @override
  String get waitingNo => 'ไม่';

  @override
  String get waitingCancelFailed => 'ยกเลิกไม่สำเร็จ';

  @override
  String waitingCancelError(Object error) {
    return 'เกิดข้อผิดพลาดในการยกเลิก: $error';
  }

  @override
  String get waitingCancel => 'ยกเลิก';

  @override
  String get waitingBookingInfo => 'ข้อมูลการจอง';

  @override
  String waitingOrderCode(Object code) {
    return 'รหัสออเดอร์: $code';
  }

  @override
  String waitingType(Object type) {
    return 'ประเภท: $type';
  }

  @override
  String waitingPrice(Object price) {
    return 'ราคา: ฿$price';
  }

  @override
  String waitingStatus(Object status) {
    return 'สถานะ: $status';
  }

  @override
  String get restCategoryOther => 'อื่นๆ';

  @override
  String get restDeliveryTime => '20-30 นาที';

  @override
  String get restDeliveryFee => 'ค่าส่ง ฿15';

  @override
  String restCouponCopied(Object code) {
    return 'คัดลอกโค้ด $code แล้ว';
  }

  @override
  String get restCouponHint => 'แตะเพื่อคัดลอกโค้ดไปใช้ตอนชำระเงิน';

  @override
  String get restNoMenu => 'ไม่มีเมนูในขณะนี้';

  @override
  String get restRefresh => 'รีเฟรช';

  @override
  String get restCannotLoadMenu => 'ไม่สามารถโหลดเมนูได้';

  @override
  String get restTryAgain => 'กรุณาลองใหม่อีกครั้ง';

  @override
  String get restRetry => 'ลองใหม่';

  @override
  String get restSwitchRestaurant => 'เปลี่ยนร้านอาหาร?';

  @override
  String restSwitchRestaurantBody(Object name) {
    return 'ตะกร้ามีอาหารจาก \"$name\" อยู่\nต้องการล้างตะกร้าและสั่งจากร้านนี้แทนหรือไม่?';
  }

  @override
  String get restCancel => 'ยกเลิก';

  @override
  String get restClearAndAdd => 'ล้างและเพิ่ม';

  @override
  String restAddedToCart(Object name) {
    return 'เพิ่ม $name ลงตะกร้าแล้ว';
  }

  @override
  String get restViewCart => 'ดูตะกร้า';

  @override
  String get restYourCart => 'ตะกร้าของคุณ';

  @override
  String get restClear => 'ล้าง';

  @override
  String get restTotal => 'รวม';

  @override
  String restGoToCheckout(Object amount) {
    return 'ไปชำระเงิน — ฿$amount';
  }

  @override
  String get restItemNoName => 'ไม่ระบุชื่อ';

  @override
  String get restMustSelectOption => 'ต้องเลือกตัวเลือก';

  @override
  String get ratingPleaseRateDriver => 'กรุณาให้คะแนนคนขับ';

  @override
  String get ratingPleaseRateMerchant => 'กรุณาให้คะแนนร้านค้า';

  @override
  String get ratingUserNotFound => 'ไม่พบข้อมูลผู้ใช้';

  @override
  String ratingError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get ratingThankYou => 'ขอบคุณสำหรับการให้คะแนน!';

  @override
  String get ratingFeedbackHelps => 'ความคิดเห็นของคุณช่วยพัฒนาบริการ';

  @override
  String get ratingTitle => 'ให้คะแนน';

  @override
  String get ratingRateDriver => 'ให้คะแนนคนขับ';

  @override
  String get ratingDriverHint => 'แสดงความคิดเห็นเกี่ยวกับคนขับ (ไม่บังคับ)';

  @override
  String get ratingRateMerchant => 'ให้คะแนนร้านค้า';

  @override
  String get ratingMerchantHint => 'แสดงความคิดเห็นเกี่ยวกับร้านค้า (ไม่บังคับ)';

  @override
  String get ratingSubmit => 'ส่งคะแนน';

  @override
  String get ratingSkip => 'ข้ามไปก่อน';

  @override
  String get ratingServiceFood => 'สั่งอาหาร';

  @override
  String get ratingServiceRide => 'เรียกรถ';

  @override
  String get ratingServiceParcel => 'ส่งพัสดุ';

  @override
  String get ratingLabel1 => 'แย่มาก';

  @override
  String get ratingLabel2 => 'ไม่ดี';

  @override
  String get ratingLabel3 => 'ปานกลาง';

  @override
  String get ratingLabel4 => 'ดี';

  @override
  String get ratingLabel5 => 'ยอดเยี่ยม';

  @override
  String get cancelReasonWaitTooLong => 'รอนานเกินไป';

  @override
  String get cancelReasonChangedMind => 'เปลี่ยนใจ ไม่ต้องการแล้ว';

  @override
  String get cancelReasonWrongAddress => 'ใส่ที่อยู่ผิด';

  @override
  String get cancelReasonPriceTooHigh => 'ราคาสูงเกินไป';

  @override
  String get cancelReasonWrongOrder => 'สั่งผิดรายการ';

  @override
  String get cancelReasonOther => 'เหตุผลอื่น';

  @override
  String get cancelSelectReason => 'กรุณาเลือกเหตุผลการยกเลิก';

  @override
  String get cancelConfirmTitle => 'ยืนยันการยกเลิก';

  @override
  String get cancelConfirmBody => 'คุณแน่ใจว่าต้องการยกเลิกออเดอร์นี้?';

  @override
  String cancelReasonLabel(Object reason) {
    return 'เหตุผล: $reason';
  }

  @override
  String get cancelKeep => 'ไม่ยกเลิก';

  @override
  String get cancelConfirmBtn => 'ยืนยันยกเลิก';

  @override
  String get cancelSuccess => 'ยกเลิกออเดอร์สำเร็จ';

  @override
  String cancelError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get cancelServiceFood => 'ออเดอร์อาหาร';

  @override
  String get cancelServiceRide => 'เรียกรถ';

  @override
  String get cancelServiceParcel => 'ส่งพัสดุ';

  @override
  String get cancelServiceDefault => 'ออเดอร์';

  @override
  String get cancelTitle => 'ยกเลิกออเดอร์';

  @override
  String get cancelReasonsTitle => 'เหตุผลในการยกเลิก';

  @override
  String get cancelReasonsSubtitle => 'กรุณาเลือกเหตุผลเพื่อช่วยเราปรับปรุงบริการ';

  @override
  String get cancelOtherHint => 'โปรดระบุเหตุผล...';

  @override
  String get cancelButton => 'ยกเลิกออเดอร์';

  @override
  String get addrLabelHome => 'บ้าน';

  @override
  String get addrLabelWork => 'ที่ทำงาน';

  @override
  String get addrLabelOther => 'อื่นๆ';

  @override
  String get addrEditTitle => 'แก้ไขที่อยู่';

  @override
  String get addrAddTitle => 'เพิ่มที่อยู่ใหม่';

  @override
  String get addrType => 'ประเภท';

  @override
  String get addrPlaceName => 'ชื่อสถานที่';

  @override
  String get addrPlaceNameHint => 'เช่น บ้านพ่อแม่, คอนโด';

  @override
  String get addrPinPlaced => 'ปักหมุดแล้ว';

  @override
  String get addrPinOnMap => 'ปักหมุดบนแผนที่';

  @override
  String get addrAddressLabel => 'ที่อยู่ (รายละเอียดเพิ่มเติม)';

  @override
  String get addrAddressHint => 'เช่น 123/4 ถ.สุขุมวิท';

  @override
  String get addrNoteLabel => 'หมายเหตุ (ไม่บังคับ)';

  @override
  String get addrNoteHint => 'เช่น ตึก A ชั้น 5 ห้อง 501';

  @override
  String get addrCancel => 'ยกเลิก';

  @override
  String get addrValidation => 'กรุณากรอกชื่อสถานที่และปักหมุดบนแผนที่';

  @override
  String get addrSave => 'บันทึก';

  @override
  String get addrDeleteTitle => 'ลบที่อยู่';

  @override
  String addrDeleteConfirm(Object name) {
    return 'ต้องการลบ \"$name\" หรือไม่?';
  }

  @override
  String get addrDelete => 'ลบ';

  @override
  String get addrPickTitle => 'เลือกที่อยู่';

  @override
  String get addrBookTitle => 'สมุดที่อยู่';

  @override
  String get addrAddButton => 'เพิ่มที่อยู่';

  @override
  String get addrEmptyTitle => 'ยังไม่มีที่อยู่ที่บันทึก';

  @override
  String get addrEmptySubtitle => 'เพิ่มที่อยู่ \"บ้าน\" หรือ \"ที่ทำงาน\"\nเพื่อเลือกง่ายๆ ไม่ต้องพิมพ์ใหม่ทุกครั้ง';

  @override
  String addrQuickAdd(Object name) {
    return 'เพิ่ม $name';
  }

  @override
  String get confirmServiceFood => 'สั่งอาหาร';

  @override
  String get confirmServiceRide => 'เรียกรถ';

  @override
  String get confirmServiceParcel => 'ส่งพัสดุ';

  @override
  String get confirmSuccess => 'จองสำเร็จ!';

  @override
  String confirmOrderCode(Object code) {
    return 'ออเดอร์ $code';
  }

  @override
  String get confirmPickup => 'จุดรับ';

  @override
  String get confirmDestination => 'จุดส่ง';

  @override
  String get confirmNotSpecified => 'ไม่ระบุ';

  @override
  String get confirmDistance => 'ระยะทาง';

  @override
  String confirmDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String get confirmOrderTime => 'เวลาสั่ง';

  @override
  String get confirmFoodCost => 'ค่าอาหาร';

  @override
  String get confirmDeliveryFee => 'ค่าจัดส่ง';

  @override
  String get confirmTotal => 'ยอดรวม';

  @override
  String get confirmPayCash => 'ชำระเงินสด';

  @override
  String get confirmCash => 'เงินสด';

  @override
  String get confirmTrackOrder => 'ติดตามออเดอร์';

  @override
  String get confirmBackToHome => 'กลับหน้าหลัก';

  @override
  String foodDetAddedToCart(Object name) {
    return 'เพิ่ม $name ลงตะกร้าแล้ว';
  }

  @override
  String foodDetAddFailed(Object error) {
    return 'เพิ่มลงตะกร้าไม่สำเร็จ: $error';
  }

  @override
  String get foodDetAvailable => 'พร้อมจำหน่าย';

  @override
  String get foodDetSoldOut => 'หมด';

  @override
  String get foodDetCustomize => 'ปรับแต่งออเดอร์';

  @override
  String get foodDetNoOptions => 'ไม่มีตัวเลือกเพิ่มเติมสำหรับเมนูนี้';

  @override
  String get foodDetLoadingOptions => 'กำลังโหลดตัวเลือก...';

  @override
  String get foodDetDescription => 'รายละเอียด';

  @override
  String get foodDetRestaurant => 'ร้านอาหาร';

  @override
  String foodDetAddToCart(Object price) {
    return 'เพิ่มลงตะกร้า — ฿$price';
  }

  @override
  String foodDefaultNote(Object merchant) {
    return 'สั่งอาหารจาก $merchant';
  }

  @override
  String foodCouponNote(Object code, Object amount) {
    return '[คูปอง: $code | ส่วนลด: ฿$amount]';
  }

  @override
  String get trackPickup => 'จุดรับ';

  @override
  String get trackDestination => 'จุดส่ง';

  @override
  String get trackNotSpecified => 'ไม่ระบุ';

  @override
  String get trackDriverFallback => 'คนขับ';

  @override
  String get trackStatusPendingTitle => 'รอคนขับรับงาน';

  @override
  String get trackStatusPendingSub => 'กำลังค้นหาคนขับในพื้นที่ใกล้คุณ';

  @override
  String get trackStatusAcceptedTitle => 'คนขับรับงานแล้ว';

  @override
  String get trackStatusAcceptedSub => 'คนขับกำลังเดินทางมาหาคุณ';

  @override
  String get trackStatusPickingUpTitle => 'กำลังรับสินค้า';

  @override
  String get trackStatusPickingUpSub => 'คนขับถึงจุดรับแล้ว';

  @override
  String get trackStatusPreparingTitle => 'ร้านกำลังเตรียม';

  @override
  String get trackStatusPreparingSub => 'ร้านค้ากำลังเตรียมออเดอร์ของคุณ';

  @override
  String get trackStatusInTransitTitle => 'กำลังจัดส่ง';

  @override
  String get trackStatusInTransitSub => 'คนขับกำลังเดินทางไปจุดส่ง';

  @override
  String get trackStatusArrivedTitle => 'ถึงจุดส่งแล้ว';

  @override
  String get trackStatusArrivedSub => 'คนขับถึงจุดหมายปลายทางแล้ว';

  @override
  String get trackStatusCompletedTitle => 'จัดส่งสำเร็จ';

  @override
  String get trackStatusCompletedSub => 'ออเดอร์เสร็จสมบูรณ์';

  @override
  String get trackStatusCancelledTitle => 'ยกเลิกแล้ว';

  @override
  String get trackStatusCancelledSub => 'ออเดอร์นี้ถูกยกเลิก';

  @override
  String get trackStatusUnknownTitle => 'ไม่ทราบสถานะ';

  @override
  String get trackTimelineCreated => 'สร้างออเดอร์แล้ว';

  @override
  String get trackTimelineAccepted => 'คนขับรับงาน';

  @override
  String get trackTimelinePickingUp => 'กำลังรับสินค้า';

  @override
  String get trackTimelineInTransit => 'กำลังจัดส่ง';

  @override
  String get trackTimelineCompleted => 'จัดส่งสำเร็จ';

  @override
  String get helpTitle => 'ช่วยเหลือ';

  @override
  String get helpCenterTitle => 'ศูนย์ช่วยเหลือ';

  @override
  String get helpCenterSubtitle => 'พร้อมช่วยเหลือคุณตลอด 24 ชั่วโมง';

  @override
  String get helpContactTitle => 'ช่องทางติดต่อ';

  @override
  String get helpPhone => 'โทรศัพท์';

  @override
  String get helpEmail => 'อีเมล';

  @override
  String get helpFaqTitle => 'คำถามที่พบบ่อย (FAQ)';

  @override
  String get helpReportProblem => 'รายงานปัญหา';

  @override
  String get helpFaq1Q => 'สั่งอาหารแล้วไม่ได้รับ ทำอย่างไร?';

  @override
  String get helpFaq1A => 'กรุณาตรวจสอบสถานะออเดอร์ในหน้า \"กิจกรรม\" หากออเดอร์แสดงว่าจัดส่งแล้วแต่ยังไม่ได้รับ ให้แจ้งปัญหาผ่านปุ่ม \"รายงานปัญหา\" ด้านล่าง ทีมงานจะตรวจสอบและดำเนินการภายใน 24 ชั่วโมง';

  @override
  String get helpFaq2Q => 'จะยกเลิกออเดอร์ได้อย่างไร?';

  @override
  String get helpFaq2A => 'ไปที่หน้า \"กิจกรรม\" > เลือกออเดอร์ที่ต้องการ > กด \"ยกเลิก\" หมายเหตุ: สามารถยกเลิกได้เฉพาะออเดอร์ที่ยังไม่มีคนขับรับงาน';

  @override
  String get helpFaq3Q => 'ค่าจัดส่งคำนวณอย่างไร?';

  @override
  String get helpFaq3A => 'ค่าจัดส่งคำนวณจากระยะทางระหว่างร้านค้า/จุดรับ กับจุดหมายปลายทางของคุณ โดยมีค่าขั้นต่ำและราคาต่อกิโลเมตรตามที่ระบบกำหนด';

  @override
  String get helpFaq4Q => 'ชำระเงินได้ช่องทางไหนบ้าง?';

  @override
  String get helpFaq4A => 'ปัจจุบันรองรับการชำระด้วยเงินสด PromptPay และ Mobile Banking ทีมงานกำลังพัฒนาช่องทางเพิ่มเติม';

  @override
  String get helpFaq5Q => 'อาหารที่ได้รับไม่ถูกต้อง ทำอย่างไร?';

  @override
  String get helpFaq5A => 'กรุณาแจ้งปัญหาผ่านปุ่ม \"รายงานปัญหา\" พร้อมแนบรูปถ่ายและรายละเอียด ทีมงานจะประสานงานกับร้านค้าเพื่อแก้ไขให้';

  @override
  String get helpFaq6Q => 'สมัครเป็นคนขับได้อย่างไร?';

  @override
  String get helpFaq6A => 'ลงทะเบียนผ่านแอปโดยเลือก role เป็น \"คนขับ\" จากนั้นกรอกข้อมูลส่วนตัว ใบขับขี่ และรอการอนุมัติจากแอดมิน';

  @override
  String get payTitle => 'การชำระเงิน';

  @override
  String get payCash => 'เงินสด';

  @override
  String get payCashSubtitle => 'ชำระเงินสดกับคนขับ';

  @override
  String get payPromptPaySubtitle => 'โอนผ่าน QR Code';

  @override
  String get payMobileBankingSubtitle => 'โอนผ่านแอปธนาคาร';

  @override
  String payError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get paySuccess => 'ชำระเงินสำเร็จ!';

  @override
  String get payCashPrepare => 'กรุณาเตรียมเงินสดให้คนขับ';

  @override
  String get payRecorded => 'รายการชำระเงินบันทึกแล้ว';

  @override
  String get payOk => 'ตกลง';

  @override
  String get paySelectMethod => 'เลือกวิธีชำระเงิน';

  @override
  String get payPromptPayNote => 'ระบบจะสร้าง QR Code สำหรับโอนเงินผ่าน PromptPay ให้อัตโนมัติ';

  @override
  String payButton(Object amount) {
    return 'ชำระเงิน ฿$amount';
  }

  @override
  String get payTotalAmount => 'ยอดรวมทั้งหมด';

  @override
  String get payFoodCost => 'ค่าอาหาร';

  @override
  String get payDeliveryFee => 'ค่าส่ง';

  @override
  String get ticketTitle => 'แจ้งปัญหา / ร้องเรียน';

  @override
  String get ticketCatLostItem => 'ของหาย';

  @override
  String get ticketCatWrongOrder => 'อาหาร/สินค้าผิด';

  @override
  String get ticketCatRudeDriver => 'คนขับไม่สุภาพ';

  @override
  String get ticketCatRefund => 'ขอคืนเงิน';

  @override
  String get ticketCatAppBug => 'ปัญหาแอป';

  @override
  String get ticketCatOther => 'อื่นๆ';

  @override
  String get ticketCreateTitle => 'แจ้งปัญหา';

  @override
  String get ticketCategoryLabel => 'ประเภทปัญหา';

  @override
  String get ticketSubjectLabel => 'หัวข้อ';

  @override
  String get ticketSubjectHint => 'เช่น ลืมของไว้ในรถ';

  @override
  String get ticketDescLabel => 'รายละเอียด';

  @override
  String get ticketDescHint => 'อธิบายปัญหาให้ละเอียด...';

  @override
  String get ticketValidation => 'กรุณากรอกข้อมูลให้ครบถ้วน';

  @override
  String get ticketSubmit => 'ส่งแจ้งปัญหา';

  @override
  String get ticketFab => 'แจ้งปัญหา';

  @override
  String get ticketEmptyTitle => 'ยังไม่มีรายการแจ้งปัญหา';

  @override
  String get ticketEmptySubtitle => 'หากพบปัญหากดปุ่ม \"แจ้งปัญหา\" ด้านล่าง';

  @override
  String get mapPickerTitle => 'เลือกตำแหน่งจัดส่ง';

  @override
  String get mapPickerLoadingAddress => 'กำลังโหลดที่อยู่...';

  @override
  String get mapPickerSearching => 'กำลังค้นหาที่อยู่...';

  @override
  String get mapPickerDeliveryLocation => 'ตำแหน่งจัดส่ง';

  @override
  String get mapPickerConfirm => 'ยืนยันตำแหน่งนี้';

  @override
  String mapPickerPosition(Object lat, Object lng) {
    return 'ตำแหน่ง: $lat, $lng';
  }

  @override
  String get foodSvcTitle => 'สั่งอาหาร';

  @override
  String foodSvcLoadError(Object error) {
    return 'ไม่สามารถโหลดรายชื่อร้านอาหารได้: $error';
  }

  @override
  String get foodSvcRetry => 'ลองใหม่';

  @override
  String get foodSvcEmpty => 'ไม่มีร้านอาหารเปิดให้บริการในขณะนี้';

  @override
  String get foodSvcRefresh => 'รีเฟรช';

  @override
  String get foodSvcRestaurantFallback => 'ร้านอาหาร';

  @override
  String get foodSvcNotSpecified => 'ไม่ระบุ';

  @override
  String get foodSvcOpen => 'เปิด';

  @override
  String get accountEditName => 'แก้ไขชื่อ';

  @override
  String get accountEditPhone => 'แก้ไขเบอร์โทร';

  @override
  String get accountEditNameHint => 'กรอกชื่อ-นามสกุล';

  @override
  String get accountEditPhoneHint => 'กรอกเบอร์โทรศัพท์';

  @override
  String get accountEditCancel => 'ยกเลิก';

  @override
  String get accountEditSave => 'บันทึก';

  @override
  String get accountEditSuccess => 'อัปเดตสำเร็จ!';

  @override
  String accountEditError(Object error) {
    return 'อัปเดตไม่สำเร็จ: $error';
  }

  @override
  String get accountUserFallback => 'ผู้ใช้';

  @override
  String get couponScreenTitle => 'คูปองของฉัน';

  @override
  String get couponTabMine => 'คูปองของฉัน';

  @override
  String get couponTabDiscover => 'เก็บคูปองเพิ่ม';

  @override
  String get couponTabHistory => 'ประวัติการใช้';

  @override
  String get couponEmptyWallet => 'ไม่มีคูปองในกระเป๋า';

  @override
  String get couponEmptyDiscover => 'ไม่มีคูปองใหม่ให้เก็บในขณะนี้';

  @override
  String get couponEmptyHistory => 'ยังไม่มีประวัติการใช้คูปอง';

  @override
  String get couponClaimSuccess => 'เก็บคูปองสำเร็จ!';

  @override
  String couponRemainingUses(Object count) {
    return 'เหลือ $count สิทธิ์';
  }

  @override
  String couponExpiry(Object date) {
    return 'หมดอายุ: $date';
  }

  @override
  String get couponClaimed => 'เก็บแล้ว';

  @override
  String get couponClaim => 'เก็บ';

  @override
  String couponHistoryCode(Object code, Object time) {
    return 'โค้ด: $code\nเวลา: $time';
  }

  @override
  String get referralTitle => 'ชวนเพื่อนรับรางวัล';

  @override
  String get referralHeroTitle => 'ชวนเพื่อนใช้แอป\nรับคูปองทั้งคู่!';

  @override
  String get referralHeroSubtitle => 'รับคูปองส่วนลด 20 บาท ทันที\nเมื่อเพื่อนของคุณสั่งอาหารครั้งแรกสำเร็จ';

  @override
  String get referralMyCodeLabel => 'โค้ดชวนเพื่อนของคุณ';

  @override
  String get referralShareButton => 'แชร์ให้เพื่อน';

  @override
  String get referralHaveCode => 'มีโค้ดชวนเพื่อนไหม?';

  @override
  String get referralEnterCodeHint => 'กรอกโค้ดจากเพื่อนเพื่อรับคูปองต้อนรับทันที';

  @override
  String get referralCodePlaceholder => 'กรอกโค้ดที่นี่';

  @override
  String get referralUseCode => 'ใช้โค้ด';

  @override
  String get referralCopied => 'คัดลอกโค้ดชวนเพื่อนแล้ว';

  @override
  String get referralCodeSuccess => 'ใช้โค้ดสำเร็จ!';

  @override
  String get referralOk => 'ตกลง';

  @override
  String get referralSuccessful => 'ชวนสำเร็จ';

  @override
  String get referralHowTitle => 'ทำงานอย่างไร?';

  @override
  String get referralStep1Title => 'แชร์โค้ดให้เพื่อน';

  @override
  String get referralStep1Desc => 'ส่งโค้ดของคุณให้เพื่อนที่ยังไม่เคยใช้แอป';

  @override
  String get referralStep2Title => 'เพื่อนสั่งอาหารครั้งแรก';

  @override
  String get referralStep2Desc => 'เพื่อนสมัครและสั่งอาหารสำเร็จเป็นครั้งแรก';

  @override
  String get referralStep3Title => 'รับคูปองส่วนลด!';

  @override
  String get referralStep3Desc => 'คุณจะได้คูปองส่วนลดส่งตรงเข้ากระเป๋าทันที';

  @override
  String get driverAssignedTitle => 'คนขับรับงานแล้ว';

  @override
  String get driverAssignedHeading => 'คนขับรับงานแล้ว!';

  @override
  String get driverAssignedSubtitle => 'คนขับกำลังเดินทางมาหาคุณ';

  @override
  String get driverAssignedOnTheWay => 'คนขับกำลังเดินทาง';

  @override
  String get driverAssignedEta => 'ระยะเวลาโดยประมาณ: 5-10 นาที';

  @override
  String get driverAssignedContact => 'ติดต่อคนขับ';

  @override
  String get driverAssignedCancelBooking => 'ยกเลิกการจอง';

  @override
  String get driverAssignedContactTitle => 'ติดต่อคนขับ';

  @override
  String get driverAssignedPhone => 'โทรศัพท์';

  @override
  String get driverAssignedMessage => 'ข้อความ';

  @override
  String get driverAssignedMessageSub => 'ส่งข้อความถึงคนขับ';

  @override
  String get driverAssignedClose => 'ปิด';

  @override
  String get driverAssignedCancelTitle => 'ยกเลิกการจอง';

  @override
  String get driverAssignedCancelBody => 'คุณแน่ใจว่าต้องการยกเลิกการจองนี้?';

  @override
  String get driverAssignedNo => 'ไม่';

  @override
  String get driverAssignedCancel => 'ยกเลิก';

  @override
  String get mapSvcRide => 'เรียกรถ';

  @override
  String get mapSvcFood => 'สั่งอาหาร';

  @override
  String get mapSvcParcel => 'ส่งของ';

  @override
  String get mapSelectService => 'เลือกบริการ';

  @override
  String get mapFindingLocation => 'กำลังหาตำแหน่ง...';

  @override
  String get mapUserFallback => 'ผู้ใช้';

  @override
  String get mapLogout => 'ออกจากระบบ';

  @override
  String get mapLocServiceTitle => 'บริการตำแหน่ง';

  @override
  String get mapLocServiceBody => 'บริการตำแหน่งถูกปิดใช้งานอยู่ กรุณาเปิดใช้งานบริการตำแหน่ง';

  @override
  String get mapLocOpenSettings => 'เปิดการตั้งค่า';

  @override
  String get mapLocCancel => 'ยกเลิก';

  @override
  String get mapLocPermTitle => 'สิทธิ์การเข้าถึงตำแหน่ง';

  @override
  String get mapLocPermDenied => 'การอนุญาตให้เข้าถึงตำแหน่งถูกปฏิเสธ กรุณาอนุญาตให้เข้าถึงตำแหน่งเพื่อใช้งานแผนที่';

  @override
  String get mapLocRetry => 'ลองใหม่';

  @override
  String get mapLocPermForever => 'การอนุญาตให้เข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดการตั้งค่าแอปเพื่ออนุญาตสิทธิ์';

  @override
  String get mapLocErrorTitle => 'ข้อผิดพลาดตำแหน่ง';

  @override
  String mapLocErrorBody(Object error) {
    return 'ไม่สามารถดึงตำแหน่งได้: $error';
  }

  @override
  String get mapLocOk => 'ตกลง';

  @override
  String mapLogoutError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get rideTitle => 'เรียกรถ';

  @override
  String get rideMotorcycle => 'มอเตอร์ไซค์';

  @override
  String get rideCar => 'รถยนต์';

  @override
  String get rideMotorcycleDesc => 'เร็ว ประหยัด';

  @override
  String get rideCarDesc => 'สะดวกสบาย';

  @override
  String get rideSelectPayment => 'เลือกวิธีชำระเงิน';

  @override
  String get rideCash => 'เงินสด';

  @override
  String get rideTransfer => 'โอนเงิน';

  @override
  String get rideSelectDestination => 'กรุณาเลือกจุดหมายปลายทาง';

  @override
  String get rideSelectVehicle => 'กรุณาเลือกประเภทรถก่อนเรียก';

  @override
  String get ridePleaseLogin => 'กรุณาเข้าสู่ระบบ';

  @override
  String get rideSearchingDriver => 'กำลังค้นหาคนขับ...';

  @override
  String rideError(Object error) {
    return 'เกิดข้อผิดพลาด: $error';
  }

  @override
  String get rideCurrentLocation => 'ตำแหน่งปัจจุบัน';

  @override
  String get rideFindingLocation => 'กำลังหาตำแหน่ง...';

  @override
  String get rideDestHint => 'ไปไหน? แตะแผนที่เพื่อเลือก';

  @override
  String rideOnlineCount(Object count) {
    return 'ออนไลน์ $count คน';
  }

  @override
  String get rideNoDrivers => 'ไม่มีคนขับ';

  @override
  String rideNoVehicleOnline(Object vehicle) {
    return 'ไม่มี$vehicleออนไลน์ในขณะนี้';
  }

  @override
  String rideDistanceKm(Object km) {
    return '$km กม.';
  }

  @override
  String get rideBtnSelectDest => 'เลือกจุดหมายปลายทาง';

  @override
  String get rideBtnSelectVehicle => 'กรุณาเลือกประเภทรถ';

  @override
  String rideBtnCallRide(Object price) {
    return 'เรียกรถ — ฿$price';
  }

  @override
  String rideNoteVehicleType(Object name) {
    return 'ประเภทรถ: $name';
  }

  @override
  String rideNotePickupSurcharge(Object km, Object surcharge) {
    return 'เพิ่มระยะคนขับ→จุดรับ $km กม. (+฿$surcharge)';
  }

  @override
  String get ridePickupAddress => 'ตำแหน่งปัจจุบัน';

  @override
  String get rideNotifTitle => '🚗 งานใหม่! รับส่งผู้โดยสาร';

  @override
  String rideNotifBody(Object pickup, Object destination, Object price) {
    return 'มีคนเรียกรถจาก $pickup ไป $destination - ราคา ฿$price';
  }

  @override
  String get rideNotifPickupFallback => 'จุดเริ่มต้น';

  @override
  String get rideNotifDestFallback => 'จุดหมาย';

  @override
  String get drvProfileEditName => 'แก้ไขชื่อ';

  @override
  String get drvProfileEditPhone => 'แก้ไขเบอร์โทร';

  @override
  String get drvProfileEditPlate => 'แก้ไขทะเบียนรถ';

  @override
  String get drvProfileHintName => 'ชื่อ-นามสกุล';

  @override
  String get drvProfileHintPhone => 'เบอร์โทรศัพท์';

  @override
  String get drvProfileHintPlate => 'เช่น กข 1234';

  @override
  String get drvProfileCancel => 'ยกเลิก';

  @override
  String get drvProfileSave => 'บันทึก';

  @override
  String get drvProfileUpdateSuccess => 'อัปเดตสำเร็จ!';

  @override
  String drvProfileUpdateError(Object error) {
    return 'อัปเดตไม่สำเร็จ: $error';
  }

  @override
  String get drvProfileSelectVehicle => 'เลือกประเภทรถ';

  @override
  String get drvProfileMotorcycle => 'มอเตอร์ไซค์';

  @override
  String get drvProfileCar => 'รถยนต์';

  @override
  String get earnTitle => 'รายได้';

  @override
  String get earnWalletTooltip => 'กระเป๋าเงิน';

  @override
  String get earnRefresh => 'รีเฟรช';

  @override
  String get earnLoadError => 'ไม่สามารถโหลดข้อมูลได้';

  @override
  String get earnRetry => 'ลองใหม่';

  @override
  String get earnPeriodToday => 'วันนี้';

  @override
  String get earnPeriodWeek => 'สัปดาห์นี้';

  @override
  String get earnPeriodMonth => 'เดือนนี้';

  @override
  String get earnPeriodAll => 'ทั้งหมด';

  @override
  String get earnPeriodCustom => 'ระบุวันที่';

  @override
  String earnRevenueLabel(Object period) {
    return 'รายได้$period';
  }

  @override
  String earnAvgPerJob(Object amount) {
    return 'เฉลี่ย $amount / งาน';
  }

  @override
  String get earnTotalJobs => 'งานทั้งหมด';

  @override
  String get earnCompleted => 'สำเร็จ';

  @override
  String get earnCancelled => 'ยกเลิก';

  @override
  String get earnWalletTitle => 'กระเป๋าเงิน';

  @override
  String get earnWalletLoading => 'กำลังโหลด...';

  @override
  String earnWalletBaht(Object amount) {
    return '$amount บาท';
  }

  @override
  String get earnViewAll => 'ดูทั้งหมด';

  @override
  String get earnJobHistory => 'ประวัติงาน';

  @override
  String get earnNoJobs => 'ไม่มีงานในช่วงเวลานี้';

  @override
  String get earnStatusCompleted => 'สำเร็จ';

  @override
  String get earnStatusCancelled => 'ยกเลิก';

  @override
  String get earnStatusPickedUp => 'รับแล้ว';

  @override
  String get earnStatusDelivering => 'กำลังส่ง';

  @override
  String get earnSvcRide => 'รับส่ง';

  @override
  String get earnSvcFood => 'อาหาร';

  @override
  String get earnSvcParcel => 'พัสดุ';

  @override
  String get earnSvcOther => 'อื่นๆ';

  @override
  String earnAppFee(Object amount) {
    return '(ค่าบริการระบบ $amount)';
  }

  @override
  String get earnCollectCustomer => 'เก็บเงินลูกค้า';

  @override
  String get earnCouponDiscount => 'ส่วนลดจากคูปอง';

  @override
  String get earnOpenDetailError => 'ไม่สามารถเปิดรายละเอียดงานได้';

  @override
  String get earnUserNotFound => 'ไม่พบข้อมูลผู้ใช้';

  @override
  String get jobDetailTitle => 'รายละเอียดการให้บริการ';

  @override
  String get jobDetailNoRoute => 'ไม่มีข้อมูลเส้นทาง';

  @override
  String get jobDetailPickupFallback => 'จุดรับ';

  @override
  String get jobDetailDestFallback => 'จุดส่ง';

  @override
  String jobDetailDurationHrMin(Object hr, Object min) {
    return '$hr ชม. $min น.';
  }

  @override
  String jobDetailDurationMin(Object min) {
    return '$min นาที';
  }

  @override
  String get jobDetailCash => 'เงินสด';

  @override
  String get jobDetailOrderFood => 'สั่งอาหาร';

  @override
  String get jobDetailRide => 'เรียกรถ';

  @override
  String get jobDetailParcel => 'ส่งพัสดุ';

  @override
  String get jobDetailNetEarnings => 'ยอดรายได้สุทธิ';

  @override
  String get jobDetailEarningsBreakdown => 'รายละเอียดรายได้';

  @override
  String get jobDetailTripFare => 'ค่ารอบ';

  @override
  String get jobDetailCouponDiscountGeneric => 'ส่วนลดคูปอง';

  @override
  String jobDetailCouponDiscountCode(Object code) {
    return 'ส่วนลดคูปอง ($code)';
  }

  @override
  String get jobDetailPlatformFee => 'ค่าบริการระบบ';

  @override
  String get jobDetailFoodCost => '  ค่าอาหาร';

  @override
  String get jobDetailDeliveryFee => '  ค่าส่ง';

  @override
  String get jobDetailCashCollection => 'รายการชำระเงินสด';

  @override
  String get jobDetailCollectFromCustomer => 'ยอดที่ต้องเก็บจากลูกค้า';

  @override
  String get parcelConfirmPickupTitle => 'ยืนยันรับพัสดุ';

  @override
  String get parcelConfirmDeliveryTitle => 'ยืนยันส่งพัสดุ';

  @override
  String get parcelConfirmPhotoRequired => 'กรุณาถ่ายรูปยืนยัน';

  @override
  String get parcelConfirmSignatureRequired => 'กรุณาถ่ายรูปลายเซ็นผู้รับ';

  @override
  String get parcelConfirmUploadFailed => 'อัปโหลดรูปไม่สำเร็จ';

  @override
  String get parcelConfirmUpdateFailed => 'อัปเดตสถานะไม่สำเร็จ';

  @override
  String get parcelConfirmPickupSuccess => 'รับพัสดุสำเร็จ!';

  @override
  String get parcelConfirmPickupSuccessBody => 'บันทึกรูปภาพเรียบร้อย\nกรุณาเดินทางไปส่งพัสดุ';

  @override
  String get parcelConfirmDeliverySuccess => 'ส่งพัสดุสำเร็จ!';

  @override
  String get parcelConfirmDeliverySuccessBody => 'บันทึกรูปภาพและลายเซ็นเรียบร้อย\nงานเสร็จสมบูรณ์';

  @override
  String get parcelConfirmError => 'เกิดข้อผิดพลาด\nกรุณาลองใหม่อีกครั้ง';

  @override
  String get parcelConfirmErrorTitle => 'เกิดข้อผิดพลาด';

  @override
  String get parcelConfirmOk => 'ตกลง';

  @override
  String get parcelConfirmNoData => 'ไม่พบข้อมูลพัสดุ';

  @override
  String get parcelConfirmParcelInfo => 'ข้อมูลพัสดุ';

  @override
  String get parcelConfirmSender => 'ผู้ส่ง';

  @override
  String get parcelConfirmRecipient => 'ผู้รับ';

  @override
  String get parcelConfirmSize => 'ขนาด';

  @override
  String get parcelConfirmDescription => 'รายละเอียด';

  @override
  String get parcelConfirmWeightKg => 'น้ำหนัก';

  @override
  String parcelConfirmWeightValue(Object kg) {
    return '$kg กก.';
  }

  @override
  String get parcelConfirmStatus => 'สถานะ';

  @override
  String get parcelConfirmCustomerPhoto => 'รูปพัสดุจากลูกค้า';

  @override
  String get parcelConfirmPickupPhotoTitle => 'ถ่ายรูปยืนยันรับพัสดุ *';

  @override
  String get parcelConfirmDeliveryPhotoTitle => 'ถ่ายรูปยืนยันส่งพัสดุ *';

  @override
  String get parcelConfirmPickupPhotoDesc => 'ถ่ายรูปพัสดุที่รับมาเพื่อยืนยัน';

  @override
  String get parcelConfirmDeliveryPhotoDesc => 'ถ่ายรูปพัสดุที่ส่งถึงผู้รับ';

  @override
  String get parcelConfirmSignatureTitle => 'ถ่ายรูปลายเซ็นผู้รับ *';

  @override
  String get parcelConfirmSignatureDesc => 'ถ่ายรูปลายเซ็นหรือบัตรประชาชนผู้รับ';

  @override
  String get parcelConfirmTapToPhoto => 'แตะเพื่อถ่ายรูป';

  @override
  String get parcelConfirmPickupBtn => 'ยืนยันรับพัสดุ';

  @override
  String get parcelConfirmDeliveryBtn => 'ยืนยันส่งพัสดุสำเร็จ';

  @override
  String get merchantNavOrders => 'ออเดอร์';

  @override
  String get merchantNavMenu => 'เมนู';

  @override
  String get merchantNavReport => 'รายงาน';

  @override
  String get merchantNavAccount => 'บัญชี';

  @override
  String get merchantPressBackAgain => 'กดอีกครั้งเพื่อออกจากแอป';

  @override
  String get mchSetShopInfoTitle => 'ข้อมูลร้านค้า';

  @override
  String get mchSetShopName => 'ชื่อร้าน';

  @override
  String get mchSetPhone => 'เบอร์โทร';

  @override
  String get mchSetEmail => 'อีเมล';

  @override
  String get mchSetAddress => 'ที่อยู่ร้าน';

  @override
  String get mchSetShopStatus => 'สถานะร้าน';

  @override
  String get mchSetShopOpen => 'เปิดรับออเดอร์';

  @override
  String get mchSetShopClosed => 'ปิดร้าน';

  @override
  String get mchSetOpenCloseTime => 'เวลาเปิด-ปิดร้าน';

  @override
  String get mchSetOpenDays => 'วันเปิดร้าน';

  @override
  String get mchSetOrderAcceptMode => 'รูปแบบรับออเดอร์';

  @override
  String get mchSetAutoSchedule => 'เปิด-ปิดร้านอัตโนมัติ';

  @override
  String get mchSetAutoScheduleOn => 'เปิดใช้งาน';

  @override
  String get mchSetAutoScheduleOff => 'ปิดใช้งาน';

  @override
  String get mchSetNotSet => 'ยังไม่ได้ตั้งค่า';

  @override
  String get mchSetEveryDay => 'ทุกวัน';

  @override
  String get mchSetAcceptAuto => 'รับออเดอร์อัตโนมัติ';

  @override
  String get mchSetAcceptManual => 'รับออเดอร์ด้วยตนเอง';

  @override
  String mchSetEditField(Object label) {
    return 'แก้ไข$label';
  }

  @override
  String get mchSetHintShopName => 'ชื่อร้านค้า';

  @override
  String get mchSetHintPhone => 'เบอร์โทรศัพท์';

  @override
  String get mchSetCancel => 'ยกเลิก';

  @override
  String get mchSetSave => 'บันทึก';

  @override
  String get mchSetEditShopHoursTitle => 'ตั้งเวลาเปิด-ปิดร้าน';

  @override
  String get mchSetOpenTime => 'เวลาเปิดร้าน';

  @override
  String get mchSetCloseTime => 'เวลาปิดร้าน';

  @override
  String get mchSetOpenDaysLabel => 'วันที่เปิดร้าน';

  @override
  String get mchSetOrderAcceptModeLabel => 'รูปแบบการรับออเดอร์';

  @override
  String get mchSetAcceptManualShort => 'รับเอง';

  @override
  String get mchSetAcceptAutoShort => 'อัตโนมัติ';

  @override
  String get mchSetAutoScheduleSwitch => 'เปิด-ปิดร้านอัตโนมัติตามวันและเวลา';

  @override
  String get mchSetAutoScheduleOnDesc => 'ระบบจะสลับสถานะร้านให้อัตโนมัติ';

  @override
  String get mchSetAutoScheduleOffDesc => 'ปิดไว้ จะเปิด/ปิดร้านด้วยตนเองเท่านั้น';

  @override
  String get mchSetSelectAtLeast1Day => 'กรุณาเลือกวันเปิดร้านอย่างน้อย 1 วัน';

  @override
  String mchSetShopHoursSaved(Object open, Object close, Object days) {
    return 'ตั้งเวลาเปิด-ปิดร้าน: $open - $close ($days)';
  }

  @override
  String mchSetSaveFailed(Object error) {
    return 'บันทึกไม่สำเร็จ: $error';
  }

  @override
  String get mchSetWeekMon => 'จ';

  @override
  String get mchSetWeekTue => 'อ';

  @override
  String get mchSetWeekWed => 'พ';

  @override
  String get mchSetWeekThu => 'พฤ';

  @override
  String get mchSetWeekFri => 'ศ';

  @override
  String get mchSetWeekSat => 'ส';

  @override
  String get mchSetWeekSun => 'อา';

  @override
  String get mchDashTitle => 'รายงานการขาย';

  @override
  String get mchDashRefresh => 'รีเฟรช';

  @override
  String get mchDashLoadError => 'ไม่สามารถโหลดข้อมูลได้';

  @override
  String get mchDashRetry => 'ลองใหม่';

  @override
  String get mchDashPeriodToday => 'วันนี้';

  @override
  String get mchDashPeriodWeek => 'สัปดาห์นี้';

  @override
  String get mchDashPeriodMonth => 'เดือนนี้';

  @override
  String get mchDashPeriodAll => 'ทั้งหมด';

  @override
  String get mchDashPeriodCustom => 'ระบุวันที่';

  @override
  String get mchDashPickDateRange => 'เลือกช่วงวันที่';

  @override
  String get mchDashClearDateFilter => 'ล้างตัวกรองวันที่';

  @override
  String mchDashNetRevenue(Object period) {
    return 'รายได้สุทธิ$period';
  }

  @override
  String mchDashAvgPerOrder(Object amount) {
    return 'เฉลี่ย $amount / ออเดอร์';
  }

  @override
  String get mchDashTotalOrders => 'ออเดอร์ทั้งหมด';

  @override
  String get mchDashCompleted => 'สำเร็จ';

  @override
  String get mchDashCancelled => 'ยกเลิก';

  @override
  String get mchDashOrderHistory => 'ประวัติออเดอร์';

  @override
  String get mchDashNoOrders => 'ไม่มีออเดอร์ในช่วงเวลานี้';

  @override
  String get mchDashViewDetail => 'ดูรายละเอียด';

  @override
  String get mchDashStatusCompleted => 'สำเร็จ';

  @override
  String get mchDashStatusCancelled => 'ยกเลิก';

  @override
  String get mchDashStatusPreparing => 'กำลังเตรียม';

  @override
  String get mchDashStatusReady => 'พร้อมส่ง';

  @override
  String get mchDashStatusPickedUp => 'ไรเดอร์รับแล้ว';

  @override
  String get mchDashStatusDelivering => 'กำลังจัดส่ง';

  @override
  String get mchDashUserNotFound => 'ไม่พบข้อมูลผู้ใช้';

  @override
  String get menuMgmtTitle => 'จัดการเมนู';

  @override
  String get menuMgmtOptionTooltip => 'จัดการตัวเลือก';

  @override
  String get menuMgmtError => 'เกิดข้อผิดพลาด';

  @override
  String get menuMgmtRetry => 'ลองใหม่';

  @override
  String get menuMgmtEmpty => 'ยังไม่มีเมนู';

  @override
  String get menuMgmtEmptyHint => 'กดปุ่ม + เพื่อเพิ่มเมนูแรกของคุณ';

  @override
  String get menuMgmtNoName => 'ไม่มีชื่อ';

  @override
  String get menuMgmtAvailable => 'วางขาย';

  @override
  String get menuMgmtSoldOut => 'หมด';

  @override
  String get menuMgmtEdit => 'แก้ไข';

  @override
  String get menuMgmtDelete => 'ลบ';

  @override
  String get menuMgmtDeleteConfirmTitle => 'ยืนยันการลบ';

  @override
  String menuMgmtDeleteConfirmBody(Object name) {
    return 'คุณต้องการลบเมนู \"$name\" ใช่หรือไม่?';
  }

  @override
  String get menuMgmtNo => 'ไม่';

  @override
  String get menuMgmtYes => 'ใช่';

  @override
  String get menuMgmtDeleteSuccess => 'ลบเมนูสำเร็จ';

  @override
  String get menuMgmtCannotDeleteTitle => 'ไม่สามารถลบเมนูได้';

  @override
  String get menuMgmtCannotDeleteBody => 'เมนูนี้มีออเดอร์ที่เกี่ยวข้องอยู่จึงไม่สามารถลบได้\n\nต้องการซ่อนเมนูนี้แทนหรือไม่? (เปลี่ยนสถานะเป็น \"หมด\")';

  @override
  String get menuMgmtCancel => 'ยกเลิก';

  @override
  String get menuMgmtHideMenu => 'ซ่อนเมนู';

  @override
  String get menuMgmtHideSuccess => 'ซ่อนเมนูสำเร็จ (เปลี่ยนเป็น \"หมด\")';

  @override
  String menuMgmtDeleteFailed(Object error) {
    return 'ไม่สามารถลบเมนู: $error';
  }

  @override
  String get menuMgmtToggleOn => 'เปิดการขายเมนูแล้ว';

  @override
  String get menuMgmtToggleOff => 'ปิดการขายเมนูแล้ว';

  @override
  String menuMgmtToggleFailed(Object error) {
    return 'เปลี่ยนสถานะไม่สำเร็จ: $error';
  }

  @override
  String get menuMgmtUserNotFound => 'ไม่พบข้อมูลผู้ใช้';

  @override
  String get menuEditTitleEdit => 'แก้ไขเมนู';

  @override
  String get menuEditTitleAdd => 'เพิ่มเมนูใหม่';

  @override
  String get menuEditBtnUpdate => 'อัปเดตเมนู';

  @override
  String get menuEditBtnAdd => 'เพิ่มเมนู';

  @override
  String get menuEditInfoTitle => 'ข้อมูลเมนู';

  @override
  String get menuEditNameLabel => 'ชื่อเมนู *';

  @override
  String get menuEditNameRequired => 'กรุณาระบุชื่อเมนู';

  @override
  String get menuEditDescLabel => 'รายละเอียด';

  @override
  String get menuEditPriceLabel => 'ราคา *';

  @override
  String get menuEditPriceRequired => 'กรุณาระบุราคา';

  @override
  String get menuEditPriceInvalid => 'กรุณาระบุราคาที่ถูกต้อง';

  @override
  String get menuEditPhotoLabel => 'รูปภาพเมนู';

  @override
  String get menuEditTapToPhoto => 'แตะเพื่อถ่ายรูปหรือเลือกรูป';

  @override
  String get menuEditCategoryLabel => 'หมวดหมู่ *';

  @override
  String get menuEditCategoryRequired => 'กรุณาเลือกหมวดหมู่';

  @override
  String get menuEditAvailable => 'พร้อมวางขาย';

  @override
  String get menuEditOptionGroupsTitle => 'กลุ่มตัวเลือก';

  @override
  String menuEditGroupCount(Object count) {
    return '$count กลุ่ม';
  }

  @override
  String get menuEditNoOptionGroups => 'ยังไม่ได้เลือกกลุ่มตัวเลือก';

  @override
  String get menuEditNoOptionGroupsHint => 'เพิ่มกลุ่มตัวเลือกเพื่อให้ลูกค้าเลือกจากเมนูนี้';

  @override
  String get menuEditAddSuccess => 'เพิ่มเมนูสำเร็จ';

  @override
  String get menuEditUpdateSuccess => 'แก้ไขเมนูสำเร็จ';

  @override
  String menuEditLoadOptionsFailed(Object error) {
    return 'โหลดตัวเลือกไม่สำเร็จ: $error';
  }

  @override
  String menuEditDeleteGroupSuccess(Object name) {
    return 'ลบกลุ่ม \"$name\" เรียบร้อย';
  }

  @override
  String menuEditDeleteGroupFailed(Object error) {
    return 'ลบกลุ่มไม่สำเร็จ: $error';
  }

  @override
  String get menuEditCatMadeToOrder => 'อาหารตามสั่ง';

  @override
  String get menuEditCatNoodles => 'ก๋วยเตี๋ยว';

  @override
  String get menuEditCatDrinks => 'เครื่องดื่ม';

  @override
  String get menuEditCatDessert => 'ของหวาน';

  @override
  String get menuEditCatFastFood => 'ฟาสต์ฟู้ด';

  @override
  String get menuEditCatBreakfast => 'อาหารเช้า';

  @override
  String get menuEditCatJapanese => 'อาหารญี่ปุ่น';

  @override
  String get menuEditCatIsaan => 'อาหารอีสาน';

  @override
  String get menuEditCatSnacks => 'ของทานเล่น';

  @override
  String get menuEditCatOther => 'อื่นๆ';

  @override
  String get optGroupEditTitle => 'แก้ไขกลุ่มตัวเลือก';

  @override
  String get optGroupCreateTitle => 'สร้างกลุ่มตัวเลือก';

  @override
  String get optGroupBtnUpdate => 'อัปเดตกลุ่มตัวเลือก';

  @override
  String get optGroupBtnCreate => 'สร้างกลุ่มตัวเลือก';

  @override
  String get optGroupInfoTitle => 'ข้อมูลกลุ่มตัวเลือก';

  @override
  String get optGroupNameLabel => 'ชื่อกลุ่มตัวเลือก';

  @override
  String get optGroupNameHint => 'เช่น ระดับความเผ็ด, ท็อปปิ้ง';

  @override
  String get optGroupNameRequired => 'กรุณากรอกชื่อกลุ่มตัวเลือก';

  @override
  String get optGroupMinLabel => 'เลือกขั้นต่ำ';

  @override
  String get optGroupMinRequired => 'กรุณากรอกจำนวนขั้นต่ำ';

  @override
  String get optGroupMinInvalid => 'กรุณากรอกจำนวนที่ถูกต้อง';

  @override
  String get optGroupMaxLabel => 'เลือกสูงสุด';

  @override
  String get optGroupMaxRequired => 'กรุณากรอกจำนวนสูงสุด';

  @override
  String get optGroupMaxInvalid => 'กรุณากรอกจำนวนที่ถูกต้อง (อย่างน้อย 1)';

  @override
  String get optGroupSelectionHint => 'คำแนะนำ: 0=ไม่จำเป็นต้องเลือก, 1=ต้องเลือก 1 รายการ';

  @override
  String get optGroupAddOptionTitle => 'เพิ่มตัวเลือก';

  @override
  String get optGroupOptionNameLabel => 'ชื่อตัวเลือก';

  @override
  String get optGroupOptionNameHint => 'เช่น ไม่เผ็ด, เผ็ดมาก';

  @override
  String get optGroupOptionPriceLabel => 'ราคาเพิ่ม';

  @override
  String get optGroupNoOptions => 'ยังไม่มีตัวเลือก';

  @override
  String get optGroupNoOptionsHint => 'เพิ่มตัวเลือกเพื่อให้ลูกค้าเลือกจากกลุ่มนี้';

  @override
  String get optGroupAllOptionsTitle => 'ตัวเลือกทั้งหมด';

  @override
  String optGroupItemCount(Object count) {
    return '$count รายการ';
  }

  @override
  String get optGroupOptionNameRequired => 'กรุณากรอกชื่อตัวเลือก';

  @override
  String get optGroupOptionPriceNegative => 'ราคาต้องไม่ติดลบ';

  @override
  String get optGroupCreateSuccess => 'สร้างกลุ่มตัวเลือกเรียบร้อย';

  @override
  String get optGroupUpdateSuccess => 'อัปเดตกลุ่มตัวเลือกเรียบร้อย';

  @override
  String get optGroupMinMaxError => 'ค่าต่ำสุดต้องไม่ต่ำกว่า 0 และค่าสูงสุดต้องไม่ต่ำกว่า 1';

  @override
  String get optGroupMinGtMaxError => 'ค่าต่ำสุดต้องไม่มากกว่าค่าสูงสุด';

  @override
  String get optGroupSaveError => 'ไม่สามารถบันทึกกลุ่มตัวเลือกได้';

  @override
  String get optLibTitle => 'จัดการตัวเลือกอาหาร';

  @override
  String get optLibRetry => 'ลองใหม่';

  @override
  String get optLibEmpty => 'ยังไม่มีกลุ่มตัวเลือก';

  @override
  String get optLibEmptyHint => 'สร้างกลุ่มตัวเลือกเพื่อนำไปใช้กับเมนูอาหารของคุณ';

  @override
  String get optLibCreateNew => 'สร้างกลุ่มใหม่';

  @override
  String get optLibDeleteConfirmTitle => 'ยืนยันการลบ';

  @override
  String optLibDeleteConfirmBody(Object name) {
    return 'คุณต้องการลบกลุ่ม \"$name\" ใช่หรือไม่?';
  }

  @override
  String optLibDeleteNote(Object count) {
    return 'หมายเหตุ: การลบกลุ่มนี้จะลบตัวเลือกทั้งหมด $count รายการ';
  }

  @override
  String get optLibCancel => 'ยกเลิก';

  @override
  String get optLibDeleteBtn => 'ลบ';

  @override
  String optLibDeleteSuccess(Object name) {
    return 'ลบกลุ่ม \"$name\" เรียบร้อย';
  }

  @override
  String optLibDeleteFailed(Object error) {
    return 'ลบกลุ่มไม่สำเร็จ: $error';
  }

  @override
  String get optLibSelectMax1 => 'เลือกได้ 1 รายการ';

  @override
  String optLibSelectMaxN(Object max) {
    return 'เลือกได้สูงสุด $max รายการ';
  }

  @override
  String optLibSelectExact(Object n) {
    return 'เลือก $n รายการ';
  }

  @override
  String optLibSelectRange(Object min, Object max) {
    return 'เลือก $min-$max รายการ';
  }

  @override
  String optLibOptionCount(Object count) {
    return 'ตัวเลือก $count รายการ';
  }

  @override
  String get optLibShowFirst3 => 'แสดง 3 รายการแรก';

  @override
  String get menuEditAddOptionGroup => 'เพิ่มกลุ่มตัวเลือก';

  @override
  String get menuEditSelectOptionGroups => 'เลือกกลุ่มตัวเลือก';

  @override
  String get menuEditSaveSelection => 'บันทึกการเลือก';

  @override
  String get menuEditSheetRetry => 'ลองใหม่';

  @override
  String get menuEditSheetNoGroups => 'ไม่มีกลุ่มตัวเลือก';

  @override
  String get menuEditSheetNoGroupsHint => 'สร้างกลุ่มตัวเลือกก่อนเพื่อนำมาใช้กับเมนู';

  @override
  String get menuEditRemoveGroupTooltip => 'ลบกลุ่มนี้';

  @override
  String menuEditOptionCount(Object count) {
    return '$count ตัวเลือก';
  }

  @override
  String get couponAdminDialogTitle => 'สร้างคูปองร้าน (แอดมิน)';

  @override
  String get couponCreateSuccess => 'สร้างคูปองร้านค้าสำเร็จ';

  @override
  String get couponCreateFailed => 'สร้างคูปองไม่สำเร็จ';

  @override
  String couponAdminTitle(Object name) {
    return 'คูปองร้าน: $name';
  }

  @override
  String get couponAdminTitleNoName => 'คูปองร้าน: ไม่ระบุชื่อ';

  @override
  String get couponTitle => 'คูปองร้านค้า';

  @override
  String get couponListTitle => 'คูปองของร้าน';

  @override
  String get couponEmpty => 'ยังไม่มีคูปองร้านค้า';

  @override
  String get couponGuideTitle => 'วิธีใช้งานคูปองร้าน';

  @override
  String get couponGuideStep1Admin => '1) แอดมินกำลังจัดการคูปองของร้านที่เลือก ลูกค้าจะเห็นบนหน้าร้านโดยอัตโนมัติ';

  @override
  String get couponGuideStep1Merchant => '1) สร้างคูปองเฉพาะร้านของคุณ แล้วลูกค้าจะเห็นบนหน้าร้านโดยอัตโนมัติ';

  @override
  String get couponGuideStep2Admin => '2) กดปุ่ม \"เปิดฟอร์มคูปอง\" เพื่อแก้ไขผ่าน Dialog แทนฟอร์มหน้าเดิม';

  @override
  String get couponGuideStep2Merchant => '2) กรอกข้อมูลในฟอร์มด้านล่างเพื่อสร้างคูปองใหม่ได้ทันที';

  @override
  String get couponGuideStep3 => '3) คูปองส่งฟรีของร้าน จะคิด GP เพิ่มรวม 25%';

  @override
  String get couponGuideStep4Admin => '4) แอดมินสามารถเปิด/ปิดคูปองแต่ละรายการได้จากสวิตช์ด้านขวา';

  @override
  String get couponGuideStep4Merchant => '4) สามารถเปิด/ปิดคูปองแต่ละรายการได้จากสวิตช์ด้านขวา';

  @override
  String get couponAdminOpenForm => 'เปิดฟอร์มคูปอง (Dialog)';

  @override
  String get couponCodeLabel => 'โค้ดคูปอง';

  @override
  String get couponCodeRequired => 'กรอกโค้ดคูปอง';

  @override
  String get couponNameLabel => 'ชื่อคูปอง';

  @override
  String get couponNameRequired => 'กรอกชื่อคูปอง';

  @override
  String get couponDescLabel => 'คำอธิบาย (ไม่บังคับ)';

  @override
  String get couponTypePercentage => 'ลดเปอร์เซ็นต์';

  @override
  String get couponTypeFixed => 'ลดเป็นจำนวนเงิน';

  @override
  String get couponTypeFreeDelivery => 'ส่งฟรี';

  @override
  String get couponTypeLabel => 'ประเภทคูปอง';

  @override
  String get couponDiscountPercent => 'ส่วนลด (%)';

  @override
  String get couponDiscountBaht => 'ส่วนลด (บาท)';

  @override
  String get couponDiscountRequired => 'กรอกส่วนลดให้ถูกต้อง';

  @override
  String get couponMaxDiscount => 'ลดสูงสุด (บาท) ไม่บังคับ';

  @override
  String get couponMinOrder => 'ยอดขั้นต่ำ (บาท) ไม่บังคับ';

  @override
  String get couponUsageLimit => 'สิทธิ์รวม (0=ไม่จำกัด)';

  @override
  String get couponPerUserLimit => 'จำกัด/คน';

  @override
  String couponStartDate(Object date) {
    return 'เริ่ม: $date';
  }

  @override
  String get couponPickStartDate => 'เลือกวันเริ่มใช้งาน';

  @override
  String get couponPick => 'เลือก';

  @override
  String couponEndDate(Object date) {
    return 'หมดอายุ: $date';
  }

  @override
  String get couponPickEndDate => 'เลือกวันหมดอายุ';

  @override
  String get couponCreateBtn => 'สร้างคูปอง';

  @override
  String get editProfileTitle => 'แก้ไขข้อมูลร้าน';

  @override
  String get editProfileTapPhoto => 'แตะเพื่อเปลี่ยนรูปร้าน';

  @override
  String get editProfileShopName => 'ชื่อร้าน';

  @override
  String get editProfileShopNameRequired => 'กรุณากรอกชื่อร้าน';

  @override
  String get editProfileEmail => 'อีเมล';

  @override
  String get editProfilePhone => 'เบอร์โทรศัพท์';

  @override
  String get editProfilePhoneInvalid => 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';

  @override
  String get editProfileAddress => 'ที่อยู่ร้าน';

  @override
  String get editProfilePinLocation => 'ปักหมุดตำแหน่งร้าน';

  @override
  String get editProfileNoLocation => 'ยังไม่ได้เลือกตำแหน่งบนแผนที่';

  @override
  String get editProfileOpenDays => 'วันที่เปิดร้าน';

  @override
  String get editProfileOpenTime => 'เวลาเปิด';

  @override
  String get editProfileCloseTime => 'เวลาปิด';

  @override
  String get editProfileSelectDayRequired => 'กรุณาเลือกวันเปิดร้านอย่างน้อย 1 วัน';

  @override
  String get editProfileSaveBtn => 'บันทึกข้อมูล';

  @override
  String get editProfileSaveSuccess => 'บันทึกข้อมูลสำเร็จ';

  @override
  String editProfileSaveFailed(Object error) {
    return 'ไม่สามารถบันทึกข้อมูลได้: $error';
  }

  @override
  String get editProfileDayMon => 'จ';

  @override
  String get editProfileDayTue => 'อ';

  @override
  String get editProfileDayWed => 'พ';

  @override
  String get editProfileDayThu => 'พฤ';

  @override
  String get editProfileDayFri => 'ศ';

  @override
  String get editProfileDaySat => 'ส';

  @override
  String get editProfileDaySun => 'อา';

  @override
  String get profileCompleteRoleDriver => 'คนขับ';

  @override
  String get profileCompleteRoleMerchant => 'ร้านค้า';

  @override
  String profileCompleteTitle(Object role) {
    return 'กรอกข้อมูล$role';
  }

  @override
  String get profileCompleteLogout => 'ออกจากระบบ';

  @override
  String get profileCompleteBack => 'ย้อนกลับ';

  @override
  String get profileCompleteNext => 'ถัดไป';

  @override
  String get profileCompleteSaveStart => 'บันทึกและเริ่มใช้งาน';

  @override
  String get profileCompleteSaveSuccess => '✅ บันทึกข้อมูลโปรไฟล์สำเร็จ';

  @override
  String profileCompleteError(Object error) {
    return '❌ เกิดข้อผิดพลาด: $error';
  }

  @override
  String profileCompleteUploadMissing(Object items) {
    return 'กรุณาอัปโหลด: $items';
  }

  @override
  String get profileCompleteStepPersonalTitle => 'ข้อมูลส่วนตัว';

  @override
  String get profileCompleteStepPersonalSubtitle => 'กรุณากรอกข้อมูลของคุณ';

  @override
  String get profileCompleteFullNameLabel => 'ชื่อ-นามสกุล';

  @override
  String get profileCompleteFullNameRequired => 'กรุณากรอกชื่อ';

  @override
  String get profileCompletePhoneLabel => 'เบอร์โทรศัพท์';

  @override
  String get profileCompletePhoneRequired => 'กรุณากรอกเบอร์โทร';

  @override
  String get profileCompleteStepVehicleTitle => 'ข้อมูลรถ';

  @override
  String get profileCompleteStepVehicleSubtitle => 'กรุณาเลือกประเภทรถและกรอกทะเบียน';

  @override
  String get profileCompleteVehicleTypeLabel => 'ประเภทรถ';

  @override
  String get profileCompleteVehicleMotorcycle => 'มอเตอร์ไซค์';

  @override
  String get profileCompleteVehicleCar => 'รถยนต์';

  @override
  String get profileCompletePlateLabel => 'เลขทะเบียนรถ';

  @override
  String get profileCompletePlateRequired => 'กรุณากรอกทะเบียน';

  @override
  String get profileCompleteStepDocsTitle => 'อัปโหลดเอกสาร';

  @override
  String get profileCompleteStepDocsSubtitle => 'กรุณาถ่ายรูปเอกสารของคุณ';

  @override
  String get profileCompleteDocIdCard => 'รูปบัตรประชาชน';

  @override
  String get profileCompleteDocDriverLicense => 'ใบขับขี่';

  @override
  String get profileCompleteDocVehiclePhoto => 'รูปรถ';

  @override
  String get profileCompleteDocPlatePhoto => 'รูปป้ายทะเบียน';

  @override
  String get profileCompleteDocsHint => '* กรุณาอัปโหลดเอกสารทั้ง 4 รายการ';

  @override
  String get profileCompleteDocSelected => 'เลือกรูปแล้ว ✓';

  @override
  String get profileCompleteDocTapToPick => 'แตะเพื่อถ่ายรูปหรือเลือกจากแกลเลอรี';

  @override
  String get profileCompleteStepMerchantTitle => 'ข้อมูลร้านค้า';

  @override
  String get profileCompleteStepMerchantSubtitle => 'กรุณากรอกข้อมูลร้านค้าของคุณ';

  @override
  String get profileCompleteMerchantNameLabel => 'ชื่อร้านค้า / เจ้าของ';

  @override
  String get profileCompleteAddressLabel => 'ที่อยู่ร้าน';

  @override
  String get profileCompleteAddressRequired => 'กรุณากรอกที่อยู่';

  @override
  String get profileCompleteStepBankTitle => 'ข้อมูลธนาคาร';

  @override
  String get profileCompleteStepBankSubtitle => 'สำหรับรับเงินจากระบบ (ไม่บังคับ)';

  @override
  String get profileCompleteBankNameLabel => 'ชื่อธนาคาร';

  @override
  String get profileCompleteBankNameHint => 'เช่น กสิกรไทย, ไทยพาณิชย์';

  @override
  String get profileCompleteBankAccountNumberLabel => 'เลขบัญชี';

  @override
  String get profileCompleteBankAccountNameLabel => 'ชื่อบัญชี';

  @override
  String get imagePickerChooseImage => 'เลือกรูปภาพ';

  @override
  String get imagePickerTakePhoto => 'ถ่ายรูป';

  @override
  String get imagePickerTakePhotoSubtitle => 'ใช้กล้องถ่ายรูปใหม่';

  @override
  String get imagePickerPickGallery => 'เลือกจากแกลเลอรี';

  @override
  String get imagePickerPickGallerySubtitle => 'เลือกรูปจากอัลบั้ม';

  @override
  String get landingLogin => 'เข้าสู่ระบบ';

  @override
  String get landingStart => 'เริ่มใช้งาน';

  @override
  String get landingHeadline => 'บริการเรียกรถ\nส่งอาหาร & พัสดุ';

  @override
  String get landingSubheadline => 'แพลตฟอร์ม Super App สำหรับชุมชน\nเรียกรถ สั่งอาหาร ส่งพัสดุ ครบจบในแอปเดียว';

  @override
  String get landingServicesTitle => 'บริการของเรา';

  @override
  String get landingServicesSubtitle => 'ครบทุกบริการในแอปเดียว';

  @override
  String get landingServiceRideTitle => 'เรียกรถ';

  @override
  String get landingServiceRideDesc => 'เรียกรถมอเตอร์ไซค์หรือรถยนต์\nไปไหนก็ได้ สะดวก ปลอดภัย';

  @override
  String get landingServiceFoodTitle => 'สั่งอาหาร';

  @override
  String get landingServiceFoodDesc => 'สั่งอาหารจากร้านใกล้คุณ\nส่งถึงบ้านรวดเร็ว';

  @override
  String get landingServiceParcelTitle => 'ส่งพัสดุ';

  @override
  String get landingServiceParcelDesc => 'ส่งพัสดุถึงปลายทาง\nราคาประหยัด ติดตามได้';

  @override
  String get landingSignupNow => 'สมัครเลย';

  @override
  String get landingHowTitle => 'ใช้งานง่าย 4 ขั้นตอน';

  @override
  String get landingHowStep1Number => '1';

  @override
  String get landingHowStep1Title => 'สมัครสมาชิก';

  @override
  String get landingHowStep1Desc => 'ลงทะเบียนด้วยเบอร์โทร';

  @override
  String get landingHowStep2Number => '2';

  @override
  String get landingHowStep2Title => 'เลือกบริการ';

  @override
  String get landingHowStep2Desc => 'เรียกรถ สั่งอาหาร หรือส่งพัสดุ';

  @override
  String get landingHowStep3Number => '3';

  @override
  String get landingHowStep3Title => 'ยืนยันออเดอร์';

  @override
  String get landingHowStep3Desc => 'เลือกจุดหมายและวิธีชำระเงิน';

  @override
  String get landingHowStep4Number => '4';

  @override
  String get landingHowStep4Title => 'รับบริการ';

  @override
  String get landingHowStep4Desc => 'คนขับรับงานและมาหาคุณ';

  @override
  String get landingDriverCtaTitle => 'สมัครเป็นคนขับ Jedechai';

  @override
  String get landingDriverCtaSubtitle => 'สร้างรายได้เสริม ทำงานอิสระ เลือกเวลาเอง';

  @override
  String get topupAdminPushTitle => '💰 คำขอเติมเงินใหม่';

  @override
  String topupAdminPushBody(Object driverName, Object amount) {
    return '$driverName แจ้งเติมเงิน ฿$amount — รอการอนุมัติ';
  }

  @override
  String topupAdminEmailSubject(Object driverName, Object amount) {
    return '💰 คำขอเติมเงินใหม่ — $driverName ฿$amount';
  }

  @override
  String topupAdminEmailHtml(Object driverName, Object amount) {
    return '<div style=\"font-family:sans-serif;max-width:500px;margin:0 auto;padding:20px;\">\n  <h2 style=\"color:#1565C0;\">💰 คำขอเติมเงินใหม่</h2>\n  <div style=\"background:#f5f5f5;padding:16px;border-radius:12px;margin:16px 0;\">\n    <p><strong>คนขับ:</strong> $driverName</p>\n    <p><strong>จำนวนเงิน:</strong> <span style=\"color:#4CAF50;font-size:24px;font-weight:bold;\">฿$amount</span></p>\n    <p><strong>สถานะ:</strong> <span style=\"color:#FF9800;\">รอการอนุมัติ</span></p>\n  </div>\n  <p style=\"color:#666;\">กรุณาเข้าสู่ระบบ Admin เพื่อตรวจสอบและอนุมัติคำขอเติมเงิน</p>\n  <hr style=\"border:none;border-top:1px solid #eee;margin:20px 0;\">\n  <p style=\"color:#999;font-size:12px;\">JDC Delivery Admin System</p>\n</div>\n';
  }

  @override
  String topupOmiseTransactionDescription(Object amount, Object chargeId) {
    return 'เติมเงินผ่าน Omise PromptPay (฿$amount) — Charge: $chargeId';
  }

  @override
  String topupPromptPayTransactionDescription(Object amount) {
    return 'เติมเงินผ่าน PromptPay (฿$amount)';
  }

  @override
  String topupWithdrawalTransactionDescription(Object amount, Object bankName, Object accountNumber) {
    return 'แจ้งถอนเงิน ฿$amount ไปยัง $bankName $accountNumber';
  }
}
