import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'JDC Delivery'**
  String get appName;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @useSystemLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use system language'**
  String get useSystemLanguage;

  /// No description provided for @thai.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get thai;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get loginWelcomeTitle;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginWelcomeSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmailLabel;

  /// No description provided for @loginPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordLabel;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @loginNoAccountPrefix.
  ///
  /// In en, this message translates to:
  /// **'No account? '**
  String get loginNoAccountPrefix;

  /// No description provided for @loginRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginRegisterButton;

  /// No description provided for @loginSuccessSnack.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get loginSuccessSnack;

  /// No description provided for @loginBackPressToExit.
  ///
  /// In en, this message translates to:
  /// **'Press again to exit'**
  String get loginBackPressToExit;

  /// No description provided for @loginErrorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get loginErrorDialogTitle;

  /// No description provided for @loginValidationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get loginValidationEmailRequired;

  /// No description provided for @loginValidationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get loginValidationEmailInvalid;

  /// No description provided for @loginValidationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get loginValidationPasswordRequired;

  /// No description provided for @loginValidationPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get loginValidationPasswordMinLength;

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password\nPlease try again'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed\nPlease check your inbox'**
  String get loginErrorEmailNotConfirmed;

  /// No description provided for @loginErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found\nPlease sign up first'**
  String get loginErrorUserNotFound;

  /// No description provided for @loginErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts\nPlease wait and try again'**
  String get loginErrorTooManyRequests;

  /// No description provided for @loginErrorCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server\nPlease check your internet'**
  String get loginErrorCannotConnect;

  /// No description provided for @loginErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error\nPlease try again'**
  String get loginErrorNetwork;

  /// No description provided for @loginErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again'**
  String get loginErrorGeneric;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get registerTitle;

  /// No description provided for @registerHeader.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get registerHeader;

  /// No description provided for @registerSubheader.
  ///
  /// In en, this message translates to:
  /// **'Please fill in your information'**
  String get registerSubheader;

  /// No description provided for @registerSelectRole.
  ///
  /// In en, this message translates to:
  /// **'Select account type'**
  String get registerSelectRole;

  /// No description provided for @registerFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerFullNameLabel;

  /// No description provided for @registerShopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get registerShopNameLabel;

  /// No description provided for @registerPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get registerPhoneLabel;

  /// No description provided for @registerEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get registerEmailLabel;

  /// No description provided for @registerReferralCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get registerReferralCodeLabel;

  /// No description provided for @registerPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get registerPasswordLabel;

  /// No description provided for @registerConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registerConfirmPasswordLabel;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get registerButton;

  /// No description provided for @registerHaveAccountPrefix.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get registerHaveAccountPrefix;

  /// No description provided for @registerGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get registerGoToLogin;

  /// No description provided for @registerValidationFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get registerValidationFullNameRequired;

  /// No description provided for @registerValidationShopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter shop name'**
  String get registerValidationShopNameRequired;

  /// No description provided for @registerValidationPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get registerValidationPhoneRequired;

  /// No description provided for @registerValidationPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get registerValidationPhoneInvalid;

  /// No description provided for @registerValidationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get registerValidationEmailRequired;

  /// No description provided for @registerValidationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get registerValidationEmailInvalid;

  /// No description provided for @registerValidationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get registerValidationPasswordRequired;

  /// No description provided for @registerValidationPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get registerValidationPasswordMinLength;

  /// No description provided for @registerValidationConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get registerValidationConfirmPasswordRequired;

  /// No description provided for @registerValidationPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerValidationPasswordMismatch;

  /// No description provided for @registerErrorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up failed'**
  String get registerErrorDialogTitle;

  /// No description provided for @registerErrorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match\nPlease check and try again'**
  String get registerErrorPasswordMismatch;

  /// No description provided for @registerErrorPhoneUsed.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already in use\nPlease use another phone or sign in'**
  String get registerErrorPhoneUsed;

  /// No description provided for @registerErrorEmailUsed.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use\nPlease sign in or use another email'**
  String get registerErrorEmailUsed;

  /// No description provided for @registerErrorEmailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use\nPlease sign in or use another email'**
  String get registerErrorEmailAlreadyRegistered;

  /// No description provided for @registerErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Weak password\nPlease use at least 6 characters'**
  String get registerErrorWeakPassword;

  /// No description provided for @registerErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format\nPlease check your email'**
  String get registerErrorInvalidEmail;

  /// No description provided for @registerErrorCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server\nPlease check your internet'**
  String get registerErrorCannotConnect;

  /// No description provided for @registerErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts\nPlease wait and try again'**
  String get registerErrorTooManyRequests;

  /// No description provided for @registerErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again'**
  String get registerErrorGeneric;

  /// No description provided for @registerSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed up successfully!'**
  String get registerSuccessTitle;

  /// No description provided for @registerSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Registration completed\nPlease sign in to start using the app'**
  String get registerSuccessBody;

  /// No description provided for @registerSuccessGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get registerSuccessGoToLogin;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordHeader.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordHeader;

  /// No description provided for @forgotPasswordSubheader.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a reset link'**
  String get forgotPasswordSubheader;

  /// No description provided for @forgotPasswordEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotPasswordEmailLabel;

  /// No description provided for @forgotPasswordEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get forgotPasswordEmailRequired;

  /// No description provided for @forgotPasswordEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get forgotPasswordEmailInvalid;

  /// No description provided for @forgotPasswordSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send reset email'**
  String get forgotPasswordSubmit;

  /// No description provided for @forgotPasswordBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotPasswordBackToLogin;

  /// No description provided for @forgotPasswordErrorDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to send email'**
  String get forgotPasswordErrorDialogTitle;

  /// No description provided for @forgotPasswordSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Email sent!'**
  String get forgotPasswordSuccessTitle;

  /// No description provided for @forgotPasswordSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'A password reset link has been sent to\n{email}\n\nPlease check your inbox'**
  String forgotPasswordSuccessBody(Object email);

  /// No description provided for @forgotPasswordSuccessBodyMock.
  ///
  /// In en, this message translates to:
  /// **'Mock Mode\nA reset email was simulated to\n{email}\n\n*No real email was sent*'**
  String forgotPasswordSuccessBodyMock(Object email);

  /// No description provided for @forgotPasswordSuccessGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get forgotPasswordSuccessGoToLogin;

  /// No description provided for @forgotPasswordErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this email\nPlease check your email'**
  String get forgotPasswordErrorUserNotFound;

  /// No description provided for @forgotPasswordErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests\nPlease wait and try again'**
  String get forgotPasswordErrorTooManyRequests;

  /// No description provided for @forgotPasswordErrorCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server\nPlease check your internet'**
  String get forgotPasswordErrorCannotConnect;

  /// No description provided for @forgotPasswordErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again'**
  String get forgotPasswordErrorGeneric;

  /// No description provided for @foodCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get foodCategoryAll;

  /// No description provided for @foodCategoryMadeToOrder.
  ///
  /// In en, this message translates to:
  /// **'Made to order'**
  String get foodCategoryMadeToOrder;

  /// No description provided for @foodCategoryNoodles.
  ///
  /// In en, this message translates to:
  /// **'Noodles'**
  String get foodCategoryNoodles;

  /// No description provided for @foodCategoryDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get foodCategoryDrinks;

  /// No description provided for @foodCategoryDesserts.
  ///
  /// In en, this message translates to:
  /// **'Desserts'**
  String get foodCategoryDesserts;

  /// No description provided for @foodCategoryFastFood.
  ///
  /// In en, this message translates to:
  /// **'Fast food'**
  String get foodCategoryFastFood;

  /// No description provided for @foodHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Food'**
  String get foodHomeTitle;

  /// No description provided for @foodHomeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search restaurants...'**
  String get foodHomeSearchHint;

  /// No description provided for @foodHomeTopSelling.
  ///
  /// In en, this message translates to:
  /// **'Best Sellers'**
  String get foodHomeTopSelling;

  /// No description provided for @foodHomeTopCount.
  ///
  /// In en, this message translates to:
  /// **'Top {count}'**
  String foodHomeTopCount(Object count);

  /// No description provided for @foodHomeSoldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String foodHomeSoldCount(Object count);

  /// No description provided for @foodHomeNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurants near you'**
  String get foodHomeNearbyTitle;

  /// No description provided for @foodHomeRestaurantCount.
  ///
  /// In en, this message translates to:
  /// **'{count} restaurants'**
  String foodHomeRestaurantCount(Object count);

  /// No description provided for @foodHomeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading restaurants...'**
  String get foodHomeLoading;

  /// No description provided for @foodHomeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to load data'**
  String get foodHomeErrorTitle;

  /// No description provided for @foodHomeErrorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please check your internet connection'**
  String get foodHomeErrorSubtitle;

  /// No description provided for @foodHomeRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get foodHomeRetry;

  /// No description provided for @foodHomeEmptySearch.
  ///
  /// In en, this message translates to:
  /// **'No restaurants found'**
  String get foodHomeEmptySearch;

  /// No description provided for @foodHomeEmptyNoArea.
  ///
  /// In en, this message translates to:
  /// **'No restaurants in your area yet'**
  String get foodHomeEmptyNoArea;

  /// No description provided for @foodHomeEmptyNoneOpen.
  ///
  /// In en, this message translates to:
  /// **'No restaurants currently open'**
  String get foodHomeEmptyNoneOpen;

  /// No description provided for @foodHomeEmptySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Try another search term'**
  String get foodHomeEmptySearchHint;

  /// No description provided for @foodHomeEmptyNoAreaHint.
  ///
  /// In en, this message translates to:
  /// **'No open restaurants within {radius} km'**
  String foodHomeEmptyNoAreaHint(Object radius);

  /// No description provided for @foodHomeEmptyTryLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get foodHomeEmptyTryLater;

  /// No description provided for @foodHomeRestaurantDefault.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get foodHomeRestaurantDefault;

  /// No description provided for @foodHomeOpenBadge.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get foodHomeOpenBadge;

  /// No description provided for @foodHomeDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String foodHomeDistanceKm(Object km);

  /// No description provided for @foodHomeEstTime.
  ///
  /// In en, this message translates to:
  /// **'20-30 min'**
  String get foodHomeEstTime;

  /// No description provided for @foodPromoCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get foodPromoCodeTitle;

  /// No description provided for @foodPromoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Use this code at checkout for a discount'**
  String get foodPromoCodeHint;

  /// No description provided for @foodPromoCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied code \"{code}\"'**
  String foodPromoCodeCopied(Object code);

  /// No description provided for @foodPromoCodeClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get foodPromoCodeClose;

  /// No description provided for @foodPromoCodeCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get foodPromoCodeCopy;

  /// No description provided for @foodCartViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get foodCartViewCart;

  /// No description provided for @foodCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart'**
  String get foodCartTitle;

  /// No description provided for @foodCartClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get foodCartClear;

  /// No description provided for @foodCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get foodCartEmpty;

  /// No description provided for @foodCartFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get foodCartFoodCost;

  /// No description provided for @foodCartDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get foodCartDeliveryFee;

  /// No description provided for @foodCartDeliveryCalcLater.
  ///
  /// In en, this message translates to:
  /// **'Calculated at order'**
  String get foodCartDeliveryCalcLater;

  /// No description provided for @foodCartTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get foodCartTotal;

  /// No description provided for @foodCartOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Order food'**
  String get foodCartOrderButton;

  /// No description provided for @foodCheckoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get foodCheckoutTitle;

  /// No description provided for @foodCheckoutRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get foodCheckoutRestaurant;

  /// No description provided for @foodCheckoutDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get foodCheckoutDeliveryAddress;

  /// No description provided for @foodCheckoutCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get foodCheckoutCurrentLocation;

  /// No description provided for @foodCheckoutItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Food items ({count} items)'**
  String foodCheckoutItemsTitle(Object count);

  /// No description provided for @foodCheckoutNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Note to restaurant'**
  String get foodCheckoutNoteTitle;

  /// No description provided for @foodCheckoutNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. no vegetables, less spicy...'**
  String get foodCheckoutNoteHint;

  /// No description provided for @foodCheckoutPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get foodCheckoutPaymentTitle;

  /// No description provided for @foodCheckoutPayCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get foodCheckoutPayCash;

  /// No description provided for @foodCheckoutPayTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get foodCheckoutPayTransfer;

  /// No description provided for @foodCheckoutDeliveryEstimate.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee (estimated)'**
  String get foodCheckoutDeliveryEstimate;

  /// No description provided for @foodCheckoutConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get foodCheckoutConfirmButton;

  /// No description provided for @foodCheckoutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order placed successfully!'**
  String get foodCheckoutSuccess;

  /// No description provided for @foodCheckoutLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get foodCheckoutLoginRequired;

  /// No description provided for @foodCheckoutCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create order'**
  String get foodCheckoutCreateFailed;

  /// No description provided for @foodCheckoutOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to place order: {error}'**
  String foodCheckoutOrderFailed(Object error);

  /// No description provided for @foodCheckoutNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'New order!'**
  String get foodCheckoutNotifTitle;

  /// No description provided for @foodCheckoutNotifBody.
  ///
  /// In en, this message translates to:
  /// **'Customer ordered food ฿{amount} — please confirm'**
  String foodCheckoutNotifBody(Object amount);

  /// No description provided for @foodScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery time'**
  String get foodScheduleTitle;

  /// No description provided for @foodScheduleNow.
  ///
  /// In en, this message translates to:
  /// **'Deliver now'**
  String get foodScheduleNow;

  /// No description provided for @foodScheduleNowDesc.
  ///
  /// In en, this message translates to:
  /// **'Restaurant will start preparing immediately after confirmation'**
  String get foodScheduleNowDesc;

  /// No description provided for @foodScheduleLater.
  ///
  /// In en, this message translates to:
  /// **'Schedule delivery'**
  String get foodScheduleLater;

  /// No description provided for @foodScheduleLaterDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose date and time you want to receive food'**
  String get foodScheduleLaterDesc;

  /// No description provided for @foodScheduleLaterSet.
  ///
  /// In en, this message translates to:
  /// **'Scheduled: {dateTime}'**
  String foodScheduleLaterSet(Object dateTime);

  /// No description provided for @foodSchedulePickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose delivery date'**
  String get foodSchedulePickDate;

  /// No description provided for @foodSchedulePickTime.
  ///
  /// In en, this message translates to:
  /// **'Choose delivery time'**
  String get foodSchedulePickTime;

  /// No description provided for @foodScheduleMinTime.
  ///
  /// In en, this message translates to:
  /// **'Please choose a time at least 20 minutes from now'**
  String get foodScheduleMinTime;

  /// No description provided for @foodScheduleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose delivery date and time'**
  String get foodScheduleRequired;

  /// No description provided for @foodDistanceWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of delivery range'**
  String get foodDistanceWarningTitle;

  /// No description provided for @foodDistanceWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Your delivery location is {distance} km from the restaurant\nwhich exceeds the default range of {maxRadius} km.'**
  String foodDistanceWarningBody(Object distance, Object maxRadius);

  /// No description provided for @foodDistanceWarningFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee based on actual distance: ฿{fee}'**
  String foodDistanceWarningFee(Object fee);

  /// No description provided for @foodDistanceWarningOk.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get foodDistanceWarningOk;

  /// No description provided for @foodAddressCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get foodAddressCurrentLocation;

  /// No description provided for @foodAddressPinOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pin on map'**
  String get foodAddressPinOnMap;

  /// No description provided for @foodAddressSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get foodAddressSaved;

  /// No description provided for @foodAddressDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance: {km} km'**
  String foodAddressDistance(Object km);

  /// No description provided for @foodAddressUnknown.
  ///
  /// In en, this message translates to:
  /// **'Current location (unable to determine)'**
  String get foodAddressUnknown;

  /// No description provided for @foodDeliveryFeeWithDist.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee ({km} km)'**
  String foodDeliveryFeeWithDist(Object km);

  /// No description provided for @foodCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating...'**
  String get foodCalculating;

  /// No description provided for @foodCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get foodCouponDiscount;

  /// No description provided for @foodCheckoutLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Unable to determine delivery location. Please select a location'**
  String get foodCheckoutLocationRequired;

  /// No description provided for @foodCheckoutNoResponse.
  ///
  /// In en, this message translates to:
  /// **'No order data received from server'**
  String get foodCheckoutNoResponse;

  /// No description provided for @foodCheckoutFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order failed'**
  String get foodCheckoutFailedTitle;

  /// No description provided for @foodCheckoutSuccessScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled order placed successfully ({dateTime})'**
  String foodCheckoutSuccessScheduled(Object dateTime);

  /// No description provided for @foodCheckoutSuccessNow.
  ///
  /// In en, this message translates to:
  /// **'Order placed! Waiting for restaurant to confirm'**
  String get foodCheckoutSuccessNow;

  /// No description provided for @foodCheckoutNotifScheduledBody.
  ///
  /// In en, this message translates to:
  /// **'Customer pre-ordered food ฿{amount} for {dateTime}'**
  String foodCheckoutNotifScheduledBody(Object amount, Object dateTime);

  /// No description provided for @orderDetailScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Order details'**
  String get orderDetailScreenTitle;

  /// No description provided for @orderDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get orderDetailCancel;

  /// No description provided for @orderDetailOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order {code}'**
  String orderDetailOrderId(Object code);

  /// No description provided for @orderDetailOrderedAt.
  ///
  /// In en, this message translates to:
  /// **'Ordered: {dateTime}'**
  String orderDetailOrderedAt(Object dateTime);

  /// No description provided for @orderDetailLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get orderDetailLocationTitle;

  /// No description provided for @orderDetailPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get orderDetailPickup;

  /// No description provided for @orderDetailDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get orderDetailDestination;

  /// No description provided for @orderDetailDriverTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver info'**
  String get orderDetailDriverTitle;

  /// No description provided for @orderDetailDriverUnnamed.
  ///
  /// In en, this message translates to:
  /// **'No name'**
  String get orderDetailDriverUnnamed;

  /// No description provided for @orderDetailTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get orderDetailTrack;

  /// No description provided for @orderDetailChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get orderDetailChat;

  /// No description provided for @orderDetailCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get orderDetailCall;

  /// No description provided for @orderDetailCannotCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot call {phone}'**
  String orderDetailCannotCall(Object phone);

  /// No description provided for @orderDetailItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Food items'**
  String get orderDetailItemsTitle;

  /// No description provided for @orderDetailNoItems.
  ///
  /// In en, this message translates to:
  /// **'No food items found'**
  String get orderDetailNoItems;

  /// No description provided for @orderDetailItemUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get orderDetailItemUnnamed;

  /// No description provided for @orderDetailQuantity.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String orderDetailQuantity(Object qty);

  /// No description provided for @orderDetailOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Extras:'**
  String get orderDetailOptionsLabel;

  /// No description provided for @orderDetailOptionDefault.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get orderDetailOptionDefault;

  /// No description provided for @orderDetailAddressUnknown.
  ///
  /// In en, this message translates to:
  /// **'Address not specified'**
  String get orderDetailAddressUnknown;

  /// No description provided for @orderDetailAddressCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get orderDetailAddressCurrent;

  /// No description provided for @orderDetailPriceTitle.
  ///
  /// In en, this message translates to:
  /// **'Price details'**
  String get orderDetailPriceTitle;

  /// No description provided for @orderDetailFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get orderDetailFoodCost;

  /// No description provided for @orderDetailDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get orderDetailDeliveryFee;

  /// No description provided for @orderDetailCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get orderDetailCouponDiscount;

  /// No description provided for @orderDetailCouponDiscountCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount ({code})'**
  String orderDetailCouponDiscountCode(Object code);

  /// No description provided for @orderDetailDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get orderDetailDistance;

  /// No description provided for @orderDetailDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String orderDetailDistanceKm(Object km);

  /// No description provided for @orderDetailTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get orderDetailTotal;

  /// No description provided for @orderDetailServiceRide.
  ///
  /// In en, this message translates to:
  /// **'Ride service'**
  String get orderDetailServiceRide;

  /// No description provided for @orderDetailServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food order'**
  String get orderDetailServiceFood;

  /// No description provided for @orderDetailServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get orderDetailServiceParcel;

  /// No description provided for @orderDetailStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending confirmation'**
  String get orderDetailStatusPending;

  /// No description provided for @orderDetailStatusPendingMerchant.
  ///
  /// In en, this message translates to:
  /// **'Waiting for restaurant'**
  String get orderDetailStatusPendingMerchant;

  /// No description provided for @orderDetailStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing food'**
  String get orderDetailStatusPreparing;

  /// No description provided for @orderDetailStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get orderDetailStatusReady;

  /// No description provided for @orderDetailStatusDriverAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get orderDetailStatusDriverAccepted;

  /// No description provided for @orderDetailStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get orderDetailStatusConfirmed;

  /// No description provided for @orderDetailStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get orderDetailStatusArrived;

  /// No description provided for @orderDetailStatusPickingUp.
  ///
  /// In en, this message translates to:
  /// **'Driver picking up'**
  String get orderDetailStatusPickingUp;

  /// No description provided for @orderDetailStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'Delivering food'**
  String get orderDetailStatusInTransit;

  /// No description provided for @orderDetailStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get orderDetailStatusCompleted;

  /// No description provided for @orderDetailStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get orderDetailStatusCancelled;

  /// No description provided for @orderDetailCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurant rejected order'**
  String get orderDetailCancelledTitle;

  /// No description provided for @orderDetailCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'Sorry, the restaurant cannot accept your order at this time'**
  String get orderDetailCancelledBody;

  /// No description provided for @orderDetailOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderDetailOrderNumber;

  /// No description provided for @orderDetailCancelledRetry.
  ///
  /// In en, this message translates to:
  /// **'Please try ordering again or choose another restaurant'**
  String get orderDetailCancelledRetry;

  /// No description provided for @orderDetailUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get orderDetailUnderstood;

  /// No description provided for @orderDetailChatError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open chat'**
  String get orderDetailChatError;

  /// No description provided for @orderDetailDriverDefault.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get orderDetailDriverDefault;

  /// No description provided for @orderDetailCompletedFood.
  ///
  /// In en, this message translates to:
  /// **'Delivered successfully!'**
  String get orderDetailCompletedFood;

  /// No description provided for @orderDetailCompletedRide.
  ///
  /// In en, this message translates to:
  /// **'Trip completed!'**
  String get orderDetailCompletedRide;

  /// No description provided for @orderDetailThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using our service'**
  String get orderDetailThankYou;

  /// No description provided for @orderDetailTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get orderDetailTotalAmount;

  /// No description provided for @orderDetailIncludingDelivery.
  ///
  /// In en, this message translates to:
  /// **'Including delivery'**
  String get orderDetailIncludingDelivery;

  /// No description provided for @orderDetailCouponUsed.
  ///
  /// In en, this message translates to:
  /// **'Used coupon {code} discount ฿{amount}'**
  String orderDetailCouponUsed(Object code, Object amount);

  /// No description provided for @orderDetailCouponUsedNoCode.
  ///
  /// In en, this message translates to:
  /// **'Used coupon discount ฿{amount}'**
  String orderDetailCouponUsedNoCode(Object amount);

  /// No description provided for @orderDetailCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm order cancellation'**
  String get orderDetailCancelConfirmTitle;

  /// No description provided for @orderDetailCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to cancel this order?'**
  String get orderDetailCancelConfirmBody;

  /// No description provided for @orderDetailCancelNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Orders in progress cannot be cancelled'**
  String get orderDetailCancelNote;

  /// No description provided for @orderDetailCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep order'**
  String get orderDetailCancelKeep;

  /// No description provided for @orderDetailCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancel'**
  String get orderDetailCancelConfirm;

  /// No description provided for @orderDetailCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling order...'**
  String get orderDetailCancelling;

  /// No description provided for @orderDetailCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled successfully'**
  String get orderDetailCancelSuccess;

  /// No description provided for @orderDetailCancelError.
  ///
  /// In en, this message translates to:
  /// **'Cannot cancel order: {error}'**
  String orderDetailCancelError(Object error);

  /// No description provided for @driverDashTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Dashboard'**
  String get driverDashTitle;

  /// No description provided for @driverDashOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get driverDashOnline;

  /// No description provided for @driverDashOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get driverDashOffline;

  /// No description provided for @driverDashProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get driverDashProfile;

  /// No description provided for @driverDashLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get driverDashLogout;

  /// No description provided for @driverDashJobList.
  ///
  /// In en, this message translates to:
  /// **'Job list'**
  String get driverDashJobList;

  /// No description provided for @driverDashRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get driverDashRefreshing;

  /// No description provided for @driverDashRealtime.
  ///
  /// In en, this message translates to:
  /// **'Realtime'**
  String get driverDashRealtime;

  /// No description provided for @driverDashDriverDefault.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverDashDriverDefault;

  /// No description provided for @driverDashPendingJobs.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get driverDashPendingJobs;

  /// No description provided for @driverDashCompletedToday.
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get driverDashCompletedToday;

  /// No description provided for @driverDashEarningsToday.
  ///
  /// In en, this message translates to:
  /// **'Earnings today'**
  String get driverDashEarningsToday;

  /// No description provided for @driverDashNowOnline.
  ///
  /// In en, this message translates to:
  /// **'You are now online'**
  String get driverDashNowOnline;

  /// No description provided for @driverDashNowOffline.
  ///
  /// In en, this message translates to:
  /// **'You are now offline'**
  String get driverDashNowOffline;

  /// No description provided for @driverDashOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get driverDashOfflineTitle;

  /// No description provided for @driverDashNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No new jobs'**
  String get driverDashNoJobs;

  /// No description provided for @driverDashOfflineHint.
  ///
  /// In en, this message translates to:
  /// **'Go online to receive new jobs'**
  String get driverDashOfflineHint;

  /// No description provided for @driverDashNoJobsHint.
  ///
  /// In en, this message translates to:
  /// **'New jobs will appear here instantly'**
  String get driverDashNoJobsHint;

  /// No description provided for @driverDashRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get driverDashRefresh;

  /// No description provided for @driverDashNewJob.
  ///
  /// In en, this message translates to:
  /// **'New job! {type} - {status}'**
  String driverDashNewJob(Object type, Object status);

  /// No description provided for @driverDashViewJob.
  ///
  /// In en, this message translates to:
  /// **'View job'**
  String get driverDashViewJob;

  /// No description provided for @driverDashJobFood.
  ///
  /// In en, this message translates to:
  /// **'Food delivery'**
  String get driverDashJobFood;

  /// No description provided for @driverDashJobRide.
  ///
  /// In en, this message translates to:
  /// **'Passenger ride'**
  String get driverDashJobRide;

  /// No description provided for @driverDashJobParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get driverDashJobParcel;

  /// No description provided for @driverDashJobGeneral.
  ///
  /// In en, this message translates to:
  /// **'General job'**
  String get driverDashJobGeneral;

  /// No description provided for @driverDashStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver'**
  String get driverDashStatusPending;

  /// No description provided for @driverDashStatusPendingMerchant.
  ///
  /// In en, this message translates to:
  /// **'Waiting for restaurant'**
  String get driverDashStatusPendingMerchant;

  /// No description provided for @driverDashStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing food'**
  String get driverDashStatusPreparing;

  /// No description provided for @driverDashStatusMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched'**
  String get driverDashStatusMatched;

  /// No description provided for @driverDashStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get driverDashStatusReady;

  /// No description provided for @driverDashStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get driverDashStatusAccepted;

  /// No description provided for @driverDashStatusDriverAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get driverDashStatusDriverAccepted;

  /// No description provided for @driverDashStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get driverDashStatusUnknown;

  /// No description provided for @driverDashMustOnline.
  ///
  /// In en, this message translates to:
  /// **'Please go online before accepting jobs'**
  String get driverDashMustOnline;

  /// No description provided for @driverDashNoUser.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get driverDashNoUser;

  /// No description provided for @driverDashPleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get driverDashPleaseLogin;

  /// No description provided for @driverDashAccepted.
  ///
  /// In en, this message translates to:
  /// **'Job accepted! Navigating...'**
  String get driverDashAccepted;

  /// No description provided for @driverDashErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get driverDashErrorTitle;

  /// No description provided for @driverDashNavError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open navigation: {error}'**
  String driverDashNavError(Object error);

  /// No description provided for @driverDashInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get driverDashInsufficientBalance;

  /// No description provided for @driverDashClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get driverDashClose;

  /// No description provided for @driverDashTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get driverDashTopUp;

  /// No description provided for @driverDashCannotAccept.
  ///
  /// In en, this message translates to:
  /// **'Cannot accept job'**
  String get driverDashCannotAccept;

  /// No description provided for @driverDashOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get driverDashOk;

  /// No description provided for @driverDashErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String driverDashErrorGeneric(Object error);

  /// No description provided for @driverDashPickupRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get driverDashPickupRestaurant;

  /// No description provided for @driverDashPickupPoint.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get driverDashPickupPoint;

  /// No description provided for @driverDashPickupFoodFallback.
  ///
  /// In en, this message translates to:
  /// **'Restaurant location'**
  String get driverDashPickupFoodFallback;

  /// No description provided for @driverDashPickupRideFallback.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get driverDashPickupRideFallback;

  /// No description provided for @driverDashDestCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer location'**
  String get driverDashDestCustomer;

  /// No description provided for @driverDashDestPoint.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get driverDashDestPoint;

  /// No description provided for @driverDashDestFallback.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get driverDashDestFallback;

  /// No description provided for @driverDashScheduledFrom.
  ///
  /// In en, this message translates to:
  /// **'Scheduled: available from {dateTime}'**
  String driverDashScheduledFrom(Object dateTime);

  /// No description provided for @driverDashScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled: {dateTime}'**
  String driverDashScheduledAt(Object dateTime);

  /// No description provided for @driverDashAcceptAt.
  ///
  /// In en, this message translates to:
  /// **'Available at {dateTime}'**
  String driverDashAcceptAt(Object dateTime);

  /// No description provided for @driverDashAcceptParcel.
  ///
  /// In en, this message translates to:
  /// **'Accept parcel job'**
  String get driverDashAcceptParcel;

  /// No description provided for @driverDashAcceptRide.
  ///
  /// In en, this message translates to:
  /// **'Accept this job'**
  String get driverDashAcceptRide;

  /// No description provided for @driverDashAcceptFood.
  ///
  /// In en, this message translates to:
  /// **'Accept food order'**
  String get driverDashAcceptFood;

  /// No description provided for @driverDashIncompleteJob.
  ///
  /// In en, this message translates to:
  /// **'Incomplete job'**
  String get driverDashIncompleteJob;

  /// No description provided for @driverDashInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get driverDashInProgress;

  /// No description provided for @driverDashGoToNav.
  ///
  /// In en, this message translates to:
  /// **'Go to navigation'**
  String get driverDashGoToNav;

  /// No description provided for @driverDashNavigating.
  ///
  /// In en, this message translates to:
  /// **'Opening navigation...'**
  String get driverDashNavigating;

  /// No description provided for @driverDashCannotNav.
  ///
  /// In en, this message translates to:
  /// **'Cannot navigate: {error}'**
  String driverDashCannotNav(Object error);

  /// No description provided for @driverDashCollectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Collect from customer'**
  String get driverDashCollectCustomer;

  /// No description provided for @driverDashFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get driverDashFoodCost;

  /// No description provided for @driverDashDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get driverDashDeliveryFee;

  /// No description provided for @driverDashDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get driverDashDistance;

  /// No description provided for @driverDashDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String driverDashDistanceKm(Object km);

  /// No description provided for @driverDashCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount -฿{amount}'**
  String driverDashCouponDiscount(Object amount);

  /// No description provided for @driverDashCouponDiscountCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon -฿{amount}'**
  String driverDashCouponDiscountCode(Object amount);

  /// No description provided for @driverDashTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get driverDashTimeJustNow;

  /// No description provided for @driverDashTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{min} min ago'**
  String driverDashTimeMinutes(Object min);

  /// No description provided for @driverDashTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String driverDashTimeHours(Object hours);

  /// No description provided for @driverDashTimeDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String driverDashTimeDays(Object days);

  /// No description provided for @driverDashVehicleMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get driverDashVehicleMotorcycle;

  /// No description provided for @driverDashVehicleCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get driverDashVehicleCar;

  /// No description provided for @driverDashNotifFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted your order!'**
  String get driverDashNotifFoodTitle;

  /// No description provided for @driverDashNotifFoodBody.
  ///
  /// In en, this message translates to:
  /// **'Driver {name} is coming to pick up your food'**
  String driverDashNotifFoodBody(Object name);

  /// No description provided for @driverDashNotifFoodBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'A driver is coming to pick up your food'**
  String get driverDashNotifFoodBodyDefault;

  /// No description provided for @driverDashNotifParcelTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted your parcel!'**
  String get driverDashNotifParcelTitle;

  /// No description provided for @driverDashNotifParcelBody.
  ///
  /// In en, this message translates to:
  /// **'Driver {name} is coming to pick up your parcel'**
  String driverDashNotifParcelBody(Object name);

  /// No description provided for @driverDashNotifParcelBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'A driver is coming to pick up your parcel'**
  String get driverDashNotifParcelBodyDefault;

  /// No description provided for @driverDashNotifRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted your trip!'**
  String get driverDashNotifRideTitle;

  /// No description provided for @driverDashNotifRideBody.
  ///
  /// In en, this message translates to:
  /// **'Driver {name} is coming to pick you up'**
  String driverDashNotifRideBody(Object name);

  /// No description provided for @driverDashNotifRideBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'A driver is coming to pick you up'**
  String get driverDashNotifRideBodyDefault;

  /// No description provided for @driverDashNotifMerchantTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted the order!'**
  String get driverDashNotifMerchantTitle;

  /// No description provided for @driverDashNotifMerchantBody.
  ///
  /// In en, this message translates to:
  /// **'Driver {name} is coming to pick up order {code}'**
  String driverDashNotifMerchantBody(Object name, Object code);

  /// No description provided for @driverDashNotifMerchantBodyDefault.
  ///
  /// In en, this message translates to:
  /// **'A driver is coming to pick up your order'**
  String get driverDashNotifMerchantBodyDefault;

  /// No description provided for @driverNavCustomerDefault.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get driverNavCustomerDefault;

  /// No description provided for @driverNavPhoneUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get driverNavPhoneUnknown;

  /// No description provided for @driverNavMerchantDefault.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get driverNavMerchantDefault;

  /// No description provided for @driverNavLocationPermSnack.
  ///
  /// In en, this message translates to:
  /// **'Please allow location access to use this feature'**
  String get driverNavLocationPermSnack;

  /// No description provided for @driverNavLocationDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot access location'**
  String get driverNavLocationDeniedTitle;

  /// No description provided for @driverNavLocationDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Please enable location access in device settings to use the app normally'**
  String get driverNavLocationDeniedBody;

  /// No description provided for @driverNavOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get driverNavOk;

  /// No description provided for @driverNavOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get driverNavOpenSettings;

  /// No description provided for @driverNavNoMerchantPhone.
  ///
  /// In en, this message translates to:
  /// **'Merchant phone not found'**
  String get driverNavNoMerchantPhone;

  /// No description provided for @driverNavCannotCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot make a call'**
  String get driverNavCannotCall;

  /// No description provided for @driverNavCallError.
  ///
  /// In en, this message translates to:
  /// **'Error making call'**
  String get driverNavCallError;

  /// No description provided for @driverNavNoCustomerPhone.
  ///
  /// In en, this message translates to:
  /// **'Customer phone not found'**
  String get driverNavNoCustomerPhone;

  /// No description provided for @driverNavCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get driverNavCancelTitle;

  /// No description provided for @driverNavCancelSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Please select a cancellation reason:'**
  String get driverNavCancelSelectReason;

  /// No description provided for @driverNavCancelReason1.
  ///
  /// In en, this message translates to:
  /// **'Customer unreachable'**
  String get driverNavCancelReason1;

  /// No description provided for @driverNavCancelReason2.
  ///
  /// In en, this message translates to:
  /// **'Restaurant closed/unavailable'**
  String get driverNavCancelReason2;

  /// No description provided for @driverNavCancelReason3.
  ///
  /// In en, this message translates to:
  /// **'Distance too far'**
  String get driverNavCancelReason3;

  /// No description provided for @driverNavCancelReason4.
  ///
  /// In en, this message translates to:
  /// **'Personal emergency'**
  String get driverNavCancelReason4;

  /// No description provided for @driverNavCancelReason5.
  ///
  /// In en, this message translates to:
  /// **'Bad weather/road conditions'**
  String get driverNavCancelReason5;

  /// No description provided for @driverNavCancelReason6.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get driverNavCancelReason6;

  /// No description provided for @driverNavCancelWarning.
  ///
  /// In en, this message translates to:
  /// **'Frequent cancellations may affect your rating'**
  String get driverNavCancelWarning;

  /// No description provided for @driverNavCancelBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get driverNavCancelBack;

  /// No description provided for @driverNavCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancel'**
  String get driverNavCancelConfirm;

  /// No description provided for @driverNavCancelNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver cancelled job'**
  String get driverNavCancelNotifTitle;

  /// No description provided for @driverNavCancelNotifBody.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String driverNavCancelNotifBody(Object reason);

  /// No description provided for @driverNavCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Job cancelled successfully'**
  String get driverNavCancelSuccess;

  /// No description provided for @driverNavCancelError.
  ///
  /// In en, this message translates to:
  /// **'Cannot cancel job: {error}'**
  String driverNavCancelError(Object error);

  /// No description provided for @driverNavMarkerPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get driverNavMarkerPickup;

  /// No description provided for @driverNavMarkerPickupFallback.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get driverNavMarkerPickupFallback;

  /// No description provided for @driverNavMarkerDest.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get driverNavMarkerDest;

  /// No description provided for @driverNavMarkerDestFallback.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get driverNavMarkerDestFallback;

  /// No description provided for @driverNavMarkerDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver location'**
  String get driverNavMarkerDriver;

  /// No description provided for @driverNavMarkerYou.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get driverNavMarkerYou;

  /// No description provided for @driverNavMarkerPosition.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get driverNavMarkerPosition;

  /// No description provided for @driverNavNoDriverData.
  ///
  /// In en, this message translates to:
  /// **'Driver data not found. Please sign out and sign in again'**
  String get driverNavNoDriverData;

  /// No description provided for @driverNavStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated successfully'**
  String get driverNavStatusUpdated;

  /// No description provided for @driverNavPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied. Please check your account permissions'**
  String get driverNavPermDenied;

  /// No description provided for @driverNavBookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found. Please refresh and try again'**
  String get driverNavBookingNotFound;

  /// No description provided for @driverNavDriverInvalid.
  ///
  /// In en, this message translates to:
  /// **'Driver data invalid. Please sign out and sign in again'**
  String get driverNavDriverInvalid;

  /// No description provided for @driverNavStatusUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Cannot update status: {error}'**
  String driverNavStatusUpdateError(Object error);

  /// No description provided for @driverNavCannotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Cannot open Google Maps'**
  String get driverNavCannotOpenMaps;

  /// No description provided for @driverNavMapsError.
  ///
  /// In en, this message translates to:
  /// **'Error opening navigation map'**
  String get driverNavMapsError;

  /// No description provided for @driverNavFoodArrivedMerchant.
  ///
  /// In en, this message translates to:
  /// **'Arrived at restaurant'**
  String get driverNavFoodArrivedMerchant;

  /// No description provided for @driverNavFoodWaitReady.
  ///
  /// In en, this message translates to:
  /// **'Wait for food ready'**
  String get driverNavFoodWaitReady;

  /// No description provided for @driverNavFoodPickup.
  ///
  /// In en, this message translates to:
  /// **'Pick up food'**
  String get driverNavFoodPickup;

  /// No description provided for @driverNavFoodStartDelivery.
  ///
  /// In en, this message translates to:
  /// **'Start food delivery'**
  String get driverNavFoodStartDelivery;

  /// No description provided for @driverNavFoodComplete.
  ///
  /// In en, this message translates to:
  /// **'Food delivery complete'**
  String get driverNavFoodComplete;

  /// No description provided for @driverNavParcelArrivedPickup.
  ///
  /// In en, this message translates to:
  /// **'Arrived at parcel pickup'**
  String get driverNavParcelArrivedPickup;

  /// No description provided for @driverNavParcelStartDelivery.
  ///
  /// In en, this message translates to:
  /// **'Pick up parcel, start delivery'**
  String get driverNavParcelStartDelivery;

  /// No description provided for @driverNavParcelComplete.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery complete'**
  String get driverNavParcelComplete;

  /// No description provided for @driverNavRideArrivedPickup.
  ///
  /// In en, this message translates to:
  /// **'Arrived at customer pickup'**
  String get driverNavRideArrivedPickup;

  /// No description provided for @driverNavRideStartTrip.
  ///
  /// In en, this message translates to:
  /// **'Pick up passenger, start trip'**
  String get driverNavRideStartTrip;

  /// No description provided for @driverNavRideComplete.
  ///
  /// In en, this message translates to:
  /// **'Passenger drop-off complete'**
  String get driverNavRideComplete;

  /// No description provided for @driverNavUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get driverNavUpdateStatus;

  /// No description provided for @driverNavWaitMerchantReady.
  ///
  /// In en, this message translates to:
  /// **'Please wait for restaurant to mark food ready'**
  String get driverNavWaitMerchantReady;

  /// No description provided for @driverNavInvalidStatus.
  ///
  /// In en, this message translates to:
  /// **'Invalid status: {status}'**
  String driverNavInvalidStatus(Object status);

  /// No description provided for @driverNavProxCustomerDest.
  ///
  /// In en, this message translates to:
  /// **'Customer destination'**
  String get driverNavProxCustomerDest;

  /// No description provided for @driverNavProxMerchant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get driverNavProxMerchant;

  /// No description provided for @driverNavProxRidePickup.
  ///
  /// In en, this message translates to:
  /// **'Passenger pickup'**
  String get driverNavProxRidePickup;

  /// No description provided for @driverNavProxParcelPickup.
  ///
  /// In en, this message translates to:
  /// **'Parcel pickup'**
  String get driverNavProxParcelPickup;

  /// No description provided for @driverNavTooFarTitle.
  ///
  /// In en, this message translates to:
  /// **'Too far away'**
  String get driverNavTooFarTitle;

  /// No description provided for @driverNavTooFarBody.
  ///
  /// In en, this message translates to:
  /// **'Please move closer to the destination\n\nCurrent distance: {current} meters\nAllowed distance: {allowed} meters'**
  String driverNavTooFarBody(Object current, Object allowed);

  /// No description provided for @driverNavCannotCheckLocation.
  ///
  /// In en, this message translates to:
  /// **'Cannot verify location: {error}'**
  String driverNavCannotCheckLocation(Object error);

  /// No description provided for @driverNavChatError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open chat'**
  String get driverNavChatError;

  /// No description provided for @driverNavChatRoomError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open chat room'**
  String get driverNavChatRoomError;

  /// No description provided for @driverNavChatOpenError.
  ///
  /// In en, this message translates to:
  /// **'Error opening chat'**
  String get driverNavChatOpenError;

  /// No description provided for @driverNavOrderItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Food items'**
  String get driverNavOrderItemsTitle;

  /// No description provided for @driverNavOrderItemsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No food items found'**
  String get driverNavOrderItemsEmpty;

  /// No description provided for @driverNavItemUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get driverNavItemUnspecified;

  /// No description provided for @driverNavOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Options:'**
  String get driverNavOptionsLabel;

  /// No description provided for @driverNavClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get driverNavClose;

  /// No description provided for @driverNavLoadItemsError.
  ///
  /// In en, this message translates to:
  /// **'Cannot load food items'**
  String get driverNavLoadItemsError;

  /// No description provided for @driverNavStatusFoodGoingMerchant.
  ///
  /// In en, this message translates to:
  /// **'Going to restaurant'**
  String get driverNavStatusFoodGoingMerchant;

  /// No description provided for @driverNavStatusFoodAtMerchant.
  ///
  /// In en, this message translates to:
  /// **'At restaurant, waiting for food'**
  String get driverNavStatusFoodAtMerchant;

  /// No description provided for @driverNavStatusFoodReady.
  ///
  /// In en, this message translates to:
  /// **'Food is ready'**
  String get driverNavStatusFoodReady;

  /// No description provided for @driverNavStatusFoodPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Food picked up'**
  String get driverNavStatusFoodPickedUp;

  /// No description provided for @driverNavStatusFoodDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering food...'**
  String get driverNavStatusFoodDelivering;

  /// No description provided for @driverNavStatusParcelGoing.
  ///
  /// In en, this message translates to:
  /// **'Going to pick up parcel'**
  String get driverNavStatusParcelGoing;

  /// No description provided for @driverNavStatusParcelArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at parcel pickup'**
  String get driverNavStatusParcelArrived;

  /// No description provided for @driverNavStatusParcelReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to deliver parcel'**
  String get driverNavStatusParcelReady;

  /// No description provided for @driverNavStatusParcelDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering parcel...'**
  String get driverNavStatusParcelDelivering;

  /// No description provided for @driverNavStatusRideGoing.
  ///
  /// In en, this message translates to:
  /// **'Going to pick up passenger'**
  String get driverNavStatusRideGoing;

  /// No description provided for @driverNavStatusRideArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at customer pickup'**
  String get driverNavStatusRideArrived;

  /// No description provided for @driverNavStatusRideReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to pick up passenger'**
  String get driverNavStatusRideReady;

  /// No description provided for @driverNavStatusRideTraveling.
  ///
  /// In en, this message translates to:
  /// **'Traveling...'**
  String get driverNavStatusRideTraveling;

  /// No description provided for @driverNavStatusAtPickup.
  ///
  /// In en, this message translates to:
  /// **'At pickup point'**
  String get driverNavStatusAtPickup;

  /// No description provided for @driverNavStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get driverNavStatusPickedUp;

  /// No description provided for @driverNavStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Delivery complete'**
  String get driverNavStatusCompleted;

  /// No description provided for @driverNavStatusDefault.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get driverNavStatusDefault;

  /// No description provided for @driverNavServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food order'**
  String get driverNavServiceFood;

  /// No description provided for @driverNavServiceRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get driverNavServiceRide;

  /// No description provided for @driverNavServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get driverNavServiceParcel;

  /// No description provided for @driverNavServiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get driverNavServiceDefault;

  /// No description provided for @driverNavBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave navigation?'**
  String get driverNavBackTitle;

  /// No description provided for @driverNavBackBody.
  ///
  /// In en, this message translates to:
  /// **'You still have an active job. The job will continue'**
  String get driverNavBackBody;

  /// No description provided for @driverNavBackStay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get driverNavBackStay;

  /// No description provided for @driverNavBackLeave.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get driverNavBackLeave;

  /// No description provided for @driverNavLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get driverNavLoading;

  /// No description provided for @driverNavActiveJob.
  ///
  /// In en, this message translates to:
  /// **'Active job'**
  String get driverNavActiveJob;

  /// No description provided for @driverNavCallCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call customer'**
  String get driverNavCallCustomer;

  /// No description provided for @driverNavTooltipNav.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get driverNavTooltipNav;

  /// No description provided for @driverNavTooltipChat.
  ///
  /// In en, this message translates to:
  /// **'Chat with customer'**
  String get driverNavTooltipChat;

  /// No description provided for @driverNavChipType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get driverNavChipType;

  /// No description provided for @driverNavChipDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get driverNavChipDistance;

  /// No description provided for @driverNavViewFoodItems.
  ///
  /// In en, this message translates to:
  /// **'View food items'**
  String get driverNavViewFoodItems;

  /// No description provided for @driverNavReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report issue'**
  String get driverNavReportIssue;

  /// No description provided for @driverNavCancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get driverNavCancelJob;

  /// No description provided for @driverNavJobCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Job cancelled'**
  String get driverNavJobCancelledTitle;

  /// No description provided for @driverNavJobCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'This job has been cancelled. Returning to driver home'**
  String get driverNavJobCancelledBody;

  /// No description provided for @driverNavGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get driverNavGoHome;

  /// No description provided for @driverNavNotifStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Job status update'**
  String get driverNavNotifStatusTitle;

  /// No description provided for @driverNavNotifAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver has accepted the job'**
  String get driverNavNotifAccepted;

  /// No description provided for @driverNavNotifArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver has arrived at pickup'**
  String get driverNavNotifArrived;

  /// No description provided for @driverNavNotifPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Driver picked up food, delivering now'**
  String get driverNavNotifPickedUp;

  /// No description provided for @driverNavNotifInTransit.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way to you'**
  String get driverNavNotifInTransit;

  /// No description provided for @driverNavNotifCompleted.
  ///
  /// In en, this message translates to:
  /// **'Job completed successfully'**
  String get driverNavNotifCompleted;

  /// No description provided for @driverNavNotifCancelled.
  ///
  /// In en, this message translates to:
  /// **'Job has been cancelled'**
  String get driverNavNotifCancelled;

  /// No description provided for @driverNavNotifStatusUpdate.
  ///
  /// In en, this message translates to:
  /// **'Job status updated to {status}'**
  String driverNavNotifStatusUpdate(Object status);

  /// No description provided for @driverNavMerchantArrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived at restaurant'**
  String get driverNavMerchantArrivedTitle;

  /// No description provided for @driverNavMerchantArrivedBody.
  ///
  /// In en, this message translates to:
  /// **'Driver has arrived. Please prepare the food for handover'**
  String get driverNavMerchantArrivedBody;

  /// No description provided for @driverNavPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Merchant payment successful'**
  String get driverNavPaymentTitle;

  /// No description provided for @driverNavPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Food picked up from restaurant\nPlease deliver to customer'**
  String get driverNavPaymentBody;

  /// No description provided for @driverNavPaymentSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get driverNavPaymentSales;

  /// No description provided for @driverNavPaymentDeduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction ({percent}%)'**
  String driverNavPaymentDeduction(Object percent);

  /// No description provided for @driverNavPaymentToMerchant.
  ///
  /// In en, this message translates to:
  /// **'Pay to merchant'**
  String get driverNavPaymentToMerchant;

  /// No description provided for @driverNavPaymentDeliver.
  ///
  /// In en, this message translates to:
  /// **'Deliver to customer'**
  String get driverNavPaymentDeliver;

  /// No description provided for @driverNavCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Job completed!'**
  String get driverNavCompletionTitle;

  /// No description provided for @driverNavCompletionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Delivered successfully!'**
  String get driverNavCompletionSuccess;

  /// No description provided for @driverNavCompletionCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect from customer'**
  String get driverNavCompletionCollect;

  /// No description provided for @driverNavCompletionFoodCost.
  ///
  /// In en, this message translates to:
  /// **'  Food cost'**
  String get driverNavCompletionFoodCost;

  /// No description provided for @driverNavCompletionDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'  Delivery fee'**
  String get driverNavCompletionDeliveryFee;

  /// No description provided for @driverNavCompletionCouponPlatform.
  ///
  /// In en, this message translates to:
  /// **'  Platform coupon discount'**
  String get driverNavCompletionCouponPlatform;

  /// No description provided for @driverNavCompletionCouponCode.
  ///
  /// In en, this message translates to:
  /// **'  Coupon discount ({code})'**
  String driverNavCompletionCouponCode(Object code);

  /// No description provided for @driverNavCompletionCoupon.
  ///
  /// In en, this message translates to:
  /// **'  Coupon discount'**
  String get driverNavCompletionCoupon;

  /// No description provided for @driverNavCompletionServiceFee.
  ///
  /// In en, this message translates to:
  /// **'System service fee'**
  String get driverNavCompletionServiceFee;

  /// No description provided for @driverNavCompletionNetEarnings.
  ///
  /// In en, this message translates to:
  /// **'Net earnings'**
  String get driverNavCompletionNetEarnings;

  /// No description provided for @driverNavCompletionViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get driverNavCompletionViewDetails;

  /// No description provided for @driverNavFinCardCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect from customer'**
  String get driverNavFinCardCollect;

  /// No description provided for @driverNavFinCardFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get driverNavFinCardFoodCost;

  /// No description provided for @driverNavFinCardDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get driverNavFinCardDeliveryFee;

  /// No description provided for @driverNavFinCardPayMerchant.
  ///
  /// In en, this message translates to:
  /// **'Pay to merchant'**
  String get driverNavFinCardPayMerchant;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get walletBalance;

  /// No description provided for @walletBalanceBaht.
  ///
  /// In en, this message translates to:
  /// **'{amount} Baht'**
  String walletBalanceBaht(Object amount);

  /// No description provided for @walletTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get walletTopUp;

  /// No description provided for @walletTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get walletTransactionHistory;

  /// No description provided for @walletLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get walletLoadError;

  /// No description provided for @walletRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get walletRetry;

  /// No description provided for @walletNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transaction history yet'**
  String get walletNoTransactions;

  /// No description provided for @walletTypeTopup.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get walletTypeTopup;

  /// No description provided for @walletTypeCommission.
  ///
  /// In en, this message translates to:
  /// **'System service fee'**
  String get walletTypeCommission;

  /// No description provided for @walletTypeFoodCommission.
  ///
  /// In en, this message translates to:
  /// **'Food system service fee'**
  String get walletTypeFoodCommission;

  /// No description provided for @walletTypeJobIncome.
  ///
  /// In en, this message translates to:
  /// **'Job income'**
  String get walletTypeJobIncome;

  /// No description provided for @walletTypePenalty.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get walletTypePenalty;

  /// No description provided for @walletToday.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String walletToday(Object time);

  /// No description provided for @walletYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String walletYesterday(Object time);

  /// No description provided for @topupTitle.
  ///
  /// In en, this message translates to:
  /// **'Top up / Withdraw'**
  String get topupTitle;

  /// No description provided for @topupMinAmountError.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least {amount} Baht'**
  String topupMinAmountError(Object amount);

  /// No description provided for @topupMaxAmountError.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds limit per transaction (max ฿{amount})'**
  String topupMaxAmountError(Object amount);

  /// No description provided for @topupOmiseSourceError.
  ///
  /// In en, this message translates to:
  /// **'Cannot create PromptPay Source\nPlease check Omise Key in .env'**
  String get topupOmiseSourceError;

  /// No description provided for @topupOmiseChargeError.
  ///
  /// In en, this message translates to:
  /// **'Cannot create Charge\nPlease check Omise Secret Key'**
  String get topupOmiseChargeError;

  /// No description provided for @topupOmiseQRError.
  ///
  /// In en, this message translates to:
  /// **'QR Code not found in Charge response\nPlease try again'**
  String get topupOmiseQRError;

  /// No description provided for @topupOmiseError.
  ///
  /// In en, this message translates to:
  /// **'Omise error: {error}'**
  String topupOmiseError(Object error);

  /// No description provided for @topupQRExpired.
  ///
  /// In en, this message translates to:
  /// **'QR Code expired, please generate a new one'**
  String get topupQRExpired;

  /// No description provided for @topupPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed, please try again'**
  String get topupPaymentFailed;

  /// No description provided for @topupCreditError.
  ///
  /// In en, this message translates to:
  /// **'Payment successful but cannot add to wallet\nPlease contact Admin with transfer proof'**
  String get topupCreditError;

  /// No description provided for @topupCreditGenericError.
  ///
  /// In en, this message translates to:
  /// **'Payment successful but an error occurred\nPlease contact Admin'**
  String get topupCreditGenericError;

  /// No description provided for @topupPromptPayNotSet.
  ///
  /// In en, this message translates to:
  /// **'PromptPay number not configured\nPlease contact Admin to set up'**
  String get topupPromptPayNotSet;

  /// No description provided for @topupPromptPayInvalid.
  ///
  /// In en, this message translates to:
  /// **'PromptPay number in system is invalid\nPlease contact Admin'**
  String get topupPromptPayInvalid;

  /// No description provided for @topupLocalError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String topupLocalError(Object error);

  /// No description provided for @topupDirectError.
  ///
  /// In en, this message translates to:
  /// **'Cannot add to wallet\nPlease contact Admin'**
  String get topupDirectError;

  /// No description provided for @topupDirectGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error adding to wallet\nPlease contact Admin'**
  String get topupDirectGenericError;

  /// No description provided for @topupDriverDefault.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get topupDriverDefault;

  /// No description provided for @topupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get topupErrorTitle;

  /// No description provided for @topupOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get topupOk;

  /// No description provided for @topupRequestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-up request sent'**
  String get topupRequestSentTitle;

  /// No description provided for @topupRequestSentBody.
  ///
  /// In en, this message translates to:
  /// **'Top-up request ฿{amount} has been sent\nWaiting for Admin to verify'**
  String topupRequestSentBody(Object amount);

  /// No description provided for @topupSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Top up successful!'**
  String get topupSuccessTitle;

  /// No description provided for @topupSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Added ฿{amount} to wallet successfully'**
  String topupSuccessBody(Object amount);

  /// No description provided for @topupWithdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get topupWithdrawTitle;

  /// No description provided for @topupWithdrawBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: ฿{amount}'**
  String topupWithdrawBalance(Object amount);

  /// No description provided for @topupWithdrawAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount to withdraw'**
  String get topupWithdrawAmountLabel;

  /// No description provided for @topupWithdrawBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get topupWithdrawBankName;

  /// No description provided for @topupWithdrawBankHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kasikorn, SCB'**
  String get topupWithdrawBankHint;

  /// No description provided for @topupWithdrawAccountNum.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get topupWithdrawAccountNum;

  /// No description provided for @topupWithdrawAccountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get topupWithdrawAccountName;

  /// No description provided for @topupWithdrawCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get topupWithdrawCancel;

  /// No description provided for @topupWithdrawAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter amount'**
  String get topupWithdrawAmountRequired;

  /// No description provided for @topupWithdrawInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get topupWithdrawInsufficientBalance;

  /// No description provided for @topupWithdrawBankRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in bank info'**
  String get topupWithdrawBankRequired;

  /// No description provided for @topupWithdrawError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String topupWithdrawError(Object error);

  /// No description provided for @topupWithdrawSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit withdrawal request'**
  String get topupWithdrawSubmit;

  /// No description provided for @topupWithdrawBtn.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get topupWithdrawBtn;

  /// No description provided for @topupWithdrawHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal history'**
  String get topupWithdrawHistoryTitle;

  /// No description provided for @topupWithdrawHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No withdrawal history yet'**
  String get topupWithdrawHistoryEmpty;

  /// No description provided for @topupHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Top-up history'**
  String get topupHistoryTitle;

  /// No description provided for @topupHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No top-up history yet'**
  String get topupHistoryEmpty;

  /// No description provided for @topupStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Transferred'**
  String get topupStatusCompleted;

  /// No description provided for @topupStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get topupStatusRejected;

  /// No description provided for @topupStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get topupStatusCancelled;

  /// No description provided for @topupStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get topupStatusPending;

  /// No description provided for @topupStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get topupStatusApproved;

  /// No description provided for @topupSelectAmount.
  ///
  /// In en, this message translates to:
  /// **'Select amount'**
  String get topupSelectAmount;

  /// No description provided for @topupCustomAmount.
  ///
  /// In en, this message translates to:
  /// **'Or enter custom amount'**
  String get topupCustomAmount;

  /// No description provided for @topupScanQR.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code to transfer'**
  String get topupScanQR;

  /// No description provided for @topupOmiseScanDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan QR via bank app — auto-verified'**
  String get topupOmiseScanDesc;

  /// No description provided for @topupManualScanDesc.
  ///
  /// In en, this message translates to:
  /// **'Transfer via PromptPay then confirm'**
  String get topupManualScanDesc;

  /// No description provided for @topupAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount: ฿{amount}'**
  String topupAmount(Object amount);

  /// No description provided for @topupOmiseAutoDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan QR to transfer — system auto-verifies'**
  String get topupOmiseAutoDesc;

  /// No description provided for @topupManualConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Scan QR then press \"Confirm transfer\" below'**
  String get topupManualConfirmDesc;

  /// No description provided for @topupRequestSentCard.
  ///
  /// In en, this message translates to:
  /// **'Top-up request sent'**
  String get topupRequestSentCard;

  /// No description provided for @topupRequestSentCardBody.
  ///
  /// In en, this message translates to:
  /// **'Amount ฿{amount} — waiting for Admin to verify'**
  String topupRequestSentCardBody(Object amount);

  /// No description provided for @topupCheckingPayment.
  ///
  /// In en, this message translates to:
  /// **'Checking payment...'**
  String get topupCheckingPayment;

  /// No description provided for @topupAutoCheckDesc.
  ///
  /// In en, this message translates to:
  /// **'System checks every 5 seconds\nWallet credited instantly on success'**
  String get topupAutoCheckDesc;

  /// No description provided for @topupCancelNewQR.
  ///
  /// In en, this message translates to:
  /// **'Cancel / Generate new QR'**
  String get topupCancelNewQR;

  /// No description provided for @topupOmiseSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get topupOmiseSuccessTitle;

  /// No description provided for @topupOmiseSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Added ฿{amount} to wallet successfully'**
  String topupOmiseSuccessBody(Object amount);

  /// No description provided for @topupOmiseAutoVerified.
  ///
  /// In en, this message translates to:
  /// **'Auto-verified via Omise'**
  String get topupOmiseAutoVerified;

  /// No description provided for @topupGeneratingQR.
  ///
  /// In en, this message translates to:
  /// **'Generating QR...'**
  String get topupGeneratingQR;

  /// No description provided for @topupPayPromptPay.
  ///
  /// In en, this message translates to:
  /// **'Pay with PromptPay'**
  String get topupPayPromptPay;

  /// No description provided for @topupSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get topupSending;

  /// No description provided for @topupConfirmTransfer.
  ///
  /// In en, this message translates to:
  /// **'Confirm transfer ฿{amount}'**
  String topupConfirmTransfer(Object amount);

  /// No description provided for @topupGenerateNewQR.
  ///
  /// In en, this message translates to:
  /// **'Generate new QR'**
  String get topupGenerateNewQR;

  /// No description provided for @withdrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdrawTitle;

  /// No description provided for @withdrawBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get withdrawBalance;

  /// No description provided for @withdrawAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify withdrawal amount'**
  String get withdrawAmountRequired;

  /// No description provided for @withdrawInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance\nRemaining: ฿{amount}'**
  String withdrawInsufficientBalance(Object amount);

  /// No description provided for @withdrawFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot submit withdrawal\nPlease try again'**
  String get withdrawFailed;

  /// No description provided for @withdrawGenericError.
  ///
  /// In en, this message translates to:
  /// **'Error occurred\nPlease try again'**
  String get withdrawGenericError;

  /// No description provided for @withdrawErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get withdrawErrorTitle;

  /// No description provided for @withdrawOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get withdrawOk;

  /// No description provided for @withdrawSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal request submitted'**
  String get withdrawSuccessTitle;

  /// No description provided for @withdrawSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal request ฿{amount} received\n\nAdmin will review and transfer within 1-3 business days'**
  String withdrawSuccessBody(Object amount);

  /// No description provided for @withdrawAmountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal amount'**
  String get withdrawAmountSectionTitle;

  /// No description provided for @withdrawAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (Baht)'**
  String get withdrawAmountLabel;

  /// No description provided for @withdrawMinHelper.
  ///
  /// In en, this message translates to:
  /// **'Minimum ฿100'**
  String get withdrawMinHelper;

  /// No description provided for @withdrawAmountValidation.
  ///
  /// In en, this message translates to:
  /// **'Please specify amount'**
  String get withdrawAmountValidation;

  /// No description provided for @withdrawMinValidation.
  ///
  /// In en, this message translates to:
  /// **'Minimum ฿100'**
  String get withdrawMinValidation;

  /// No description provided for @withdrawBankInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank account information'**
  String get withdrawBankInfoTitle;

  /// No description provided for @withdrawBankLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get withdrawBankLabel;

  /// No description provided for @withdrawBankValidation.
  ///
  /// In en, this message translates to:
  /// **'Please select a bank'**
  String get withdrawBankValidation;

  /// No description provided for @withdrawAccountNumLabel.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get withdrawAccountNumLabel;

  /// No description provided for @withdrawAccountNumValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter account number'**
  String get withdrawAccountNumValidation;

  /// No description provided for @withdrawAccountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get withdrawAccountNameLabel;

  /// No description provided for @withdrawAccountNameValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter account name'**
  String get withdrawAccountNameValidation;

  /// No description provided for @withdrawProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get withdrawProcessing;

  /// No description provided for @withdrawSubmitBtn.
  ///
  /// In en, this message translates to:
  /// **'Submit withdrawal'**
  String get withdrawSubmitBtn;

  /// No description provided for @withdrawHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal request history'**
  String get withdrawHistoryTitle;

  /// No description provided for @withdrawStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Transferred'**
  String get withdrawStatusCompleted;

  /// No description provided for @withdrawStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get withdrawStatusRejected;

  /// No description provided for @withdrawStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get withdrawStatusCancelled;

  /// No description provided for @withdrawStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get withdrawStatusPending;

  /// No description provided for @withdrawBankKasikorn.
  ///
  /// In en, this message translates to:
  /// **'Kasikorn Bank'**
  String get withdrawBankKasikorn;

  /// No description provided for @withdrawBankSCB.
  ///
  /// In en, this message translates to:
  /// **'Siam Commercial Bank'**
  String get withdrawBankSCB;

  /// No description provided for @withdrawBankBangkok.
  ///
  /// In en, this message translates to:
  /// **'Bangkok Bank'**
  String get withdrawBankBangkok;

  /// No description provided for @withdrawBankKrungthai.
  ///
  /// In en, this message translates to:
  /// **'Krungthai Bank'**
  String get withdrawBankKrungthai;

  /// No description provided for @withdrawBankKrungsri.
  ///
  /// In en, this message translates to:
  /// **'Krungsri Bank'**
  String get withdrawBankKrungsri;

  /// No description provided for @withdrawBankTTB.
  ///
  /// In en, this message translates to:
  /// **'TMBThanachart Bank'**
  String get withdrawBankTTB;

  /// No description provided for @withdrawBankGSB.
  ///
  /// In en, this message translates to:
  /// **'Government Savings Bank'**
  String get withdrawBankGSB;

  /// No description provided for @withdrawBankKKP.
  ///
  /// In en, this message translates to:
  /// **'Kiatnakin Phatra Bank'**
  String get withdrawBankKKP;

  /// No description provided for @withdrawBankCIMB.
  ///
  /// In en, this message translates to:
  /// **'CIMB Thai Bank'**
  String get withdrawBankCIMB;

  /// No description provided for @withdrawBankTisco.
  ///
  /// In en, this message translates to:
  /// **'Tisco Bank'**
  String get withdrawBankTisco;

  /// No description provided for @withdrawBankUOB.
  ///
  /// In en, this message translates to:
  /// **'UOB Bank'**
  String get withdrawBankUOB;

  /// No description provided for @withdrawBankLH.
  ///
  /// In en, this message translates to:
  /// **'Land and Houses Bank'**
  String get withdrawBankLH;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get accountErrorTitle;

  /// No description provided for @accountRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get accountRetry;

  /// No description provided for @accountPersonalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get accountPersonalInfoTitle;

  /// No description provided for @accountMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get accountMenuTitle;

  /// No description provided for @accountAppInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'App info'**
  String get accountAppInfoTitle;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountLogout;

  /// No description provided for @accountLogoutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountLogoutDialogTitle;

  /// No description provided for @accountLogoutDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to sign out?'**
  String get accountLogoutDialogBody;

  /// No description provided for @accountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancel;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteDialogTitle;

  /// No description provided for @accountDeleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Once confirmed, your request will be sent to an admin for approval.\nWhile waiting for approval, you will not be able to use the account.'**
  String get accountDeleteDialogBody;

  /// No description provided for @accountDeleteReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason for deletion (optional)'**
  String get accountDeleteReasonHint;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get accountDeleteConfirm;

  /// No description provided for @accountUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get accountUploadingImage;

  /// No description provided for @accountUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile photo uploaded successfully!'**
  String get accountUploadSuccess;

  /// No description provided for @accountUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String accountUploadFailed(Object error);

  /// No description provided for @accountUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully!'**
  String get accountUpdateSuccess;

  /// No description provided for @accountUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String accountUpdateFailed(Object error);

  /// No description provided for @accountOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open link'**
  String get accountOpenLinkFailed;

  /// No description provided for @accountErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String accountErrorGeneric(Object error);

  /// No description provided for @accountInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get accountInfoTitle;

  /// No description provided for @accountInfoName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountInfoName;

  /// No description provided for @accountInfoPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get accountInfoPhone;

  /// No description provided for @accountInfoEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountInfoEmail;

  /// No description provided for @accountNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get accountNotSet;

  /// No description provided for @accountMenuEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get accountMenuEditProfile;

  /// No description provided for @accountMenuCoupons.
  ///
  /// In en, this message translates to:
  /// **'My coupons'**
  String get accountMenuCoupons;

  /// No description provided for @accountMenuReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get accountMenuReferral;

  /// No description provided for @accountMenuHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get accountMenuHelp;

  /// No description provided for @accountMenuNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountMenuNotifications;

  /// No description provided for @accountMenuPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get accountMenuPrivacyPolicy;

  /// No description provided for @accountFeatureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'This feature will be available in a future version'**
  String get accountFeatureComingSoon;

  /// No description provided for @merchantMenuEditShop.
  ///
  /// In en, this message translates to:
  /// **'Edit shop information'**
  String get merchantMenuEditShop;

  /// No description provided for @merchantMenuCoupons.
  ///
  /// In en, this message translates to:
  /// **'Merchant coupons'**
  String get merchantMenuCoupons;

  /// No description provided for @accountRoleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get accountRoleCustomer;

  /// No description provided for @accountRoleMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get accountRoleMerchant;

  /// No description provided for @accountRoleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get accountRoleDriver;

  /// No description provided for @driverInfoVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get driverInfoVehicleType;

  /// No description provided for @driverInfoLicensePlate.
  ///
  /// In en, this message translates to:
  /// **'License plate'**
  String get driverInfoLicensePlate;

  /// No description provided for @profileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditTitle;

  /// No description provided for @profileLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get profileLoadFailedTitle;

  /// No description provided for @profileLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Unable to load profile data: {error}'**
  String profileLoadFailedBody(Object error);

  /// No description provided for @profileSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile saved successfully'**
  String get profileSaveSuccess;

  /// No description provided for @profileSaveFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get profileSaveFailedTitle;

  /// No description provided for @profileSaveFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Unable to save profile: {error}'**
  String profileSaveFailedBody(Object error);

  /// No description provided for @profileBasicInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get profileBasicInfoSection;

  /// No description provided for @profileVehicleSection.
  ///
  /// In en, this message translates to:
  /// **'Vehicle information'**
  String get profileVehicleSection;

  /// No description provided for @profileMerchantSection.
  ///
  /// In en, this message translates to:
  /// **'Shop information'**
  String get profileMerchantSection;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileUploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get profileUploadingImage;

  /// No description provided for @profileVehicleMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get profileVehicleMotorcycle;

  /// No description provided for @profileVehicleCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get profileVehicleCar;

  /// No description provided for @profileFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileFullNameLabel;

  /// No description provided for @profileFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get profileFullNameRequired;

  /// No description provided for @profilePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profilePhoneLabel;

  /// No description provided for @profilePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get profilePhoneRequired;

  /// No description provided for @profileLicensePlateRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your license plate'**
  String get profileLicensePlateRequired;

  /// No description provided for @profileShopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get profileShopNameLabel;

  /// No description provided for @profileShopNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter shop name'**
  String get profileShopNameHint;

  /// No description provided for @profileShopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter shop name'**
  String get profileShopNameRequired;

  /// No description provided for @profileShopAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop address'**
  String get profileShopAddressLabel;

  /// No description provided for @profileShopAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter shop address'**
  String get profileShopAddressHint;

  /// No description provided for @profileShopAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter shop address'**
  String get profileShopAddressRequired;

  /// No description provided for @profileShopPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop phone'**
  String get profileShopPhoneLabel;

  /// No description provided for @profileShopPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter shop phone number'**
  String get profileShopPhoneHint;

  /// No description provided for @profileShopPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter shop phone number'**
  String get profileShopPhoneRequired;

  /// No description provided for @accountVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get accountVersionLabel;

  /// No description provided for @accountDevelopedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Developed by'**
  String get accountDevelopedByLabel;

  /// No description provided for @accountLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get accountLoading;

  /// No description provided for @accountDeleteRequestSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to submit request: {error}'**
  String accountDeleteRequestSubmitFailed(Object error);

  /// No description provided for @merchantCloseShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Close shop?'**
  String get merchantCloseShopTitle;

  /// No description provided for @merchantCloseShopBody.
  ///
  /// In en, this message translates to:
  /// **'Closing the shop manually will disable auto open/close.\nYou can re-enable this feature in Settings.'**
  String get merchantCloseShopBody;

  /// No description provided for @merchantCloseShopCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get merchantCloseShopCancel;

  /// No description provided for @merchantCloseShopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close shop'**
  String get merchantCloseShopConfirm;

  /// No description provided for @merchantNewOrderAlert.
  ///
  /// In en, this message translates to:
  /// **'🚨 New order!'**
  String get merchantNewOrderAlert;

  /// No description provided for @merchantNewOrderWaiting.
  ///
  /// In en, this message translates to:
  /// **'You have a new order waiting for confirmation!'**
  String get merchantNewOrderWaiting;

  /// No description provided for @merchantAlarmDesc.
  ///
  /// In en, this message translates to:
  /// **'Sound will keep alerting until you press stop'**
  String get merchantAlarmDesc;

  /// No description provided for @merchantStopAlarm.
  ///
  /// In en, this message translates to:
  /// **'Stop sound / Acknowledge'**
  String get merchantStopAlarm;

  /// No description provided for @merchantUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User data not found'**
  String get merchantUserNotFound;

  /// No description provided for @merchantOrderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order has been confirmed!'**
  String get merchantOrderConfirmed;

  /// No description provided for @merchantShopOpenedAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Shop opened (auto schedule disabled)'**
  String get merchantShopOpenedAutoOff;

  /// No description provided for @merchantShopOpened.
  ///
  /// In en, this message translates to:
  /// **'Shop opened'**
  String get merchantShopOpened;

  /// No description provided for @merchantShopClosedAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Shop closed (auto schedule disabled)'**
  String get merchantShopClosedAutoOff;

  /// No description provided for @merchantShopClosed.
  ///
  /// In en, this message translates to:
  /// **'Shop closed'**
  String get merchantShopClosed;

  /// No description provided for @merchantShopStatusError.
  ///
  /// In en, this message translates to:
  /// **'Unable to change shop status: {error}'**
  String merchantShopStatusError(Object error);

  /// No description provided for @merchantDriverStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Driver: Waiting for driver...'**
  String get merchantDriverStatusWaiting;

  /// No description provided for @merchantDriverStatusComing.
  ///
  /// In en, this message translates to:
  /// **'Driver: {name} is on the way'**
  String merchantDriverStatusComing(Object name);

  /// No description provided for @merchantDriverStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver: {name} has arrived'**
  String merchantDriverStatusArrived(Object name);

  /// No description provided for @merchantDriverStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Driver: Waiting for food preparation'**
  String get merchantDriverStatusPreparing;

  /// No description provided for @merchantDriverStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Driver: Waiting for food ready'**
  String get merchantDriverStatusReady;

  /// No description provided for @merchantDriverStatusDefault.
  ///
  /// In en, this message translates to:
  /// **'Driver: Processing'**
  String get merchantDriverStatusDefault;

  /// No description provided for @merchantDriverDefault.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get merchantDriverDefault;

  /// No description provided for @merchantStatusNewOrder.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get merchantStatusNewOrder;

  /// No description provided for @merchantStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get merchantStatusPending;

  /// No description provided for @merchantStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get merchantStatusPreparing;

  /// No description provided for @merchantStatusDriverAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get merchantStatusDriverAccepted;

  /// No description provided for @merchantStatusArrivedAtMerchant.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get merchantStatusArrivedAtMerchant;

  /// No description provided for @merchantStatusMatched.
  ///
  /// In en, this message translates to:
  /// **'Driver matched'**
  String get merchantStatusMatched;

  /// No description provided for @merchantStatusReadyForPickup.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get merchantStatusReadyForPickup;

  /// No description provided for @merchantStatusPickingUp.
  ///
  /// In en, this message translates to:
  /// **'Driver picking up'**
  String get merchantStatusPickingUp;

  /// No description provided for @merchantStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get merchantStatusInTransit;

  /// No description provided for @merchantStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get merchantStatusCompleted;

  /// No description provided for @merchantStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get merchantStatusCancelled;

  /// No description provided for @merchantStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get merchantStatusUnknown;

  /// No description provided for @merchantAppBarOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get merchantAppBarOrders;

  /// No description provided for @merchantAppBarHistory.
  ///
  /// In en, this message translates to:
  /// **'Order history'**
  String get merchantAppBarHistory;

  /// No description provided for @merchantTooltipActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'View active orders'**
  String get merchantTooltipActiveOrders;

  /// No description provided for @merchantTooltipHistory.
  ///
  /// In en, this message translates to:
  /// **'View order history'**
  String get merchantTooltipHistory;

  /// No description provided for @merchantRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Data refreshed'**
  String get merchantRefreshed;

  /// No description provided for @merchantErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get merchantErrorOccurred;

  /// No description provided for @merchantRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get merchantRetry;

  /// No description provided for @merchantNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No new orders'**
  String get merchantNoOrders;

  /// No description provided for @merchantOrdersWillAppear.
  ///
  /// In en, this message translates to:
  /// **'New orders will appear here instantly'**
  String get merchantOrdersWillAppear;

  /// No description provided for @merchantOpenShopToReceive.
  ///
  /// In en, this message translates to:
  /// **'Open shop to receive orders'**
  String get merchantOpenShopToReceive;

  /// No description provided for @merchantShopStatus.
  ///
  /// In en, this message translates to:
  /// **'Shop status'**
  String get merchantShopStatus;

  /// No description provided for @merchantShopOpen.
  ///
  /// In en, this message translates to:
  /// **'Shop open'**
  String get merchantShopOpen;

  /// No description provided for @merchantShopClosed2.
  ///
  /// In en, this message translates to:
  /// **'Shop closed'**
  String get merchantShopClosed2;

  /// No description provided for @merchantShopOpenDesc.
  ///
  /// In en, this message translates to:
  /// **'Customers can order food'**
  String get merchantShopOpenDesc;

  /// No description provided for @merchantShopClosedDesc.
  ///
  /// In en, this message translates to:
  /// **'Shop temporarily closed'**
  String get merchantShopClosedDesc;

  /// No description provided for @merchantAcceptModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto accept orders'**
  String get merchantAcceptModeAuto;

  /// No description provided for @merchantAcceptModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual accept orders'**
  String get merchantAcceptModeManual;

  /// No description provided for @merchantAutoScheduleOn.
  ///
  /// In en, this message translates to:
  /// **'Auto open/close: Enabled'**
  String get merchantAutoScheduleOn;

  /// No description provided for @merchantAutoScheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Auto open/close: Disabled'**
  String get merchantAutoScheduleOff;

  /// No description provided for @merchantAcceptOrder.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get merchantAcceptOrder;

  /// No description provided for @merchantPreparingFood.
  ///
  /// In en, this message translates to:
  /// **'Preparing food'**
  String get merchantPreparingFood;

  /// No description provided for @merchantTapForDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for details'**
  String get merchantTapForDetails;

  /// No description provided for @merchantDriverAcceptedCard.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get merchantDriverAcceptedCard;

  /// No description provided for @merchantCookingFood.
  ///
  /// In en, this message translates to:
  /// **'Cooking food'**
  String get merchantCookingFood;

  /// No description provided for @merchantDriverMatchedCard.
  ///
  /// In en, this message translates to:
  /// **'Driver matched'**
  String get merchantDriverMatchedCard;

  /// No description provided for @merchantDriverTravelingToShop.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way to shop'**
  String get merchantDriverTravelingToShop;

  /// No description provided for @merchantPrepareFood.
  ///
  /// In en, this message translates to:
  /// **'Please prepare the food'**
  String get merchantPrepareFood;

  /// No description provided for @merchantDriverArrivedCard.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived at shop'**
  String get merchantDriverArrivedCard;

  /// No description provided for @merchantDriverPickingUpCard.
  ///
  /// In en, this message translates to:
  /// **'Driver picking up order'**
  String get merchantDriverPickingUpCard;

  /// No description provided for @merchantDeliveringToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Delivering to customer'**
  String get merchantDeliveringToCustomer;

  /// No description provided for @merchantDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering food'**
  String get merchantDelivering;

  /// No description provided for @merchantOrderEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Order on the way to customer'**
  String get merchantOrderEnRoute;

  /// No description provided for @merchantDriverPickedUpCard.
  ///
  /// In en, this message translates to:
  /// **'Driver picked up order'**
  String get merchantDriverPickedUpCard;

  /// No description provided for @merchantOrderDoneForMerchant.
  ///
  /// In en, this message translates to:
  /// **'This order is done for the merchant'**
  String get merchantOrderDoneForMerchant;

  /// No description provided for @merchantAddressNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get merchantAddressNotSpecified;

  /// No description provided for @merchantAddressPinLocation.
  ///
  /// In en, this message translates to:
  /// **'📍 Customer pin location'**
  String get merchantAddressPinLocation;

  /// No description provided for @merchantScheduledOrder.
  ///
  /// In en, this message translates to:
  /// **'Scheduled order: {dateTime}'**
  String merchantScheduledOrder(Object dateTime);

  /// No description provided for @merchantPickupTime.
  ///
  /// In en, this message translates to:
  /// **'Pickup time: {dateTime}'**
  String merchantPickupTime(Object dateTime);

  /// No description provided for @merchantDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance {km} km'**
  String merchantDistance(Object km);

  /// No description provided for @merchantTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get merchantTimeJustNow;

  /// No description provided for @merchantTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String merchantTimeMinutesAgo(Object minutes);

  /// No description provided for @merchantTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String merchantTimeHoursAgo(Object hours);

  /// No description provided for @merchantTimeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String merchantTimeDaysAgo(Object days);

  /// No description provided for @merchantNotifMerchantDefault.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get merchantNotifMerchantDefault;

  /// No description provided for @merchantNotifOrderAccepted.
  ///
  /// In en, this message translates to:
  /// **'✅ Shop confirmed your order!'**
  String get merchantNotifOrderAccepted;

  /// No description provided for @merchantNotifPreparingBody.
  ///
  /// In en, this message translates to:
  /// **'{merchantName} is preparing your food'**
  String merchantNotifPreparingBody(Object merchantName);

  /// No description provided for @merchantNotifFoodReadyCustomer.
  ///
  /// In en, this message translates to:
  /// **'🍔 Food is ready!'**
  String get merchantNotifFoodReadyCustomer;

  /// No description provided for @merchantNotifFoodReadyCustomerBody.
  ///
  /// In en, this message translates to:
  /// **'{merchantName} finished preparing, waiting for driver pickup'**
  String merchantNotifFoodReadyCustomerBody(Object merchantName);

  /// No description provided for @merchantNotifFoodReadyDriver.
  ///
  /// In en, this message translates to:
  /// **'🍔 Food ready for pickup!'**
  String get merchantNotifFoodReadyDriver;

  /// No description provided for @merchantNotifFoodReadyDriverBody.
  ///
  /// In en, this message translates to:
  /// **'{merchantName} finished preparing, ready for pickup'**
  String merchantNotifFoodReadyDriverBody(Object merchantName);

  /// No description provided for @merchantViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View order history'**
  String get merchantViewHistory;

  /// No description provided for @merchantViewActive.
  ///
  /// In en, this message translates to:
  /// **'View active orders'**
  String get merchantViewActive;

  /// No description provided for @orderDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order {code}'**
  String orderDetailTitle(Object code);

  /// No description provided for @orderDetailDriverPhoneNotFound.
  ///
  /// In en, this message translates to:
  /// **'Driver phone not found'**
  String get orderDetailDriverPhoneNotFound;

  /// No description provided for @orderDetailLoadItemsError.
  ///
  /// In en, this message translates to:
  /// **'Cannot load food items: {error}'**
  String orderDetailLoadItemsError(Object error);

  /// No description provided for @orderDetailAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed!'**
  String get orderDetailAccepted;

  /// No description provided for @orderDetailAcceptFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept order'**
  String get orderDetailAcceptFailed;

  /// No description provided for @orderDetailAcceptError.
  ///
  /// In en, this message translates to:
  /// **'Cannot accept order: {error}'**
  String orderDetailAcceptError(Object error);

  /// No description provided for @orderDetailOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get orderDetailOk;

  /// No description provided for @orderDetailDeclined.
  ///
  /// In en, this message translates to:
  /// **'Order declined'**
  String get orderDetailDeclined;

  /// No description provided for @orderDetailDeclineFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline order'**
  String get orderDetailDeclineFailed;

  /// No description provided for @orderDetailDeclineError.
  ///
  /// In en, this message translates to:
  /// **'Cannot decline order: {error}'**
  String orderDetailDeclineError(Object error);

  /// No description provided for @orderDetailStatusUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot update status'**
  String get orderDetailStatusUpdateFailed;

  /// No description provided for @orderDetailFoodReady.
  ///
  /// In en, this message translates to:
  /// **'Food ready! Waiting for driver'**
  String get orderDetailFoodReady;

  /// No description provided for @orderDetailUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status'**
  String get orderDetailUpdateFailed;

  /// No description provided for @orderDetailUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Cannot update status: {error}'**
  String orderDetailUpdateError(Object error);

  /// No description provided for @orderDetailAddressNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get orderDetailAddressNotSpecified;

  /// No description provided for @orderDetailAddressPinLocation.
  ///
  /// In en, this message translates to:
  /// **'Customer pin location'**
  String get orderDetailAddressPinLocation;

  /// No description provided for @orderDetailOrderInfo.
  ///
  /// In en, this message translates to:
  /// **'Order information'**
  String get orderDetailOrderInfo;

  /// No description provided for @orderDetailOrderCode.
  ///
  /// In en, this message translates to:
  /// **'Order code'**
  String get orderDetailOrderCode;

  /// No description provided for @orderDetailOrderTime.
  ///
  /// In en, this message translates to:
  /// **'Order time'**
  String get orderDetailOrderTime;

  /// No description provided for @orderDetailPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get orderDetailPayment;

  /// No description provided for @orderDetailPaymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get orderDetailPaymentCash;

  /// No description provided for @orderDetailPaymentTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get orderDetailPaymentTransfer;

  /// No description provided for @orderDetailDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get orderDetailDistanceLabel;

  /// No description provided for @orderDetailScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get orderDetailScheduled;

  /// No description provided for @orderDetailPriceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Price breakdown'**
  String get orderDetailPriceBreakdown;

  /// No description provided for @orderDetailSalesAmount.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get orderDetailSalesAmount;

  /// No description provided for @orderDetailGpDeduction.
  ///
  /// In en, this message translates to:
  /// **'GP deduction ({percent}%)'**
  String orderDetailGpDeduction(Object percent);

  /// No description provided for @orderDetailNetReceived.
  ///
  /// In en, this message translates to:
  /// **'Net received'**
  String get orderDetailNetReceived;

  /// No description provided for @orderDetailDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get orderDetailDeliveryAddress;

  /// No description provided for @orderDetailCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Customer note'**
  String get orderDetailCustomerNote;

  /// No description provided for @orderDetailFoodItems.
  ///
  /// In en, this message translates to:
  /// **'Food items'**
  String get orderDetailFoodItems;

  /// No description provided for @orderDetailOptions.
  ///
  /// In en, this message translates to:
  /// **'Extras:'**
  String get orderDetailOptions;

  /// No description provided for @orderDetailDeclineBtn.
  ///
  /// In en, this message translates to:
  /// **'Decline order'**
  String get orderDetailDeclineBtn;

  /// No description provided for @orderDetailAcceptBtn.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get orderDetailAcceptBtn;

  /// No description provided for @orderDetailWaitingDriver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver'**
  String get orderDetailWaitingDriver;

  /// No description provided for @orderDetailWaitingDriverDesc.
  ///
  /// In en, this message translates to:
  /// **'Please wait for driver to accept\nbefore marking food as ready'**
  String get orderDetailWaitingDriverDesc;

  /// No description provided for @orderDetailFoodReadyBtn.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get orderDetailFoodReadyBtn;

  /// No description provided for @orderDetailStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String orderDetailStatusLabel(Object status);

  /// No description provided for @orderDetailStatusArrivedMerchant.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get orderDetailStatusArrivedMerchant;

  /// No description provided for @orderDetailStatusReadyPickup.
  ///
  /// In en, this message translates to:
  /// **'Food ready to deliver'**
  String get orderDetailStatusReadyPickup;

  /// No description provided for @orderDetailStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get orderDetailStatusUnknown;

  /// No description provided for @orderDetailCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'✅ Order completed'**
  String get orderDetailCompletionTitle;

  /// No description provided for @orderDetailCompletionBody.
  ///
  /// In en, this message translates to:
  /// **'Driver has picked up the food and is delivering to customer'**
  String get orderDetailCompletionBody;

  /// No description provided for @orderDetailCompletionOrderNum.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get orderDetailCompletionOrderNum;

  /// No description provided for @orderDetailCompletionCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get orderDetailCompletionCustomer;

  /// No description provided for @orderDetailCompletionNetReceived.
  ///
  /// In en, this message translates to:
  /// **'Net received'**
  String get orderDetailCompletionNetReceived;

  /// No description provided for @orderDetailCompletionAfterGP.
  ///
  /// In en, this message translates to:
  /// **'After GP deduction {percent}%'**
  String orderDetailCompletionAfterGP(Object percent);

  /// No description provided for @orderDetailCompletionOk.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get orderDetailCompletionOk;

  /// No description provided for @orderDetailCustomerDefault.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get orderDetailCustomerDefault;

  /// No description provided for @orderDetailItemNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get orderDetailItemNotSpecified;

  /// No description provided for @orderDetailNotifRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'❌ Shop declined order'**
  String get orderDetailNotifRejectTitle;

  /// No description provided for @orderDetailNotifRejectBody.
  ///
  /// In en, this message translates to:
  /// **'Sorry, the shop cannot accept your order at this time'**
  String get orderDetailNotifRejectBody;

  /// No description provided for @customerHomeOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get customerHomeOk;

  /// No description provided for @customerHomeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get customerHomeGreeting;

  /// No description provided for @customerHomeNoNewNotifications.
  ///
  /// In en, this message translates to:
  /// **'No new notifications'**
  String get customerHomeNoNewNotifications;

  /// No description provided for @customerHomeHelpToday.
  ///
  /// In en, this message translates to:
  /// **'What can we help you with today?'**
  String get customerHomeHelpToday;

  /// No description provided for @customerHomeAvailable247.
  ///
  /// In en, this message translates to:
  /// **'Available 24/7'**
  String get customerHomeAvailable247;

  /// No description provided for @customerHomeRealtimeTracking.
  ///
  /// In en, this message translates to:
  /// **'Real-time tracking'**
  String get customerHomeRealtimeTracking;

  /// No description provided for @customerHomePendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending orders'**
  String get customerHomePendingOrders;

  /// No description provided for @customerHomeJobCount.
  ///
  /// In en, this message translates to:
  /// **'{count} jobs'**
  String customerHomeJobCount(Object count);

  /// No description provided for @customerHomeNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No pending orders. Start a new service!'**
  String get customerHomeNoJobs;

  /// No description provided for @customerHomePopularServices.
  ///
  /// In en, this message translates to:
  /// **'Popular services'**
  String get customerHomePopularServices;

  /// No description provided for @customerHomeCallRide.
  ///
  /// In en, this message translates to:
  /// **'Call a ride'**
  String get customerHomeCallRide;

  /// No description provided for @customerHomeCallRideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast & safe'**
  String get customerHomeCallRideSubtitle;

  /// No description provided for @customerHomeOrderFood.
  ///
  /// In en, this message translates to:
  /// **'Order food'**
  String get customerHomeOrderFood;

  /// No description provided for @customerHomeOrderFoodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Order from nearby'**
  String get customerHomeOrderFoodSubtitle;

  /// No description provided for @customerHomeSendParcel.
  ///
  /// In en, this message translates to:
  /// **'Send parcel'**
  String get customerHomeSendParcel;

  /// No description provided for @customerHomeSendParcelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deliver to destination'**
  String get customerHomeSendParcelSubtitle;

  /// No description provided for @customerHomeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get customerHomeQuickActions;

  /// No description provided for @customerHomeHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get customerHomeHistory;

  /// No description provided for @customerHomeBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get customerHomeBookings;

  /// No description provided for @customerHomeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get customerHomeSaved;

  /// No description provided for @customerHomePlaces.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get customerHomePlaces;

  /// No description provided for @customerHomeHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get customerHomeHelp;

  /// No description provided for @customerHomeContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get customerHomeContactUs;

  /// No description provided for @customerHomeHelpDeveloping.
  ///
  /// In en, this message translates to:
  /// **'Help system under development'**
  String get customerHomeHelpDeveloping;

  /// No description provided for @customerHomePromotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get customerHomePromotions;

  /// No description provided for @customerHomeDiscountCode.
  ///
  /// In en, this message translates to:
  /// **'Discount code'**
  String get customerHomeDiscountCode;

  /// No description provided for @customerHomePromoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Use this code when ordering to get a discount'**
  String get customerHomePromoCodeHint;

  /// No description provided for @customerHomeClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get customerHomeClose;

  /// No description provided for @customerHomeCopiedCode.
  ///
  /// In en, this message translates to:
  /// **'Copied code \"{code}\"'**
  String customerHomeCopiedCode(Object code);

  /// No description provided for @customerHomeCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get customerHomeCopyCode;

  /// No description provided for @customerHomeOrderCode.
  ///
  /// In en, this message translates to:
  /// **'Order {code}'**
  String customerHomeOrderCode(Object code);

  /// No description provided for @customerHomeDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get customerHomeDestination;

  /// No description provided for @customerHomePickupPoint.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get customerHomePickupPoint;

  /// No description provided for @customerHomeDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String customerHomeDistanceKm(Object km);

  /// No description provided for @customerHomeOrderedAt.
  ///
  /// In en, this message translates to:
  /// **'Ordered: {datetime}'**
  String customerHomeOrderedAt(Object datetime);

  /// No description provided for @customerHomeStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get customerHomeStatusPending;

  /// No description provided for @customerHomeStatusPendingMerchant.
  ///
  /// In en, this message translates to:
  /// **'Waiting for merchant'**
  String get customerHomeStatusPendingMerchant;

  /// No description provided for @customerHomeStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing food'**
  String get customerHomeStatusPreparing;

  /// No description provided for @customerHomeStatusReadyPickup.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get customerHomeStatusReadyPickup;

  /// No description provided for @customerHomeStatusDriverAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get customerHomeStatusDriverAccepted;

  /// No description provided for @customerHomeStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get customerHomeStatusConfirmed;

  /// No description provided for @customerHomeStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived at pickup'**
  String get customerHomeStatusArrived;

  /// No description provided for @customerHomeStatusArrivedMerchant.
  ///
  /// In en, this message translates to:
  /// **'Driver at merchant'**
  String get customerHomeStatusArrivedMerchant;

  /// No description provided for @customerHomeStatusMatched.
  ///
  /// In en, this message translates to:
  /// **'Driver matched'**
  String get customerHomeStatusMatched;

  /// No description provided for @customerHomeStatusPickingUp.
  ///
  /// In en, this message translates to:
  /// **'Picking up food'**
  String get customerHomeStatusPickingUp;

  /// No description provided for @customerHomeStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get customerHomeStatusInTransit;

  /// No description provided for @customerHomeStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get customerHomeStatusCompleted;

  /// No description provided for @customerHomeStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get customerHomeStatusCancelled;

  /// No description provided for @customerHomeAddressNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Address not specified'**
  String get customerHomeAddressNotSpecified;

  /// No description provided for @customerHomeCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get customerHomeCurrentLocation;

  /// No description provided for @rideStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Status'**
  String get rideStatusTitle;

  /// No description provided for @rideStatusDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get rideStatusDriver;

  /// No description provided for @rideStatusCannotCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot call {phone}'**
  String rideStatusCannotCall(Object phone);

  /// No description provided for @rideStatusCannotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Cannot open chat'**
  String get rideStatusCannotOpenChat;

  /// No description provided for @rideStatusEnableLocation.
  ///
  /// In en, this message translates to:
  /// **'Please enable Location Service'**
  String get rideStatusEnableLocation;

  /// No description provided for @rideStatusAllowLocation.
  ///
  /// In en, this message translates to:
  /// **'Please allow location access'**
  String get rideStatusAllowLocation;

  /// No description provided for @rideStatusLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Cannot access location'**
  String get rideStatusLocationDenied;

  /// No description provided for @rideStatusLocationDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'Please enable location access in device settings'**
  String get rideStatusLocationDeniedBody;

  /// No description provided for @rideStatusOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get rideStatusOk;

  /// No description provided for @rideStatusOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get rideStatusOpenSettings;

  /// No description provided for @rideStatusMerchantMarker.
  ///
  /// In en, this message translates to:
  /// **'Merchant: {address}'**
  String rideStatusMerchantMarker(Object address);

  /// No description provided for @rideStatusMerchantDefault.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get rideStatusMerchantDefault;

  /// No description provided for @rideStatusPickupMarker.
  ///
  /// In en, this message translates to:
  /// **'Pickup: {address}'**
  String rideStatusPickupMarker(Object address);

  /// No description provided for @rideStatusPickupDefault.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get rideStatusPickupDefault;

  /// No description provided for @rideStatusYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get rideStatusYourLocation;

  /// No description provided for @rideStatusDestMarker.
  ///
  /// In en, this message translates to:
  /// **'Destination: {address}'**
  String rideStatusDestMarker(Object address);

  /// No description provided for @rideStatusDestDefault.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get rideStatusDestDefault;

  /// No description provided for @rideStatusDriverInfo.
  ///
  /// In en, this message translates to:
  /// **'Driver info'**
  String get rideStatusDriverInfo;

  /// No description provided for @rideStatusMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get rideStatusMotorcycle;

  /// No description provided for @rideStatusCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get rideStatusCall;

  /// No description provided for @rideStatusChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get rideStatusChat;

  /// No description provided for @rideStatusFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get rideStatusFoodCost;

  /// No description provided for @rideStatusDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get rideStatusDeliveryFee;

  /// No description provided for @rideStatusCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get rideStatusCouponDiscount;

  /// No description provided for @rideStatusCouponDiscountWithCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon ({code})'**
  String rideStatusCouponDiscountWithCode(Object code);

  /// No description provided for @rideStatusDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get rideStatusDistance;

  /// No description provided for @rideStatusDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String rideStatusDistanceKm(Object km);

  /// No description provided for @rideStatusGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand total'**
  String get rideStatusGrandTotal;

  /// No description provided for @rideStatusServiceFee.
  ///
  /// In en, this message translates to:
  /// **'Service fee'**
  String get rideStatusServiceFee;

  /// No description provided for @rideStatusTripCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get rideStatusTripCompleted;

  /// No description provided for @rideStatusCancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get rideStatusCancelTrip;

  /// No description provided for @rideStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get rideStatusAccepted;

  /// No description provided for @rideStatusDriverGoingPickup.
  ///
  /// In en, this message translates to:
  /// **'Driver going to pick up food'**
  String get rideStatusDriverGoingPickup;

  /// No description provided for @rideStatusArrivedPickup.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived at pickup'**
  String get rideStatusArrivedPickup;

  /// No description provided for @rideStatusArrivedMerchant.
  ///
  /// In en, this message translates to:
  /// **'Driver at merchant'**
  String get rideStatusArrivedMerchant;

  /// No description provided for @rideStatusFoodReady.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get rideStatusFoodReady;

  /// No description provided for @rideStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Driver picked up food'**
  String get rideStatusPickedUp;

  /// No description provided for @rideStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get rideStatusInTransit;

  /// No description provided for @rideStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get rideStatusCompleted;

  /// No description provided for @rideStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get rideStatusPending;

  /// No description provided for @rideStatusDriverComing.
  ///
  /// In en, this message translates to:
  /// **'Driver is coming'**
  String get rideStatusDriverComing;

  /// No description provided for @rideStatusDriverGoingFood.
  ///
  /// In en, this message translates to:
  /// **'Driver going to pick up food'**
  String get rideStatusDriverGoingFood;

  /// No description provided for @rideStatusDriverArrivedPickup.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived at pickup'**
  String get rideStatusDriverArrivedPickup;

  /// No description provided for @rideStatusDriverAtMerchantWaiting.
  ///
  /// In en, this message translates to:
  /// **'Driver at merchant, waiting for food'**
  String get rideStatusDriverAtMerchantWaiting;

  /// No description provided for @rideStatusFoodReadyDriverPickup.
  ///
  /// In en, this message translates to:
  /// **'Food ready, driver picking up'**
  String get rideStatusFoodReadyDriverPickup;

  /// No description provided for @rideStatusDriverPickedUpDelivering.
  ///
  /// In en, this message translates to:
  /// **'Driver picked up, on the way'**
  String get rideStatusDriverPickedUpDelivering;

  /// No description provided for @rideStatusNavigating.
  ///
  /// In en, this message translates to:
  /// **'Navigating to destination'**
  String get rideStatusNavigating;

  /// No description provided for @rideStatusDriverCompleted.
  ///
  /// In en, this message translates to:
  /// **'Trip completed'**
  String get rideStatusDriverCompleted;

  /// No description provided for @rideStatusWaitingDriver.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver'**
  String get rideStatusWaitingDriver;

  /// No description provided for @rideStatusMerchantRejected.
  ///
  /// In en, this message translates to:
  /// **'Merchant declined order'**
  String get rideStatusMerchantRejected;

  /// No description provided for @rideStatusMerchantRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Sorry, the merchant cannot accept your order at this time.\n\nPlease try ordering again or choose another restaurant.'**
  String get rideStatusMerchantRejectedBody;

  /// No description provided for @rideStatusUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get rideStatusUnderstood;

  /// No description provided for @rideStatusDeliverySuccess.
  ///
  /// In en, this message translates to:
  /// **'🎉 Delivery successful!'**
  String get rideStatusDeliverySuccess;

  /// No description provided for @rideStatusTripSuccess.
  ///
  /// In en, this message translates to:
  /// **'🎉 Trip completed!'**
  String get rideStatusTripSuccess;

  /// No description provided for @rideStatusThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for using our service'**
  String get rideStatusThankYou;

  /// No description provided for @rideStatusOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order number'**
  String get rideStatusOrderNumber;

  /// No description provided for @rideStatusTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get rideStatusTotalAmount;

  /// No description provided for @rideStatusIncludingDelivery.
  ///
  /// In en, this message translates to:
  /// **'Including delivery'**
  String get rideStatusIncludingDelivery;

  /// No description provided for @rideStatusUsedCouponWithCode.
  ///
  /// In en, this message translates to:
  /// **'Used coupon {code} discount ฿{amount}'**
  String rideStatusUsedCouponWithCode(Object code, Object amount);

  /// No description provided for @rideStatusUsedCoupon.
  ///
  /// In en, this message translates to:
  /// **'Used coupon discount ฿{amount}'**
  String rideStatusUsedCoupon(Object amount);

  /// No description provided for @rideStatusCancelTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get rideStatusCancelTripTitle;

  /// No description provided for @rideStatusCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to cancel this trip?'**
  String get rideStatusCancelConfirm;

  /// No description provided for @rideStatusNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get rideStatusNo;

  /// No description provided for @rideStatusYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get rideStatusYes;

  /// No description provided for @rideStatusCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Trip cancelled successfully'**
  String get rideStatusCancelSuccess;

  /// No description provided for @rideStatusCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed'**
  String get rideStatusCancelFailed;

  /// No description provided for @rideStatusCancelError.
  ///
  /// In en, this message translates to:
  /// **'Error cancelling: {error}'**
  String rideStatusCancelError(Object error);

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity History'**
  String get activityTitle;

  /// No description provided for @activityPaymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get activityPaymentCash;

  /// No description provided for @activityPaymentTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get activityPaymentTransfer;

  /// No description provided for @activityPaymentCard.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get activityPaymentCard;

  /// No description provided for @activityPaymentUnknown.
  ///
  /// In en, this message translates to:
  /// **'Payment not specified'**
  String get activityPaymentUnknown;

  /// No description provided for @activityDatePickerHelp.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get activityDatePickerHelp;

  /// No description provided for @activityDatePickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get activityDatePickerConfirm;

  /// No description provided for @activityDatePickerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get activityDatePickerCancel;

  /// No description provided for @activityFilterToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get activityFilterToday;

  /// No description provided for @activityFilterLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get activityFilterLast7Days;

  /// No description provided for @activityFilterLast7DaysShort.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get activityFilterLast7DaysShort;

  /// No description provided for @activityFilterThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get activityFilterThisMonth;

  /// No description provided for @activityFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityFilterAll;

  /// No description provided for @activityFilterDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get activityFilterDateRange;

  /// No description provided for @activityTimeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get activityTimeUnknown;

  /// No description provided for @activityTimeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String activityTimeHoursAgo(Object hours);

  /// No description provided for @activityTimeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes ago'**
  String activityTimeMinutesAgo(Object minutes);

  /// No description provided for @activityTimeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get activityTimeJustNow;

  /// No description provided for @activityServiceRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get activityServiceRide;

  /// No description provided for @activityServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food order'**
  String get activityServiceFood;

  /// No description provided for @activityServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel'**
  String get activityServiceParcel;

  /// No description provided for @activityFilterByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by date'**
  String get activityFilterByDate;

  /// No description provided for @activityOrderStats.
  ///
  /// In en, this message translates to:
  /// **'Order statistics'**
  String get activityOrderStats;

  /// No description provided for @activityTimePeriod.
  ///
  /// In en, this message translates to:
  /// **'Period: {period}'**
  String activityTimePeriod(Object period);

  /// No description provided for @activityStatTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get activityStatTotal;

  /// No description provided for @activityStatItems.
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String activityStatItems(Object count);

  /// No description provided for @activityStatCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get activityStatCompleted;

  /// No description provided for @activityStatCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get activityStatCancelled;

  /// No description provided for @activityStatTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get activityStatTotalSpent;

  /// No description provided for @activityStatCouponSavings.
  ///
  /// In en, this message translates to:
  /// **'Coupon savings'**
  String get activityStatCouponSavings;

  /// No description provided for @activityFilteredEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items in selected date range'**
  String get activityFilteredEmpty;

  /// No description provided for @activityFilteredEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Try changing the date filter to see more order history'**
  String get activityFilteredEmptyHint;

  /// No description provided for @activityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load data'**
  String get activityLoadFailed;

  /// No description provided for @activityNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get activityNoHistory;

  /// No description provided for @activityNoHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Your booking history will appear here'**
  String get activityNoHistoryHint;

  /// No description provided for @activityBookingCode.
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String activityBookingCode(Object code);

  /// No description provided for @activityDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String activityDistanceKm(Object km);

  /// No description provided for @activityScheduledService.
  ///
  /// In en, this message translates to:
  /// **'Scheduled service: {datetime}'**
  String activityScheduledService(Object datetime);

  /// No description provided for @activityScheduledOrder.
  ///
  /// In en, this message translates to:
  /// **'Scheduled order: {datetime}'**
  String activityScheduledOrder(Object datetime);

  /// No description provided for @activityAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get activityAmountPaid;

  /// No description provided for @activityViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get activityViewDetails;

  /// No description provided for @activityStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get activityStatusCompleted;

  /// No description provided for @activityStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get activityStatusCancelled;

  /// No description provided for @activityStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get activityStatusConfirmed;

  /// No description provided for @activityStatusDriverAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get activityStatusDriverAccepted;

  /// No description provided for @activityStatusInTransit.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get activityStatusInTransit;

  /// No description provided for @activityStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing food'**
  String get activityStatusPreparing;

  /// No description provided for @activityStatusReadyPickup.
  ///
  /// In en, this message translates to:
  /// **'Food ready'**
  String get activityStatusReadyPickup;

  /// No description provided for @activityStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get activityStatusArrived;

  /// No description provided for @activityStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get activityStatusPending;

  /// No description provided for @activityAddressNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get activityAddressNotSpecified;

  /// No description provided for @activityAddressFallback.
  ///
  /// In en, this message translates to:
  /// **'Destination address'**
  String get activityAddressFallback;

  /// No description provided for @activityUsedCouponWithCode.
  ///
  /// In en, this message translates to:
  /// **'Used coupon {code} discount ฿{amount}'**
  String activityUsedCouponWithCode(Object code, Object amount);

  /// No description provided for @activityUsedCoupon.
  ///
  /// In en, this message translates to:
  /// **'Used coupon discount ฿{amount}'**
  String activityUsedCoupon(Object amount);

  /// No description provided for @parcelTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Parcel'**
  String get parcelTitle;

  /// No description provided for @parcelHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel Delivery'**
  String get parcelHeaderTitle;

  /// No description provided for @parcelHeaderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast and safe delivery to your door'**
  String get parcelHeaderSubtitle;

  /// No description provided for @parcelSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small (S)'**
  String get parcelSizeSmall;

  /// No description provided for @parcelSizeSmallDesc.
  ///
  /// In en, this message translates to:
  /// **'Envelopes, documents'**
  String get parcelSizeSmallDesc;

  /// No description provided for @parcelSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (M)'**
  String get parcelSizeMedium;

  /// No description provided for @parcelSizeMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Parcel box up to 5 kg'**
  String get parcelSizeMediumDesc;

  /// No description provided for @parcelSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large (L)'**
  String get parcelSizeLarge;

  /// No description provided for @parcelSizeLargeDesc.
  ///
  /// In en, this message translates to:
  /// **'Large box up to 15 kg'**
  String get parcelSizeLargeDesc;

  /// No description provided for @parcelSizeXLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra (XL)'**
  String get parcelSizeXLarge;

  /// No description provided for @parcelSizeXLargeDesc.
  ///
  /// In en, this message translates to:
  /// **'Large items up to 30 kg'**
  String get parcelSizeXLargeDesc;

  /// No description provided for @parcelPickupCoord.
  ///
  /// In en, this message translates to:
  /// **'Pickup ({lat}, {lng})'**
  String parcelPickupCoord(Object lat, Object lng);

  /// No description provided for @parcelDropoffCoord.
  ///
  /// In en, this message translates to:
  /// **'Drop-off ({lat}, {lng})'**
  String parcelDropoffCoord(Object lat, Object lng);

  /// No description provided for @parcelCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location ({lat}, {lng})'**
  String parcelCurrentLocation(Object lat, Object lng);

  /// No description provided for @parcelErrorNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Please wait for location\nor enable GPS and try again'**
  String get parcelErrorNoLocation;

  /// No description provided for @parcelErrorNoDrivers.
  ///
  /// In en, this message translates to:
  /// **'No online drivers found within {radius} km\nPlease try again later'**
  String parcelErrorNoDrivers(Object radius);

  /// No description provided for @parcelErrorCreateBooking.
  ///
  /// In en, this message translates to:
  /// **'Cannot create booking'**
  String get parcelErrorCreateBooking;

  /// No description provided for @parcelErrorBookFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot book parcel delivery\nPlease try again'**
  String get parcelErrorBookFailed;

  /// No description provided for @parcelErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get parcelErrorTitle;

  /// No description provided for @parcelOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get parcelOk;

  /// No description provided for @parcelDriversFound.
  ///
  /// In en, this message translates to:
  /// **'Found {count} online drivers near you (within {radius} km)'**
  String parcelDriversFound(Object count, Object radius);

  /// No description provided for @parcelNoDriversNearby.
  ///
  /// In en, this message translates to:
  /// **'No online drivers found within {radius} km'**
  String parcelNoDriversNearby(Object radius);

  /// No description provided for @parcelSenderInfo.
  ///
  /// In en, this message translates to:
  /// **'Sender info'**
  String get parcelSenderInfo;

  /// No description provided for @parcelSenderName.
  ///
  /// In en, this message translates to:
  /// **'Sender name'**
  String get parcelSenderName;

  /// No description provided for @parcelSenderNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify sender name'**
  String get parcelSenderNameRequired;

  /// No description provided for @parcelSenderPhone.
  ///
  /// In en, this message translates to:
  /// **'Sender phone'**
  String get parcelSenderPhone;

  /// No description provided for @parcelSenderPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify sender phone'**
  String get parcelSenderPhoneRequired;

  /// No description provided for @parcelPickupAddress.
  ///
  /// In en, this message translates to:
  /// **'Pickup address'**
  String get parcelPickupAddress;

  /// No description provided for @parcelPickupRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify pickup location'**
  String get parcelPickupRequired;

  /// No description provided for @parcelPinPickup.
  ///
  /// In en, this message translates to:
  /// **'Pin pickup on map'**
  String get parcelPinPickup;

  /// No description provided for @parcelPickupCoords.
  ///
  /// In en, this message translates to:
  /// **'Pickup coordinates: {lat}, {lng}'**
  String parcelPickupCoords(Object lat, Object lng);

  /// No description provided for @parcelRecipientInfo.
  ///
  /// In en, this message translates to:
  /// **'Recipient info'**
  String get parcelRecipientInfo;

  /// No description provided for @parcelSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved addresses'**
  String get parcelSavedAddresses;

  /// No description provided for @parcelPinDropoff.
  ///
  /// In en, this message translates to:
  /// **'Pin drop-off on map'**
  String get parcelPinDropoff;

  /// No description provided for @parcelRecipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient name'**
  String get parcelRecipientName;

  /// No description provided for @parcelRecipientNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify recipient name'**
  String get parcelRecipientNameRequired;

  /// No description provided for @parcelRecipientPhone.
  ///
  /// In en, this message translates to:
  /// **'Recipient phone'**
  String get parcelRecipientPhone;

  /// No description provided for @parcelRecipientPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify recipient phone'**
  String get parcelRecipientPhoneRequired;

  /// No description provided for @parcelDropoffAddress.
  ///
  /// In en, this message translates to:
  /// **'Drop-off address'**
  String get parcelDropoffAddress;

  /// No description provided for @parcelDropoffRequired.
  ///
  /// In en, this message translates to:
  /// **'Please specify drop-off location'**
  String get parcelDropoffRequired;

  /// No description provided for @parcelEstimatedDistance.
  ///
  /// In en, this message translates to:
  /// **'Estimated distance: {km} km'**
  String parcelEstimatedDistance(Object km);

  /// No description provided for @parcelDropoffCoords.
  ///
  /// In en, this message translates to:
  /// **'Drop-off coordinates: {lat}, {lng}'**
  String parcelDropoffCoords(Object lat, Object lng);

  /// No description provided for @parcelSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel size'**
  String get parcelSizeTitle;

  /// No description provided for @parcelDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel details'**
  String get parcelDetailsTitle;

  /// No description provided for @parcelDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Describe items (e.g. documents, food, clothes)'**
  String get parcelDescriptionLabel;

  /// No description provided for @parcelDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe items'**
  String get parcelDescriptionRequired;

  /// No description provided for @parcelWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated weight (kg) - optional'**
  String get parcelWeightLabel;

  /// No description provided for @parcelPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel photo'**
  String get parcelPhotoTitle;

  /// No description provided for @parcelPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the parcel for the driver (optional)'**
  String get parcelPhotoHint;

  /// No description provided for @parcelPhotoTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to take or select photo'**
  String get parcelPhotoTap;

  /// No description provided for @parcelEstimatedFee.
  ///
  /// In en, this message translates to:
  /// **'Estimated service fee'**
  String get parcelEstimatedFee;

  /// No description provided for @parcelDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'Distance {km} km'**
  String parcelDistanceKm(Object km);

  /// No description provided for @parcelBookButton.
  ///
  /// In en, this message translates to:
  /// **'Book Parcel Delivery'**
  String get parcelBookButton;

  /// No description provided for @waitingSearchingDriver.
  ///
  /// In en, this message translates to:
  /// **'Searching for driver...'**
  String get waitingSearchingDriver;

  /// No description provided for @waitingPriceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Price updated'**
  String get waitingPriceUpdated;

  /// No description provided for @waitingPriceAdjustedBody.
  ///
  /// In en, this message translates to:
  /// **'The price has been adjusted because the driver who accepted is beyond the set distance\n\nOriginal price: ฿{oldPrice}\nNew price: ฿{newPrice}\n\nDo you want to continue?'**
  String waitingPriceAdjustedBody(Object oldPrice, Object newPrice);

  /// No description provided for @waitingCancelJob.
  ///
  /// In en, this message translates to:
  /// **'Cancel job'**
  String get waitingCancelJob;

  /// No description provided for @waitingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get waitingContinue;

  /// No description provided for @waitingConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error, retrying...'**
  String get waitingConnectionError;

  /// No description provided for @waitingConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get waitingConnectionFailed;

  /// No description provided for @waitingCannotConnect.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server: {error}'**
  String waitingCannotConnect(Object error);

  /// No description provided for @waitingOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get waitingOk;

  /// No description provided for @waitingDriverFallback.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get waitingDriverFallback;

  /// No description provided for @waitingMotorcycleFallback.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get waitingMotorcycleFallback;

  /// No description provided for @waitingMerchantRejected.
  ///
  /// In en, this message translates to:
  /// **'Merchant rejected order'**
  String get waitingMerchantRejected;

  /// No description provided for @waitingMerchantRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Sorry, the merchant cannot accept your order at this time.\n\nPlease try ordering again or choose another restaurant.'**
  String get waitingMerchantRejectedBody;

  /// No description provided for @waitingUnderstood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get waitingUnderstood;

  /// No description provided for @waitingForMerchant.
  ///
  /// In en, this message translates to:
  /// **'Waiting for merchant'**
  String get waitingForMerchant;

  /// No description provided for @waitingSearchingForDriver.
  ///
  /// In en, this message translates to:
  /// **'Searching for driver'**
  String get waitingSearchingForDriver;

  /// No description provided for @waitingMerchantConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Merchant confirmed order!'**
  String get waitingMerchantConfirmed;

  /// No description provided for @waitingDriverFound.
  ///
  /// In en, this message translates to:
  /// **'Driver found!'**
  String get waitingDriverFound;

  /// No description provided for @waitingForMerchantDots.
  ///
  /// In en, this message translates to:
  /// **'Waiting for merchant...'**
  String get waitingForMerchantDots;

  /// No description provided for @waitingSearchingDriverDots.
  ///
  /// In en, this message translates to:
  /// **'Searching for driver...'**
  String get waitingSearchingDriverDots;

  /// No description provided for @waitingMerchantPreparing.
  ///
  /// In en, this message translates to:
  /// **'Merchant is preparing your food'**
  String get waitingMerchantPreparing;

  /// No description provided for @waitingDriverComing.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way to you'**
  String get waitingDriverComing;

  /// No description provided for @waitingEstimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated time {minutes} minutes'**
  String waitingEstimatedTime(Object minutes);

  /// No description provided for @waitingRestaurantPreparing.
  ///
  /// In en, this message translates to:
  /// **'Restaurant preparing food'**
  String get waitingRestaurantPreparing;

  /// No description provided for @waitingPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment...'**
  String get waitingPleaseWait;

  /// No description provided for @waitingAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get waitingAssigned;

  /// No description provided for @waitingContactDriver.
  ///
  /// In en, this message translates to:
  /// **'Contact driver'**
  String get waitingContactDriver;

  /// No description provided for @waitingCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get waitingCancelBooking;

  /// No description provided for @waitingPhoneCall.
  ///
  /// In en, this message translates to:
  /// **'Phone call'**
  String get waitingPhoneCall;

  /// No description provided for @waitingChatWithDriver.
  ///
  /// In en, this message translates to:
  /// **'Chat with driver'**
  String get waitingChatWithDriver;

  /// No description provided for @waitingChatInApp.
  ///
  /// In en, this message translates to:
  /// **'Send message in app'**
  String get waitingChatInApp;

  /// No description provided for @waitingClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get waitingClose;

  /// No description provided for @waitingCannotCall.
  ///
  /// In en, this message translates to:
  /// **'Cannot call {phone}'**
  String waitingCannotCall(Object phone);

  /// No description provided for @waitingCannotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Cannot open chat'**
  String get waitingCannotOpenChat;

  /// No description provided for @waitingCancelBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get waitingCancelBookingTitle;

  /// No description provided for @waitingCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this booking?'**
  String get waitingCancelConfirm;

  /// No description provided for @waitingNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get waitingNo;

  /// No description provided for @waitingCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed'**
  String get waitingCancelFailed;

  /// No description provided for @waitingCancelError.
  ///
  /// In en, this message translates to:
  /// **'Error cancelling: {error}'**
  String waitingCancelError(Object error);

  /// No description provided for @waitingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get waitingCancel;

  /// No description provided for @waitingBookingInfo.
  ///
  /// In en, this message translates to:
  /// **'Booking info'**
  String get waitingBookingInfo;

  /// No description provided for @waitingOrderCode.
  ///
  /// In en, this message translates to:
  /// **'Order code: {code}'**
  String waitingOrderCode(Object code);

  /// No description provided for @waitingType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String waitingType(Object type);

  /// No description provided for @waitingPrice.
  ///
  /// In en, this message translates to:
  /// **'Price: ฿{price}'**
  String waitingPrice(Object price);

  /// No description provided for @waitingStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String waitingStatus(Object status);

  /// No description provided for @restCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get restCategoryOther;

  /// No description provided for @restDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'20-30 min'**
  String get restDeliveryTime;

  /// No description provided for @restDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery ฿15'**
  String get restDeliveryFee;

  /// No description provided for @restCouponCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied code {code}'**
  String restCouponCopied(Object code);

  /// No description provided for @restCouponHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to copy code for checkout'**
  String get restCouponHint;

  /// No description provided for @restNoMenu.
  ///
  /// In en, this message translates to:
  /// **'No menu available at this time'**
  String get restNoMenu;

  /// No description provided for @restRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get restRefresh;

  /// No description provided for @restCannotLoadMenu.
  ///
  /// In en, this message translates to:
  /// **'Cannot load menu'**
  String get restCannotLoadMenu;

  /// No description provided for @restTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get restTryAgain;

  /// No description provided for @restRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get restRetry;

  /// No description provided for @restSwitchRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Switch restaurant?'**
  String get restSwitchRestaurant;

  /// No description provided for @restSwitchRestaurantBody.
  ///
  /// In en, this message translates to:
  /// **'Cart has food from \"{name}\"\nClear cart and order from this restaurant instead?'**
  String restSwitchRestaurantBody(Object name);

  /// No description provided for @restCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get restCancel;

  /// No description provided for @restClearAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Clear and add'**
  String get restClearAndAdd;

  /// No description provided for @restAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to cart'**
  String restAddedToCart(Object name);

  /// No description provided for @restViewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get restViewCart;

  /// No description provided for @restYourCart.
  ///
  /// In en, this message translates to:
  /// **'Your cart'**
  String get restYourCart;

  /// No description provided for @restClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get restClear;

  /// No description provided for @restTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get restTotal;

  /// No description provided for @restGoToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Go to checkout — ฿{amount}'**
  String restGoToCheckout(Object amount);

  /// No description provided for @restItemNoName.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get restItemNoName;

  /// No description provided for @restMustSelectOption.
  ///
  /// In en, this message translates to:
  /// **'Must select option'**
  String get restMustSelectOption;

  /// No description provided for @ratingPleaseRateDriver.
  ///
  /// In en, this message translates to:
  /// **'Please rate the driver'**
  String get ratingPleaseRateDriver;

  /// No description provided for @ratingPleaseRateMerchant.
  ///
  /// In en, this message translates to:
  /// **'Please rate the merchant'**
  String get ratingPleaseRateMerchant;

  /// No description provided for @ratingUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get ratingUserNotFound;

  /// No description provided for @ratingError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String ratingError(Object error);

  /// No description provided for @ratingThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for rating!'**
  String get ratingThankYou;

  /// No description provided for @ratingFeedbackHelps.
  ///
  /// In en, this message translates to:
  /// **'Your feedback helps improve our service'**
  String get ratingFeedbackHelps;

  /// No description provided for @ratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get ratingTitle;

  /// No description provided for @ratingRateDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate driver'**
  String get ratingRateDriver;

  /// No description provided for @ratingDriverHint.
  ///
  /// In en, this message translates to:
  /// **'Comment about the driver (optional)'**
  String get ratingDriverHint;

  /// No description provided for @ratingRateMerchant.
  ///
  /// In en, this message translates to:
  /// **'Rate merchant'**
  String get ratingRateMerchant;

  /// No description provided for @ratingMerchantHint.
  ///
  /// In en, this message translates to:
  /// **'Comment about the merchant (optional)'**
  String get ratingMerchantHint;

  /// No description provided for @ratingSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get ratingSubmit;

  /// No description provided for @ratingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get ratingSkip;

  /// No description provided for @ratingServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food order'**
  String get ratingServiceFood;

  /// No description provided for @ratingServiceRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get ratingServiceRide;

  /// No description provided for @ratingServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get ratingServiceParcel;

  /// No description provided for @ratingLabel1.
  ///
  /// In en, this message translates to:
  /// **'Very bad'**
  String get ratingLabel1;

  /// No description provided for @ratingLabel2.
  ///
  /// In en, this message translates to:
  /// **'Bad'**
  String get ratingLabel2;

  /// No description provided for @ratingLabel3.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get ratingLabel3;

  /// No description provided for @ratingLabel4.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingLabel4;

  /// No description provided for @ratingLabel5.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingLabel5;

  /// No description provided for @cancelReasonWaitTooLong.
  ///
  /// In en, this message translates to:
  /// **'Waited too long'**
  String get cancelReasonWaitTooLong;

  /// No description provided for @cancelReasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'Changed mind, no longer needed'**
  String get cancelReasonChangedMind;

  /// No description provided for @cancelReasonWrongAddress.
  ///
  /// In en, this message translates to:
  /// **'Wrong address'**
  String get cancelReasonWrongAddress;

  /// No description provided for @cancelReasonPriceTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Price too high'**
  String get cancelReasonPriceTooHigh;

  /// No description provided for @cancelReasonWrongOrder.
  ///
  /// In en, this message translates to:
  /// **'Ordered wrong items'**
  String get cancelReasonWrongOrder;

  /// No description provided for @cancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other reason'**
  String get cancelReasonOther;

  /// No description provided for @cancelSelectReason.
  ///
  /// In en, this message translates to:
  /// **'Please select a cancellation reason'**
  String get cancelSelectReason;

  /// No description provided for @cancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get cancelConfirmTitle;

  /// No description provided for @cancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get cancelConfirmBody;

  /// No description provided for @cancelReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String cancelReasonLabel(Object reason);

  /// No description provided for @cancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Don\'t cancel'**
  String get cancelKeep;

  /// No description provided for @cancelConfirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm cancel'**
  String get cancelConfirmBtn;

  /// No description provided for @cancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled successfully'**
  String get cancelSuccess;

  /// No description provided for @cancelError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String cancelError(Object error);

  /// No description provided for @cancelServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food order'**
  String get cancelServiceFood;

  /// No description provided for @cancelServiceRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get cancelServiceRide;

  /// No description provided for @cancelServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get cancelServiceParcel;

  /// No description provided for @cancelServiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get cancelServiceDefault;

  /// No description provided for @cancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelTitle;

  /// No description provided for @cancelReasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get cancelReasonsTitle;

  /// No description provided for @cancelReasonsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason to help us improve'**
  String get cancelReasonsSubtitle;

  /// No description provided for @cancelOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Please specify reason...'**
  String get cancelOtherHint;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelButton;

  /// No description provided for @addrLabelHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get addrLabelHome;

  /// No description provided for @addrLabelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get addrLabelWork;

  /// No description provided for @addrLabelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addrLabelOther;

  /// No description provided for @addrEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get addrEditTitle;

  /// No description provided for @addrAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add new address'**
  String get addrAddTitle;

  /// No description provided for @addrType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get addrType;

  /// No description provided for @addrPlaceName.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get addrPlaceName;

  /// No description provided for @addrPlaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Parents\' house, Condo'**
  String get addrPlaceNameHint;

  /// No description provided for @addrPinPlaced.
  ///
  /// In en, this message translates to:
  /// **'Pin placed'**
  String get addrPinPlaced;

  /// No description provided for @addrPinOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pin on map'**
  String get addrPinOnMap;

  /// No description provided for @addrAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address (additional details)'**
  String get addrAddressLabel;

  /// No description provided for @addrAddressHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 123/4 Main Street'**
  String get addrAddressHint;

  /// No description provided for @addrNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get addrNoteLabel;

  /// No description provided for @addrNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Building A, Floor 5, Room 501'**
  String get addrNoteHint;

  /// No description provided for @addrCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get addrCancel;

  /// No description provided for @addrValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter place name and pin on map'**
  String get addrValidation;

  /// No description provided for @addrSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get addrSave;

  /// No description provided for @addrDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete address'**
  String get addrDeleteTitle;

  /// No description provided for @addrDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete \"{name}\"?'**
  String addrDeleteConfirm(Object name);

  /// No description provided for @addrDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get addrDelete;

  /// No description provided for @addrPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose address'**
  String get addrPickTitle;

  /// No description provided for @addrBookTitle.
  ///
  /// In en, this message translates to:
  /// **'Address book'**
  String get addrBookTitle;

  /// No description provided for @addrAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addrAddButton;

  /// No description provided for @addrEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get addrEmptyTitle;

  /// No description provided for @addrEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a \"Home\" or \"Work\" address\nfor easy selection without retyping'**
  String get addrEmptySubtitle;

  /// No description provided for @addrQuickAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {name}'**
  String addrQuickAdd(Object name);

  /// No description provided for @confirmServiceFood.
  ///
  /// In en, this message translates to:
  /// **'Food order'**
  String get confirmServiceFood;

  /// No description provided for @confirmServiceRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get confirmServiceRide;

  /// No description provided for @confirmServiceParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivery'**
  String get confirmServiceParcel;

  /// No description provided for @confirmSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking successful!'**
  String get confirmSuccess;

  /// No description provided for @confirmOrderCode.
  ///
  /// In en, this message translates to:
  /// **'Order {code}'**
  String confirmOrderCode(Object code);

  /// No description provided for @confirmPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get confirmPickup;

  /// No description provided for @confirmDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get confirmDestination;

  /// No description provided for @confirmNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get confirmNotSpecified;

  /// No description provided for @confirmDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get confirmDistance;

  /// No description provided for @confirmDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String confirmDistanceKm(Object km);

  /// No description provided for @confirmOrderTime.
  ///
  /// In en, this message translates to:
  /// **'Order time'**
  String get confirmOrderTime;

  /// No description provided for @confirmFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get confirmFoodCost;

  /// No description provided for @confirmDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get confirmDeliveryFee;

  /// No description provided for @confirmTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get confirmTotal;

  /// No description provided for @confirmPayCash.
  ///
  /// In en, this message translates to:
  /// **'Pay with cash'**
  String get confirmPayCash;

  /// No description provided for @confirmCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get confirmCash;

  /// No description provided for @confirmTrackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track order'**
  String get confirmTrackOrder;

  /// No description provided for @confirmBackToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get confirmBackToHome;

  /// No description provided for @foodDetAddedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added {name} to cart'**
  String foodDetAddedToCart(Object name);

  /// No description provided for @foodDetAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add to cart: {error}'**
  String foodDetAddFailed(Object error);

  /// No description provided for @foodDetAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get foodDetAvailable;

  /// No description provided for @foodDetSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get foodDetSoldOut;

  /// No description provided for @foodDetCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize order'**
  String get foodDetCustomize;

  /// No description provided for @foodDetNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No additional options for this item'**
  String get foodDetNoOptions;

  /// No description provided for @foodDetLoadingOptions.
  ///
  /// In en, this message translates to:
  /// **'Loading options...'**
  String get foodDetLoadingOptions;

  /// No description provided for @foodDetDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get foodDetDescription;

  /// No description provided for @foodDetRestaurant.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get foodDetRestaurant;

  /// No description provided for @foodDetAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart — ฿{price}'**
  String foodDetAddToCart(Object price);

  /// No description provided for @foodDefaultNote.
  ///
  /// In en, this message translates to:
  /// **'Food order from {merchant}'**
  String foodDefaultNote(Object merchant);

  /// No description provided for @foodCouponNote.
  ///
  /// In en, this message translates to:
  /// **'[Coupon: {code} | Discount: ฿{amount}]'**
  String foodCouponNote(Object code, Object amount);

  /// No description provided for @trackPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get trackPickup;

  /// No description provided for @trackDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get trackDestination;

  /// No description provided for @trackNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get trackNotSpecified;

  /// No description provided for @trackDriverFallback.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get trackDriverFallback;

  /// No description provided for @trackStatusPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for driver'**
  String get trackStatusPendingTitle;

  /// No description provided for @trackStatusPendingSub.
  ///
  /// In en, this message translates to:
  /// **'Searching for a driver near you'**
  String get trackStatusPendingSub;

  /// No description provided for @trackStatusAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get trackStatusAcceptedTitle;

  /// No description provided for @trackStatusAcceptedSub.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way to you'**
  String get trackStatusAcceptedSub;

  /// No description provided for @trackStatusPickingUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Picking up'**
  String get trackStatusPickingUpTitle;

  /// No description provided for @trackStatusPickingUpSub.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived at pickup'**
  String get trackStatusPickingUpSub;

  /// No description provided for @trackStatusPreparingTitle.
  ///
  /// In en, this message translates to:
  /// **'Restaurant preparing'**
  String get trackStatusPreparingTitle;

  /// No description provided for @trackStatusPreparingSub.
  ///
  /// In en, this message translates to:
  /// **'Restaurant is preparing your order'**
  String get trackStatusPreparingSub;

  /// No description provided for @trackStatusInTransitTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get trackStatusInTransitTitle;

  /// No description provided for @trackStatusInTransitSub.
  ///
  /// In en, this message translates to:
  /// **'Driver is heading to destination'**
  String get trackStatusInTransitSub;

  /// No description provided for @trackStatusArrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrived at destination'**
  String get trackStatusArrivedTitle;

  /// No description provided for @trackStatusArrivedSub.
  ///
  /// In en, this message translates to:
  /// **'Driver has arrived at the destination'**
  String get trackStatusArrivedSub;

  /// No description provided for @trackStatusCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get trackStatusCompletedTitle;

  /// No description provided for @trackStatusCompletedSub.
  ///
  /// In en, this message translates to:
  /// **'Order completed'**
  String get trackStatusCompletedSub;

  /// No description provided for @trackStatusCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get trackStatusCancelledTitle;

  /// No description provided for @trackStatusCancelledSub.
  ///
  /// In en, this message translates to:
  /// **'This order has been cancelled'**
  String get trackStatusCancelledSub;

  /// No description provided for @trackStatusUnknownTitle.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get trackStatusUnknownTitle;

  /// No description provided for @trackTimelineCreated.
  ///
  /// In en, this message translates to:
  /// **'Order created'**
  String get trackTimelineCreated;

  /// No description provided for @trackTimelineAccepted.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted'**
  String get trackTimelineAccepted;

  /// No description provided for @trackTimelinePickingUp.
  ///
  /// In en, this message translates to:
  /// **'Picking up'**
  String get trackTimelinePickingUp;

  /// No description provided for @trackTimelineInTransit.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get trackTimelineInTransit;

  /// No description provided for @trackTimelineCompleted.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get trackTimelineCompleted;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get helpTitle;

  /// No description provided for @helpCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenterTitle;

  /// No description provided for @helpCenterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Available to help you 24 hours'**
  String get helpCenterSubtitle;

  /// No description provided for @helpContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Channels'**
  String get helpContactTitle;

  /// No description provided for @helpPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get helpPhone;

  /// No description provided for @helpEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get helpEmail;

  /// No description provided for @helpFaqTitle.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions (FAQ)'**
  String get helpFaqTitle;

  /// No description provided for @helpReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report Problem'**
  String get helpReportProblem;

  /// No description provided for @helpFaq1Q.
  ///
  /// In en, this message translates to:
  /// **'I ordered food but didn\'t receive it. What should I do?'**
  String get helpFaq1Q;

  /// No description provided for @helpFaq1A.
  ///
  /// In en, this message translates to:
  /// **'Please check the order status on the \"Activity\" page. If the order shows delivered but you haven\'t received it, report the issue using the \"Report Problem\" button below. Our team will investigate within 24 hours.'**
  String get helpFaq1A;

  /// No description provided for @helpFaq2Q.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel an order?'**
  String get helpFaq2Q;

  /// No description provided for @helpFaq2A.
  ///
  /// In en, this message translates to:
  /// **'Go to \"Activity\" > select the order > press \"Cancel\". Note: You can only cancel orders that haven\'t been accepted by a driver yet.'**
  String get helpFaq2A;

  /// No description provided for @helpFaq3Q.
  ///
  /// In en, this message translates to:
  /// **'How is the delivery fee calculated?'**
  String get helpFaq3Q;

  /// No description provided for @helpFaq3A.
  ///
  /// In en, this message translates to:
  /// **'The delivery fee is calculated based on the distance between the store/pickup point and your destination, with a minimum fee and per-kilometer rate set by the system.'**
  String get helpFaq3A;

  /// No description provided for @helpFaq4Q.
  ///
  /// In en, this message translates to:
  /// **'What payment methods are available?'**
  String get helpFaq4Q;

  /// No description provided for @helpFaq4A.
  ///
  /// In en, this message translates to:
  /// **'Currently we support cash, PromptPay, and Mobile Banking. Our team is developing additional payment methods.'**
  String get helpFaq4A;

  /// No description provided for @helpFaq5Q.
  ///
  /// In en, this message translates to:
  /// **'The food I received is incorrect. What should I do?'**
  String get helpFaq5Q;

  /// No description provided for @helpFaq5A.
  ///
  /// In en, this message translates to:
  /// **'Please report the issue using the \"Report Problem\" button with photos and details. Our team will coordinate with the restaurant to resolve it.'**
  String get helpFaq5A;

  /// No description provided for @helpFaq6Q.
  ///
  /// In en, this message translates to:
  /// **'How do I become a driver?'**
  String get helpFaq6Q;

  /// No description provided for @helpFaq6A.
  ///
  /// In en, this message translates to:
  /// **'Register through the app by selecting the \"Driver\" role, then fill in your personal information, driver\'s license, and wait for admin approval.'**
  String get helpFaq6A;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payTitle;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payCashSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay cash to driver'**
  String get payCashSubtitle;

  /// No description provided for @payPromptPaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer via QR Code'**
  String get payPromptPaySubtitle;

  /// No description provided for @payMobileBankingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer via banking app'**
  String get payMobileBankingSubtitle;

  /// No description provided for @payError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String payError(Object error);

  /// No description provided for @paySuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get paySuccess;

  /// No description provided for @payCashPrepare.
  ///
  /// In en, this message translates to:
  /// **'Please prepare cash for the driver'**
  String get payCashPrepare;

  /// No description provided for @payRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment has been recorded'**
  String get payRecorded;

  /// No description provided for @payOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get payOk;

  /// No description provided for @paySelectMethod.
  ///
  /// In en, this message translates to:
  /// **'Select payment method'**
  String get paySelectMethod;

  /// No description provided for @payPromptPayNote.
  ///
  /// In en, this message translates to:
  /// **'The system will automatically generate a QR Code for PromptPay transfer'**
  String get payPromptPayNote;

  /// No description provided for @payButton.
  ///
  /// In en, this message translates to:
  /// **'Pay ฿{amount}'**
  String payButton(Object amount);

  /// No description provided for @payTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get payTotalAmount;

  /// No description provided for @payFoodCost.
  ///
  /// In en, this message translates to:
  /// **'Food cost'**
  String get payFoodCost;

  /// No description provided for @payDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get payDeliveryFee;

  /// No description provided for @ticketTitle.
  ///
  /// In en, this message translates to:
  /// **'Report / Complaint'**
  String get ticketTitle;

  /// No description provided for @ticketCatLostItem.
  ///
  /// In en, this message translates to:
  /// **'Lost item'**
  String get ticketCatLostItem;

  /// No description provided for @ticketCatWrongOrder.
  ///
  /// In en, this message translates to:
  /// **'Wrong food/item'**
  String get ticketCatWrongOrder;

  /// No description provided for @ticketCatRudeDriver.
  ///
  /// In en, this message translates to:
  /// **'Rude driver'**
  String get ticketCatRudeDriver;

  /// No description provided for @ticketCatRefund.
  ///
  /// In en, this message translates to:
  /// **'Request refund'**
  String get ticketCatRefund;

  /// No description provided for @ticketCatAppBug.
  ///
  /// In en, this message translates to:
  /// **'App issue'**
  String get ticketCatAppBug;

  /// No description provided for @ticketCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ticketCatOther;

  /// No description provided for @ticketCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Problem'**
  String get ticketCreateTitle;

  /// No description provided for @ticketCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Problem type'**
  String get ticketCategoryLabel;

  /// No description provided for @ticketSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get ticketSubjectLabel;

  /// No description provided for @ticketSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Left item in car'**
  String get ticketSubjectHint;

  /// No description provided for @ticketDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get ticketDescLabel;

  /// No description provided for @ticketDescHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem in detail...'**
  String get ticketDescHint;

  /// No description provided for @ticketValidation.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get ticketValidation;

  /// No description provided for @ticketSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get ticketSubmit;

  /// No description provided for @ticketFab.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get ticketFab;

  /// No description provided for @ticketEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get ticketEmptyTitle;

  /// No description provided for @ticketEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'If you encounter a problem, press \"Report\" below'**
  String get ticketEmptySubtitle;

  /// No description provided for @mapPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select delivery location'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerLoadingAddress.
  ///
  /// In en, this message translates to:
  /// **'Loading address...'**
  String get mapPickerLoadingAddress;

  /// No description provided for @mapPickerSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for address...'**
  String get mapPickerSearching;

  /// No description provided for @mapPickerDeliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery location'**
  String get mapPickerDeliveryLocation;

  /// No description provided for @mapPickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get mapPickerConfirm;

  /// No description provided for @mapPickerPosition.
  ///
  /// In en, this message translates to:
  /// **'Position: {lat}, {lng}'**
  String mapPickerPosition(Object lat, Object lng);

  /// No description provided for @foodSvcTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Food'**
  String get foodSvcTitle;

  /// No description provided for @foodSvcLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load restaurants: {error}'**
  String foodSvcLoadError(Object error);

  /// No description provided for @foodSvcRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get foodSvcRetry;

  /// No description provided for @foodSvcEmpty.
  ///
  /// In en, this message translates to:
  /// **'No restaurants are currently open'**
  String get foodSvcEmpty;

  /// No description provided for @foodSvcRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get foodSvcRefresh;

  /// No description provided for @foodSvcRestaurantFallback.
  ///
  /// In en, this message translates to:
  /// **'Restaurant'**
  String get foodSvcRestaurantFallback;

  /// No description provided for @foodSvcNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get foodSvcNotSpecified;

  /// No description provided for @foodSvcOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get foodSvcOpen;

  /// No description provided for @accountEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get accountEditName;

  /// No description provided for @accountEditPhone.
  ///
  /// In en, this message translates to:
  /// **'Edit Phone'**
  String get accountEditPhone;

  /// No description provided for @accountEditNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter full name'**
  String get accountEditNameHint;

  /// No description provided for @accountEditPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get accountEditPhoneHint;

  /// No description provided for @accountEditCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountEditCancel;

  /// No description provided for @accountEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountEditSave;

  /// No description provided for @accountEditSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully!'**
  String get accountEditSuccess;

  /// No description provided for @accountEditError.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String accountEditError(Object error);

  /// No description provided for @accountUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get accountUserFallback;

  /// No description provided for @couponScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'My Coupons'**
  String get couponScreenTitle;

  /// No description provided for @couponTabMine.
  ///
  /// In en, this message translates to:
  /// **'My Coupons'**
  String get couponTabMine;

  /// No description provided for @couponTabDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover More'**
  String get couponTabDiscover;

  /// No description provided for @couponTabHistory.
  ///
  /// In en, this message translates to:
  /// **'Usage History'**
  String get couponTabHistory;

  /// No description provided for @couponEmptyWallet.
  ///
  /// In en, this message translates to:
  /// **'No coupons in wallet'**
  String get couponEmptyWallet;

  /// No description provided for @couponEmptyDiscover.
  ///
  /// In en, this message translates to:
  /// **'No new coupons available right now'**
  String get couponEmptyDiscover;

  /// No description provided for @couponEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'No coupon usage history yet'**
  String get couponEmptyHistory;

  /// No description provided for @couponClaimSuccess.
  ///
  /// In en, this message translates to:
  /// **'Coupon claimed successfully!'**
  String get couponClaimSuccess;

  /// No description provided for @couponRemainingUses.
  ///
  /// In en, this message translates to:
  /// **'{count} uses remaining'**
  String couponRemainingUses(Object count);

  /// No description provided for @couponExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String couponExpiry(Object date);

  /// No description provided for @couponClaimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get couponClaimed;

  /// No description provided for @couponClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get couponClaim;

  /// No description provided for @couponHistoryCode.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}\nTime: {time}'**
  String couponHistoryCode(Object code, Object time);

  /// No description provided for @referralTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends & Get Rewards'**
  String get referralTitle;

  /// No description provided for @referralHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends to use the app\nBoth get coupons!'**
  String get referralHeroTitle;

  /// No description provided for @referralHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get a ฿20 discount coupon instantly\nwhen your friend completes their first order'**
  String get referralHeroSubtitle;

  /// No description provided for @referralMyCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get referralMyCodeLabel;

  /// No description provided for @referralShareButton.
  ///
  /// In en, this message translates to:
  /// **'Share with friends'**
  String get referralShareButton;

  /// No description provided for @referralHaveCode.
  ///
  /// In en, this message translates to:
  /// **'Have a referral code?'**
  String get referralHaveCode;

  /// No description provided for @referralEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your friend to get a welcome coupon'**
  String get referralEnterCodeHint;

  /// No description provided for @referralCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter code here'**
  String get referralCodePlaceholder;

  /// No description provided for @referralUseCode.
  ///
  /// In en, this message translates to:
  /// **'Use Code'**
  String get referralUseCode;

  /// No description provided for @referralCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get referralCopied;

  /// No description provided for @referralCodeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Code used successfully!'**
  String get referralCodeSuccess;

  /// No description provided for @referralOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get referralOk;

  /// No description provided for @referralSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Successful referrals'**
  String get referralSuccessful;

  /// No description provided for @referralHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How does it work?'**
  String get referralHowTitle;

  /// No description provided for @referralStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Share code with friends'**
  String get referralStep1Title;

  /// No description provided for @referralStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Send your code to friends who haven\'t used the app yet'**
  String get referralStep1Desc;

  /// No description provided for @referralStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Friend places first order'**
  String get referralStep2Title;

  /// No description provided for @referralStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Friend registers and completes their first food order'**
  String get referralStep2Desc;

  /// No description provided for @referralStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Get discount coupon!'**
  String get referralStep3Title;

  /// No description provided for @referralStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a discount coupon sent directly to your wallet'**
  String get referralStep3Desc;

  /// No description provided for @driverAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Driver Accepted'**
  String get driverAssignedTitle;

  /// No description provided for @driverAssignedHeading.
  ///
  /// In en, this message translates to:
  /// **'Driver accepted the job!'**
  String get driverAssignedHeading;

  /// No description provided for @driverAssignedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The driver is on the way to you'**
  String get driverAssignedSubtitle;

  /// No description provided for @driverAssignedOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver is on the way'**
  String get driverAssignedOnTheWay;

  /// No description provided for @driverAssignedEta.
  ///
  /// In en, this message translates to:
  /// **'Estimated time: 5-10 minutes'**
  String get driverAssignedEta;

  /// No description provided for @driverAssignedContact.
  ///
  /// In en, this message translates to:
  /// **'Contact Driver'**
  String get driverAssignedContact;

  /// No description provided for @driverAssignedCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get driverAssignedCancelBooking;

  /// No description provided for @driverAssignedContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Driver'**
  String get driverAssignedContactTitle;

  /// No description provided for @driverAssignedPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get driverAssignedPhone;

  /// No description provided for @driverAssignedMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get driverAssignedMessage;

  /// No description provided for @driverAssignedMessageSub.
  ///
  /// In en, this message translates to:
  /// **'Send a message to the driver'**
  String get driverAssignedMessageSub;

  /// No description provided for @driverAssignedClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get driverAssignedClose;

  /// No description provided for @driverAssignedCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get driverAssignedCancelTitle;

  /// No description provided for @driverAssignedCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this booking?'**
  String get driverAssignedCancelBody;

  /// No description provided for @driverAssignedNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get driverAssignedNo;

  /// No description provided for @driverAssignedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get driverAssignedCancel;

  /// No description provided for @mapSvcRide.
  ///
  /// In en, this message translates to:
  /// **'Call Ride'**
  String get mapSvcRide;

  /// No description provided for @mapSvcFood.
  ///
  /// In en, this message translates to:
  /// **'Order Food'**
  String get mapSvcFood;

  /// No description provided for @mapSvcParcel.
  ///
  /// In en, this message translates to:
  /// **'Send Parcel'**
  String get mapSvcParcel;

  /// No description provided for @mapSelectService.
  ///
  /// In en, this message translates to:
  /// **'Select Service'**
  String get mapSelectService;

  /// No description provided for @mapFindingLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding location...'**
  String get mapFindingLocation;

  /// No description provided for @mapUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get mapUserFallback;

  /// No description provided for @mapLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get mapLogout;

  /// No description provided for @mapLocServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Service'**
  String get mapLocServiceTitle;

  /// No description provided for @mapLocServiceBody.
  ///
  /// In en, this message translates to:
  /// **'Location service is disabled. Please enable it.'**
  String get mapLocServiceBody;

  /// No description provided for @mapLocOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get mapLocOpenSettings;

  /// No description provided for @mapLocCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mapLocCancel;

  /// No description provided for @mapLocPermTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Permission'**
  String get mapLocPermTitle;

  /// No description provided for @mapLocPermDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. Please allow location access to use the map.'**
  String get mapLocPermDenied;

  /// No description provided for @mapLocRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mapLocRetry;

  /// No description provided for @mapLocPermForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission was permanently denied. Please open app settings to allow permission.'**
  String get mapLocPermForever;

  /// No description provided for @mapLocErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Error'**
  String get mapLocErrorTitle;

  /// No description provided for @mapLocErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Unable to get location: {error}'**
  String mapLocErrorBody(Object error);

  /// No description provided for @mapLocOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get mapLocOk;

  /// No description provided for @mapLogoutError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String mapLogoutError(Object error);

  /// No description provided for @rideTitle.
  ///
  /// In en, this message translates to:
  /// **'Call Ride'**
  String get rideTitle;

  /// No description provided for @rideMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get rideMotorcycle;

  /// No description provided for @rideCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get rideCar;

  /// No description provided for @rideMotorcycleDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast & affordable'**
  String get rideMotorcycleDesc;

  /// No description provided for @rideCarDesc.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get rideCarDesc;

  /// No description provided for @rideSelectPayment.
  ///
  /// In en, this message translates to:
  /// **'Select payment method'**
  String get rideSelectPayment;

  /// No description provided for @rideCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get rideCash;

  /// No description provided for @rideTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get rideTransfer;

  /// No description provided for @rideSelectDestination.
  ///
  /// In en, this message translates to:
  /// **'Please select a destination'**
  String get rideSelectDestination;

  /// No description provided for @rideSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Please select a vehicle type first'**
  String get rideSelectVehicle;

  /// No description provided for @ridePleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Please log in'**
  String get ridePleaseLogin;

  /// No description provided for @rideSearchingDriver.
  ///
  /// In en, this message translates to:
  /// **'Searching for a driver...'**
  String get rideSearchingDriver;

  /// No description provided for @rideError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String rideError(Object error);

  /// No description provided for @rideCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get rideCurrentLocation;

  /// No description provided for @rideFindingLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding location...'**
  String get rideFindingLocation;

  /// No description provided for @rideDestHint.
  ///
  /// In en, this message translates to:
  /// **'Where to? Tap map to select'**
  String get rideDestHint;

  /// No description provided for @rideOnlineCount.
  ///
  /// In en, this message translates to:
  /// **'{count} online'**
  String rideOnlineCount(Object count);

  /// No description provided for @rideNoDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers'**
  String get rideNoDrivers;

  /// No description provided for @rideNoVehicleOnline.
  ///
  /// In en, this message translates to:
  /// **'No {vehicle} online right now'**
  String rideNoVehicleOnline(Object vehicle);

  /// No description provided for @rideDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String rideDistanceKm(Object km);

  /// No description provided for @rideBtnSelectDest.
  ///
  /// In en, this message translates to:
  /// **'Select destination'**
  String get rideBtnSelectDest;

  /// No description provided for @rideBtnSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Please select vehicle type'**
  String get rideBtnSelectVehicle;

  /// No description provided for @rideBtnCallRide.
  ///
  /// In en, this message translates to:
  /// **'Call Ride — ฿{price}'**
  String rideBtnCallRide(Object price);

  /// No description provided for @rideNoteVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type: {name}'**
  String rideNoteVehicleType(Object name);

  /// No description provided for @rideNotePickupSurcharge.
  ///
  /// In en, this message translates to:
  /// **'Extra driver→pickup {km} km (+฿{surcharge})'**
  String rideNotePickupSurcharge(Object km, Object surcharge);

  /// No description provided for @ridePickupAddress.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get ridePickupAddress;

  /// No description provided for @rideNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'🚗 New job! Passenger ride'**
  String get rideNotifTitle;

  /// No description provided for @rideNotifBody.
  ///
  /// In en, this message translates to:
  /// **'Ride request from {pickup} to {destination} — ฿{price}'**
  String rideNotifBody(Object pickup, Object destination, Object price);

  /// No description provided for @rideNotifPickupFallback.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get rideNotifPickupFallback;

  /// No description provided for @rideNotifDestFallback.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get rideNotifDestFallback;

  /// No description provided for @drvProfileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get drvProfileEditName;

  /// No description provided for @drvProfileEditPhone.
  ///
  /// In en, this message translates to:
  /// **'Edit Phone'**
  String get drvProfileEditPhone;

  /// No description provided for @drvProfileEditPlate.
  ///
  /// In en, this message translates to:
  /// **'Edit License Plate'**
  String get drvProfileEditPlate;

  /// No description provided for @drvProfileHintName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get drvProfileHintName;

  /// No description provided for @drvProfileHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get drvProfileHintPhone;

  /// No description provided for @drvProfileHintPlate.
  ///
  /// In en, this message translates to:
  /// **'e.g. ABC 1234'**
  String get drvProfileHintPlate;

  /// No description provided for @drvProfileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get drvProfileCancel;

  /// No description provided for @drvProfileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get drvProfileSave;

  /// No description provided for @drvProfileUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Updated successfully!'**
  String get drvProfileUpdateSuccess;

  /// No description provided for @drvProfileUpdateError.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String drvProfileUpdateError(Object error);

  /// No description provided for @drvProfileSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle type'**
  String get drvProfileSelectVehicle;

  /// No description provided for @drvProfileMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get drvProfileMotorcycle;

  /// No description provided for @drvProfileCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get drvProfileCar;

  /// No description provided for @earnTitle.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnTitle;

  /// No description provided for @earnWalletTooltip.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get earnWalletTooltip;

  /// No description provided for @earnRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get earnRefresh;

  /// No description provided for @earnLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load data'**
  String get earnLoadError;

  /// No description provided for @earnRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get earnRetry;

  /// No description provided for @earnPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get earnPeriodToday;

  /// No description provided for @earnPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get earnPeriodWeek;

  /// No description provided for @earnPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get earnPeriodMonth;

  /// No description provided for @earnPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get earnPeriodAll;

  /// No description provided for @earnPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Date'**
  String get earnPeriodCustom;

  /// No description provided for @earnRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Earnings {period}'**
  String earnRevenueLabel(Object period);

  /// No description provided for @earnAvgPerJob.
  ///
  /// In en, this message translates to:
  /// **'Average {amount} / job'**
  String earnAvgPerJob(Object amount);

  /// No description provided for @earnTotalJobs.
  ///
  /// In en, this message translates to:
  /// **'Total Jobs'**
  String get earnTotalJobs;

  /// No description provided for @earnCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get earnCompleted;

  /// No description provided for @earnCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get earnCancelled;

  /// No description provided for @earnWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get earnWalletTitle;

  /// No description provided for @earnWalletLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get earnWalletLoading;

  /// No description provided for @earnWalletBaht.
  ///
  /// In en, this message translates to:
  /// **'{amount} THB'**
  String earnWalletBaht(Object amount);

  /// No description provided for @earnViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get earnViewAll;

  /// No description provided for @earnJobHistory.
  ///
  /// In en, this message translates to:
  /// **'Job History'**
  String get earnJobHistory;

  /// No description provided for @earnNoJobs.
  ///
  /// In en, this message translates to:
  /// **'No jobs in this period'**
  String get earnNoJobs;

  /// No description provided for @earnStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get earnStatusCompleted;

  /// No description provided for @earnStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get earnStatusCancelled;

  /// No description provided for @earnStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get earnStatusPickedUp;

  /// No description provided for @earnStatusDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get earnStatusDelivering;

  /// No description provided for @earnSvcRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get earnSvcRide;

  /// No description provided for @earnSvcFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get earnSvcFood;

  /// No description provided for @earnSvcParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel'**
  String get earnSvcParcel;

  /// No description provided for @earnSvcOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get earnSvcOther;

  /// No description provided for @earnAppFee.
  ///
  /// In en, this message translates to:
  /// **'(Platform fee {amount})'**
  String earnAppFee(Object amount);

  /// No description provided for @earnCollectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Collect from customer'**
  String get earnCollectCustomer;

  /// No description provided for @earnCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get earnCouponDiscount;

  /// No description provided for @earnOpenDetailError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open job detail'**
  String get earnOpenDetailError;

  /// No description provided for @earnUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get earnUserNotFound;

  /// No description provided for @jobDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Detail'**
  String get jobDetailTitle;

  /// No description provided for @jobDetailNoRoute.
  ///
  /// In en, this message translates to:
  /// **'No route data'**
  String get jobDetailNoRoute;

  /// No description provided for @jobDetailPickupFallback.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get jobDetailPickupFallback;

  /// No description provided for @jobDetailDestFallback.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get jobDetailDestFallback;

  /// No description provided for @jobDetailDurationHrMin.
  ///
  /// In en, this message translates to:
  /// **'{hr} hr {min} min'**
  String jobDetailDurationHrMin(Object hr, Object min);

  /// No description provided for @jobDetailDurationMin.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String jobDetailDurationMin(Object min);

  /// No description provided for @jobDetailCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get jobDetailCash;

  /// No description provided for @jobDetailOrderFood.
  ///
  /// In en, this message translates to:
  /// **'Food Order'**
  String get jobDetailOrderFood;

  /// No description provided for @jobDetailRide.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get jobDetailRide;

  /// No description provided for @jobDetailParcel.
  ///
  /// In en, this message translates to:
  /// **'Parcel'**
  String get jobDetailParcel;

  /// No description provided for @jobDetailNetEarnings.
  ///
  /// In en, this message translates to:
  /// **'Net Earnings'**
  String get jobDetailNetEarnings;

  /// No description provided for @jobDetailEarningsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Earnings Breakdown'**
  String get jobDetailEarningsBreakdown;

  /// No description provided for @jobDetailTripFare.
  ///
  /// In en, this message translates to:
  /// **'Trip fare'**
  String get jobDetailTripFare;

  /// No description provided for @jobDetailCouponDiscountGeneric.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get jobDetailCouponDiscountGeneric;

  /// No description provided for @jobDetailCouponDiscountCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount ({code})'**
  String jobDetailCouponDiscountCode(Object code);

  /// No description provided for @jobDetailPlatformFee.
  ///
  /// In en, this message translates to:
  /// **'Platform fee'**
  String get jobDetailPlatformFee;

  /// No description provided for @jobDetailFoodCost.
  ///
  /// In en, this message translates to:
  /// **'  Food cost'**
  String get jobDetailFoodCost;

  /// No description provided for @jobDetailDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'  Delivery fee'**
  String get jobDetailDeliveryFee;

  /// No description provided for @jobDetailCashCollection.
  ///
  /// In en, this message translates to:
  /// **'Cash payment items'**
  String get jobDetailCashCollection;

  /// No description provided for @jobDetailCollectFromCustomer.
  ///
  /// In en, this message translates to:
  /// **'Collect from customer'**
  String get jobDetailCollectFromCustomer;

  /// No description provided for @parcelConfirmPickupTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup'**
  String get parcelConfirmPickupTitle;

  /// No description provided for @parcelConfirmDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery'**
  String get parcelConfirmDeliveryTitle;

  /// No description provided for @parcelConfirmPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please take a confirmation photo'**
  String get parcelConfirmPhotoRequired;

  /// No description provided for @parcelConfirmSignatureRequired.
  ///
  /// In en, this message translates to:
  /// **'Please take a recipient signature photo'**
  String get parcelConfirmSignatureRequired;

  /// No description provided for @parcelConfirmUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed'**
  String get parcelConfirmUploadFailed;

  /// No description provided for @parcelConfirmUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Status update failed'**
  String get parcelConfirmUpdateFailed;

  /// No description provided for @parcelConfirmPickupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Parcel picked up!'**
  String get parcelConfirmPickupSuccess;

  /// No description provided for @parcelConfirmPickupSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Photo saved successfully\nPlease deliver the parcel'**
  String get parcelConfirmPickupSuccessBody;

  /// No description provided for @parcelConfirmDeliverySuccess.
  ///
  /// In en, this message translates to:
  /// **'Parcel delivered!'**
  String get parcelConfirmDeliverySuccess;

  /// No description provided for @parcelConfirmDeliverySuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Photo and signature saved\nJob completed'**
  String get parcelConfirmDeliverySuccessBody;

  /// No description provided for @parcelConfirmError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred\nPlease try again'**
  String get parcelConfirmError;

  /// No description provided for @parcelConfirmErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get parcelConfirmErrorTitle;

  /// No description provided for @parcelConfirmOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get parcelConfirmOk;

  /// No description provided for @parcelConfirmNoData.
  ///
  /// In en, this message translates to:
  /// **'Parcel data not found'**
  String get parcelConfirmNoData;

  /// No description provided for @parcelConfirmParcelInfo.
  ///
  /// In en, this message translates to:
  /// **'Parcel Info'**
  String get parcelConfirmParcelInfo;

  /// No description provided for @parcelConfirmSender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get parcelConfirmSender;

  /// No description provided for @parcelConfirmRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get parcelConfirmRecipient;

  /// No description provided for @parcelConfirmSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get parcelConfirmSize;

  /// No description provided for @parcelConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get parcelConfirmDescription;

  /// No description provided for @parcelConfirmWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get parcelConfirmWeightKg;

  /// No description provided for @parcelConfirmWeightValue.
  ///
  /// In en, this message translates to:
  /// **'{kg} kg'**
  String parcelConfirmWeightValue(Object kg);

  /// No description provided for @parcelConfirmStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get parcelConfirmStatus;

  /// No description provided for @parcelConfirmCustomerPhoto.
  ///
  /// In en, this message translates to:
  /// **'Customer parcel photo'**
  String get parcelConfirmCustomerPhoto;

  /// No description provided for @parcelConfirmPickupPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Take pickup confirmation photo *'**
  String get parcelConfirmPickupPhotoTitle;

  /// No description provided for @parcelConfirmDeliveryPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Take delivery confirmation photo *'**
  String get parcelConfirmDeliveryPhotoTitle;

  /// No description provided for @parcelConfirmPickupPhotoDesc.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the parcel received'**
  String get parcelConfirmPickupPhotoDesc;

  /// No description provided for @parcelConfirmDeliveryPhotoDesc.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of the parcel delivered'**
  String get parcelConfirmDeliveryPhotoDesc;

  /// No description provided for @parcelConfirmSignatureTitle.
  ///
  /// In en, this message translates to:
  /// **'Take recipient signature photo *'**
  String get parcelConfirmSignatureTitle;

  /// No description provided for @parcelConfirmSignatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Take a photo of recipient signature or ID'**
  String get parcelConfirmSignatureDesc;

  /// No description provided for @parcelConfirmTapToPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to take photo'**
  String get parcelConfirmTapToPhoto;

  /// No description provided for @parcelConfirmPickupBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Pickup'**
  String get parcelConfirmPickupBtn;

  /// No description provided for @parcelConfirmDeliveryBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery Complete'**
  String get parcelConfirmDeliveryBtn;

  /// No description provided for @merchantNavOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get merchantNavOrders;

  /// No description provided for @merchantNavMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get merchantNavMenu;

  /// No description provided for @merchantNavReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get merchantNavReport;

  /// No description provided for @merchantNavAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get merchantNavAccount;

  /// No description provided for @merchantPressBackAgain.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get merchantPressBackAgain;

  /// No description provided for @mchSetShopInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Information'**
  String get mchSetShopInfoTitle;

  /// No description provided for @mchSetShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get mchSetShopName;

  /// No description provided for @mchSetPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get mchSetPhone;

  /// No description provided for @mchSetEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get mchSetEmail;

  /// No description provided for @mchSetAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop Address'**
  String get mchSetAddress;

  /// No description provided for @mchSetShopStatus.
  ///
  /// In en, this message translates to:
  /// **'Shop Status'**
  String get mchSetShopStatus;

  /// No description provided for @mchSetShopOpen.
  ///
  /// In en, this message translates to:
  /// **'Accepting Orders'**
  String get mchSetShopOpen;

  /// No description provided for @mchSetShopClosed.
  ///
  /// In en, this message translates to:
  /// **'Shop Closed'**
  String get mchSetShopClosed;

  /// No description provided for @mchSetOpenCloseTime.
  ///
  /// In en, this message translates to:
  /// **'Open-Close Time'**
  String get mchSetOpenCloseTime;

  /// No description provided for @mchSetOpenDays.
  ///
  /// In en, this message translates to:
  /// **'Open Days'**
  String get mchSetOpenDays;

  /// No description provided for @mchSetOrderAcceptMode.
  ///
  /// In en, this message translates to:
  /// **'Order Accept Mode'**
  String get mchSetOrderAcceptMode;

  /// No description provided for @mchSetAutoSchedule.
  ///
  /// In en, this message translates to:
  /// **'Auto Open-Close'**
  String get mchSetAutoSchedule;

  /// No description provided for @mchSetAutoScheduleOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get mchSetAutoScheduleOn;

  /// No description provided for @mchSetAutoScheduleOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get mchSetAutoScheduleOff;

  /// No description provided for @mchSetNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get mchSetNotSet;

  /// No description provided for @mchSetEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get mchSetEveryDay;

  /// No description provided for @mchSetAcceptAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto accept orders'**
  String get mchSetAcceptAuto;

  /// No description provided for @mchSetAcceptManual.
  ///
  /// In en, this message translates to:
  /// **'Manual accept orders'**
  String get mchSetAcceptManual;

  /// No description provided for @mchSetEditField.
  ///
  /// In en, this message translates to:
  /// **'Edit {label}'**
  String mchSetEditField(Object label);

  /// No description provided for @mchSetHintShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get mchSetHintShopName;

  /// No description provided for @mchSetHintPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get mchSetHintPhone;

  /// No description provided for @mchSetCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get mchSetCancel;

  /// No description provided for @mchSetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get mchSetSave;

  /// No description provided for @mchSetEditShopHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Shop Hours'**
  String get mchSetEditShopHoursTitle;

  /// No description provided for @mchSetOpenTime.
  ///
  /// In en, this message translates to:
  /// **'Open Time'**
  String get mchSetOpenTime;

  /// No description provided for @mchSetCloseTime.
  ///
  /// In en, this message translates to:
  /// **'Close Time'**
  String get mchSetCloseTime;

  /// No description provided for @mchSetOpenDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Open Days'**
  String get mchSetOpenDaysLabel;

  /// No description provided for @mchSetOrderAcceptModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Order Accept Mode'**
  String get mchSetOrderAcceptModeLabel;

  /// No description provided for @mchSetAcceptManualShort.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get mchSetAcceptManualShort;

  /// No description provided for @mchSetAcceptAutoShort.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get mchSetAcceptAutoShort;

  /// No description provided for @mchSetAutoScheduleSwitch.
  ///
  /// In en, this message translates to:
  /// **'Auto open-close by schedule'**
  String get mchSetAutoScheduleSwitch;

  /// No description provided for @mchSetAutoScheduleOnDesc.
  ///
  /// In en, this message translates to:
  /// **'System will toggle shop status automatically'**
  String get mchSetAutoScheduleOnDesc;

  /// No description provided for @mchSetAutoScheduleOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Off — manual open/close only'**
  String get mchSetAutoScheduleOffDesc;

  /// No description provided for @mchSetSelectAtLeast1Day.
  ///
  /// In en, this message translates to:
  /// **'Please select at least 1 open day'**
  String get mchSetSelectAtLeast1Day;

  /// No description provided for @mchSetShopHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Shop hours set: {open} - {close} ({days})'**
  String mchSetShopHoursSaved(Object open, Object close, Object days);

  /// No description provided for @mchSetSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String mchSetSaveFailed(Object error);

  /// No description provided for @mchSetWeekMon.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get mchSetWeekMon;

  /// No description provided for @mchSetWeekTue.
  ///
  /// In en, this message translates to:
  /// **'T'**
  String get mchSetWeekTue;

  /// No description provided for @mchSetWeekWed.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get mchSetWeekWed;

  /// No description provided for @mchSetWeekThu.
  ///
  /// In en, this message translates to:
  /// **'Th'**
  String get mchSetWeekThu;

  /// No description provided for @mchSetWeekFri.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get mchSetWeekFri;

  /// No description provided for @mchSetWeekSat.
  ///
  /// In en, this message translates to:
  /// **'Sa'**
  String get mchSetWeekSat;

  /// No description provided for @mchSetWeekSun.
  ///
  /// In en, this message translates to:
  /// **'Su'**
  String get mchSetWeekSun;

  /// No description provided for @mchDashTitle.
  ///
  /// In en, this message translates to:
  /// **'Sales Report'**
  String get mchDashTitle;

  /// No description provided for @mchDashRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get mchDashRefresh;

  /// No description provided for @mchDashLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load data'**
  String get mchDashLoadError;

  /// No description provided for @mchDashRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mchDashRetry;

  /// No description provided for @mchDashPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get mchDashPeriodToday;

  /// No description provided for @mchDashPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get mchDashPeriodWeek;

  /// No description provided for @mchDashPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get mchDashPeriodMonth;

  /// No description provided for @mchDashPeriodAll.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get mchDashPeriodAll;

  /// No description provided for @mchDashPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Date'**
  String get mchDashPeriodCustom;

  /// No description provided for @mchDashPickDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get mchDashPickDateRange;

  /// No description provided for @mchDashClearDateFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear date filter'**
  String get mchDashClearDateFilter;

  /// No description provided for @mchDashNetRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net Revenue {period}'**
  String mchDashNetRevenue(Object period);

  /// No description provided for @mchDashAvgPerOrder.
  ///
  /// In en, this message translates to:
  /// **'Average {amount} / order'**
  String mchDashAvgPerOrder(Object amount);

  /// No description provided for @mchDashTotalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get mchDashTotalOrders;

  /// No description provided for @mchDashCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get mchDashCompleted;

  /// No description provided for @mchDashCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get mchDashCancelled;

  /// No description provided for @mchDashOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get mchDashOrderHistory;

  /// No description provided for @mchDashNoOrders.
  ///
  /// In en, this message translates to:
  /// **'No orders in this period'**
  String get mchDashNoOrders;

  /// No description provided for @mchDashViewDetail.
  ///
  /// In en, this message translates to:
  /// **'View detail'**
  String get mchDashViewDetail;

  /// No description provided for @mchDashStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get mchDashStatusCompleted;

  /// No description provided for @mchDashStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get mchDashStatusCancelled;

  /// No description provided for @mchDashStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get mchDashStatusPreparing;

  /// No description provided for @mchDashStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get mchDashStatusReady;

  /// No description provided for @mchDashStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked Up'**
  String get mchDashStatusPickedUp;

  /// No description provided for @mchDashStatusDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering'**
  String get mchDashStatusDelivering;

  /// No description provided for @mchDashUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get mchDashUserNotFound;

  /// No description provided for @menuMgmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu Management'**
  String get menuMgmtTitle;

  /// No description provided for @menuMgmtOptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage options'**
  String get menuMgmtOptionTooltip;

  /// No description provided for @menuMgmtError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get menuMgmtError;

  /// No description provided for @menuMgmtRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get menuMgmtRetry;

  /// No description provided for @menuMgmtEmpty.
  ///
  /// In en, this message translates to:
  /// **'No menu items yet'**
  String get menuMgmtEmpty;

  /// No description provided for @menuMgmtEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first menu item'**
  String get menuMgmtEmptyHint;

  /// No description provided for @menuMgmtNoName.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get menuMgmtNoName;

  /// No description provided for @menuMgmtAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get menuMgmtAvailable;

  /// No description provided for @menuMgmtSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold Out'**
  String get menuMgmtSoldOut;

  /// No description provided for @menuMgmtEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuMgmtEdit;

  /// No description provided for @menuMgmtDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get menuMgmtDelete;

  /// No description provided for @menuMgmtDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get menuMgmtDeleteConfirmTitle;

  /// No description provided for @menuMgmtDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete menu \"{name}\"?'**
  String menuMgmtDeleteConfirmBody(Object name);

  /// No description provided for @menuMgmtNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get menuMgmtNo;

  /// No description provided for @menuMgmtYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get menuMgmtYes;

  /// No description provided for @menuMgmtDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Menu deleted successfully'**
  String get menuMgmtDeleteSuccess;

  /// No description provided for @menuMgmtCannotDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete menu'**
  String get menuMgmtCannotDeleteTitle;

  /// No description provided for @menuMgmtCannotDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This menu has related orders and cannot be deleted.\n\nWould you like to hide it instead? (Change status to \"Sold Out\")'**
  String get menuMgmtCannotDeleteBody;

  /// No description provided for @menuMgmtCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get menuMgmtCancel;

  /// No description provided for @menuMgmtHideMenu.
  ///
  /// In en, this message translates to:
  /// **'Hide Menu'**
  String get menuMgmtHideMenu;

  /// No description provided for @menuMgmtHideSuccess.
  ///
  /// In en, this message translates to:
  /// **'Menu hidden (changed to \"Sold Out\")'**
  String get menuMgmtHideSuccess;

  /// No description provided for @menuMgmtDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete menu: {error}'**
  String menuMgmtDeleteFailed(Object error);

  /// No description provided for @menuMgmtToggleOn.
  ///
  /// In en, this message translates to:
  /// **'Menu is now available'**
  String get menuMgmtToggleOn;

  /// No description provided for @menuMgmtToggleOff.
  ///
  /// In en, this message translates to:
  /// **'Menu is now unavailable'**
  String get menuMgmtToggleOff;

  /// No description provided for @menuMgmtToggleFailed.
  ///
  /// In en, this message translates to:
  /// **'Status change failed: {error}'**
  String menuMgmtToggleFailed(Object error);

  /// No description provided for @menuMgmtUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get menuMgmtUserNotFound;

  /// No description provided for @menuEditTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Menu'**
  String get menuEditTitleEdit;

  /// No description provided for @menuEditTitleAdd.
  ///
  /// In en, this message translates to:
  /// **'Add New Menu'**
  String get menuEditTitleAdd;

  /// No description provided for @menuEditBtnUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Menu'**
  String get menuEditBtnUpdate;

  /// No description provided for @menuEditBtnAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Menu'**
  String get menuEditBtnAdd;

  /// No description provided for @menuEditInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Menu Info'**
  String get menuEditInfoTitle;

  /// No description provided for @menuEditNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu Name *'**
  String get menuEditNameLabel;

  /// No description provided for @menuEditNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a menu name'**
  String get menuEditNameRequired;

  /// No description provided for @menuEditDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get menuEditDescLabel;

  /// No description provided for @menuEditPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price *'**
  String get menuEditPriceLabel;

  /// No description provided for @menuEditPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a price'**
  String get menuEditPriceRequired;

  /// No description provided for @menuEditPriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get menuEditPriceInvalid;

  /// No description provided for @menuEditPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Menu Photo'**
  String get menuEditPhotoLabel;

  /// No description provided for @menuEditTapToPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to take or select photo'**
  String get menuEditTapToPhoto;

  /// No description provided for @menuEditCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category *'**
  String get menuEditCategoryLabel;

  /// No description provided for @menuEditCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get menuEditCategoryRequired;

  /// No description provided for @menuEditAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available for sale'**
  String get menuEditAvailable;

  /// No description provided for @menuEditOptionGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Option Groups'**
  String get menuEditOptionGroupsTitle;

  /// No description provided for @menuEditGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{count} groups'**
  String menuEditGroupCount(Object count);

  /// No description provided for @menuEditNoOptionGroups.
  ///
  /// In en, this message translates to:
  /// **'No option groups selected'**
  String get menuEditNoOptionGroups;

  /// No description provided for @menuEditNoOptionGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Add option groups for customers to choose from'**
  String get menuEditNoOptionGroupsHint;

  /// No description provided for @menuEditAddSuccess.
  ///
  /// In en, this message translates to:
  /// **'Menu added successfully'**
  String get menuEditAddSuccess;

  /// No description provided for @menuEditUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Menu updated successfully'**
  String get menuEditUpdateSuccess;

  /// No description provided for @menuEditLoadOptionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load options: {error}'**
  String menuEditLoadOptionsFailed(Object error);

  /// No description provided for @menuEditDeleteGroupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group \"{name}\" deleted'**
  String menuEditDeleteGroupSuccess(Object name);

  /// No description provided for @menuEditDeleteGroupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group: {error}'**
  String menuEditDeleteGroupFailed(Object error);

  /// No description provided for @menuEditCatMadeToOrder.
  ///
  /// In en, this message translates to:
  /// **'Made to Order'**
  String get menuEditCatMadeToOrder;

  /// No description provided for @menuEditCatNoodles.
  ///
  /// In en, this message translates to:
  /// **'Noodles'**
  String get menuEditCatNoodles;

  /// No description provided for @menuEditCatDrinks.
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get menuEditCatDrinks;

  /// No description provided for @menuEditCatDessert.
  ///
  /// In en, this message translates to:
  /// **'Dessert'**
  String get menuEditCatDessert;

  /// No description provided for @menuEditCatFastFood.
  ///
  /// In en, this message translates to:
  /// **'Fast Food'**
  String get menuEditCatFastFood;

  /// No description provided for @menuEditCatBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get menuEditCatBreakfast;

  /// No description provided for @menuEditCatJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get menuEditCatJapanese;

  /// No description provided for @menuEditCatIsaan.
  ///
  /// In en, this message translates to:
  /// **'Isaan'**
  String get menuEditCatIsaan;

  /// No description provided for @menuEditCatSnacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get menuEditCatSnacks;

  /// No description provided for @menuEditCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get menuEditCatOther;

  /// No description provided for @optGroupEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Option Group'**
  String get optGroupEditTitle;

  /// No description provided for @optGroupCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Option Group'**
  String get optGroupCreateTitle;

  /// No description provided for @optGroupBtnUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Option Group'**
  String get optGroupBtnUpdate;

  /// No description provided for @optGroupBtnCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Option Group'**
  String get optGroupBtnCreate;

  /// No description provided for @optGroupInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Option Group Info'**
  String get optGroupInfoTitle;

  /// No description provided for @optGroupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Option Group Name'**
  String get optGroupNameLabel;

  /// No description provided for @optGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Spice Level, Toppings'**
  String get optGroupNameHint;

  /// No description provided for @optGroupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a group name'**
  String get optGroupNameRequired;

  /// No description provided for @optGroupMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Selection'**
  String get optGroupMinLabel;

  /// No description provided for @optGroupMinRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter minimum'**
  String get optGroupMinRequired;

  /// No description provided for @optGroupMinInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get optGroupMinInvalid;

  /// No description provided for @optGroupMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Selection'**
  String get optGroupMaxLabel;

  /// No description provided for @optGroupMaxRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter maximum'**
  String get optGroupMaxRequired;

  /// No description provided for @optGroupMaxInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number (at least 1)'**
  String get optGroupMaxInvalid;

  /// No description provided for @optGroupSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Hint: 0=optional, 1=must select 1 item'**
  String get optGroupSelectionHint;

  /// No description provided for @optGroupAddOptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get optGroupAddOptionTitle;

  /// No description provided for @optGroupOptionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Option Name'**
  String get optGroupOptionNameLabel;

  /// No description provided for @optGroupOptionNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Not Spicy, Very Spicy'**
  String get optGroupOptionNameHint;

  /// No description provided for @optGroupOptionPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra Price'**
  String get optGroupOptionPriceLabel;

  /// No description provided for @optGroupNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options yet'**
  String get optGroupNoOptions;

  /// No description provided for @optGroupNoOptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Add options for customers to choose from'**
  String get optGroupNoOptionsHint;

  /// No description provided for @optGroupAllOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'All Options'**
  String get optGroupAllOptionsTitle;

  /// No description provided for @optGroupItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String optGroupItemCount(Object count);

  /// No description provided for @optGroupOptionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an option name'**
  String get optGroupOptionNameRequired;

  /// No description provided for @optGroupOptionPriceNegative.
  ///
  /// In en, this message translates to:
  /// **'Price must not be negative'**
  String get optGroupOptionPriceNegative;

  /// No description provided for @optGroupCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Option group created'**
  String get optGroupCreateSuccess;

  /// No description provided for @optGroupUpdateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Option group updated'**
  String get optGroupUpdateSuccess;

  /// No description provided for @optGroupMinMaxError.
  ///
  /// In en, this message translates to:
  /// **'Min must not be less than 0 and max must not be less than 1'**
  String get optGroupMinMaxError;

  /// No description provided for @optGroupMinGtMaxError.
  ///
  /// In en, this message translates to:
  /// **'Min must not be greater than max'**
  String get optGroupMinGtMaxError;

  /// No description provided for @optGroupSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save option group'**
  String get optGroupSaveError;

  /// No description provided for @optLibTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Food Options'**
  String get optLibTitle;

  /// No description provided for @optLibRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get optLibRetry;

  /// No description provided for @optLibEmpty.
  ///
  /// In en, this message translates to:
  /// **'No option groups yet'**
  String get optLibEmpty;

  /// No description provided for @optLibEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create option groups to use with your menu items'**
  String get optLibEmptyHint;

  /// No description provided for @optLibCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create New Group'**
  String get optLibCreateNew;

  /// No description provided for @optLibDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get optLibDeleteConfirmTitle;

  /// No description provided for @optLibDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete group \"{name}\"?'**
  String optLibDeleteConfirmBody(Object name);

  /// No description provided for @optLibDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Deleting this group will also delete all {count} options'**
  String optLibDeleteNote(Object count);

  /// No description provided for @optLibCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get optLibCancel;

  /// No description provided for @optLibDeleteBtn.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get optLibDeleteBtn;

  /// No description provided for @optLibDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group \"{name}\" deleted'**
  String optLibDeleteSuccess(Object name);

  /// No description provided for @optLibDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete group: {error}'**
  String optLibDeleteFailed(Object error);

  /// No description provided for @optLibSelectMax1.
  ///
  /// In en, this message translates to:
  /// **'Select up to 1 item'**
  String get optLibSelectMax1;

  /// No description provided for @optLibSelectMaxN.
  ///
  /// In en, this message translates to:
  /// **'Select up to {max} items'**
  String optLibSelectMaxN(Object max);

  /// No description provided for @optLibSelectExact.
  ///
  /// In en, this message translates to:
  /// **'Select {n} items'**
  String optLibSelectExact(Object n);

  /// No description provided for @optLibSelectRange.
  ///
  /// In en, this message translates to:
  /// **'Select {min}-{max} items'**
  String optLibSelectRange(Object min, Object max);

  /// No description provided for @optLibOptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} options'**
  String optLibOptionCount(Object count);

  /// No description provided for @optLibShowFirst3.
  ///
  /// In en, this message translates to:
  /// **'Showing first 3'**
  String get optLibShowFirst3;

  /// No description provided for @menuEditAddOptionGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Option Group'**
  String get menuEditAddOptionGroup;

  /// No description provided for @menuEditSelectOptionGroups.
  ///
  /// In en, this message translates to:
  /// **'Select Option Groups'**
  String get menuEditSelectOptionGroups;

  /// No description provided for @menuEditSaveSelection.
  ///
  /// In en, this message translates to:
  /// **'Save Selection'**
  String get menuEditSaveSelection;

  /// No description provided for @menuEditSheetRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get menuEditSheetRetry;

  /// No description provided for @menuEditSheetNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No option groups'**
  String get menuEditSheetNoGroups;

  /// No description provided for @menuEditSheetNoGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Create option groups first to use with menus'**
  String get menuEditSheetNoGroupsHint;

  /// No description provided for @menuEditRemoveGroupTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove this group'**
  String get menuEditRemoveGroupTooltip;

  /// No description provided for @menuEditOptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} options'**
  String menuEditOptionCount(Object count);

  /// No description provided for @couponAdminDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Shop Coupon (Admin)'**
  String get couponAdminDialogTitle;

  /// No description provided for @couponCreateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shop coupon created successfully'**
  String get couponCreateSuccess;

  /// No description provided for @couponCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create coupon'**
  String get couponCreateFailed;

  /// No description provided for @couponAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Coupons: {name}'**
  String couponAdminTitle(Object name);

  /// No description provided for @couponAdminTitleNoName.
  ///
  /// In en, this message translates to:
  /// **'Shop Coupons: Unknown'**
  String get couponAdminTitleNoName;

  /// No description provided for @couponTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Coupons'**
  String get couponTitle;

  /// No description provided for @couponListTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Coupons'**
  String get couponListTitle;

  /// No description provided for @couponEmpty.
  ///
  /// In en, this message translates to:
  /// **'No shop coupons yet'**
  String get couponEmpty;

  /// No description provided for @couponGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'How to use shop coupons'**
  String get couponGuideTitle;

  /// No description provided for @couponGuideStep1Admin.
  ///
  /// In en, this message translates to:
  /// **'1) Admin is managing coupons for the selected shop. Customers will see them on the shop page automatically.'**
  String get couponGuideStep1Admin;

  /// No description provided for @couponGuideStep1Merchant.
  ///
  /// In en, this message translates to:
  /// **'1) Create coupons for your shop. Customers will see them on the shop page automatically.'**
  String get couponGuideStep1Merchant;

  /// No description provided for @couponGuideStep2Admin.
  ///
  /// In en, this message translates to:
  /// **'2) Press \"Open Coupon Form\" to edit via Dialog instead of inline form.'**
  String get couponGuideStep2Admin;

  /// No description provided for @couponGuideStep2Merchant.
  ///
  /// In en, this message translates to:
  /// **'2) Fill in the form below to create new coupons instantly.'**
  String get couponGuideStep2Merchant;

  /// No description provided for @couponGuideStep3.
  ///
  /// In en, this message translates to:
  /// **'3) Free delivery coupons will charge an additional 25% GP.'**
  String get couponGuideStep3;

  /// No description provided for @couponGuideStep4Admin.
  ///
  /// In en, this message translates to:
  /// **'4) Admin can enable/disable each coupon via the switch on the right.'**
  String get couponGuideStep4Admin;

  /// No description provided for @couponGuideStep4Merchant.
  ///
  /// In en, this message translates to:
  /// **'4) You can enable/disable each coupon via the switch on the right.'**
  String get couponGuideStep4Merchant;

  /// No description provided for @couponAdminOpenForm.
  ///
  /// In en, this message translates to:
  /// **'Open Coupon Form (Dialog)'**
  String get couponAdminOpenForm;

  /// No description provided for @couponCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon Code'**
  String get couponCodeLabel;

  /// No description provided for @couponCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get couponCodeRequired;

  /// No description provided for @couponNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon Name'**
  String get couponNameLabel;

  /// No description provided for @couponNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon name'**
  String get couponNameRequired;

  /// No description provided for @couponDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get couponDescLabel;

  /// No description provided for @couponTypePercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage Discount'**
  String get couponTypePercentage;

  /// No description provided for @couponTypeFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed Amount Discount'**
  String get couponTypeFixed;

  /// No description provided for @couponTypeFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Free Delivery'**
  String get couponTypeFreeDelivery;

  /// No description provided for @couponTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon Type'**
  String get couponTypeLabel;

  /// No description provided for @couponDiscountPercent.
  ///
  /// In en, this message translates to:
  /// **'Discount (%)'**
  String get couponDiscountPercent;

  /// No description provided for @couponDiscountBaht.
  ///
  /// In en, this message translates to:
  /// **'Discount (Baht)'**
  String get couponDiscountBaht;

  /// No description provided for @couponDiscountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter valid discount'**
  String get couponDiscountRequired;

  /// No description provided for @couponMaxDiscount.
  ///
  /// In en, this message translates to:
  /// **'Max Discount (Baht) optional'**
  String get couponMaxDiscount;

  /// No description provided for @couponMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Min Order (Baht) optional'**
  String get couponMinOrder;

  /// No description provided for @couponUsageLimit.
  ///
  /// In en, this message translates to:
  /// **'Total uses (0=unlimited)'**
  String get couponUsageLimit;

  /// No description provided for @couponPerUserLimit.
  ///
  /// In en, this message translates to:
  /// **'Limit/person'**
  String get couponPerUserLimit;

  /// No description provided for @couponStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start: {date}'**
  String couponStartDate(Object date);

  /// No description provided for @couponPickStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select start date'**
  String get couponPickStartDate;

  /// No description provided for @couponPick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get couponPick;

  /// No description provided for @couponEndDate.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String couponEndDate(Object date);

  /// No description provided for @couponPickEndDate.
  ///
  /// In en, this message translates to:
  /// **'Select expiry date'**
  String get couponPickEndDate;

  /// No description provided for @couponCreateBtn.
  ///
  /// In en, this message translates to:
  /// **'Create Coupon'**
  String get couponCreateBtn;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Shop Info'**
  String get editProfileTitle;

  /// No description provided for @editProfileTapPhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change shop photo'**
  String get editProfileTapPhoto;

  /// No description provided for @editProfileShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop Name'**
  String get editProfileShopName;

  /// No description provided for @editProfileShopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter shop name'**
  String get editProfileShopNameRequired;

  /// No description provided for @editProfileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get editProfileEmail;

  /// No description provided for @editProfilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get editProfilePhone;

  /// No description provided for @editProfilePhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get editProfilePhoneInvalid;

  /// No description provided for @editProfileAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop Address'**
  String get editProfileAddress;

  /// No description provided for @editProfilePinLocation.
  ///
  /// In en, this message translates to:
  /// **'Pin shop location'**
  String get editProfilePinLocation;

  /// No description provided for @editProfileNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location selected on map'**
  String get editProfileNoLocation;

  /// No description provided for @editProfileOpenDays.
  ///
  /// In en, this message translates to:
  /// **'Open Days'**
  String get editProfileOpenDays;

  /// No description provided for @editProfileOpenTime.
  ///
  /// In en, this message translates to:
  /// **'Open Time'**
  String get editProfileOpenTime;

  /// No description provided for @editProfileCloseTime.
  ///
  /// In en, this message translates to:
  /// **'Close Time'**
  String get editProfileCloseTime;

  /// No description provided for @editProfileSelectDayRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select at least 1 open day'**
  String get editProfileSelectDayRequired;

  /// No description provided for @editProfileSaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editProfileSaveBtn;

  /// No description provided for @editProfileSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get editProfileSaveSuccess;

  /// No description provided for @editProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot save: {error}'**
  String editProfileSaveFailed(Object error);

  /// No description provided for @editProfileDayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get editProfileDayMon;

  /// No description provided for @editProfileDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get editProfileDayTue;

  /// No description provided for @editProfileDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get editProfileDayWed;

  /// No description provided for @editProfileDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get editProfileDayThu;

  /// No description provided for @editProfileDayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get editProfileDayFri;

  /// No description provided for @editProfileDaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get editProfileDaySat;

  /// No description provided for @editProfileDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get editProfileDaySun;

  /// No description provided for @profileCompleteRoleDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get profileCompleteRoleDriver;

  /// No description provided for @profileCompleteRoleMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get profileCompleteRoleMerchant;

  /// No description provided for @profileCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Profile ({role})'**
  String profileCompleteTitle(Object role);

  /// No description provided for @profileCompleteLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileCompleteLogout;

  /// No description provided for @profileCompleteBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get profileCompleteBack;

  /// No description provided for @profileCompleteNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get profileCompleteNext;

  /// No description provided for @profileCompleteSaveStart.
  ///
  /// In en, this message translates to:
  /// **'Save & Start'**
  String get profileCompleteSaveStart;

  /// No description provided for @profileCompleteSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Profile saved successfully'**
  String get profileCompleteSaveSuccess;

  /// No description provided for @profileCompleteError.
  ///
  /// In en, this message translates to:
  /// **'❌ Error: {error}'**
  String profileCompleteError(Object error);

  /// No description provided for @profileCompleteUploadMissing.
  ///
  /// In en, this message translates to:
  /// **'Please upload: {items}'**
  String profileCompleteUploadMissing(Object items);

  /// No description provided for @profileCompleteStepPersonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Info'**
  String get profileCompleteStepPersonalTitle;

  /// No description provided for @profileCompleteStepPersonalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your information'**
  String get profileCompleteStepPersonalSubtitle;

  /// No description provided for @profileCompleteFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get profileCompleteFullNameLabel;

  /// No description provided for @profileCompleteFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get profileCompleteFullNameRequired;

  /// No description provided for @profileCompletePhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get profileCompletePhoneLabel;

  /// No description provided for @profileCompletePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get profileCompletePhoneRequired;

  /// No description provided for @profileCompleteStepVehicleTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Info'**
  String get profileCompleteStepVehicleTitle;

  /// No description provided for @profileCompleteStepVehicleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle type and enter plate number'**
  String get profileCompleteStepVehicleSubtitle;

  /// No description provided for @profileCompleteVehicleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get profileCompleteVehicleTypeLabel;

  /// No description provided for @profileCompleteVehicleMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get profileCompleteVehicleMotorcycle;

  /// No description provided for @profileCompleteVehicleCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get profileCompleteVehicleCar;

  /// No description provided for @profileCompletePlateLabel.
  ///
  /// In en, this message translates to:
  /// **'License plate'**
  String get profileCompletePlateLabel;

  /// No description provided for @profileCompletePlateRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter plate number'**
  String get profileCompletePlateRequired;

  /// No description provided for @profileCompleteStepDocsTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Documents'**
  String get profileCompleteStepDocsTitle;

  /// No description provided for @profileCompleteStepDocsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please take photos of your documents'**
  String get profileCompleteStepDocsSubtitle;

  /// No description provided for @profileCompleteDocIdCard.
  ///
  /// In en, this message translates to:
  /// **'ID card photo'**
  String get profileCompleteDocIdCard;

  /// No description provided for @profileCompleteDocDriverLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver license photo'**
  String get profileCompleteDocDriverLicense;

  /// No description provided for @profileCompleteDocVehiclePhoto.
  ///
  /// In en, this message translates to:
  /// **'Vehicle photo'**
  String get profileCompleteDocVehiclePhoto;

  /// No description provided for @profileCompleteDocPlatePhoto.
  ///
  /// In en, this message translates to:
  /// **'Plate photo'**
  String get profileCompleteDocPlatePhoto;

  /// No description provided for @profileCompleteDocsHint.
  ///
  /// In en, this message translates to:
  /// **'* Please upload all 4 documents'**
  String get profileCompleteDocsHint;

  /// No description provided for @profileCompleteDocSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected ✓'**
  String get profileCompleteDocSelected;

  /// No description provided for @profileCompleteDocTapToPick.
  ///
  /// In en, this message translates to:
  /// **'Tap to take photo or choose from gallery'**
  String get profileCompleteDocTapToPick;

  /// No description provided for @profileCompleteStepMerchantTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Info'**
  String get profileCompleteStepMerchantTitle;

  /// No description provided for @profileCompleteStepMerchantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your shop information'**
  String get profileCompleteStepMerchantSubtitle;

  /// No description provided for @profileCompleteMerchantNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name / owner'**
  String get profileCompleteMerchantNameLabel;

  /// No description provided for @profileCompleteAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop address'**
  String get profileCompleteAddressLabel;

  /// No description provided for @profileCompleteAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter address'**
  String get profileCompleteAddressRequired;

  /// No description provided for @profileCompleteStepBankTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank Info'**
  String get profileCompleteStepBankTitle;

  /// No description provided for @profileCompleteStepBankSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For receiving payouts (optional)'**
  String get profileCompleteStepBankSubtitle;

  /// No description provided for @profileCompleteBankNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank name'**
  String get profileCompleteBankNameLabel;

  /// No description provided for @profileCompleteBankNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Kasikorn, SCB'**
  String get profileCompleteBankNameHint;

  /// No description provided for @profileCompleteBankAccountNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get profileCompleteBankAccountNumberLabel;

  /// No description provided for @profileCompleteBankAccountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get profileCompleteBankAccountNameLabel;

  /// No description provided for @imagePickerChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get imagePickerChooseImage;

  /// No description provided for @imagePickerTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get imagePickerTakePhoto;

  /// No description provided for @imagePickerTakePhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use camera to take a new photo'**
  String get imagePickerTakePhotoSubtitle;

  /// No description provided for @imagePickerPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get imagePickerPickGallery;

  /// No description provided for @imagePickerPickGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick from your album'**
  String get imagePickerPickGallerySubtitle;

  /// No description provided for @landingLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get landingLogin;

  /// No description provided for @landingStart.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get landingStart;

  /// No description provided for @landingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Ride-hailing\nFood & Parcel Delivery'**
  String get landingHeadline;

  /// No description provided for @landingSubheadline.
  ///
  /// In en, this message translates to:
  /// **'A community super app\nRide, order food, and send parcels in one app'**
  String get landingSubheadline;

  /// No description provided for @landingServicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Services'**
  String get landingServicesTitle;

  /// No description provided for @landingServicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything in one app'**
  String get landingServicesSubtitle;

  /// No description provided for @landingServiceRideTitle.
  ///
  /// In en, this message translates to:
  /// **'Ride'**
  String get landingServiceRideTitle;

  /// No description provided for @landingServiceRideDesc.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle or car rides\nConvenient and safe'**
  String get landingServiceRideDesc;

  /// No description provided for @landingServiceFoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get landingServiceFoodTitle;

  /// No description provided for @landingServiceFoodDesc.
  ///
  /// In en, this message translates to:
  /// **'Order from nearby restaurants\nFast delivery to your home'**
  String get landingServiceFoodDesc;

  /// No description provided for @landingServiceParcelTitle.
  ///
  /// In en, this message translates to:
  /// **'Parcel'**
  String get landingServiceParcelTitle;

  /// No description provided for @landingServiceParcelDesc.
  ///
  /// In en, this message translates to:
  /// **'Send parcels to destination\nAffordable and trackable'**
  String get landingServiceParcelDesc;

  /// No description provided for @landingSignupNow.
  ///
  /// In en, this message translates to:
  /// **'Sign up now'**
  String get landingSignupNow;

  /// No description provided for @landingHowTitle.
  ///
  /// In en, this message translates to:
  /// **'Easy in 4 steps'**
  String get landingHowTitle;

  /// No description provided for @landingHowStep1Number.
  ///
  /// In en, this message translates to:
  /// **'1'**
  String get landingHowStep1Number;

  /// No description provided for @landingHowStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get landingHowStep1Title;

  /// No description provided for @landingHowStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Register with your phone number'**
  String get landingHowStep1Desc;

  /// No description provided for @landingHowStep2Number.
  ///
  /// In en, this message translates to:
  /// **'2'**
  String get landingHowStep2Number;

  /// No description provided for @landingHowStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Choose a service'**
  String get landingHowStep2Title;

  /// No description provided for @landingHowStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Ride, Food, or Parcel'**
  String get landingHowStep2Desc;

  /// No description provided for @landingHowStep3Number.
  ///
  /// In en, this message translates to:
  /// **'3'**
  String get landingHowStep3Number;

  /// No description provided for @landingHowStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get landingHowStep3Title;

  /// No description provided for @landingHowStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Choose destination and payment method'**
  String get landingHowStep3Desc;

  /// No description provided for @landingHowStep4Number.
  ///
  /// In en, this message translates to:
  /// **'4'**
  String get landingHowStep4Number;

  /// No description provided for @landingHowStep4Title.
  ///
  /// In en, this message translates to:
  /// **'Get served'**
  String get landingHowStep4Title;

  /// No description provided for @landingHowStep4Desc.
  ///
  /// In en, this message translates to:
  /// **'A driver accepts and comes to you'**
  String get landingHowStep4Desc;

  /// No description provided for @landingDriverCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Jedechai driver'**
  String get landingDriverCtaTitle;

  /// No description provided for @landingDriverCtaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn extra income, work freely, choose your own hours'**
  String get landingDriverCtaSubtitle;

  /// No description provided for @topupAdminPushTitle.
  ///
  /// In en, this message translates to:
  /// **'💰 New top-up request'**
  String get topupAdminPushTitle;

  /// No description provided for @topupAdminPushBody.
  ///
  /// In en, this message translates to:
  /// **'{driverName} requested a top-up of ฿{amount} — pending approval'**
  String topupAdminPushBody(Object driverName, Object amount);

  /// No description provided for @topupAdminEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'💰 New top-up request — {driverName} ฿{amount}'**
  String topupAdminEmailSubject(Object driverName, Object amount);

  /// No description provided for @topupAdminEmailHtml.
  ///
  /// In en, this message translates to:
  /// **'<div style=\"font-family:sans-serif;max-width:500px;margin:0 auto;padding:20px;\">\n  <h2 style=\"color:#1565C0;\">💰 New top-up request</h2>\n  <div style=\"background:#f5f5f5;padding:16px;border-radius:12px;margin:16px 0;\">\n    <p><strong>Driver:</strong> {driverName}</p>\n    <p><strong>Amount:</strong> <span style=\"color:#4CAF50;font-size:24px;font-weight:bold;\">฿{amount}</span></p>\n    <p><strong>Status:</strong> <span style=\"color:#FF9800;\">Pending approval</span></p>\n  </div>\n  <p style=\"color:#666;\">Please sign in to Admin to review and approve the top-up request</p>\n  <hr style=\"border:none;border-top:1px solid #eee;margin:20px 0;\">\n  <p style=\"color:#999;font-size:12px;\">JDC Delivery Admin System</p>\n</div>\n'**
  String topupAdminEmailHtml(Object driverName, Object amount);

  /// No description provided for @topupOmiseTransactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Top up via Omise PromptPay (฿{amount}) — Charge: {chargeId}'**
  String topupOmiseTransactionDescription(Object amount, Object chargeId);

  /// No description provided for @topupPromptPayTransactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Top up via PromptPay (฿{amount})'**
  String topupPromptPayTransactionDescription(Object amount);

  /// No description provided for @topupWithdrawalTransactionDescription.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal request ฿{amount} to {bankName} {accountNumber}'**
  String topupWithdrawalTransactionDescription(Object amount, Object bankName, Object accountNumber);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'th': return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
