// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'JDC Delivery';

  @override
  String get language => 'Language';

  @override
  String get useSystemLanguage => 'Use system language';

  @override
  String get thai => 'Thai';

  @override
  String get english => 'English';

  @override
  String get commonOk => 'OK';

  @override
  String get loginWelcomeTitle => 'Welcome';

  @override
  String get loginWelcomeSubtitle => 'Sign in to continue';

  @override
  String get loginEmailLabel => 'Email';

  @override
  String get loginPasswordLabel => 'Password';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginNoAccountPrefix => 'No account? ';

  @override
  String get loginRegisterButton => 'Sign up';

  @override
  String get loginSuccessSnack => 'Signed in successfully';

  @override
  String get loginBackPressToExit => 'Press again to exit';

  @override
  String get loginErrorDialogTitle => 'Sign in failed';

  @override
  String get loginValidationEmailRequired => 'Please enter your email';

  @override
  String get loginValidationEmailInvalid => 'Invalid email';

  @override
  String get loginValidationPasswordRequired => 'Please enter your password';

  @override
  String get loginValidationPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get loginErrorInvalidCredentials => 'Incorrect email or password\nPlease try again';

  @override
  String get loginErrorEmailNotConfirmed => 'Email not confirmed\nPlease check your inbox';

  @override
  String get loginErrorUserNotFound => 'User not found\nPlease sign up first';

  @override
  String get loginErrorTooManyRequests => 'Too many attempts\nPlease wait and try again';

  @override
  String get loginErrorCannotConnect => 'Cannot connect to server\nPlease check your internet';

  @override
  String get loginErrorNetwork => 'Network error\nPlease try again';

  @override
  String get loginErrorGeneric => 'An error occurred. Please try again';

  @override
  String get registerTitle => 'Sign up';

  @override
  String get registerHeader => 'Create a new account';

  @override
  String get registerSubheader => 'Please fill in your information';

  @override
  String get registerSelectRole => 'Select account type';

  @override
  String get registerFullNameLabel => 'Full name';

  @override
  String get registerShopNameLabel => 'Shop name';

  @override
  String get registerPhoneLabel => 'Phone number';

  @override
  String get registerEmailLabel => 'Email';

  @override
  String get registerReferralCodeLabel => 'Referral code (optional)';

  @override
  String get registerPasswordLabel => 'Password';

  @override
  String get registerConfirmPasswordLabel => 'Confirm password';

  @override
  String get registerButton => 'Sign up';

  @override
  String get registerHaveAccountPrefix => 'Already have an account? ';

  @override
  String get registerGoToLogin => 'Sign in';

  @override
  String get registerValidationFullNameRequired => 'Please enter your name';

  @override
  String get registerValidationShopNameRequired => 'Please enter shop name';

  @override
  String get registerValidationPhoneRequired => 'Please enter phone number';

  @override
  String get registerValidationPhoneInvalid => 'Invalid phone number';

  @override
  String get registerValidationEmailRequired => 'Please enter email';

  @override
  String get registerValidationEmailInvalid => 'Invalid email';

  @override
  String get registerValidationPasswordRequired => 'Please enter password';

  @override
  String get registerValidationPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get registerValidationConfirmPasswordRequired => 'Please confirm your password';

  @override
  String get registerValidationPasswordMismatch => 'Passwords do not match';

  @override
  String get registerErrorDialogTitle => 'Sign up failed';

  @override
  String get registerErrorPasswordMismatch => 'Passwords do not match\nPlease check and try again';

  @override
  String get registerErrorPhoneUsed => 'This phone number is already in use\nPlease use another phone or sign in';

  @override
  String get registerErrorEmailUsed => 'This email is already in use\nPlease sign in or use another email';

  @override
  String get registerErrorEmailAlreadyRegistered => 'This email is already in use\nPlease sign in or use another email';

  @override
  String get registerErrorWeakPassword => 'Weak password\nPlease use at least 6 characters';

  @override
  String get registerErrorInvalidEmail => 'Invalid email format\nPlease check your email';

  @override
  String get registerErrorCannotConnect => 'Cannot connect to server\nPlease check your internet';

  @override
  String get registerErrorTooManyRequests => 'Too many attempts\nPlease wait and try again';

  @override
  String get registerErrorGeneric => 'An error occurred. Please try again';

  @override
  String get registerSuccessTitle => 'Signed up successfully!';

  @override
  String get registerSuccessBody => 'Registration completed\nPlease sign in to start using the app';

  @override
  String get registerSuccessGoToLogin => 'Sign in';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordHeader => 'Forgot password?';

  @override
  String get forgotPasswordSubheader => 'Enter your email to receive a reset link';

  @override
  String get forgotPasswordEmailLabel => 'Email';

  @override
  String get forgotPasswordEmailRequired => 'Please enter email';

  @override
  String get forgotPasswordEmailInvalid => 'Please enter a valid email';

  @override
  String get forgotPasswordSubmit => 'Send reset email';

  @override
  String get forgotPasswordBackToLogin => 'Back to sign in';

  @override
  String get forgotPasswordErrorDialogTitle => 'Failed to send email';

  @override
  String get forgotPasswordSuccessTitle => 'Email sent!';

  @override
  String forgotPasswordSuccessBody(Object email) {
    return 'A password reset link has been sent to\n$email\n\nPlease check your inbox';
  }

  @override
  String forgotPasswordSuccessBodyMock(Object email) {
    return 'Mock Mode\nA reset email was simulated to\n$email\n\n*No real email was sent*';
  }

  @override
  String get forgotPasswordSuccessGoToLogin => 'Back to sign in';

  @override
  String get forgotPasswordErrorUserNotFound => 'No account found for this email\nPlease check your email';

  @override
  String get forgotPasswordErrorTooManyRequests => 'Too many requests\nPlease wait and try again';

  @override
  String get forgotPasswordErrorCannotConnect => 'Cannot connect to server\nPlease check your internet';

  @override
  String get forgotPasswordErrorGeneric => 'An error occurred. Please try again';

  @override
  String get foodCategoryAll => 'All';

  @override
  String get foodCategoryMadeToOrder => 'Made to order';

  @override
  String get foodCategoryNoodles => 'Noodles';

  @override
  String get foodCategoryDrinks => 'Drinks';

  @override
  String get foodCategoryDesserts => 'Desserts';

  @override
  String get foodCategoryFastFood => 'Fast food';

  @override
  String get foodHomeTitle => 'Order Food';

  @override
  String get foodHomeSearchHint => 'Search restaurants...';

  @override
  String get foodHomeTopSelling => 'Best Sellers';

  @override
  String foodHomeTopCount(Object count) {
    return 'Top $count';
  }

  @override
  String foodHomeSoldCount(Object count) {
    return '$count sold';
  }

  @override
  String get foodHomeNearbyTitle => 'Restaurants near you';

  @override
  String foodHomeRestaurantCount(Object count) {
    return '$count restaurants';
  }

  @override
  String get foodHomeLoading => 'Loading restaurants...';

  @override
  String get foodHomeErrorTitle => 'Unable to load data';

  @override
  String get foodHomeErrorSubtitle => 'Please check your internet connection';

  @override
  String get foodHomeRetry => 'Try again';

  @override
  String get foodHomeEmptySearch => 'No restaurants found';

  @override
  String get foodHomeEmptyNoArea => 'No restaurants in your area yet';

  @override
  String get foodHomeEmptyNoneOpen => 'No restaurants currently open';

  @override
  String get foodHomeEmptySearchHint => 'Try another search term';

  @override
  String foodHomeEmptyNoAreaHint(Object radius) {
    return 'No open restaurants within $radius km';
  }

  @override
  String get foodHomeEmptyTryLater => 'Please try again later';

  @override
  String get foodHomeRestaurantDefault => 'Restaurant';

  @override
  String get foodHomeOpenBadge => 'Open';

  @override
  String foodHomeDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String get foodHomeEstTime => '20-30 min';

  @override
  String get foodPromoCodeTitle => 'Promo Code';

  @override
  String get foodPromoCodeHint => 'Use this code at checkout for a discount';

  @override
  String foodPromoCodeCopied(Object code) {
    return 'Copied code \"$code\"';
  }

  @override
  String get foodPromoCodeClose => 'Close';

  @override
  String get foodPromoCodeCopy => 'Copy code';

  @override
  String get foodCartViewCart => 'View cart';

  @override
  String get foodCartTitle => 'Your cart';

  @override
  String get foodCartClear => 'Clear';

  @override
  String get foodCartEmpty => 'Cart is empty';

  @override
  String get foodCartFoodCost => 'Food cost';

  @override
  String get foodCartDeliveryFee => 'Delivery fee';

  @override
  String get foodCartDeliveryCalcLater => 'Calculated at order';

  @override
  String get foodCartTotal => 'Total';

  @override
  String get foodCartOrderButton => 'Order food';

  @override
  String get foodCheckoutTitle => 'Confirm order';

  @override
  String get foodCheckoutRestaurant => 'Restaurant';

  @override
  String get foodCheckoutDeliveryAddress => 'Delivery address';

  @override
  String get foodCheckoutCurrentLocation => 'Current location';

  @override
  String foodCheckoutItemsTitle(Object count) {
    return 'Food items ($count items)';
  }

  @override
  String get foodCheckoutNoteTitle => 'Note to restaurant';

  @override
  String get foodCheckoutNoteHint => 'e.g. no vegetables, less spicy...';

  @override
  String get foodCheckoutPaymentTitle => 'Payment method';

  @override
  String get foodCheckoutPayCash => 'Cash';

  @override
  String get foodCheckoutPayTransfer => 'Bank transfer';

  @override
  String get foodCheckoutDeliveryEstimate => 'Delivery fee (estimated)';

  @override
  String get foodCheckoutConfirmButton => 'Confirm order';

  @override
  String get foodCheckoutSuccess => 'Order placed successfully!';

  @override
  String get foodCheckoutLoginRequired => 'Please sign in';

  @override
  String get foodCheckoutCreateFailed => 'Unable to create order';

  @override
  String foodCheckoutOrderFailed(Object error) {
    return 'Unable to place order: $error';
  }

  @override
  String get foodCheckoutNotifTitle => 'New order!';

  @override
  String foodCheckoutNotifBody(Object amount) {
    return 'Customer ordered food ฿$amount — please confirm';
  }

  @override
  String get foodScheduleTitle => 'Delivery time';

  @override
  String get foodScheduleNow => 'Deliver now';

  @override
  String get foodScheduleNowDesc => 'Restaurant will start preparing immediately after confirmation';

  @override
  String get foodScheduleLater => 'Schedule delivery';

  @override
  String get foodScheduleLaterDesc => 'Choose date and time you want to receive food';

  @override
  String foodScheduleLaterSet(Object dateTime) {
    return 'Scheduled: $dateTime';
  }

  @override
  String get foodSchedulePickDate => 'Choose delivery date';

  @override
  String get foodSchedulePickTime => 'Choose delivery time';

  @override
  String get foodScheduleMinTime => 'Please choose a time at least 20 minutes from now';

  @override
  String get foodScheduleRequired => 'Please choose delivery date and time';

  @override
  String get foodDistanceWarningTitle => 'Out of delivery range';

  @override
  String foodDistanceWarningBody(Object distance, Object maxRadius) {
    return 'Your delivery location is $distance km from the restaurant\nwhich exceeds the default range of $maxRadius km.';
  }

  @override
  String foodDistanceWarningFee(Object fee) {
    return 'Delivery fee based on actual distance: ฿$fee';
  }

  @override
  String get foodDistanceWarningOk => 'Understood';

  @override
  String get foodAddressCurrentLocation => 'Current location';

  @override
  String get foodAddressPinOnMap => 'Pin on map';

  @override
  String get foodAddressSaved => 'Saved addresses';

  @override
  String foodAddressDistance(Object km) {
    return 'Distance: $km km';
  }

  @override
  String get foodAddressUnknown => 'Current location (unable to determine)';

  @override
  String foodDeliveryFeeWithDist(Object km) {
    return 'Delivery fee ($km km)';
  }

  @override
  String get foodCalculating => 'Calculating...';

  @override
  String get foodCouponDiscount => 'Coupon discount';

  @override
  String get foodCheckoutLocationRequired => 'Unable to determine delivery location. Please select a location';

  @override
  String get foodCheckoutNoResponse => 'No order data received from server';

  @override
  String get foodCheckoutFailedTitle => 'Order failed';

  @override
  String foodCheckoutSuccessScheduled(Object dateTime) {
    return 'Scheduled order placed successfully ($dateTime)';
  }

  @override
  String get foodCheckoutSuccessNow => 'Order placed! Waiting for restaurant to confirm';

  @override
  String foodCheckoutNotifScheduledBody(Object amount, Object dateTime) {
    return 'Customer pre-ordered food ฿$amount for $dateTime';
  }

  @override
  String get orderDetailScreenTitle => 'Order details';

  @override
  String get orderDetailCancel => 'Cancel';

  @override
  String orderDetailOrderId(Object code) {
    return 'Order $code';
  }

  @override
  String orderDetailOrderedAt(Object dateTime) {
    return 'Ordered: $dateTime';
  }

  @override
  String get orderDetailLocationTitle => 'Location';

  @override
  String get orderDetailPickup => 'Pickup';

  @override
  String get orderDetailDestination => 'Destination';

  @override
  String get orderDetailDriverTitle => 'Driver info';

  @override
  String get orderDetailDriverUnnamed => 'No name';

  @override
  String get orderDetailTrack => 'Track';

  @override
  String get orderDetailChat => 'Chat';

  @override
  String get orderDetailCall => 'Call';

  @override
  String orderDetailCannotCall(Object phone) {
    return 'Cannot call $phone';
  }

  @override
  String get orderDetailItemsTitle => 'Food items';

  @override
  String get orderDetailNoItems => 'No food items found';

  @override
  String get orderDetailItemUnnamed => 'Unnamed';

  @override
  String orderDetailQuantity(Object qty) {
    return 'Qty: $qty';
  }

  @override
  String get orderDetailOptionsLabel => 'Extras:';

  @override
  String get orderDetailOptionDefault => 'Option';

  @override
  String get orderDetailAddressUnknown => 'Address not specified';

  @override
  String get orderDetailAddressCurrent => 'Current location';

  @override
  String get orderDetailPriceTitle => 'Price details';

  @override
  String get orderDetailFoodCost => 'Food cost';

  @override
  String get orderDetailDeliveryFee => 'Delivery fee';

  @override
  String get orderDetailCouponDiscount => 'Coupon discount';

  @override
  String orderDetailCouponDiscountCode(Object code) {
    return 'Coupon discount ($code)';
  }

  @override
  String get orderDetailDistance => 'Distance';

  @override
  String orderDetailDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String get orderDetailTotal => 'Total';

  @override
  String get orderDetailServiceRide => 'Ride service';

  @override
  String get orderDetailServiceFood => 'Food order';

  @override
  String get orderDetailServiceParcel => 'Parcel delivery';

  @override
  String get orderDetailStatusPending => 'Pending confirmation';

  @override
  String get orderDetailStatusPendingMerchant => 'Waiting for restaurant';

  @override
  String get orderDetailStatusPreparing => 'Preparing food';

  @override
  String get orderDetailStatusReady => 'Food ready';

  @override
  String get orderDetailStatusDriverAccepted => 'Driver accepted';

  @override
  String get orderDetailStatusConfirmed => 'Confirmed';

  @override
  String get orderDetailStatusArrived => 'Arrived at pickup';

  @override
  String get orderDetailStatusPickingUp => 'Driver picking up';

  @override
  String get orderDetailStatusInTransit => 'Delivering food';

  @override
  String get orderDetailStatusCompleted => 'Completed';

  @override
  String get orderDetailStatusCancelled => 'Declined';

  @override
  String get orderDetailCancelledTitle => 'Restaurant rejected order';

  @override
  String get orderDetailCancelledBody => 'Sorry, the restaurant cannot accept your order at this time';

  @override
  String get orderDetailOrderNumber => 'Order number';

  @override
  String get orderDetailCancelledRetry => 'Please try ordering again or choose another restaurant';

  @override
  String get orderDetailUnderstood => 'Understood';

  @override
  String get orderDetailChatError => 'Cannot open chat';

  @override
  String get orderDetailDriverDefault => 'Driver';

  @override
  String get orderDetailCompletedFood => 'Delivered successfully!';

  @override
  String get orderDetailCompletedRide => 'Trip completed!';

  @override
  String get orderDetailThankYou => 'Thank you for using our service';

  @override
  String get orderDetailTotalAmount => 'Total amount';

  @override
  String get orderDetailIncludingDelivery => 'Including delivery';

  @override
  String orderDetailCouponUsed(Object code, Object amount) {
    return 'Used coupon $code discount ฿$amount';
  }

  @override
  String orderDetailCouponUsedNoCode(Object amount) {
    return 'Used coupon discount ฿$amount';
  }

  @override
  String get orderDetailCancelConfirmTitle => 'Confirm order cancellation';

  @override
  String get orderDetailCancelConfirmBody => 'Do you want to cancel this order?';

  @override
  String get orderDetailCancelNote => 'Note: Orders in progress cannot be cancelled';

  @override
  String get orderDetailCancelKeep => 'Keep order';

  @override
  String get orderDetailCancelConfirm => 'Confirm cancel';

  @override
  String get orderDetailCancelling => 'Cancelling order...';

  @override
  String get orderDetailCancelSuccess => 'Order cancelled successfully';

  @override
  String orderDetailCancelError(Object error) {
    return 'Cannot cancel order: $error';
  }

  @override
  String get driverDashTitle => 'Driver Dashboard';

  @override
  String get driverDashOnline => 'Online';

  @override
  String get driverDashOffline => 'Offline';

  @override
  String get driverDashProfile => 'Profile';

  @override
  String get driverDashLogout => 'Sign out';

  @override
  String get driverDashJobList => 'Job list';

  @override
  String get driverDashRefreshing => 'Refreshing...';

  @override
  String get driverDashRealtime => 'Realtime';

  @override
  String get driverDashDriverDefault => 'Driver';

  @override
  String get driverDashPendingJobs => 'Pending';

  @override
  String get driverDashCompletedToday => 'Done today';

  @override
  String get driverDashEarningsToday => 'Earnings today';

  @override
  String get driverDashNowOnline => 'You are now online';

  @override
  String get driverDashNowOffline => 'You are now offline';

  @override
  String get driverDashOfflineTitle => 'You are offline';

  @override
  String get driverDashNoJobs => 'No new jobs';

  @override
  String get driverDashOfflineHint => 'Go online to receive new jobs';

  @override
  String get driverDashNoJobsHint => 'New jobs will appear here instantly';

  @override
  String get driverDashRefresh => 'Refresh';

  @override
  String driverDashNewJob(Object type, Object status) {
    return 'New job! $type - $status';
  }

  @override
  String get driverDashViewJob => 'View job';

  @override
  String get driverDashJobFood => 'Food delivery';

  @override
  String get driverDashJobRide => 'Passenger ride';

  @override
  String get driverDashJobParcel => 'Parcel delivery';

  @override
  String get driverDashJobGeneral => 'General job';

  @override
  String get driverDashStatusPending => 'Waiting for driver';

  @override
  String get driverDashStatusPendingMerchant => 'Waiting for restaurant';

  @override
  String get driverDashStatusPreparing => 'Preparing food';

  @override
  String get driverDashStatusMatched => 'Matched';

  @override
  String get driverDashStatusReady => 'Food ready';

  @override
  String get driverDashStatusAccepted => 'Accepted';

  @override
  String get driverDashStatusDriverAccepted => 'Driver accepted';

  @override
  String get driverDashStatusUnknown => 'Unknown status';

  @override
  String get driverDashMustOnline => 'Please go online before accepting jobs';

  @override
  String get driverDashNoUser => 'User not found';

  @override
  String get driverDashPleaseLogin => 'Please sign in again';

  @override
  String get driverDashAccepted => 'Job accepted! Navigating...';

  @override
  String get driverDashErrorTitle => 'Error occurred';

  @override
  String driverDashNavError(Object error) {
    return 'Cannot open navigation: $error';
  }

  @override
  String get driverDashInsufficientBalance => 'Insufficient balance';

  @override
  String get driverDashClose => 'Close';

  @override
  String get driverDashTopUp => 'Top up';

  @override
  String get driverDashCannotAccept => 'Cannot accept job';

  @override
  String get driverDashOk => 'OK';

  @override
  String driverDashErrorGeneric(Object error) {
    return 'Error: $error';
  }

  @override
  String get driverDashPickupRestaurant => 'Restaurant';

  @override
  String get driverDashPickupPoint => 'Pickup';

  @override
  String get driverDashPickupFoodFallback => 'Restaurant location';

  @override
  String get driverDashPickupRideFallback => 'Current location';

  @override
  String get driverDashDestCustomer => 'Customer location';

  @override
  String get driverDashDestPoint => 'Destination';

  @override
  String get driverDashDestFallback => 'Destination';

  @override
  String driverDashScheduledFrom(Object dateTime) {
    return 'Scheduled: available from $dateTime';
  }

  @override
  String driverDashScheduledAt(Object dateTime) {
    return 'Scheduled: $dateTime';
  }

  @override
  String driverDashAcceptAt(Object dateTime) {
    return 'Available at $dateTime';
  }

  @override
  String get driverDashAcceptParcel => 'Accept parcel job';

  @override
  String get driverDashAcceptRide => 'Accept this job';

  @override
  String get driverDashAcceptFood => 'Accept food order';

  @override
  String get driverDashIncompleteJob => 'Incomplete job';

  @override
  String get driverDashInProgress => 'In progress';

  @override
  String get driverDashGoToNav => 'Go to navigation';

  @override
  String get driverDashNavigating => 'Opening navigation...';

  @override
  String driverDashCannotNav(Object error) {
    return 'Cannot navigate: $error';
  }

  @override
  String get driverDashCollectCustomer => 'Collect from customer';

  @override
  String get driverDashFoodCost => 'Food cost';

  @override
  String get driverDashDeliveryFee => 'Delivery fee';

  @override
  String get driverDashDistance => 'Distance';

  @override
  String driverDashDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String driverDashCouponDiscount(Object amount) {
    return 'Coupon discount -฿$amount';
  }

  @override
  String driverDashCouponDiscountCode(Object amount) {
    return 'Coupon -฿$amount';
  }

  @override
  String get driverDashTimeJustNow => 'Just now';

  @override
  String driverDashTimeMinutes(Object min) {
    return '$min min ago';
  }

  @override
  String driverDashTimeHours(Object hours) {
    return '$hours hr ago';
  }

  @override
  String driverDashTimeDays(Object days) {
    return '$days days ago';
  }

  @override
  String get driverDashVehicleMotorcycle => 'Motorcycle';

  @override
  String get driverDashVehicleCar => 'Car';

  @override
  String get driverDashNotifFoodTitle => 'Driver accepted your order!';

  @override
  String driverDashNotifFoodBody(Object name) {
    return 'Driver $name is coming to pick up your food';
  }

  @override
  String get driverDashNotifFoodBodyDefault => 'A driver is coming to pick up your food';

  @override
  String get driverDashNotifParcelTitle => 'Driver accepted your parcel!';

  @override
  String driverDashNotifParcelBody(Object name) {
    return 'Driver $name is coming to pick up your parcel';
  }

  @override
  String get driverDashNotifParcelBodyDefault => 'A driver is coming to pick up your parcel';

  @override
  String get driverDashNotifRideTitle => 'Driver accepted your trip!';

  @override
  String driverDashNotifRideBody(Object name) {
    return 'Driver $name is coming to pick you up';
  }

  @override
  String get driverDashNotifRideBodyDefault => 'A driver is coming to pick you up';

  @override
  String get driverDashNotifMerchantTitle => 'Driver accepted the order!';

  @override
  String driverDashNotifMerchantBody(Object name, Object code) {
    return 'Driver $name is coming to pick up order $code';
  }

  @override
  String get driverDashNotifMerchantBodyDefault => 'A driver is coming to pick up your order';

  @override
  String get driverNavCustomerDefault => 'Customer';

  @override
  String get driverNavPhoneUnknown => 'Not specified';

  @override
  String get driverNavMerchantDefault => 'Restaurant';

  @override
  String get driverNavLocationPermSnack => 'Please allow location access to use this feature';

  @override
  String get driverNavLocationDeniedTitle => 'Cannot access location';

  @override
  String get driverNavLocationDeniedBody => 'Please enable location access in device settings to use the app normally';

  @override
  String get driverNavOk => 'OK';

  @override
  String get driverNavOpenSettings => 'Open settings';

  @override
  String get driverNavNoMerchantPhone => 'Merchant phone not found';

  @override
  String get driverNavCannotCall => 'Cannot make a call';

  @override
  String get driverNavCallError => 'Error making call';

  @override
  String get driverNavNoCustomerPhone => 'Customer phone not found';

  @override
  String get driverNavCancelTitle => 'Cancel job';

  @override
  String get driverNavCancelSelectReason => 'Please select a cancellation reason:';

  @override
  String get driverNavCancelReason1 => 'Customer unreachable';

  @override
  String get driverNavCancelReason2 => 'Restaurant closed/unavailable';

  @override
  String get driverNavCancelReason3 => 'Distance too far';

  @override
  String get driverNavCancelReason4 => 'Personal emergency';

  @override
  String get driverNavCancelReason5 => 'Bad weather/road conditions';

  @override
  String get driverNavCancelReason6 => 'Other';

  @override
  String get driverNavCancelWarning => 'Frequent cancellations may affect your rating';

  @override
  String get driverNavCancelBack => 'Back';

  @override
  String get driverNavCancelConfirm => 'Confirm cancel';

  @override
  String get driverNavCancelNotifTitle => 'Driver cancelled job';

  @override
  String driverNavCancelNotifBody(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get driverNavCancelSuccess => 'Job cancelled successfully';

  @override
  String driverNavCancelError(Object error) {
    return 'Cannot cancel job: $error';
  }

  @override
  String get driverNavMarkerPickup => 'Pickup';

  @override
  String get driverNavMarkerPickupFallback => 'Pickup location';

  @override
  String get driverNavMarkerDest => 'Destination';

  @override
  String get driverNavMarkerDestFallback => 'Destination';

  @override
  String get driverNavMarkerDriver => 'Driver location';

  @override
  String get driverNavMarkerYou => 'Your location';

  @override
  String get driverNavMarkerPosition => 'Location';

  @override
  String get driverNavNoDriverData => 'Driver data not found. Please sign out and sign in again';

  @override
  String get driverNavStatusUpdated => 'Status updated successfully';

  @override
  String get driverNavPermDenied => 'Permission denied. Please check your account permissions';

  @override
  String get driverNavBookingNotFound => 'Booking not found. Please refresh and try again';

  @override
  String get driverNavDriverInvalid => 'Driver data invalid. Please sign out and sign in again';

  @override
  String driverNavStatusUpdateError(Object error) {
    return 'Cannot update status: $error';
  }

  @override
  String get driverNavCannotOpenMaps => 'Cannot open Google Maps';

  @override
  String get driverNavMapsError => 'Error opening navigation map';

  @override
  String get driverNavFoodArrivedMerchant => 'Arrived at restaurant';

  @override
  String get driverNavFoodWaitReady => 'Wait for food ready';

  @override
  String get driverNavFoodPickup => 'Pick up food';

  @override
  String get driverNavFoodStartDelivery => 'Start food delivery';

  @override
  String get driverNavFoodComplete => 'Food delivery complete';

  @override
  String get driverNavParcelArrivedPickup => 'Arrived at parcel pickup';

  @override
  String get driverNavParcelStartDelivery => 'Pick up parcel, start delivery';

  @override
  String get driverNavParcelComplete => 'Parcel delivery complete';

  @override
  String get driverNavRideArrivedPickup => 'Arrived at customer pickup';

  @override
  String get driverNavRideStartTrip => 'Pick up passenger, start trip';

  @override
  String get driverNavRideComplete => 'Passenger drop-off complete';

  @override
  String get driverNavUpdateStatus => 'Update status';

  @override
  String get driverNavWaitMerchantReady => 'Please wait for restaurant to mark food ready';

  @override
  String driverNavInvalidStatus(Object status) {
    return 'Invalid status: $status';
  }

  @override
  String get driverNavProxCustomerDest => 'Customer destination';

  @override
  String get driverNavProxMerchant => 'Restaurant';

  @override
  String get driverNavProxRidePickup => 'Passenger pickup';

  @override
  String get driverNavProxParcelPickup => 'Parcel pickup';

  @override
  String get driverNavTooFarTitle => 'Too far away';

  @override
  String driverNavTooFarBody(Object current, Object allowed) {
    return 'Please move closer to the destination\n\nCurrent distance: $current meters\nAllowed distance: $allowed meters';
  }

  @override
  String driverNavCannotCheckLocation(Object error) {
    return 'Cannot verify location: $error';
  }

  @override
  String get driverNavChatError => 'Cannot open chat';

  @override
  String get driverNavChatRoomError => 'Cannot open chat room';

  @override
  String get driverNavChatOpenError => 'Error opening chat';

  @override
  String get driverNavOrderItemsTitle => 'Food items';

  @override
  String get driverNavOrderItemsEmpty => 'No food items found';

  @override
  String get driverNavItemUnspecified => 'Unspecified';

  @override
  String get driverNavOptionsLabel => 'Options:';

  @override
  String get driverNavClose => 'Close';

  @override
  String get driverNavLoadItemsError => 'Cannot load food items';

  @override
  String get driverNavStatusFoodGoingMerchant => 'Going to restaurant';

  @override
  String get driverNavStatusFoodAtMerchant => 'At restaurant, waiting for food';

  @override
  String get driverNavStatusFoodReady => 'Food is ready';

  @override
  String get driverNavStatusFoodPickedUp => 'Food picked up';

  @override
  String get driverNavStatusFoodDelivering => 'Delivering food...';

  @override
  String get driverNavStatusParcelGoing => 'Going to pick up parcel';

  @override
  String get driverNavStatusParcelArrived => 'Arrived at parcel pickup';

  @override
  String get driverNavStatusParcelReady => 'Ready to deliver parcel';

  @override
  String get driverNavStatusParcelDelivering => 'Delivering parcel...';

  @override
  String get driverNavStatusRideGoing => 'Going to pick up passenger';

  @override
  String get driverNavStatusRideArrived => 'Arrived at customer pickup';

  @override
  String get driverNavStatusRideReady => 'Ready to pick up passenger';

  @override
  String get driverNavStatusRideTraveling => 'Traveling...';

  @override
  String get driverNavStatusAtPickup => 'At pickup point';

  @override
  String get driverNavStatusPickedUp => 'Picked up';

  @override
  String get driverNavStatusCompleted => 'Delivery complete';

  @override
  String get driverNavStatusDefault => 'In progress';

  @override
  String get driverNavServiceFood => 'Food order';

  @override
  String get driverNavServiceRide => 'Ride';

  @override
  String get driverNavServiceParcel => 'Parcel delivery';

  @override
  String get driverNavServiceDefault => 'Service';

  @override
  String get driverNavBackTitle => 'Leave navigation?';

  @override
  String get driverNavBackBody => 'You still have an active job. The job will continue';

  @override
  String get driverNavBackStay => 'Stay';

  @override
  String get driverNavBackLeave => 'Go back';

  @override
  String get driverNavLoading => 'Loading...';

  @override
  String get driverNavActiveJob => 'Active job';

  @override
  String get driverNavCallCustomer => 'Call customer';

  @override
  String get driverNavTooltipNav => 'Navigate';

  @override
  String get driverNavTooltipChat => 'Chat with customer';

  @override
  String get driverNavChipType => 'Type';

  @override
  String get driverNavChipDistance => 'Distance';

  @override
  String get driverNavViewFoodItems => 'View food items';

  @override
  String get driverNavReportIssue => 'Report issue';

  @override
  String get driverNavCancelJob => 'Cancel job';

  @override
  String get driverNavJobCancelledTitle => 'Job cancelled';

  @override
  String get driverNavJobCancelledBody => 'This job has been cancelled. Returning to driver home';

  @override
  String get driverNavGoHome => 'Go to home';

  @override
  String get driverNavNotifStatusTitle => 'Job status update';

  @override
  String get driverNavNotifAccepted => 'Driver has accepted the job';

  @override
  String get driverNavNotifArrived => 'Driver has arrived at pickup';

  @override
  String get driverNavNotifPickedUp => 'Driver picked up food, delivering now';

  @override
  String get driverNavNotifInTransit => 'Driver is on the way to you';

  @override
  String get driverNavNotifCompleted => 'Job completed successfully';

  @override
  String get driverNavNotifCancelled => 'Job has been cancelled';

  @override
  String driverNavNotifStatusUpdate(Object status) {
    return 'Job status updated to $status';
  }

  @override
  String get driverNavMerchantArrivedTitle => 'Driver arrived at restaurant';

  @override
  String get driverNavMerchantArrivedBody => 'Driver has arrived. Please prepare the food for handover';

  @override
  String get driverNavPaymentTitle => 'Merchant payment successful';

  @override
  String get driverNavPaymentBody => 'Food picked up from restaurant\nPlease deliver to customer';

  @override
  String get driverNavPaymentSales => 'Sales';

  @override
  String driverNavPaymentDeduction(Object percent) {
    return 'Deduction ($percent%)';
  }

  @override
  String get driverNavPaymentToMerchant => 'Pay to merchant';

  @override
  String get driverNavPaymentDeliver => 'Deliver to customer';

  @override
  String get driverNavCompletionTitle => 'Job completed!';

  @override
  String get driverNavCompletionSuccess => 'Delivered successfully!';

  @override
  String get driverNavCompletionCollect => 'Collect from customer';

  @override
  String get driverNavCompletionFoodCost => '  Food cost';

  @override
  String get driverNavCompletionDeliveryFee => '  Delivery fee';

  @override
  String get driverNavCompletionCouponPlatform => '  Platform coupon discount';

  @override
  String driverNavCompletionCouponCode(Object code) {
    return '  Coupon discount ($code)';
  }

  @override
  String get driverNavCompletionCoupon => '  Coupon discount';

  @override
  String get driverNavCompletionServiceFee => 'System service fee';

  @override
  String get driverNavCompletionNetEarnings => 'Net earnings';

  @override
  String get driverNavCompletionViewDetails => 'View details';

  @override
  String get driverNavFinCardCollect => 'Collect from customer';

  @override
  String get driverNavFinCardFoodCost => 'Food cost';

  @override
  String get driverNavFinCardDeliveryFee => 'Delivery fee';

  @override
  String get driverNavFinCardPayMerchant => 'Pay to merchant';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletBalance => 'Balance';

  @override
  String walletBalanceBaht(Object amount) {
    return '$amount Baht';
  }

  @override
  String get walletTopUp => 'Top up';

  @override
  String get walletTransactionHistory => 'Transaction history';

  @override
  String get walletLoadError => 'Error loading data';

  @override
  String get walletRetry => 'Try again';

  @override
  String get walletNoTransactions => 'No transaction history yet';

  @override
  String get walletTypeTopup => 'Top up';

  @override
  String get walletTypeCommission => 'System service fee';

  @override
  String get walletTypeFoodCommission => 'Food system service fee';

  @override
  String get walletTypeJobIncome => 'Job income';

  @override
  String get walletTypePenalty => 'Penalty';

  @override
  String walletToday(Object time) {
    return 'Today $time';
  }

  @override
  String walletYesterday(Object time) {
    return 'Yesterday $time';
  }

  @override
  String get topupTitle => 'Top up / Withdraw';

  @override
  String topupMinAmountError(Object amount) {
    return 'Please enter at least $amount Baht';
  }

  @override
  String topupMaxAmountError(Object amount) {
    return 'Amount exceeds limit per transaction (max ฿$amount)';
  }

  @override
  String get topupOmiseSourceError => 'Cannot create PromptPay Source\nPlease check Omise Key in .env';

  @override
  String get topupOmiseChargeError => 'Cannot create Charge\nPlease check Omise Secret Key';

  @override
  String get topupOmiseQRError => 'QR Code not found in Charge response\nPlease try again';

  @override
  String topupOmiseError(Object error) {
    return 'Omise error: $error';
  }

  @override
  String get topupQRExpired => 'QR Code expired, please generate a new one';

  @override
  String get topupPaymentFailed => 'Payment failed, please try again';

  @override
  String get topupCreditError => 'Payment successful but cannot add to wallet\nPlease contact Admin with transfer proof';

  @override
  String get topupCreditGenericError => 'Payment successful but an error occurred\nPlease contact Admin';

  @override
  String get topupPromptPayNotSet => 'PromptPay number not configured\nPlease contact Admin to set up';

  @override
  String get topupPromptPayInvalid => 'PromptPay number in system is invalid\nPlease contact Admin';

  @override
  String topupLocalError(Object error) {
    return 'Error: $error';
  }

  @override
  String get topupDirectError => 'Cannot add to wallet\nPlease contact Admin';

  @override
  String get topupDirectGenericError => 'Error adding to wallet\nPlease contact Admin';

  @override
  String get topupDriverDefault => 'Driver';

  @override
  String get topupErrorTitle => 'Error occurred';

  @override
  String get topupOk => 'OK';

  @override
  String get topupRequestSentTitle => 'Top-up request sent';

  @override
  String topupRequestSentBody(Object amount) {
    return 'Top-up request ฿$amount has been sent\nWaiting for Admin to verify';
  }

  @override
  String get topupSuccessTitle => 'Top up successful!';

  @override
  String topupSuccessBody(Object amount) {
    return 'Added ฿$amount to wallet successfully';
  }

  @override
  String get topupWithdrawTitle => 'Withdraw';

  @override
  String topupWithdrawBalance(Object amount) {
    return 'Balance: ฿$amount';
  }

  @override
  String get topupWithdrawAmountLabel => 'Amount to withdraw';

  @override
  String get topupWithdrawBankName => 'Bank name';

  @override
  String get topupWithdrawBankHint => 'e.g. Kasikorn, SCB';

  @override
  String get topupWithdrawAccountNum => 'Account number';

  @override
  String get topupWithdrawAccountName => 'Account name';

  @override
  String get topupWithdrawCancel => 'Cancel';

  @override
  String get topupWithdrawAmountRequired => 'Please enter amount';

  @override
  String get topupWithdrawInsufficientBalance => 'Insufficient balance';

  @override
  String get topupWithdrawBankRequired => 'Please fill in bank info';

  @override
  String topupWithdrawError(Object error) {
    return 'Error: $error';
  }

  @override
  String get topupWithdrawSubmit => 'Submit withdrawal request';

  @override
  String get topupWithdrawBtn => 'Withdraw';

  @override
  String get topupWithdrawHistoryTitle => 'Withdrawal history';

  @override
  String get topupWithdrawHistoryEmpty => 'No withdrawal history yet';

  @override
  String get topupHistoryTitle => 'Top-up history';

  @override
  String get topupHistoryEmpty => 'No top-up history yet';

  @override
  String get topupStatusCompleted => 'Transferred';

  @override
  String get topupStatusRejected => 'Rejected';

  @override
  String get topupStatusCancelled => 'Cancelled';

  @override
  String get topupStatusPending => 'Pending';

  @override
  String get topupStatusApproved => 'Approved';

  @override
  String get topupSelectAmount => 'Select amount';

  @override
  String get topupCustomAmount => 'Or enter custom amount';

  @override
  String get topupScanQR => 'Scan QR Code to transfer';

  @override
  String get topupOmiseScanDesc => 'Scan QR via bank app — auto-verified';

  @override
  String get topupManualScanDesc => 'Transfer via PromptPay then confirm';

  @override
  String topupAmount(Object amount) {
    return 'Amount: ฿$amount';
  }

  @override
  String get topupOmiseAutoDesc => 'Scan QR to transfer — system auto-verifies';

  @override
  String get topupManualConfirmDesc => 'Scan QR then press \"Confirm transfer\" below';

  @override
  String get topupRequestSentCard => 'Top-up request sent';

  @override
  String topupRequestSentCardBody(Object amount) {
    return 'Amount ฿$amount — waiting for Admin to verify';
  }

  @override
  String get topupCheckingPayment => 'Checking payment...';

  @override
  String get topupAutoCheckDesc => 'System checks every 5 seconds\nWallet credited instantly on success';

  @override
  String get topupCancelNewQR => 'Cancel / Generate new QR';

  @override
  String get topupOmiseSuccessTitle => 'Payment successful!';

  @override
  String topupOmiseSuccessBody(Object amount) {
    return 'Added ฿$amount to wallet successfully';
  }

  @override
  String get topupOmiseAutoVerified => 'Auto-verified via Omise';

  @override
  String get topupGeneratingQR => 'Generating QR...';

  @override
  String get topupPayPromptPay => 'Pay with PromptPay';

  @override
  String get topupSending => 'Sending...';

  @override
  String topupConfirmTransfer(Object amount) {
    return 'Confirm transfer ฿$amount';
  }

  @override
  String get topupGenerateNewQR => 'Generate new QR';

  @override
  String get withdrawTitle => 'Withdraw';

  @override
  String get withdrawBalance => 'Balance';

  @override
  String get withdrawAmountRequired => 'Please specify withdrawal amount';

  @override
  String withdrawInsufficientBalance(Object amount) {
    return 'Insufficient balance\nRemaining: ฿$amount';
  }

  @override
  String get withdrawFailed => 'Cannot submit withdrawal\nPlease try again';

  @override
  String get withdrawGenericError => 'Error occurred\nPlease try again';

  @override
  String get withdrawErrorTitle => 'Error occurred';

  @override
  String get withdrawOk => 'OK';

  @override
  String get withdrawSuccessTitle => 'Withdrawal request submitted';

  @override
  String withdrawSuccessBody(Object amount) {
    return 'Withdrawal request ฿$amount received\n\nAdmin will review and transfer within 1-3 business days';
  }

  @override
  String get withdrawAmountSectionTitle => 'Withdrawal amount';

  @override
  String get withdrawAmountLabel => 'Amount (Baht)';

  @override
  String get withdrawMinHelper => 'Minimum ฿100';

  @override
  String get withdrawAmountValidation => 'Please specify amount';

  @override
  String get withdrawMinValidation => 'Minimum ฿100';

  @override
  String get withdrawBankInfoTitle => 'Bank account information';

  @override
  String get withdrawBankLabel => 'Bank';

  @override
  String get withdrawBankValidation => 'Please select a bank';

  @override
  String get withdrawAccountNumLabel => 'Account number';

  @override
  String get withdrawAccountNumValidation => 'Please enter account number';

  @override
  String get withdrawAccountNameLabel => 'Account name';

  @override
  String get withdrawAccountNameValidation => 'Please enter account name';

  @override
  String get withdrawProcessing => 'Processing...';

  @override
  String get withdrawSubmitBtn => 'Submit withdrawal';

  @override
  String get withdrawHistoryTitle => 'Withdrawal request history';

  @override
  String get withdrawStatusCompleted => 'Transferred';

  @override
  String get withdrawStatusRejected => 'Rejected';

  @override
  String get withdrawStatusCancelled => 'Cancelled';

  @override
  String get withdrawStatusPending => 'Pending';

  @override
  String get withdrawBankKasikorn => 'Kasikorn Bank';

  @override
  String get withdrawBankSCB => 'Siam Commercial Bank';

  @override
  String get withdrawBankBangkok => 'Bangkok Bank';

  @override
  String get withdrawBankKrungthai => 'Krungthai Bank';

  @override
  String get withdrawBankKrungsri => 'Krungsri Bank';

  @override
  String get withdrawBankTTB => 'TMBThanachart Bank';

  @override
  String get withdrawBankGSB => 'Government Savings Bank';

  @override
  String get withdrawBankKKP => 'Kiatnakin Phatra Bank';

  @override
  String get withdrawBankCIMB => 'CIMB Thai Bank';

  @override
  String get withdrawBankTisco => 'Tisco Bank';

  @override
  String get withdrawBankUOB => 'UOB Bank';

  @override
  String get withdrawBankLH => 'Land and Houses Bank';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountErrorTitle => 'Failed to load';

  @override
  String get accountRetry => 'Try again';

  @override
  String get accountPersonalInfoTitle => 'Personal information';

  @override
  String get accountMenuTitle => 'Menu';

  @override
  String get accountAppInfoTitle => 'App info';

  @override
  String get accountLogout => 'Sign out';

  @override
  String get accountLogoutDialogTitle => 'Sign out';

  @override
  String get accountLogoutDialogBody => 'Do you want to sign out?';

  @override
  String get accountCancel => 'Cancel';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteDialogTitle => 'Delete account';

  @override
  String get accountDeleteDialogBody => 'Once confirmed, your request will be sent to an admin for approval.\nWhile waiting for approval, you will not be able to use the account.';

  @override
  String get accountDeleteReasonHint => 'Reason for deletion (optional)';

  @override
  String get accountDeleteConfirm => 'Confirm deletion';

  @override
  String get accountUploadingImage => 'Uploading image...';

  @override
  String get accountUploadSuccess => 'Profile photo uploaded successfully!';

  @override
  String accountUploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get accountUpdateSuccess => 'Updated successfully!';

  @override
  String accountUpdateFailed(Object error) {
    return 'Update failed: $error';
  }

  @override
  String get accountOpenLinkFailed => 'Unable to open link';

  @override
  String accountErrorGeneric(Object error) {
    return 'Error: $error';
  }

  @override
  String get accountInfoTitle => 'Information';

  @override
  String get accountInfoName => 'Name';

  @override
  String get accountInfoPhone => 'Phone';

  @override
  String get accountInfoEmail => 'Email';

  @override
  String get accountNotSet => 'Not set';

  @override
  String get accountMenuEditProfile => 'Edit profile';

  @override
  String get accountMenuCoupons => 'My coupons';

  @override
  String get accountMenuReferral => 'Referral';

  @override
  String get accountMenuHelp => 'Help';

  @override
  String get accountMenuNotifications => 'Notifications';

  @override
  String get accountMenuPrivacyPolicy => 'Privacy policy';

  @override
  String get accountFeatureComingSoon => 'This feature will be available in a future version';

  @override
  String get merchantMenuEditShop => 'Edit shop information';

  @override
  String get merchantMenuCoupons => 'Merchant coupons';

  @override
  String get accountRoleCustomer => 'Customer';

  @override
  String get accountRoleMerchant => 'Merchant';

  @override
  String get accountRoleDriver => 'Driver';

  @override
  String get driverInfoVehicleType => 'Vehicle type';

  @override
  String get driverInfoLicensePlate => 'License plate';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileLoadFailedTitle => 'Failed to load profile';

  @override
  String profileLoadFailedBody(Object error) {
    return 'Unable to load profile data: $error';
  }

  @override
  String get profileSaveSuccess => 'Profile saved successfully';

  @override
  String get profileSaveFailedTitle => 'Save failed';

  @override
  String profileSaveFailedBody(Object error) {
    return 'Unable to save profile: $error';
  }

  @override
  String get profileBasicInfoSection => 'Basic information';

  @override
  String get profileVehicleSection => 'Vehicle information';

  @override
  String get profileMerchantSection => 'Shop information';

  @override
  String get profileSave => 'Save';

  @override
  String get profileUploadingImage => 'Uploading image...';

  @override
  String get profileVehicleMotorcycle => 'Motorcycle';

  @override
  String get profileVehicleCar => 'Car';

  @override
  String get profileFullNameLabel => 'Full name';

  @override
  String get profileFullNameRequired => 'Please enter your name';

  @override
  String get profilePhoneLabel => 'Phone number';

  @override
  String get profilePhoneRequired => 'Please enter your phone number';

  @override
  String get profileLicensePlateRequired => 'Please enter your license plate';

  @override
  String get profileShopNameLabel => 'Shop name';

  @override
  String get profileShopNameHint => 'Enter shop name';

  @override
  String get profileShopNameRequired => 'Please enter shop name';

  @override
  String get profileShopAddressLabel => 'Shop address';

  @override
  String get profileShopAddressHint => 'Enter shop address';

  @override
  String get profileShopAddressRequired => 'Please enter shop address';

  @override
  String get profileShopPhoneLabel => 'Shop phone';

  @override
  String get profileShopPhoneHint => 'Enter shop phone number';

  @override
  String get profileShopPhoneRequired => 'Please enter shop phone number';

  @override
  String get accountVersionLabel => 'Version';

  @override
  String get accountDevelopedByLabel => 'Developed by';

  @override
  String get accountLoading => 'Loading...';

  @override
  String accountDeleteRequestSubmitFailed(Object error) {
    return 'Unable to submit request: $error';
  }

  @override
  String get merchantCloseShopTitle => 'Close shop?';

  @override
  String get merchantCloseShopBody => 'Closing the shop manually will disable auto open/close.\nYou can re-enable this feature in Settings.';

  @override
  String get merchantCloseShopCancel => 'Cancel';

  @override
  String get merchantCloseShopConfirm => 'Close shop';

  @override
  String get merchantNewOrderAlert => '🚨 New order!';

  @override
  String get merchantNewOrderWaiting => 'You have a new order waiting for confirmation!';

  @override
  String get merchantAlarmDesc => 'Sound will keep alerting until you press stop';

  @override
  String get merchantStopAlarm => 'Stop sound / Acknowledge';

  @override
  String get merchantUserNotFound => 'User data not found';

  @override
  String get merchantOrderConfirmed => 'Order has been confirmed!';

  @override
  String get merchantShopOpenedAutoOff => 'Shop opened (auto schedule disabled)';

  @override
  String get merchantShopOpened => 'Shop opened';

  @override
  String get merchantShopClosedAutoOff => 'Shop closed (auto schedule disabled)';

  @override
  String get merchantShopClosed => 'Shop closed';

  @override
  String merchantShopStatusError(Object error) {
    return 'Unable to change shop status: $error';
  }

  @override
  String get merchantDriverStatusWaiting => 'Driver: Waiting for driver...';

  @override
  String merchantDriverStatusComing(Object name) {
    return 'Driver: $name is on the way';
  }

  @override
  String merchantDriverStatusArrived(Object name) {
    return 'Driver: $name has arrived';
  }

  @override
  String get merchantDriverStatusPreparing => 'Driver: Waiting for food preparation';

  @override
  String get merchantDriverStatusReady => 'Driver: Waiting for food ready';

  @override
  String get merchantDriverStatusDefault => 'Driver: Processing';

  @override
  String get merchantDriverDefault => 'Driver';

  @override
  String get merchantStatusNewOrder => 'New order';

  @override
  String get merchantStatusPending => 'Pending';

  @override
  String get merchantStatusPreparing => 'Preparing';

  @override
  String get merchantStatusDriverAccepted => 'Driver accepted';

  @override
  String get merchantStatusArrivedAtMerchant => 'Driver arrived';

  @override
  String get merchantStatusMatched => 'Driver matched';

  @override
  String get merchantStatusReadyForPickup => 'Food ready';

  @override
  String get merchantStatusPickingUp => 'Driver picking up';

  @override
  String get merchantStatusInTransit => 'Delivering';

  @override
  String get merchantStatusCompleted => 'Completed';

  @override
  String get merchantStatusCancelled => 'Cancelled';

  @override
  String get merchantStatusUnknown => 'Unknown status';

  @override
  String get merchantAppBarOrders => 'Orders';

  @override
  String get merchantAppBarHistory => 'Order history';

  @override
  String get merchantTooltipActiveOrders => 'View active orders';

  @override
  String get merchantTooltipHistory => 'View order history';

  @override
  String get merchantRefreshed => 'Data refreshed';

  @override
  String get merchantErrorOccurred => 'An error occurred';

  @override
  String get merchantRetry => 'Try again';

  @override
  String get merchantNoOrders => 'No new orders';

  @override
  String get merchantOrdersWillAppear => 'New orders will appear here instantly';

  @override
  String get merchantOpenShopToReceive => 'Open shop to receive orders';

  @override
  String get merchantShopStatus => 'Shop status';

  @override
  String get merchantShopOpen => 'Shop open';

  @override
  String get merchantShopClosed2 => 'Shop closed';

  @override
  String get merchantShopOpenDesc => 'Customers can order food';

  @override
  String get merchantShopClosedDesc => 'Shop temporarily closed';

  @override
  String get merchantAcceptModeAuto => 'Auto accept orders';

  @override
  String get merchantAcceptModeManual => 'Manual accept orders';

  @override
  String get merchantAutoScheduleOn => 'Auto open/close: Enabled';

  @override
  String get merchantAutoScheduleOff => 'Auto open/close: Disabled';

  @override
  String get merchantAcceptOrder => 'Accept order';

  @override
  String get merchantPreparingFood => 'Preparing food';

  @override
  String get merchantTapForDetails => 'Tap for details';

  @override
  String get merchantDriverAcceptedCard => 'Driver accepted';

  @override
  String get merchantCookingFood => 'Cooking food';

  @override
  String get merchantDriverMatchedCard => 'Driver matched';

  @override
  String get merchantDriverTravelingToShop => 'Driver on the way to shop';

  @override
  String get merchantPrepareFood => 'Please prepare the food';

  @override
  String get merchantDriverArrivedCard => 'Driver arrived at shop';

  @override
  String get merchantDriverPickingUpCard => 'Driver picking up order';

  @override
  String get merchantDeliveringToCustomer => 'Delivering to customer';

  @override
  String get merchantDelivering => 'Delivering food';

  @override
  String get merchantOrderEnRoute => 'Order on the way to customer';

  @override
  String get merchantDriverPickedUpCard => 'Driver picked up order';

  @override
  String get merchantOrderDoneForMerchant => 'This order is done for the merchant';

  @override
  String get merchantAddressNotSpecified => 'Not specified';

  @override
  String get merchantAddressPinLocation => '📍 Customer pin location';

  @override
  String merchantScheduledOrder(Object dateTime) {
    return 'Scheduled order: $dateTime';
  }

  @override
  String merchantPickupTime(Object dateTime) {
    return 'Pickup time: $dateTime';
  }

  @override
  String merchantDistance(Object km) {
    return 'Distance $km km';
  }

  @override
  String get merchantTimeJustNow => 'Just now';

  @override
  String merchantTimeMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String merchantTimeHoursAgo(Object hours) {
    return '$hours hr ago';
  }

  @override
  String merchantTimeDaysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String get merchantNotifMerchantDefault => 'Shop';

  @override
  String get merchantNotifOrderAccepted => '✅ Shop confirmed your order!';

  @override
  String merchantNotifPreparingBody(Object merchantName) {
    return '$merchantName is preparing your food';
  }

  @override
  String get merchantNotifFoodReadyCustomer => '🍔 Food is ready!';

  @override
  String merchantNotifFoodReadyCustomerBody(Object merchantName) {
    return '$merchantName finished preparing, waiting for driver pickup';
  }

  @override
  String get merchantNotifFoodReadyDriver => '🍔 Food ready for pickup!';

  @override
  String merchantNotifFoodReadyDriverBody(Object merchantName) {
    return '$merchantName finished preparing, ready for pickup';
  }

  @override
  String get merchantViewHistory => 'View order history';

  @override
  String get merchantViewActive => 'View active orders';

  @override
  String orderDetailTitle(Object code) {
    return 'Order $code';
  }

  @override
  String get orderDetailDriverPhoneNotFound => 'Driver phone not found';

  @override
  String orderDetailLoadItemsError(Object error) {
    return 'Cannot load food items: $error';
  }

  @override
  String get orderDetailAccepted => 'Order confirmed!';

  @override
  String get orderDetailAcceptFailed => 'Failed to accept order';

  @override
  String orderDetailAcceptError(Object error) {
    return 'Cannot accept order: $error';
  }

  @override
  String get orderDetailOk => 'OK';

  @override
  String get orderDetailDeclined => 'Order declined';

  @override
  String get orderDetailDeclineFailed => 'Failed to decline order';

  @override
  String orderDetailDeclineError(Object error) {
    return 'Cannot decline order: $error';
  }

  @override
  String get orderDetailStatusUpdateFailed => 'Cannot update status';

  @override
  String get orderDetailFoodReady => 'Food ready! Waiting for driver';

  @override
  String get orderDetailUpdateFailed => 'Failed to update status';

  @override
  String orderDetailUpdateError(Object error) {
    return 'Cannot update status: $error';
  }

  @override
  String get orderDetailAddressNotSpecified => 'Not specified';

  @override
  String get orderDetailAddressPinLocation => 'Customer pin location';

  @override
  String get orderDetailOrderInfo => 'Order information';

  @override
  String get orderDetailOrderCode => 'Order code';

  @override
  String get orderDetailOrderTime => 'Order time';

  @override
  String get orderDetailPayment => 'Payment';

  @override
  String get orderDetailPaymentCash => 'Cash';

  @override
  String get orderDetailPaymentTransfer => 'Transfer';

  @override
  String get orderDetailDistanceLabel => 'Distance';

  @override
  String get orderDetailScheduled => 'Scheduled';

  @override
  String get orderDetailPriceBreakdown => 'Price breakdown';

  @override
  String get orderDetailSalesAmount => 'Sales';

  @override
  String orderDetailGpDeduction(Object percent) {
    return 'GP deduction ($percent%)';
  }

  @override
  String get orderDetailNetReceived => 'Net received';

  @override
  String get orderDetailDeliveryAddress => 'Delivery address';

  @override
  String get orderDetailCustomerNote => 'Customer note';

  @override
  String get orderDetailFoodItems => 'Food items';

  @override
  String get orderDetailOptions => 'Extras:';

  @override
  String get orderDetailDeclineBtn => 'Decline order';

  @override
  String get orderDetailAcceptBtn => 'Accept order';

  @override
  String get orderDetailWaitingDriver => 'Waiting for driver';

  @override
  String get orderDetailWaitingDriverDesc => 'Please wait for driver to accept\nbefore marking food as ready';

  @override
  String get orderDetailFoodReadyBtn => 'Food ready';

  @override
  String orderDetailStatusLabel(Object status) {
    return 'Status: $status';
  }

  @override
  String get orderDetailStatusArrivedMerchant => 'Driver arrived';

  @override
  String get orderDetailStatusReadyPickup => 'Food ready to deliver';

  @override
  String get orderDetailStatusUnknown => 'Unknown status';

  @override
  String get orderDetailCompletionTitle => '✅ Order completed';

  @override
  String get orderDetailCompletionBody => 'Driver has picked up the food and is delivering to customer';

  @override
  String get orderDetailCompletionOrderNum => 'Order number';

  @override
  String get orderDetailCompletionCustomer => 'Customer name';

  @override
  String get orderDetailCompletionNetReceived => 'Net received';

  @override
  String orderDetailCompletionAfterGP(Object percent) {
    return 'After GP deduction $percent%';
  }

  @override
  String get orderDetailCompletionOk => 'Understood';

  @override
  String get orderDetailCustomerDefault => 'Customer';

  @override
  String get orderDetailItemNotSpecified => 'Not specified';

  @override
  String get orderDetailNotifRejectTitle => '❌ Shop declined order';

  @override
  String get orderDetailNotifRejectBody => 'Sorry, the shop cannot accept your order at this time';

  @override
  String get customerHomeOk => 'OK';

  @override
  String get customerHomeGreeting => 'Hello';

  @override
  String get customerHomeNoNewNotifications => 'No new notifications';

  @override
  String get customerHomeHelpToday => 'What can we help you with today?';

  @override
  String get customerHomeAvailable247 => 'Available 24/7';

  @override
  String get customerHomeRealtimeTracking => 'Real-time tracking';

  @override
  String get customerHomePendingOrders => 'Pending orders';

  @override
  String customerHomeJobCount(Object count) {
    return '$count jobs';
  }

  @override
  String get customerHomeNoJobs => 'No pending orders. Start a new service!';

  @override
  String get customerHomePopularServices => 'Popular services';

  @override
  String get customerHomeCallRide => 'Call a ride';

  @override
  String get customerHomeCallRideSubtitle => 'Fast & safe';

  @override
  String get customerHomeOrderFood => 'Order food';

  @override
  String get customerHomeOrderFoodSubtitle => 'Order from nearby';

  @override
  String get customerHomeSendParcel => 'Send parcel';

  @override
  String get customerHomeSendParcelSubtitle => 'Deliver to destination';

  @override
  String get customerHomeQuickActions => 'Quick actions';

  @override
  String get customerHomeHistory => 'History';

  @override
  String get customerHomeBookings => 'Bookings';

  @override
  String get customerHomeSaved => 'Saved';

  @override
  String get customerHomePlaces => 'Places';

  @override
  String get customerHomeHelp => 'Help';

  @override
  String get customerHomeContactUs => 'Contact us';

  @override
  String get customerHomeHelpDeveloping => 'Help system under development';

  @override
  String get customerHomePromotions => 'Promotions';

  @override
  String get customerHomeDiscountCode => 'Discount code';

  @override
  String get customerHomePromoCodeHint => 'Use this code when ordering to get a discount';

  @override
  String get customerHomeClose => 'Close';

  @override
  String customerHomeCopiedCode(Object code) {
    return 'Copied code \"$code\"';
  }

  @override
  String get customerHomeCopyCode => 'Copy code';

  @override
  String customerHomeOrderCode(Object code) {
    return 'Order $code';
  }

  @override
  String get customerHomeDestination => 'Destination';

  @override
  String get customerHomePickupPoint => 'Pickup';

  @override
  String customerHomeDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String customerHomeOrderedAt(Object datetime) {
    return 'Ordered: $datetime';
  }

  @override
  String get customerHomeStatusPending => 'Pending';

  @override
  String get customerHomeStatusPendingMerchant => 'Waiting for merchant';

  @override
  String get customerHomeStatusPreparing => 'Preparing food';

  @override
  String get customerHomeStatusReadyPickup => 'Food ready';

  @override
  String get customerHomeStatusDriverAccepted => 'Driver accepted';

  @override
  String get customerHomeStatusConfirmed => 'Confirmed';

  @override
  String get customerHomeStatusArrived => 'Arrived at pickup';

  @override
  String get customerHomeStatusArrivedMerchant => 'Driver at merchant';

  @override
  String get customerHomeStatusMatched => 'Driver matched';

  @override
  String get customerHomeStatusPickingUp => 'Picking up food';

  @override
  String get customerHomeStatusInTransit => 'Delivering';

  @override
  String get customerHomeStatusCompleted => 'Completed';

  @override
  String get customerHomeStatusCancelled => 'Cancelled';

  @override
  String get customerHomeAddressNotSpecified => 'Address not specified';

  @override
  String get customerHomeCurrentLocation => 'Current location';

  @override
  String get rideStatusTitle => 'Trip Status';

  @override
  String get rideStatusDriver => 'Driver';

  @override
  String rideStatusCannotCall(Object phone) {
    return 'Cannot call $phone';
  }

  @override
  String get rideStatusCannotOpenChat => 'Cannot open chat';

  @override
  String get rideStatusEnableLocation => 'Please enable Location Service';

  @override
  String get rideStatusAllowLocation => 'Please allow location access';

  @override
  String get rideStatusLocationDenied => 'Cannot access location';

  @override
  String get rideStatusLocationDeniedBody => 'Please enable location access in device settings';

  @override
  String get rideStatusOk => 'OK';

  @override
  String get rideStatusOpenSettings => 'Open settings';

  @override
  String rideStatusMerchantMarker(Object address) {
    return 'Merchant: $address';
  }

  @override
  String get rideStatusMerchantDefault => 'Restaurant';

  @override
  String rideStatusPickupMarker(Object address) {
    return 'Pickup: $address';
  }

  @override
  String get rideStatusPickupDefault => 'Pickup';

  @override
  String get rideStatusYourLocation => 'Your location';

  @override
  String rideStatusDestMarker(Object address) {
    return 'Destination: $address';
  }

  @override
  String get rideStatusDestDefault => 'Destination';

  @override
  String get rideStatusDriverInfo => 'Driver info';

  @override
  String get rideStatusMotorcycle => 'Motorcycle';

  @override
  String get rideStatusCall => 'Call';

  @override
  String get rideStatusChat => 'Chat';

  @override
  String get rideStatusFoodCost => 'Food cost';

  @override
  String get rideStatusDeliveryFee => 'Delivery fee';

  @override
  String get rideStatusCouponDiscount => 'Coupon discount';

  @override
  String rideStatusCouponDiscountWithCode(Object code) {
    return 'Coupon ($code)';
  }

  @override
  String get rideStatusDistance => 'Distance';

  @override
  String rideStatusDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String get rideStatusGrandTotal => 'Grand total';

  @override
  String get rideStatusServiceFee => 'Service fee';

  @override
  String get rideStatusTripCompleted => 'Trip completed';

  @override
  String get rideStatusCancelTrip => 'Cancel trip';

  @override
  String get rideStatusAccepted => 'Driver accepted';

  @override
  String get rideStatusDriverGoingPickup => 'Driver going to pick up food';

  @override
  String get rideStatusArrivedPickup => 'Driver arrived at pickup';

  @override
  String get rideStatusArrivedMerchant => 'Driver at merchant';

  @override
  String get rideStatusFoodReady => 'Food ready';

  @override
  String get rideStatusPickedUp => 'Driver picked up food';

  @override
  String get rideStatusInTransit => 'On the way';

  @override
  String get rideStatusCompleted => 'Trip completed';

  @override
  String get rideStatusPending => 'Pending';

  @override
  String get rideStatusDriverComing => 'Driver is coming';

  @override
  String get rideStatusDriverGoingFood => 'Driver going to pick up food';

  @override
  String get rideStatusDriverArrivedPickup => 'Driver arrived at pickup';

  @override
  String get rideStatusDriverAtMerchantWaiting => 'Driver at merchant, waiting for food';

  @override
  String get rideStatusFoodReadyDriverPickup => 'Food ready, driver picking up';

  @override
  String get rideStatusDriverPickedUpDelivering => 'Driver picked up, on the way';

  @override
  String get rideStatusNavigating => 'Navigating to destination';

  @override
  String get rideStatusDriverCompleted => 'Trip completed';

  @override
  String get rideStatusWaitingDriver => 'Waiting for driver';

  @override
  String get rideStatusMerchantRejected => 'Merchant declined order';

  @override
  String get rideStatusMerchantRejectedBody => 'Sorry, the merchant cannot accept your order at this time.\n\nPlease try ordering again or choose another restaurant.';

  @override
  String get rideStatusUnderstood => 'Understood';

  @override
  String get rideStatusDeliverySuccess => '🎉 Delivery successful!';

  @override
  String get rideStatusTripSuccess => '🎉 Trip completed!';

  @override
  String get rideStatusThankYou => 'Thank you for using our service';

  @override
  String get rideStatusOrderNumber => 'Order number';

  @override
  String get rideStatusTotalAmount => 'Total amount';

  @override
  String get rideStatusIncludingDelivery => 'Including delivery';

  @override
  String rideStatusUsedCouponWithCode(Object code, Object amount) {
    return 'Used coupon $code discount ฿$amount';
  }

  @override
  String rideStatusUsedCoupon(Object amount) {
    return 'Used coupon discount ฿$amount';
  }

  @override
  String get rideStatusCancelTripTitle => 'Cancel trip';

  @override
  String get rideStatusCancelConfirm => 'Do you want to cancel this trip?';

  @override
  String get rideStatusNo => 'No';

  @override
  String get rideStatusYes => 'Yes';

  @override
  String get rideStatusCancelSuccess => 'Trip cancelled successfully';

  @override
  String get rideStatusCancelFailed => 'Cancel failed';

  @override
  String rideStatusCancelError(Object error) {
    return 'Error cancelling: $error';
  }

  @override
  String get activityTitle => 'Activity History';

  @override
  String get activityPaymentCash => 'Cash';

  @override
  String get activityPaymentTransfer => 'Transfer';

  @override
  String get activityPaymentCard => 'Credit card';

  @override
  String get activityPaymentUnknown => 'Payment not specified';

  @override
  String get activityDatePickerHelp => 'Select date range';

  @override
  String get activityDatePickerConfirm => 'Confirm';

  @override
  String get activityDatePickerCancel => 'Cancel';

  @override
  String get activityFilterToday => 'Today';

  @override
  String get activityFilterLast7Days => 'Last 7 days';

  @override
  String get activityFilterLast7DaysShort => '7 days';

  @override
  String get activityFilterThisMonth => 'This month';

  @override
  String get activityFilterAll => 'All';

  @override
  String get activityFilterDateRange => 'Date range';

  @override
  String get activityTimeUnknown => 'Unknown';

  @override
  String activityTimeHoursAgo(Object hours) {
    return '$hours hours ago';
  }

  @override
  String activityTimeMinutesAgo(Object minutes) {
    return '$minutes minutes ago';
  }

  @override
  String get activityTimeJustNow => 'Just now';

  @override
  String get activityServiceRide => 'Ride';

  @override
  String get activityServiceFood => 'Food order';

  @override
  String get activityServiceParcel => 'Parcel';

  @override
  String get activityFilterByDate => 'Filter by date';

  @override
  String get activityOrderStats => 'Order statistics';

  @override
  String activityTimePeriod(Object period) {
    return 'Period: $period';
  }

  @override
  String get activityStatTotal => 'Total';

  @override
  String activityStatItems(Object count) {
    return '$count orders';
  }

  @override
  String get activityStatCompleted => 'Completed';

  @override
  String get activityStatCancelled => 'Cancelled';

  @override
  String get activityStatTotalSpent => 'Total spent';

  @override
  String get activityStatCouponSavings => 'Coupon savings';

  @override
  String get activityFilteredEmpty => 'No items in selected date range';

  @override
  String get activityFilteredEmptyHint => 'Try changing the date filter to see more order history';

  @override
  String get activityLoadFailed => 'Failed to load data';

  @override
  String get activityNoHistory => 'No history yet';

  @override
  String get activityNoHistoryHint => 'Your booking history will appear here';

  @override
  String activityBookingCode(Object code) {
    return 'Code $code';
  }

  @override
  String activityDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String activityScheduledService(Object datetime) {
    return 'Scheduled service: $datetime';
  }

  @override
  String activityScheduledOrder(Object datetime) {
    return 'Scheduled order: $datetime';
  }

  @override
  String get activityAmountPaid => 'Amount paid';

  @override
  String get activityViewDetails => 'View details';

  @override
  String get activityStatusCompleted => 'Completed';

  @override
  String get activityStatusCancelled => 'Cancelled';

  @override
  String get activityStatusConfirmed => 'Confirmed';

  @override
  String get activityStatusDriverAccepted => 'Driver accepted';

  @override
  String get activityStatusInTransit => 'Delivering';

  @override
  String get activityStatusPreparing => 'Preparing food';

  @override
  String get activityStatusReadyPickup => 'Food ready';

  @override
  String get activityStatusArrived => 'Arrived';

  @override
  String get activityStatusPending => 'Pending';

  @override
  String get activityAddressNotSpecified => 'Not specified';

  @override
  String get activityAddressFallback => 'Destination address';

  @override
  String activityUsedCouponWithCode(Object code, Object amount) {
    return 'Used coupon $code discount ฿$amount';
  }

  @override
  String activityUsedCoupon(Object amount) {
    return 'Used coupon discount ฿$amount';
  }

  @override
  String get parcelTitle => 'Send Parcel';

  @override
  String get parcelHeaderTitle => 'Parcel Delivery';

  @override
  String get parcelHeaderSubtitle => 'Fast and safe delivery to your door';

  @override
  String get parcelSizeSmall => 'Small (S)';

  @override
  String get parcelSizeSmallDesc => 'Envelopes, documents';

  @override
  String get parcelSizeMedium => 'Medium (M)';

  @override
  String get parcelSizeMediumDesc => 'Parcel box up to 5 kg';

  @override
  String get parcelSizeLarge => 'Large (L)';

  @override
  String get parcelSizeLargeDesc => 'Large box up to 15 kg';

  @override
  String get parcelSizeXLarge => 'Extra (XL)';

  @override
  String get parcelSizeXLargeDesc => 'Large items up to 30 kg';

  @override
  String parcelPickupCoord(Object lat, Object lng) {
    return 'Pickup ($lat, $lng)';
  }

  @override
  String parcelDropoffCoord(Object lat, Object lng) {
    return 'Drop-off ($lat, $lng)';
  }

  @override
  String parcelCurrentLocation(Object lat, Object lng) {
    return 'Current location ($lat, $lng)';
  }

  @override
  String get parcelErrorNoLocation => 'Please wait for location\nor enable GPS and try again';

  @override
  String parcelErrorNoDrivers(Object radius) {
    return 'No online drivers found within $radius km\nPlease try again later';
  }

  @override
  String get parcelErrorCreateBooking => 'Cannot create booking';

  @override
  String get parcelErrorBookFailed => 'Cannot book parcel delivery\nPlease try again';

  @override
  String get parcelErrorTitle => 'Error occurred';

  @override
  String get parcelOk => 'OK';

  @override
  String parcelDriversFound(Object count, Object radius) {
    return 'Found $count online drivers near you (within $radius km)';
  }

  @override
  String parcelNoDriversNearby(Object radius) {
    return 'No online drivers found within $radius km';
  }

  @override
  String get parcelSenderInfo => 'Sender info';

  @override
  String get parcelSenderName => 'Sender name';

  @override
  String get parcelSenderNameRequired => 'Please specify sender name';

  @override
  String get parcelSenderPhone => 'Sender phone';

  @override
  String get parcelSenderPhoneRequired => 'Please specify sender phone';

  @override
  String get parcelPickupAddress => 'Pickup address';

  @override
  String get parcelPickupRequired => 'Please specify pickup location';

  @override
  String get parcelPinPickup => 'Pin pickup on map';

  @override
  String parcelPickupCoords(Object lat, Object lng) {
    return 'Pickup coordinates: $lat, $lng';
  }

  @override
  String get parcelRecipientInfo => 'Recipient info';

  @override
  String get parcelSavedAddresses => 'Saved addresses';

  @override
  String get parcelPinDropoff => 'Pin drop-off on map';

  @override
  String get parcelRecipientName => 'Recipient name';

  @override
  String get parcelRecipientNameRequired => 'Please specify recipient name';

  @override
  String get parcelRecipientPhone => 'Recipient phone';

  @override
  String get parcelRecipientPhoneRequired => 'Please specify recipient phone';

  @override
  String get parcelDropoffAddress => 'Drop-off address';

  @override
  String get parcelDropoffRequired => 'Please specify drop-off location';

  @override
  String parcelEstimatedDistance(Object km) {
    return 'Estimated distance: $km km';
  }

  @override
  String parcelDropoffCoords(Object lat, Object lng) {
    return 'Drop-off coordinates: $lat, $lng';
  }

  @override
  String get parcelSizeTitle => 'Parcel size';

  @override
  String get parcelDetailsTitle => 'Parcel details';

  @override
  String get parcelDescriptionLabel => 'Describe items (e.g. documents, food, clothes)';

  @override
  String get parcelDescriptionRequired => 'Please describe items';

  @override
  String get parcelWeightLabel => 'Estimated weight (kg) - optional';

  @override
  String get parcelPhotoTitle => 'Parcel photo';

  @override
  String get parcelPhotoHint => 'Take a photo of the parcel for the driver (optional)';

  @override
  String get parcelPhotoTap => 'Tap to take or select photo';

  @override
  String get parcelEstimatedFee => 'Estimated service fee';

  @override
  String parcelDistanceKm(Object km) {
    return 'Distance $km km';
  }

  @override
  String get parcelBookButton => 'Book Parcel Delivery';

  @override
  String get waitingSearchingDriver => 'Searching for driver...';

  @override
  String get waitingPriceUpdated => 'Price updated';

  @override
  String waitingPriceAdjustedBody(Object oldPrice, Object newPrice) {
    return 'The price has been adjusted because the driver who accepted is beyond the set distance\n\nOriginal price: ฿$oldPrice\nNew price: ฿$newPrice\n\nDo you want to continue?';
  }

  @override
  String get waitingCancelJob => 'Cancel job';

  @override
  String get waitingContinue => 'Continue';

  @override
  String get waitingConnectionError => 'Connection error, retrying...';

  @override
  String get waitingConnectionFailed => 'Connection failed';

  @override
  String waitingCannotConnect(Object error) {
    return 'Cannot connect to server: $error';
  }

  @override
  String get waitingOk => 'OK';

  @override
  String get waitingDriverFallback => 'Driver';

  @override
  String get waitingMotorcycleFallback => 'Motorcycle';

  @override
  String get waitingMerchantRejected => 'Merchant rejected order';

  @override
  String get waitingMerchantRejectedBody => 'Sorry, the merchant cannot accept your order at this time.\n\nPlease try ordering again or choose another restaurant.';

  @override
  String get waitingUnderstood => 'Understood';

  @override
  String get waitingForMerchant => 'Waiting for merchant';

  @override
  String get waitingSearchingForDriver => 'Searching for driver';

  @override
  String get waitingMerchantConfirmed => 'Merchant confirmed order!';

  @override
  String get waitingDriverFound => 'Driver found!';

  @override
  String get waitingForMerchantDots => 'Waiting for merchant...';

  @override
  String get waitingSearchingDriverDots => 'Searching for driver...';

  @override
  String get waitingMerchantPreparing => 'Merchant is preparing your food';

  @override
  String get waitingDriverComing => 'Driver is on the way to you';

  @override
  String waitingEstimatedTime(Object minutes) {
    return 'Estimated time $minutes minutes';
  }

  @override
  String get waitingRestaurantPreparing => 'Restaurant preparing food';

  @override
  String get waitingPleaseWait => 'Please wait a moment...';

  @override
  String get waitingAssigned => 'Assigned';

  @override
  String get waitingContactDriver => 'Contact driver';

  @override
  String get waitingCancelBooking => 'Cancel booking';

  @override
  String get waitingPhoneCall => 'Phone call';

  @override
  String get waitingChatWithDriver => 'Chat with driver';

  @override
  String get waitingChatInApp => 'Send message in app';

  @override
  String get waitingClose => 'Close';

  @override
  String waitingCannotCall(Object phone) {
    return 'Cannot call $phone';
  }

  @override
  String get waitingCannotOpenChat => 'Cannot open chat';

  @override
  String get waitingCancelBookingTitle => 'Cancel booking';

  @override
  String get waitingCancelConfirm => 'Are you sure you want to cancel this booking?';

  @override
  String get waitingNo => 'No';

  @override
  String get waitingCancelFailed => 'Cancel failed';

  @override
  String waitingCancelError(Object error) {
    return 'Error cancelling: $error';
  }

  @override
  String get waitingCancel => 'Cancel';

  @override
  String get waitingBookingInfo => 'Booking info';

  @override
  String waitingOrderCode(Object code) {
    return 'Order code: $code';
  }

  @override
  String waitingType(Object type) {
    return 'Type: $type';
  }

  @override
  String waitingPrice(Object price) {
    return 'Price: ฿$price';
  }

  @override
  String waitingStatus(Object status) {
    return 'Status: $status';
  }

  @override
  String get restCategoryOther => 'Others';

  @override
  String get restDeliveryTime => '20-30 min';

  @override
  String get restDeliveryFee => 'Delivery ฿15';

  @override
  String restCouponCopied(Object code) {
    return 'Copied code $code';
  }

  @override
  String get restCouponHint => 'Tap to copy code for checkout';

  @override
  String get restNoMenu => 'No menu available at this time';

  @override
  String get restRefresh => 'Refresh';

  @override
  String get restCannotLoadMenu => 'Cannot load menu';

  @override
  String get restTryAgain => 'Please try again';

  @override
  String get restRetry => 'Try again';

  @override
  String get restSwitchRestaurant => 'Switch restaurant?';

  @override
  String restSwitchRestaurantBody(Object name) {
    return 'Cart has food from \"$name\"\nClear cart and order from this restaurant instead?';
  }

  @override
  String get restCancel => 'Cancel';

  @override
  String get restClearAndAdd => 'Clear and add';

  @override
  String restAddedToCart(Object name) {
    return 'Added $name to cart';
  }

  @override
  String get restViewCart => 'View cart';

  @override
  String get restYourCart => 'Your cart';

  @override
  String get restClear => 'Clear';

  @override
  String get restTotal => 'Total';

  @override
  String restGoToCheckout(Object amount) {
    return 'Go to checkout — ฿$amount';
  }

  @override
  String get restItemNoName => 'Unnamed';

  @override
  String get restMustSelectOption => 'Must select option';

  @override
  String get ratingPleaseRateDriver => 'Please rate the driver';

  @override
  String get ratingPleaseRateMerchant => 'Please rate the merchant';

  @override
  String get ratingUserNotFound => 'User not found';

  @override
  String ratingError(Object error) {
    return 'Error: $error';
  }

  @override
  String get ratingThankYou => 'Thank you for rating!';

  @override
  String get ratingFeedbackHelps => 'Your feedback helps improve our service';

  @override
  String get ratingTitle => 'Rate';

  @override
  String get ratingRateDriver => 'Rate driver';

  @override
  String get ratingDriverHint => 'Comment about the driver (optional)';

  @override
  String get ratingRateMerchant => 'Rate merchant';

  @override
  String get ratingMerchantHint => 'Comment about the merchant (optional)';

  @override
  String get ratingSubmit => 'Submit rating';

  @override
  String get ratingSkip => 'Skip for now';

  @override
  String get ratingServiceFood => 'Food order';

  @override
  String get ratingServiceRide => 'Ride';

  @override
  String get ratingServiceParcel => 'Parcel delivery';

  @override
  String get ratingLabel1 => 'Very bad';

  @override
  String get ratingLabel2 => 'Bad';

  @override
  String get ratingLabel3 => 'Average';

  @override
  String get ratingLabel4 => 'Good';

  @override
  String get ratingLabel5 => 'Excellent';

  @override
  String get cancelReasonWaitTooLong => 'Waited too long';

  @override
  String get cancelReasonChangedMind => 'Changed mind, no longer needed';

  @override
  String get cancelReasonWrongAddress => 'Wrong address';

  @override
  String get cancelReasonPriceTooHigh => 'Price too high';

  @override
  String get cancelReasonWrongOrder => 'Ordered wrong items';

  @override
  String get cancelReasonOther => 'Other reason';

  @override
  String get cancelSelectReason => 'Please select a cancellation reason';

  @override
  String get cancelConfirmTitle => 'Confirm cancellation';

  @override
  String get cancelConfirmBody => 'Are you sure you want to cancel this order?';

  @override
  String cancelReasonLabel(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get cancelKeep => 'Don\'t cancel';

  @override
  String get cancelConfirmBtn => 'Confirm cancel';

  @override
  String get cancelSuccess => 'Order cancelled successfully';

  @override
  String cancelError(Object error) {
    return 'Error: $error';
  }

  @override
  String get cancelServiceFood => 'Food order';

  @override
  String get cancelServiceRide => 'Ride';

  @override
  String get cancelServiceParcel => 'Parcel delivery';

  @override
  String get cancelServiceDefault => 'Order';

  @override
  String get cancelTitle => 'Cancel order';

  @override
  String get cancelReasonsTitle => 'Cancellation reason';

  @override
  String get cancelReasonsSubtitle => 'Please select a reason to help us improve';

  @override
  String get cancelOtherHint => 'Please specify reason...';

  @override
  String get cancelButton => 'Cancel order';

  @override
  String get addrLabelHome => 'Home';

  @override
  String get addrLabelWork => 'Work';

  @override
  String get addrLabelOther => 'Other';

  @override
  String get addrEditTitle => 'Edit address';

  @override
  String get addrAddTitle => 'Add new address';

  @override
  String get addrType => 'Type';

  @override
  String get addrPlaceName => 'Place name';

  @override
  String get addrPlaceNameHint => 'e.g. Parents\' house, Condo';

  @override
  String get addrPinPlaced => 'Pin placed';

  @override
  String get addrPinOnMap => 'Pin on map';

  @override
  String get addrAddressLabel => 'Address (additional details)';

  @override
  String get addrAddressHint => 'e.g. 123/4 Main Street';

  @override
  String get addrNoteLabel => 'Note (optional)';

  @override
  String get addrNoteHint => 'e.g. Building A, Floor 5, Room 501';

  @override
  String get addrCancel => 'Cancel';

  @override
  String get addrValidation => 'Please enter place name and pin on map';

  @override
  String get addrSave => 'Save';

  @override
  String get addrDeleteTitle => 'Delete address';

  @override
  String addrDeleteConfirm(Object name) {
    return 'Do you want to delete \"$name\"?';
  }

  @override
  String get addrDelete => 'Delete';

  @override
  String get addrPickTitle => 'Choose address';

  @override
  String get addrBookTitle => 'Address book';

  @override
  String get addrAddButton => 'Add address';

  @override
  String get addrEmptyTitle => 'No saved addresses';

  @override
  String get addrEmptySubtitle => 'Add a \"Home\" or \"Work\" address\nfor easy selection without retyping';

  @override
  String addrQuickAdd(Object name) {
    return 'Add $name';
  }

  @override
  String get confirmServiceFood => 'Food order';

  @override
  String get confirmServiceRide => 'Ride';

  @override
  String get confirmServiceParcel => 'Parcel delivery';

  @override
  String get confirmSuccess => 'Booking successful!';

  @override
  String confirmOrderCode(Object code) {
    return 'Order $code';
  }

  @override
  String get confirmPickup => 'Pickup';

  @override
  String get confirmDestination => 'Destination';

  @override
  String get confirmNotSpecified => 'Not specified';

  @override
  String get confirmDistance => 'Distance';

  @override
  String confirmDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String get confirmOrderTime => 'Order time';

  @override
  String get confirmFoodCost => 'Food cost';

  @override
  String get confirmDeliveryFee => 'Delivery fee';

  @override
  String get confirmTotal => 'Total';

  @override
  String get confirmPayCash => 'Pay with cash';

  @override
  String get confirmCash => 'Cash';

  @override
  String get confirmTrackOrder => 'Track order';

  @override
  String get confirmBackToHome => 'Back to home';

  @override
  String foodDetAddedToCart(Object name) {
    return 'Added $name to cart';
  }

  @override
  String foodDetAddFailed(Object error) {
    return 'Failed to add to cart: $error';
  }

  @override
  String get foodDetAvailable => 'Available';

  @override
  String get foodDetSoldOut => 'Sold out';

  @override
  String get foodDetCustomize => 'Customize order';

  @override
  String get foodDetNoOptions => 'No additional options for this item';

  @override
  String get foodDetLoadingOptions => 'Loading options...';

  @override
  String get foodDetDescription => 'Description';

  @override
  String get foodDetRestaurant => 'Restaurant';

  @override
  String foodDetAddToCart(Object price) {
    return 'Add to cart — ฿$price';
  }

  @override
  String foodDefaultNote(Object merchant) {
    return 'Food order from $merchant';
  }

  @override
  String foodCouponNote(Object code, Object amount) {
    return '[Coupon: $code | Discount: ฿$amount]';
  }

  @override
  String get trackPickup => 'Pickup';

  @override
  String get trackDestination => 'Destination';

  @override
  String get trackNotSpecified => 'Not specified';

  @override
  String get trackDriverFallback => 'Driver';

  @override
  String get trackStatusPendingTitle => 'Waiting for driver';

  @override
  String get trackStatusPendingSub => 'Searching for a driver near you';

  @override
  String get trackStatusAcceptedTitle => 'Driver accepted';

  @override
  String get trackStatusAcceptedSub => 'Driver is on the way to you';

  @override
  String get trackStatusPickingUpTitle => 'Picking up';

  @override
  String get trackStatusPickingUpSub => 'Driver arrived at pickup';

  @override
  String get trackStatusPreparingTitle => 'Restaurant preparing';

  @override
  String get trackStatusPreparingSub => 'Restaurant is preparing your order';

  @override
  String get trackStatusInTransitTitle => 'Delivering';

  @override
  String get trackStatusInTransitSub => 'Driver is heading to destination';

  @override
  String get trackStatusArrivedTitle => 'Arrived at destination';

  @override
  String get trackStatusArrivedSub => 'Driver has arrived at the destination';

  @override
  String get trackStatusCompletedTitle => 'Delivered';

  @override
  String get trackStatusCompletedSub => 'Order completed';

  @override
  String get trackStatusCancelledTitle => 'Cancelled';

  @override
  String get trackStatusCancelledSub => 'This order has been cancelled';

  @override
  String get trackStatusUnknownTitle => 'Unknown status';

  @override
  String get trackTimelineCreated => 'Order created';

  @override
  String get trackTimelineAccepted => 'Driver accepted';

  @override
  String get trackTimelinePickingUp => 'Picking up';

  @override
  String get trackTimelineInTransit => 'Delivering';

  @override
  String get trackTimelineCompleted => 'Delivered';

  @override
  String get helpTitle => 'Help';

  @override
  String get helpCenterTitle => 'Help Center';

  @override
  String get helpCenterSubtitle => 'Available to help you 24 hours';

  @override
  String get helpContactTitle => 'Contact Channels';

  @override
  String get helpPhone => 'Phone';

  @override
  String get helpEmail => 'Email';

  @override
  String get helpFaqTitle => 'Frequently Asked Questions (FAQ)';

  @override
  String get helpReportProblem => 'Report Problem';

  @override
  String get helpFaq1Q => 'I ordered food but didn\'t receive it. What should I do?';

  @override
  String get helpFaq1A => 'Please check the order status on the \"Activity\" page. If the order shows delivered but you haven\'t received it, report the issue using the \"Report Problem\" button below. Our team will investigate within 24 hours.';

  @override
  String get helpFaq2Q => 'How do I cancel an order?';

  @override
  String get helpFaq2A => 'Go to \"Activity\" > select the order > press \"Cancel\". Note: You can only cancel orders that haven\'t been accepted by a driver yet.';

  @override
  String get helpFaq3Q => 'How is the delivery fee calculated?';

  @override
  String get helpFaq3A => 'The delivery fee is calculated based on the distance between the store/pickup point and your destination, with a minimum fee and per-kilometer rate set by the system.';

  @override
  String get helpFaq4Q => 'What payment methods are available?';

  @override
  String get helpFaq4A => 'Currently we support cash, PromptPay, and Mobile Banking. Our team is developing additional payment methods.';

  @override
  String get helpFaq5Q => 'The food I received is incorrect. What should I do?';

  @override
  String get helpFaq5A => 'Please report the issue using the \"Report Problem\" button with photos and details. Our team will coordinate with the restaurant to resolve it.';

  @override
  String get helpFaq6Q => 'How do I become a driver?';

  @override
  String get helpFaq6A => 'Register through the app by selecting the \"Driver\" role, then fill in your personal information, driver\'s license, and wait for admin approval.';

  @override
  String get payTitle => 'Payment';

  @override
  String get payCash => 'Cash';

  @override
  String get payCashSubtitle => 'Pay cash to driver';

  @override
  String get payPromptPaySubtitle => 'Transfer via QR Code';

  @override
  String get payMobileBankingSubtitle => 'Transfer via banking app';

  @override
  String payError(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get paySuccess => 'Payment successful!';

  @override
  String get payCashPrepare => 'Please prepare cash for the driver';

  @override
  String get payRecorded => 'Payment has been recorded';

  @override
  String get payOk => 'OK';

  @override
  String get paySelectMethod => 'Select payment method';

  @override
  String get payPromptPayNote => 'The system will automatically generate a QR Code for PromptPay transfer';

  @override
  String payButton(Object amount) {
    return 'Pay ฿$amount';
  }

  @override
  String get payTotalAmount => 'Total amount';

  @override
  String get payFoodCost => 'Food cost';

  @override
  String get payDeliveryFee => 'Delivery fee';

  @override
  String get ticketTitle => 'Report / Complaint';

  @override
  String get ticketCatLostItem => 'Lost item';

  @override
  String get ticketCatWrongOrder => 'Wrong food/item';

  @override
  String get ticketCatRudeDriver => 'Rude driver';

  @override
  String get ticketCatRefund => 'Request refund';

  @override
  String get ticketCatAppBug => 'App issue';

  @override
  String get ticketCatOther => 'Other';

  @override
  String get ticketCreateTitle => 'Report Problem';

  @override
  String get ticketCategoryLabel => 'Problem type';

  @override
  String get ticketSubjectLabel => 'Subject';

  @override
  String get ticketSubjectHint => 'e.g. Left item in car';

  @override
  String get ticketDescLabel => 'Description';

  @override
  String get ticketDescHint => 'Describe the problem in detail...';

  @override
  String get ticketValidation => 'Please fill in all fields';

  @override
  String get ticketSubmit => 'Submit report';

  @override
  String get ticketFab => 'Report';

  @override
  String get ticketEmptyTitle => 'No reports yet';

  @override
  String get ticketEmptySubtitle => 'If you encounter a problem, press \"Report\" below';

  @override
  String get mapPickerTitle => 'Select delivery location';

  @override
  String get mapPickerLoadingAddress => 'Loading address...';

  @override
  String get mapPickerSearching => 'Searching for address...';

  @override
  String get mapPickerDeliveryLocation => 'Delivery location';

  @override
  String get mapPickerConfirm => 'Confirm this location';

  @override
  String mapPickerPosition(Object lat, Object lng) {
    return 'Position: $lat, $lng';
  }

  @override
  String get foodSvcTitle => 'Order Food';

  @override
  String foodSvcLoadError(Object error) {
    return 'Unable to load restaurants: $error';
  }

  @override
  String get foodSvcRetry => 'Retry';

  @override
  String get foodSvcEmpty => 'No restaurants are currently open';

  @override
  String get foodSvcRefresh => 'Refresh';

  @override
  String get foodSvcRestaurantFallback => 'Restaurant';

  @override
  String get foodSvcNotSpecified => 'Not specified';

  @override
  String get foodSvcOpen => 'Open';

  @override
  String get accountEditName => 'Edit Name';

  @override
  String get accountEditPhone => 'Edit Phone';

  @override
  String get accountEditNameHint => 'Enter full name';

  @override
  String get accountEditPhoneHint => 'Enter phone number';

  @override
  String get accountEditCancel => 'Cancel';

  @override
  String get accountEditSave => 'Save';

  @override
  String get accountEditSuccess => 'Updated successfully!';

  @override
  String accountEditError(Object error) {
    return 'Update failed: $error';
  }

  @override
  String get accountUserFallback => 'User';

  @override
  String get couponScreenTitle => 'My Coupons';

  @override
  String get couponTabMine => 'My Coupons';

  @override
  String get couponTabDiscover => 'Discover More';

  @override
  String get couponTabHistory => 'Usage History';

  @override
  String get couponEmptyWallet => 'No coupons in wallet';

  @override
  String get couponEmptyDiscover => 'No new coupons available right now';

  @override
  String get couponEmptyHistory => 'No coupon usage history yet';

  @override
  String get couponClaimSuccess => 'Coupon claimed successfully!';

  @override
  String couponRemainingUses(Object count) {
    return '$count uses remaining';
  }

  @override
  String couponExpiry(Object date) {
    return 'Expires: $date';
  }

  @override
  String get couponClaimed => 'Claimed';

  @override
  String get couponClaim => 'Claim';

  @override
  String couponHistoryCode(Object code, Object time) {
    return 'Code: $code\nTime: $time';
  }

  @override
  String get referralTitle => 'Invite Friends & Get Rewards';

  @override
  String get referralHeroTitle => 'Invite friends to use the app\nBoth get coupons!';

  @override
  String get referralHeroSubtitle => 'Get a ฿20 discount coupon instantly\nwhen your friend completes their first order';

  @override
  String get referralMyCodeLabel => 'Your referral code';

  @override
  String get referralShareButton => 'Share with friends';

  @override
  String get referralHaveCode => 'Have a referral code?';

  @override
  String get referralEnterCodeHint => 'Enter the code from your friend to get a welcome coupon';

  @override
  String get referralCodePlaceholder => 'Enter code here';

  @override
  String get referralUseCode => 'Use Code';

  @override
  String get referralCopied => 'Referral code copied';

  @override
  String get referralCodeSuccess => 'Code used successfully!';

  @override
  String get referralOk => 'OK';

  @override
  String get referralSuccessful => 'Successful referrals';

  @override
  String get referralHowTitle => 'How does it work?';

  @override
  String get referralStep1Title => 'Share code with friends';

  @override
  String get referralStep1Desc => 'Send your code to friends who haven\'t used the app yet';

  @override
  String get referralStep2Title => 'Friend places first order';

  @override
  String get referralStep2Desc => 'Friend registers and completes their first food order';

  @override
  String get referralStep3Title => 'Get discount coupon!';

  @override
  String get referralStep3Desc => 'You\'ll get a discount coupon sent directly to your wallet';

  @override
  String get driverAssignedTitle => 'Driver Accepted';

  @override
  String get driverAssignedHeading => 'Driver accepted the job!';

  @override
  String get driverAssignedSubtitle => 'The driver is on the way to you';

  @override
  String get driverAssignedOnTheWay => 'Driver is on the way';

  @override
  String get driverAssignedEta => 'Estimated time: 5-10 minutes';

  @override
  String get driverAssignedContact => 'Contact Driver';

  @override
  String get driverAssignedCancelBooking => 'Cancel Booking';

  @override
  String get driverAssignedContactTitle => 'Contact Driver';

  @override
  String get driverAssignedPhone => 'Phone';

  @override
  String get driverAssignedMessage => 'Message';

  @override
  String get driverAssignedMessageSub => 'Send a message to the driver';

  @override
  String get driverAssignedClose => 'Close';

  @override
  String get driverAssignedCancelTitle => 'Cancel Booking';

  @override
  String get driverAssignedCancelBody => 'Are you sure you want to cancel this booking?';

  @override
  String get driverAssignedNo => 'No';

  @override
  String get driverAssignedCancel => 'Cancel';

  @override
  String get mapSvcRide => 'Call Ride';

  @override
  String get mapSvcFood => 'Order Food';

  @override
  String get mapSvcParcel => 'Send Parcel';

  @override
  String get mapSelectService => 'Select Service';

  @override
  String get mapFindingLocation => 'Finding location...';

  @override
  String get mapUserFallback => 'User';

  @override
  String get mapLogout => 'Logout';

  @override
  String get mapLocServiceTitle => 'Location Service';

  @override
  String get mapLocServiceBody => 'Location service is disabled. Please enable it.';

  @override
  String get mapLocOpenSettings => 'Open Settings';

  @override
  String get mapLocCancel => 'Cancel';

  @override
  String get mapLocPermTitle => 'Location Permission';

  @override
  String get mapLocPermDenied => 'Location permission was denied. Please allow location access to use the map.';

  @override
  String get mapLocRetry => 'Retry';

  @override
  String get mapLocPermForever => 'Location permission was permanently denied. Please open app settings to allow permission.';

  @override
  String get mapLocErrorTitle => 'Location Error';

  @override
  String mapLocErrorBody(Object error) {
    return 'Unable to get location: $error';
  }

  @override
  String get mapLocOk => 'OK';

  @override
  String mapLogoutError(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get rideTitle => 'Call Ride';

  @override
  String get rideMotorcycle => 'Motorcycle';

  @override
  String get rideCar => 'Car';

  @override
  String get rideMotorcycleDesc => 'Fast & affordable';

  @override
  String get rideCarDesc => 'Comfortable';

  @override
  String get rideSelectPayment => 'Select payment method';

  @override
  String get rideCash => 'Cash';

  @override
  String get rideTransfer => 'Bank Transfer';

  @override
  String get rideSelectDestination => 'Please select a destination';

  @override
  String get rideSelectVehicle => 'Please select a vehicle type first';

  @override
  String get ridePleaseLogin => 'Please log in';

  @override
  String get rideSearchingDriver => 'Searching for a driver...';

  @override
  String rideError(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get rideCurrentLocation => 'Current location';

  @override
  String get rideFindingLocation => 'Finding location...';

  @override
  String get rideDestHint => 'Where to? Tap map to select';

  @override
  String rideOnlineCount(Object count) {
    return '$count online';
  }

  @override
  String get rideNoDrivers => 'No drivers';

  @override
  String rideNoVehicleOnline(Object vehicle) {
    return 'No $vehicle online right now';
  }

  @override
  String rideDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String get rideBtnSelectDest => 'Select destination';

  @override
  String get rideBtnSelectVehicle => 'Please select vehicle type';

  @override
  String rideBtnCallRide(Object price) {
    return 'Call Ride — ฿$price';
  }

  @override
  String rideNoteVehicleType(Object name) {
    return 'Vehicle type: $name';
  }

  @override
  String rideNotePickupSurcharge(Object km, Object surcharge) {
    return 'Extra driver→pickup $km km (+฿$surcharge)';
  }

  @override
  String get ridePickupAddress => 'Current location';

  @override
  String get rideNotifTitle => '🚗 New job! Passenger ride';

  @override
  String rideNotifBody(Object pickup, Object destination, Object price) {
    return 'Ride request from $pickup to $destination — ฿$price';
  }

  @override
  String get rideNotifPickupFallback => 'Origin';

  @override
  String get rideNotifDestFallback => 'Destination';

  @override
  String get drvProfileEditName => 'Edit Name';

  @override
  String get drvProfileEditPhone => 'Edit Phone';

  @override
  String get drvProfileEditPlate => 'Edit License Plate';

  @override
  String get drvProfileHintName => 'Full name';

  @override
  String get drvProfileHintPhone => 'Phone number';

  @override
  String get drvProfileHintPlate => 'e.g. ABC 1234';

  @override
  String get drvProfileCancel => 'Cancel';

  @override
  String get drvProfileSave => 'Save';

  @override
  String get drvProfileUpdateSuccess => 'Updated successfully!';

  @override
  String drvProfileUpdateError(Object error) {
    return 'Update failed: $error';
  }

  @override
  String get drvProfileSelectVehicle => 'Select vehicle type';

  @override
  String get drvProfileMotorcycle => 'Motorcycle';

  @override
  String get drvProfileCar => 'Car';

  @override
  String get earnTitle => 'Earnings';

  @override
  String get earnWalletTooltip => 'Wallet';

  @override
  String get earnRefresh => 'Refresh';

  @override
  String get earnLoadError => 'Unable to load data';

  @override
  String get earnRetry => 'Retry';

  @override
  String get earnPeriodToday => 'Today';

  @override
  String get earnPeriodWeek => 'This Week';

  @override
  String get earnPeriodMonth => 'This Month';

  @override
  String get earnPeriodAll => 'All Time';

  @override
  String get earnPeriodCustom => 'Custom Date';

  @override
  String earnRevenueLabel(Object period) {
    return 'Earnings $period';
  }

  @override
  String earnAvgPerJob(Object amount) {
    return 'Average $amount / job';
  }

  @override
  String get earnTotalJobs => 'Total Jobs';

  @override
  String get earnCompleted => 'Completed';

  @override
  String get earnCancelled => 'Cancelled';

  @override
  String get earnWalletTitle => 'Wallet';

  @override
  String get earnWalletLoading => 'Loading...';

  @override
  String earnWalletBaht(Object amount) {
    return '$amount THB';
  }

  @override
  String get earnViewAll => 'View All';

  @override
  String get earnJobHistory => 'Job History';

  @override
  String get earnNoJobs => 'No jobs in this period';

  @override
  String get earnStatusCompleted => 'Completed';

  @override
  String get earnStatusCancelled => 'Cancelled';

  @override
  String get earnStatusPickedUp => 'Picked Up';

  @override
  String get earnStatusDelivering => 'Delivering';

  @override
  String get earnSvcRide => 'Ride';

  @override
  String get earnSvcFood => 'Food';

  @override
  String get earnSvcParcel => 'Parcel';

  @override
  String get earnSvcOther => 'Other';

  @override
  String earnAppFee(Object amount) {
    return '(Platform fee $amount)';
  }

  @override
  String get earnCollectCustomer => 'Collect from customer';

  @override
  String get earnCouponDiscount => 'Coupon discount';

  @override
  String get earnOpenDetailError => 'Unable to open job detail';

  @override
  String get earnUserNotFound => 'User not found';

  @override
  String get jobDetailTitle => 'Service Detail';

  @override
  String get jobDetailNoRoute => 'No route data';

  @override
  String get jobDetailPickupFallback => 'Pickup';

  @override
  String get jobDetailDestFallback => 'Destination';

  @override
  String jobDetailDurationHrMin(Object hr, Object min) {
    return '$hr hr $min min';
  }

  @override
  String jobDetailDurationMin(Object min) {
    return '$min min';
  }

  @override
  String get jobDetailCash => 'Cash';

  @override
  String get jobDetailOrderFood => 'Food Order';

  @override
  String get jobDetailRide => 'Ride';

  @override
  String get jobDetailParcel => 'Parcel';

  @override
  String get jobDetailNetEarnings => 'Net Earnings';

  @override
  String get jobDetailEarningsBreakdown => 'Earnings Breakdown';

  @override
  String get jobDetailTripFare => 'Trip fare';

  @override
  String get jobDetailCouponDiscountGeneric => 'Coupon discount';

  @override
  String jobDetailCouponDiscountCode(Object code) {
    return 'Coupon discount ($code)';
  }

  @override
  String get jobDetailPlatformFee => 'Platform fee';

  @override
  String get jobDetailFoodCost => '  Food cost';

  @override
  String get jobDetailDeliveryFee => '  Delivery fee';

  @override
  String get jobDetailCashCollection => 'Cash payment items';

  @override
  String get jobDetailCollectFromCustomer => 'Collect from customer';

  @override
  String get parcelConfirmPickupTitle => 'Confirm Pickup';

  @override
  String get parcelConfirmDeliveryTitle => 'Confirm Delivery';

  @override
  String get parcelConfirmPhotoRequired => 'Please take a confirmation photo';

  @override
  String get parcelConfirmSignatureRequired => 'Please take a recipient signature photo';

  @override
  String get parcelConfirmUploadFailed => 'Photo upload failed';

  @override
  String get parcelConfirmUpdateFailed => 'Status update failed';

  @override
  String get parcelConfirmPickupSuccess => 'Parcel picked up!';

  @override
  String get parcelConfirmPickupSuccessBody => 'Photo saved successfully\nPlease deliver the parcel';

  @override
  String get parcelConfirmDeliverySuccess => 'Parcel delivered!';

  @override
  String get parcelConfirmDeliverySuccessBody => 'Photo and signature saved\nJob completed';

  @override
  String get parcelConfirmError => 'An error occurred\nPlease try again';

  @override
  String get parcelConfirmErrorTitle => 'Error';

  @override
  String get parcelConfirmOk => 'OK';

  @override
  String get parcelConfirmNoData => 'Parcel data not found';

  @override
  String get parcelConfirmParcelInfo => 'Parcel Info';

  @override
  String get parcelConfirmSender => 'Sender';

  @override
  String get parcelConfirmRecipient => 'Recipient';

  @override
  String get parcelConfirmSize => 'Size';

  @override
  String get parcelConfirmDescription => 'Description';

  @override
  String get parcelConfirmWeightKg => 'Weight';

  @override
  String parcelConfirmWeightValue(Object kg) {
    return '$kg kg';
  }

  @override
  String get parcelConfirmStatus => 'Status';

  @override
  String get parcelConfirmCustomerPhoto => 'Customer parcel photo';

  @override
  String get parcelConfirmPickupPhotoTitle => 'Take pickup confirmation photo *';

  @override
  String get parcelConfirmDeliveryPhotoTitle => 'Take delivery confirmation photo *';

  @override
  String get parcelConfirmPickupPhotoDesc => 'Take a photo of the parcel received';

  @override
  String get parcelConfirmDeliveryPhotoDesc => 'Take a photo of the parcel delivered';

  @override
  String get parcelConfirmSignatureTitle => 'Take recipient signature photo *';

  @override
  String get parcelConfirmSignatureDesc => 'Take a photo of recipient signature or ID';

  @override
  String get parcelConfirmTapToPhoto => 'Tap to take photo';

  @override
  String get parcelConfirmPickupBtn => 'Confirm Pickup';

  @override
  String get parcelConfirmDeliveryBtn => 'Confirm Delivery Complete';

  @override
  String get merchantNavOrders => 'Orders';

  @override
  String get merchantNavMenu => 'Menu';

  @override
  String get merchantNavReport => 'Report';

  @override
  String get merchantNavAccount => 'Account';

  @override
  String get merchantPressBackAgain => 'Press back again to exit';

  @override
  String get mchSetShopInfoTitle => 'Shop Information';

  @override
  String get mchSetShopName => 'Shop Name';

  @override
  String get mchSetPhone => 'Phone';

  @override
  String get mchSetEmail => 'Email';

  @override
  String get mchSetAddress => 'Shop Address';

  @override
  String get mchSetShopStatus => 'Shop Status';

  @override
  String get mchSetShopOpen => 'Accepting Orders';

  @override
  String get mchSetShopClosed => 'Shop Closed';

  @override
  String get mchSetOpenCloseTime => 'Open-Close Time';

  @override
  String get mchSetOpenDays => 'Open Days';

  @override
  String get mchSetOrderAcceptMode => 'Order Accept Mode';

  @override
  String get mchSetAutoSchedule => 'Auto Open-Close';

  @override
  String get mchSetAutoScheduleOn => 'Enabled';

  @override
  String get mchSetAutoScheduleOff => 'Disabled';

  @override
  String get mchSetNotSet => 'Not set';

  @override
  String get mchSetEveryDay => 'Every day';

  @override
  String get mchSetAcceptAuto => 'Auto accept orders';

  @override
  String get mchSetAcceptManual => 'Manual accept orders';

  @override
  String mchSetEditField(Object label) {
    return 'Edit $label';
  }

  @override
  String get mchSetHintShopName => 'Shop name';

  @override
  String get mchSetHintPhone => 'Phone number';

  @override
  String get mchSetCancel => 'Cancel';

  @override
  String get mchSetSave => 'Save';

  @override
  String get mchSetEditShopHoursTitle => 'Set Shop Hours';

  @override
  String get mchSetOpenTime => 'Open Time';

  @override
  String get mchSetCloseTime => 'Close Time';

  @override
  String get mchSetOpenDaysLabel => 'Open Days';

  @override
  String get mchSetOrderAcceptModeLabel => 'Order Accept Mode';

  @override
  String get mchSetAcceptManualShort => 'Manual';

  @override
  String get mchSetAcceptAutoShort => 'Auto';

  @override
  String get mchSetAutoScheduleSwitch => 'Auto open-close by schedule';

  @override
  String get mchSetAutoScheduleOnDesc => 'System will toggle shop status automatically';

  @override
  String get mchSetAutoScheduleOffDesc => 'Off — manual open/close only';

  @override
  String get mchSetSelectAtLeast1Day => 'Please select at least 1 open day';

  @override
  String mchSetShopHoursSaved(Object open, Object close, Object days) {
    return 'Shop hours set: $open - $close ($days)';
  }

  @override
  String mchSetSaveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get mchSetWeekMon => 'M';

  @override
  String get mchSetWeekTue => 'T';

  @override
  String get mchSetWeekWed => 'W';

  @override
  String get mchSetWeekThu => 'Th';

  @override
  String get mchSetWeekFri => 'F';

  @override
  String get mchSetWeekSat => 'Sa';

  @override
  String get mchSetWeekSun => 'Su';

  @override
  String get mchDashTitle => 'Sales Report';

  @override
  String get mchDashRefresh => 'Refresh';

  @override
  String get mchDashLoadError => 'Unable to load data';

  @override
  String get mchDashRetry => 'Retry';

  @override
  String get mchDashPeriodToday => 'Today';

  @override
  String get mchDashPeriodWeek => 'This Week';

  @override
  String get mchDashPeriodMonth => 'This Month';

  @override
  String get mchDashPeriodAll => 'All Time';

  @override
  String get mchDashPeriodCustom => 'Custom Date';

  @override
  String get mchDashPickDateRange => 'Select date range';

  @override
  String get mchDashClearDateFilter => 'Clear date filter';

  @override
  String mchDashNetRevenue(Object period) {
    return 'Net Revenue $period';
  }

  @override
  String mchDashAvgPerOrder(Object amount) {
    return 'Average $amount / order';
  }

  @override
  String get mchDashTotalOrders => 'Total Orders';

  @override
  String get mchDashCompleted => 'Completed';

  @override
  String get mchDashCancelled => 'Cancelled';

  @override
  String get mchDashOrderHistory => 'Order History';

  @override
  String get mchDashNoOrders => 'No orders in this period';

  @override
  String get mchDashViewDetail => 'View detail';

  @override
  String get mchDashStatusCompleted => 'Completed';

  @override
  String get mchDashStatusCancelled => 'Cancelled';

  @override
  String get mchDashStatusPreparing => 'Preparing';

  @override
  String get mchDashStatusReady => 'Ready';

  @override
  String get mchDashStatusPickedUp => 'Picked Up';

  @override
  String get mchDashStatusDelivering => 'Delivering';

  @override
  String get mchDashUserNotFound => 'User not found';

  @override
  String get menuMgmtTitle => 'Menu Management';

  @override
  String get menuMgmtOptionTooltip => 'Manage options';

  @override
  String get menuMgmtError => 'An error occurred';

  @override
  String get menuMgmtRetry => 'Retry';

  @override
  String get menuMgmtEmpty => 'No menu items yet';

  @override
  String get menuMgmtEmptyHint => 'Tap + to add your first menu item';

  @override
  String get menuMgmtNoName => 'Unnamed';

  @override
  String get menuMgmtAvailable => 'Available';

  @override
  String get menuMgmtSoldOut => 'Sold Out';

  @override
  String get menuMgmtEdit => 'Edit';

  @override
  String get menuMgmtDelete => 'Delete';

  @override
  String get menuMgmtDeleteConfirmTitle => 'Confirm Delete';

  @override
  String menuMgmtDeleteConfirmBody(Object name) {
    return 'Do you want to delete menu \"$name\"?';
  }

  @override
  String get menuMgmtNo => 'No';

  @override
  String get menuMgmtYes => 'Yes';

  @override
  String get menuMgmtDeleteSuccess => 'Menu deleted successfully';

  @override
  String get menuMgmtCannotDeleteTitle => 'Cannot delete menu';

  @override
  String get menuMgmtCannotDeleteBody => 'This menu has related orders and cannot be deleted.\n\nWould you like to hide it instead? (Change status to \"Sold Out\")';

  @override
  String get menuMgmtCancel => 'Cancel';

  @override
  String get menuMgmtHideMenu => 'Hide Menu';

  @override
  String get menuMgmtHideSuccess => 'Menu hidden (changed to \"Sold Out\")';

  @override
  String menuMgmtDeleteFailed(Object error) {
    return 'Cannot delete menu: $error';
  }

  @override
  String get menuMgmtToggleOn => 'Menu is now available';

  @override
  String get menuMgmtToggleOff => 'Menu is now unavailable';

  @override
  String menuMgmtToggleFailed(Object error) {
    return 'Status change failed: $error';
  }

  @override
  String get menuMgmtUserNotFound => 'User not found';

  @override
  String get menuEditTitleEdit => 'Edit Menu';

  @override
  String get menuEditTitleAdd => 'Add New Menu';

  @override
  String get menuEditBtnUpdate => 'Update Menu';

  @override
  String get menuEditBtnAdd => 'Add Menu';

  @override
  String get menuEditInfoTitle => 'Menu Info';

  @override
  String get menuEditNameLabel => 'Menu Name *';

  @override
  String get menuEditNameRequired => 'Please enter a menu name';

  @override
  String get menuEditDescLabel => 'Description';

  @override
  String get menuEditPriceLabel => 'Price *';

  @override
  String get menuEditPriceRequired => 'Please enter a price';

  @override
  String get menuEditPriceInvalid => 'Please enter a valid price';

  @override
  String get menuEditPhotoLabel => 'Menu Photo';

  @override
  String get menuEditTapToPhoto => 'Tap to take or select photo';

  @override
  String get menuEditCategoryLabel => 'Category *';

  @override
  String get menuEditCategoryRequired => 'Please select a category';

  @override
  String get menuEditAvailable => 'Available for sale';

  @override
  String get menuEditOptionGroupsTitle => 'Option Groups';

  @override
  String menuEditGroupCount(Object count) {
    return '$count groups';
  }

  @override
  String get menuEditNoOptionGroups => 'No option groups selected';

  @override
  String get menuEditNoOptionGroupsHint => 'Add option groups for customers to choose from';

  @override
  String get menuEditAddSuccess => 'Menu added successfully';

  @override
  String get menuEditUpdateSuccess => 'Menu updated successfully';

  @override
  String menuEditLoadOptionsFailed(Object error) {
    return 'Failed to load options: $error';
  }

  @override
  String menuEditDeleteGroupSuccess(Object name) {
    return 'Group \"$name\" deleted';
  }

  @override
  String menuEditDeleteGroupFailed(Object error) {
    return 'Failed to delete group: $error';
  }

  @override
  String get menuEditCatMadeToOrder => 'Made to Order';

  @override
  String get menuEditCatNoodles => 'Noodles';

  @override
  String get menuEditCatDrinks => 'Drinks';

  @override
  String get menuEditCatDessert => 'Dessert';

  @override
  String get menuEditCatFastFood => 'Fast Food';

  @override
  String get menuEditCatBreakfast => 'Breakfast';

  @override
  String get menuEditCatJapanese => 'Japanese';

  @override
  String get menuEditCatIsaan => 'Isaan';

  @override
  String get menuEditCatSnacks => 'Snacks';

  @override
  String get menuEditCatOther => 'Other';

  @override
  String get optGroupEditTitle => 'Edit Option Group';

  @override
  String get optGroupCreateTitle => 'Create Option Group';

  @override
  String get optGroupBtnUpdate => 'Update Option Group';

  @override
  String get optGroupBtnCreate => 'Create Option Group';

  @override
  String get optGroupInfoTitle => 'Option Group Info';

  @override
  String get optGroupNameLabel => 'Option Group Name';

  @override
  String get optGroupNameHint => 'e.g. Spice Level, Toppings';

  @override
  String get optGroupNameRequired => 'Please enter a group name';

  @override
  String get optGroupMinLabel => 'Min Selection';

  @override
  String get optGroupMinRequired => 'Please enter minimum';

  @override
  String get optGroupMinInvalid => 'Please enter a valid number';

  @override
  String get optGroupMaxLabel => 'Max Selection';

  @override
  String get optGroupMaxRequired => 'Please enter maximum';

  @override
  String get optGroupMaxInvalid => 'Please enter a valid number (at least 1)';

  @override
  String get optGroupSelectionHint => 'Hint: 0=optional, 1=must select 1 item';

  @override
  String get optGroupAddOptionTitle => 'Add Option';

  @override
  String get optGroupOptionNameLabel => 'Option Name';

  @override
  String get optGroupOptionNameHint => 'e.g. Not Spicy, Very Spicy';

  @override
  String get optGroupOptionPriceLabel => 'Extra Price';

  @override
  String get optGroupNoOptions => 'No options yet';

  @override
  String get optGroupNoOptionsHint => 'Add options for customers to choose from';

  @override
  String get optGroupAllOptionsTitle => 'All Options';

  @override
  String optGroupItemCount(Object count) {
    return '$count items';
  }

  @override
  String get optGroupOptionNameRequired => 'Please enter an option name';

  @override
  String get optGroupOptionPriceNegative => 'Price must not be negative';

  @override
  String get optGroupCreateSuccess => 'Option group created';

  @override
  String get optGroupUpdateSuccess => 'Option group updated';

  @override
  String get optGroupMinMaxError => 'Min must not be less than 0 and max must not be less than 1';

  @override
  String get optGroupMinGtMaxError => 'Min must not be greater than max';

  @override
  String get optGroupSaveError => 'Could not save option group';

  @override
  String get optLibTitle => 'Manage Food Options';

  @override
  String get optLibRetry => 'Retry';

  @override
  String get optLibEmpty => 'No option groups yet';

  @override
  String get optLibEmptyHint => 'Create option groups to use with your menu items';

  @override
  String get optLibCreateNew => 'Create New Group';

  @override
  String get optLibDeleteConfirmTitle => 'Confirm Delete';

  @override
  String optLibDeleteConfirmBody(Object name) {
    return 'Do you want to delete group \"$name\"?';
  }

  @override
  String optLibDeleteNote(Object count) {
    return 'Note: Deleting this group will also delete all $count options';
  }

  @override
  String get optLibCancel => 'Cancel';

  @override
  String get optLibDeleteBtn => 'Delete';

  @override
  String optLibDeleteSuccess(Object name) {
    return 'Group \"$name\" deleted';
  }

  @override
  String optLibDeleteFailed(Object error) {
    return 'Failed to delete group: $error';
  }

  @override
  String get optLibSelectMax1 => 'Select up to 1 item';

  @override
  String optLibSelectMaxN(Object max) {
    return 'Select up to $max items';
  }

  @override
  String optLibSelectExact(Object n) {
    return 'Select $n items';
  }

  @override
  String optLibSelectRange(Object min, Object max) {
    return 'Select $min-$max items';
  }

  @override
  String optLibOptionCount(Object count) {
    return '$count options';
  }

  @override
  String get optLibShowFirst3 => 'Showing first 3';

  @override
  String get menuEditAddOptionGroup => 'Add Option Group';

  @override
  String get menuEditSelectOptionGroups => 'Select Option Groups';

  @override
  String get menuEditSaveSelection => 'Save Selection';

  @override
  String get menuEditSheetRetry => 'Retry';

  @override
  String get menuEditSheetNoGroups => 'No option groups';

  @override
  String get menuEditSheetNoGroupsHint => 'Create option groups first to use with menus';

  @override
  String get menuEditRemoveGroupTooltip => 'Remove this group';

  @override
  String menuEditOptionCount(Object count) {
    return '$count options';
  }

  @override
  String get couponAdminDialogTitle => 'Create Shop Coupon (Admin)';

  @override
  String get couponCreateSuccess => 'Shop coupon created successfully';

  @override
  String get couponCreateFailed => 'Failed to create coupon';

  @override
  String couponAdminTitle(Object name) {
    return 'Shop Coupons: $name';
  }

  @override
  String get couponAdminTitleNoName => 'Shop Coupons: Unknown';

  @override
  String get couponTitle => 'Shop Coupons';

  @override
  String get couponListTitle => 'Shop Coupons';

  @override
  String get couponEmpty => 'No shop coupons yet';

  @override
  String get couponGuideTitle => 'How to use shop coupons';

  @override
  String get couponGuideStep1Admin => '1) Admin is managing coupons for the selected shop. Customers will see them on the shop page automatically.';

  @override
  String get couponGuideStep1Merchant => '1) Create coupons for your shop. Customers will see them on the shop page automatically.';

  @override
  String get couponGuideStep2Admin => '2) Press \"Open Coupon Form\" to edit via Dialog instead of inline form.';

  @override
  String get couponGuideStep2Merchant => '2) Fill in the form below to create new coupons instantly.';

  @override
  String get couponGuideStep3 => '3) Free delivery coupons will charge an additional 25% GP.';

  @override
  String get couponGuideStep4Admin => '4) Admin can enable/disable each coupon via the switch on the right.';

  @override
  String get couponGuideStep4Merchant => '4) You can enable/disable each coupon via the switch on the right.';

  @override
  String get couponAdminOpenForm => 'Open Coupon Form (Dialog)';

  @override
  String get couponCodeLabel => 'Coupon Code';

  @override
  String get couponCodeRequired => 'Enter coupon code';

  @override
  String get couponNameLabel => 'Coupon Name';

  @override
  String get couponNameRequired => 'Enter coupon name';

  @override
  String get couponDescLabel => 'Description (optional)';

  @override
  String get couponTypePercentage => 'Percentage Discount';

  @override
  String get couponTypeFixed => 'Fixed Amount Discount';

  @override
  String get couponTypeFreeDelivery => 'Free Delivery';

  @override
  String get couponTypeLabel => 'Coupon Type';

  @override
  String get couponDiscountPercent => 'Discount (%)';

  @override
  String get couponDiscountBaht => 'Discount (Baht)';

  @override
  String get couponDiscountRequired => 'Enter valid discount';

  @override
  String get couponMaxDiscount => 'Max Discount (Baht) optional';

  @override
  String get couponMinOrder => 'Min Order (Baht) optional';

  @override
  String get couponUsageLimit => 'Total uses (0=unlimited)';

  @override
  String get couponPerUserLimit => 'Limit/person';

  @override
  String couponStartDate(Object date) {
    return 'Start: $date';
  }

  @override
  String get couponPickStartDate => 'Select start date';

  @override
  String get couponPick => 'Pick';

  @override
  String couponEndDate(Object date) {
    return 'Expires: $date';
  }

  @override
  String get couponPickEndDate => 'Select expiry date';

  @override
  String get couponCreateBtn => 'Create Coupon';

  @override
  String get editProfileTitle => 'Edit Shop Info';

  @override
  String get editProfileTapPhoto => 'Tap to change shop photo';

  @override
  String get editProfileShopName => 'Shop Name';

  @override
  String get editProfileShopNameRequired => 'Please enter shop name';

  @override
  String get editProfileEmail => 'Email';

  @override
  String get editProfilePhone => 'Phone Number';

  @override
  String get editProfilePhoneInvalid => 'Please enter a valid phone number';

  @override
  String get editProfileAddress => 'Shop Address';

  @override
  String get editProfilePinLocation => 'Pin shop location';

  @override
  String get editProfileNoLocation => 'No location selected on map';

  @override
  String get editProfileOpenDays => 'Open Days';

  @override
  String get editProfileOpenTime => 'Open Time';

  @override
  String get editProfileCloseTime => 'Close Time';

  @override
  String get editProfileSelectDayRequired => 'Please select at least 1 open day';

  @override
  String get editProfileSaveBtn => 'Save';

  @override
  String get editProfileSaveSuccess => 'Saved successfully';

  @override
  String editProfileSaveFailed(Object error) {
    return 'Cannot save: $error';
  }

  @override
  String get editProfileDayMon => 'Mon';

  @override
  String get editProfileDayTue => 'Tue';

  @override
  String get editProfileDayWed => 'Wed';

  @override
  String get editProfileDayThu => 'Thu';

  @override
  String get editProfileDayFri => 'Fri';

  @override
  String get editProfileDaySat => 'Sat';

  @override
  String get editProfileDaySun => 'Sun';

  @override
  String get profileCompleteRoleDriver => 'Driver';

  @override
  String get profileCompleteRoleMerchant => 'Merchant';

  @override
  String profileCompleteTitle(Object role) {
    return 'Complete Profile ($role)';
  }

  @override
  String get profileCompleteLogout => 'Logout';

  @override
  String get profileCompleteBack => 'Back';

  @override
  String get profileCompleteNext => 'Next';

  @override
  String get profileCompleteSaveStart => 'Save & Start';

  @override
  String get profileCompleteSaveSuccess => '✅ Profile saved successfully';

  @override
  String profileCompleteError(Object error) {
    return '❌ Error: $error';
  }

  @override
  String profileCompleteUploadMissing(Object items) {
    return 'Please upload: $items';
  }

  @override
  String get profileCompleteStepPersonalTitle => 'Personal Info';

  @override
  String get profileCompleteStepPersonalSubtitle => 'Please enter your information';

  @override
  String get profileCompleteFullNameLabel => 'Full name';

  @override
  String get profileCompleteFullNameRequired => 'Please enter your name';

  @override
  String get profileCompletePhoneLabel => 'Phone number';

  @override
  String get profileCompletePhoneRequired => 'Please enter phone number';

  @override
  String get profileCompleteStepVehicleTitle => 'Vehicle Info';

  @override
  String get profileCompleteStepVehicleSubtitle => 'Select vehicle type and enter plate number';

  @override
  String get profileCompleteVehicleTypeLabel => 'Vehicle type';

  @override
  String get profileCompleteVehicleMotorcycle => 'Motorcycle';

  @override
  String get profileCompleteVehicleCar => 'Car';

  @override
  String get profileCompletePlateLabel => 'License plate';

  @override
  String get profileCompletePlateRequired => 'Please enter plate number';

  @override
  String get profileCompleteStepDocsTitle => 'Upload Documents';

  @override
  String get profileCompleteStepDocsSubtitle => 'Please take photos of your documents';

  @override
  String get profileCompleteDocIdCard => 'ID card photo';

  @override
  String get profileCompleteDocDriverLicense => 'Driver license photo';

  @override
  String get profileCompleteDocVehiclePhoto => 'Vehicle photo';

  @override
  String get profileCompleteDocPlatePhoto => 'Plate photo';

  @override
  String get profileCompleteDocsHint => '* Please upload all 4 documents';

  @override
  String get profileCompleteDocSelected => 'Selected ✓';

  @override
  String get profileCompleteDocTapToPick => 'Tap to take photo or choose from gallery';

  @override
  String get profileCompleteStepMerchantTitle => 'Shop Info';

  @override
  String get profileCompleteStepMerchantSubtitle => 'Please enter your shop information';

  @override
  String get profileCompleteMerchantNameLabel => 'Shop name / owner';

  @override
  String get profileCompleteAddressLabel => 'Shop address';

  @override
  String get profileCompleteAddressRequired => 'Please enter address';

  @override
  String get profileCompleteStepBankTitle => 'Bank Info';

  @override
  String get profileCompleteStepBankSubtitle => 'For receiving payouts (optional)';

  @override
  String get profileCompleteBankNameLabel => 'Bank name';

  @override
  String get profileCompleteBankNameHint => 'e.g. Kasikorn, SCB';

  @override
  String get profileCompleteBankAccountNumberLabel => 'Account number';

  @override
  String get profileCompleteBankAccountNameLabel => 'Account name';

  @override
  String get imagePickerChooseImage => 'Choose image';

  @override
  String get imagePickerTakePhoto => 'Take photo';

  @override
  String get imagePickerTakePhotoSubtitle => 'Use camera to take a new photo';

  @override
  String get imagePickerPickGallery => 'Choose from gallery';

  @override
  String get imagePickerPickGallerySubtitle => 'Pick from your album';

  @override
  String get landingLogin => 'Login';

  @override
  String get landingStart => 'Get Started';

  @override
  String get landingHeadline => 'Ride-hailing\nFood & Parcel Delivery';

  @override
  String get landingSubheadline => 'A community super app\nRide, order food, and send parcels in one app';

  @override
  String get landingServicesTitle => 'Our Services';

  @override
  String get landingServicesSubtitle => 'Everything in one app';

  @override
  String get landingServiceRideTitle => 'Ride';

  @override
  String get landingServiceRideDesc => 'Motorcycle or car rides\nConvenient and safe';

  @override
  String get landingServiceFoodTitle => 'Food';

  @override
  String get landingServiceFoodDesc => 'Order from nearby restaurants\nFast delivery to your home';

  @override
  String get landingServiceParcelTitle => 'Parcel';

  @override
  String get landingServiceParcelDesc => 'Send parcels to destination\nAffordable and trackable';

  @override
  String get landingSignupNow => 'Sign up now';

  @override
  String get landingHowTitle => 'Easy in 4 steps';

  @override
  String get landingHowStep1Number => '1';

  @override
  String get landingHowStep1Title => 'Sign up';

  @override
  String get landingHowStep1Desc => 'Register with your phone number';

  @override
  String get landingHowStep2Number => '2';

  @override
  String get landingHowStep2Title => 'Choose a service';

  @override
  String get landingHowStep2Desc => 'Ride, Food, or Parcel';

  @override
  String get landingHowStep3Number => '3';

  @override
  String get landingHowStep3Title => 'Confirm order';

  @override
  String get landingHowStep3Desc => 'Choose destination and payment method';

  @override
  String get landingHowStep4Number => '4';

  @override
  String get landingHowStep4Title => 'Get served';

  @override
  String get landingHowStep4Desc => 'A driver accepts and comes to you';

  @override
  String get landingDriverCtaTitle => 'Become a Jedechai driver';

  @override
  String get landingDriverCtaSubtitle => 'Earn extra income, work freely, choose your own hours';

  @override
  String get topupAdminPushTitle => '💰 New top-up request';

  @override
  String topupAdminPushBody(Object driverName, Object amount) {
    return '$driverName requested a top-up of ฿$amount — pending approval';
  }

  @override
  String topupAdminEmailSubject(Object driverName, Object amount) {
    return '💰 New top-up request — $driverName ฿$amount';
  }

  @override
  String topupAdminEmailHtml(Object driverName, Object amount) {
    return '<div style=\"font-family:sans-serif;max-width:500px;margin:0 auto;padding:20px;\">\n  <h2 style=\"color:#1565C0;\">💰 New top-up request</h2>\n  <div style=\"background:#f5f5f5;padding:16px;border-radius:12px;margin:16px 0;\">\n    <p><strong>Driver:</strong> $driverName</p>\n    <p><strong>Amount:</strong> <span style=\"color:#4CAF50;font-size:24px;font-weight:bold;\">฿$amount</span></p>\n    <p><strong>Status:</strong> <span style=\"color:#FF9800;\">Pending approval</span></p>\n  </div>\n  <p style=\"color:#666;\">Please sign in to Admin to review and approve the top-up request</p>\n  <hr style=\"border:none;border-top:1px solid #eee;margin:20px 0;\">\n  <p style=\"color:#999;font-size:12px;\">JDC Delivery Admin System</p>\n</div>\n';
  }

  @override
  String topupOmiseTransactionDescription(Object amount, Object chargeId) {
    return 'Top up via Omise PromptPay (฿$amount) — Charge: $chargeId';
  }

  @override
  String topupPromptPayTransactionDescription(Object amount) {
    return 'Top up via PromptPay (฿$amount)';
  }

  @override
  String topupWithdrawalTransactionDescription(Object amount, Object bankName, Object accountNumber) {
    return 'Withdrawal request ฿$amount to $bankName $accountNumber';
  }
}
