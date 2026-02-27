import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_navigation_service.dart';

const String _kDefaultChannelId = 'jedechai_channel';
const String _kDefaultChannelName = 'JeDeChai Notifications';
const String _kDefaultChannelDescription =
    'Notifications from JeDeChai delivery app';

const String _kMerchantNewOrderChannelId = 'merchant_new_order_channel_v1';
const String _kMerchantNewOrderChannelName = 'Merchant New Orders';
const String _kMerchantNewOrderChannelDescription =
    'High priority alerts for new merchant food orders';

const int _kAndroidNotificationFlagInsistent = 4;

bool _isMerchantNewOrderMessage(RemoteMessage message) {
  final rawType = message.data['type'] ?? message.data['notification_type'];
  final type = rawType?.toString().trim();
  return type == 'merchant_new_order';
}

String _resolveNotificationTitle(RemoteMessage message) {
  final notificationTitle = message.notification?.title?.trim();
  if (notificationTitle != null && notificationTitle.isNotEmpty) {
    return notificationTitle;
  }

  final dataTitle = message.data['title']?.toString().trim();
  if (dataTitle != null && dataTitle.isNotEmpty) {
    return dataTitle;
  }

  return 'แจ้งเตือนใหม่';
}

String _resolveNotificationBody(RemoteMessage message) {
  final notificationBody = message.notification?.body?.trim();
  if (notificationBody != null && notificationBody.isNotEmpty) {
    return notificationBody;
  }

  final dataBody = message.data['body']?.toString().trim();
  if (dataBody != null && dataBody.isNotEmpty) {
    return dataBody;
  }

  return 'มีการแจ้งเตือนใหม่';
}

Future<void> _ensureAndroidNotificationChannels(
  FlutterLocalNotificationsPlugin localNotifications,
) async {
  const defaultChannel = AndroidNotificationChannel(
    _kDefaultChannelId,
    _kDefaultChannelName,
    description: _kDefaultChannelDescription,
    importance: Importance.high,
  );

  const merchantNewOrderChannel = AndroidNotificationChannel(
    _kMerchantNewOrderChannelId,
    _kMerchantNewOrderChannelName,
    description: _kMerchantNewOrderChannelDescription,
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alert_new_order'),
  );

  final androidLocalNotifications =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidLocalNotifications?.createNotificationChannel(defaultChannel);
  await androidLocalNotifications
      ?.createNotificationChannel(merchantNewOrderChannel);
}

AndroidNotificationDetails _buildAndroidNotificationDetails({
  required bool isMerchantNewOrder,
  required bool insistent,
}) {
  if (isMerchantNewOrder) {
    return AndroidNotificationDetails(
      _kMerchantNewOrderChannelId,
      _kMerchantNewOrderChannelName,
      channelDescription: _kMerchantNewOrderChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alert_new_order'),
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      showWhen: false,
      additionalFlags: insistent
          ? Int32List.fromList(
              const <int>[_kAndroidNotificationFlagInsistent],
            )
          : null,
    );
  }

  return const AndroidNotificationDetails(
    _kDefaultChannelId,
    _kDefaultChannelName,
    channelDescription: _kDefaultChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
    showWhen: false,
  );
}

DarwinNotificationDetails _buildDarwinNotificationDetails({
  required bool isMerchantNewOrder,
}) {
  return DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: isMerchantNewOrder ? 'AlertNewOrder.caf' : null,
    interruptionLevel:
        isMerchantNewOrder ? InterruptionLevel.timeSensitive : null,
  );
}

Future<void> _showBackgroundLocalNotification(RemoteMessage message) async {
  final localNotifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  const settings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
  );

  await localNotifications.initialize(settings);
  await _ensureAndroidNotificationChannels(localNotifications);

  final isMerchantNewOrder = _isMerchantNewOrderMessage(message);
  final notificationId = message.messageId?.hashCode ??
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
  final darwinDetails = _buildDarwinNotificationDetails(
    isMerchantNewOrder: isMerchantNewOrder,
  );

  await localNotifications.show(
    notificationId,
    _resolveNotificationTitle(message),
    _resolveNotificationBody(message),
    NotificationDetails(
      android: _buildAndroidNotificationDetails(
        isMerchantNewOrder: isMerchantNewOrder,
        insistent: isMerchantNewOrder,
      ),
      iOS: darwinDetails,
    ),
    payload: jsonEncode(message.data),
  );
}

/// FCM Notification Service
///
/// Handles Firebase Cloud Messaging operations:
/// - Initialize Firebase
/// - Request notification permissions
/// - Get and save FCM token
/// - Handle foreground messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugLog('🌙 ===== BACKGROUND MESSAGE RECEIVED =====');
  debugLog('📬 Message received while app is in background');
  debugLog('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
  debugLog('📋 Message ID: ${message.messageId}');
  debugLog('📋 From: ${message.from}');
  debugLog('📱 Title: ${message.notification?.title}');
  debugLog('📱 Body: ${message.notification?.body}');
  debugLog('📦 Data: ${message.data}');
  debugLog('🌙 ===== END OF BACKGROUND MESSAGE =====');

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugLog('❌ Background Firebase initialization failed: $e');
    return;
  }

  final isMerchantNewOrder = _isMerchantNewOrderMessage(message);
  if (message.notification == null || isMerchantNewOrder) {
    try {
      await _showBackgroundLocalNotification(message);
      debugLog('✅ Background local notification displayed');
    } catch (e) {
      debugLog('❌ Failed to show background local notification: $e');
    }
  }
}

class FCMNotificationService {
  static final FCMNotificationService _instance =
      FCMNotificationService._internal();
  factory FCMNotificationService() => _instance;
  FCMNotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Initialize FCM service
  Future<void> initialize() async {
    debugLog('🔔 Initializing FCM Notification Service...');
    debugLog('   └─ Timestamp: ${DateTime.now()}');

    try {
      // Initialize Firebase
      debugLog('🔍 Step 1: Initializing Firebase...');
      await Firebase.initializeApp();
      debugLog('✅ Firebase initialized');

      // Initialize Firebase Messaging
      debugLog('🔍 Step 2: Initializing Firebase Messaging...');
      _firebaseMessaging = FirebaseMessaging.instance;
      debugLog('✅ Firebase Messaging initialized');

      await _configureForegroundPresentationOptions();

      // Request notification permissions
      debugLog('🔍 Step 3: Requesting notification permissions...');
      await _requestPermissions();

      // Get FCM token
      debugLog('🔍 Step 4: Getting FCM token...');
      await _getFCMToken();

      // Listen for token refresh (iOS token can be ready after login)
      debugLog('🔍 Step 4.1: Listening for FCM token refresh...');
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        try {
          if (token.trim().isEmpty) {
            return;
          }
          _fcmToken = token;
          debugLog('🔄 FCM token refreshed');
          debugLog('   └─ Token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
          await _saveFCMTokenToSupabase(token);
        } catch (e) {
          debugLog('❌ Failed to handle token refresh: $e');
        }
      });
      debugLog('   └─ Token refresh listener set');

      // Setup message handlers
      debugLog('🔍 Step 5: Setting up message handlers...');
      _setupMessageHandlers();

      // Initialize local notifications
      debugLog('🔍 Step 6: Initializing local notifications...');
      await _initializeLocalNotifications();

      debugLog('✅ FCM Notification Service initialized successfully');
      debugLog('   └─ All steps completed');
    } catch (e) {
      debugLog('❌ Error initializing FCM service: $e');
      debugLog('   └─ Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _configureForegroundPresentationOptions() async {
    if (_firebaseMessaging == null) {
      return;
    }

    try {
      // iOS: If we allow system presentation in foreground AND we also show a local
      // notification, it will appear duplicated (system + local) and sound behavior
      // becomes inconsistent. We show local notifications ourselves.
      if (Platform.isIOS) {
        await _firebaseMessaging!.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
      } else {
        await _firebaseMessaging!.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      debugLog('✅ Foreground presentation options configured');
    } catch (e) {
      debugLog('⚠️ Could not configure foreground presentation options: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data.isEmpty) {
      debugLog('⚠️ Notification tap has no payload, skip navigation');
      return;
    }

    AppNavigationService.openFromNotification(message.data);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    debugLog('🔔 Requesting notification permissions...');
    debugLog('   └─ Platform: Android/iOS');

    try {
      final settings = await _firebaseMessaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugLog('📋 Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugLog('✅ Notification permissions granted');
        debugLog('   └─ All notification types allowed');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugLog('⚠️ Provisional notification permissions granted');
        debugLog('   └─ Some notification types allowed');
      } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugLog('❌ Notification permissions denied');
        debugLog('   └─ User explicitly denied permissions');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        debugLog('❓ Notification permissions not determined');
        debugLog('   └─ User has not made a decision yet');
      } else {
        debugLog(
            '❓ Unknown permission status: ${settings.authorizationStatus}');
      }

      debugLog('📋 Permission details:');
      debugLog('   └─ Alert: ${settings.alert}');
      debugLog('   └─ Badge: ${settings.badge}');
      debugLog('   └─ Sound: ${settings.sound}');
      debugLog('   └─ Announcement: ${settings.announcement}');
      debugLog('   └─ CarPlay: ${settings.carPlay}');
      debugLog('   └─ CriticalAlert: ${settings.criticalAlert}');
    } catch (e) {
      debugLog('❌ Error requesting permissions: $e');
      debugLog('   └─ Stack trace: ${StackTrace.current}');
    }
  }

  /// Get FCM token and save to Supabase
  Future<void> _getFCMToken() async {
    try {
      debugLog('🔔 Getting FCM token...');
      debugLog('   └─ Attempting to get token from Firebase...');

      if (_firebaseMessaging == null) {
        debugLog('❌ FirebaseMessaging is not initialized');
        return;
      }

      try {
        await _firebaseMessaging!.setAutoInitEnabled(true);
      } catch (e) {
        debugLog('⚠️ Could not enable auto-init for FCM: $e');
      }

      NotificationSettings? settings;
      try {
        settings = await _firebaseMessaging!.getNotificationSettings();
      } catch (e) {
        debugLog('⚠️ Could not read notification settings: $e');
      }

      final currentStatus = settings?.authorizationStatus;
      debugLog('📋 Current permission status: $currentStatus');
      if (currentStatus == AuthorizationStatus.denied) {
        debugLog('❌ Permission denied. Skip token fetch.');
        return;
      }

      if (currentStatus == AuthorizationStatus.notDetermined) {
        await _requestPermissions();
      }

      if (Platform.isIOS) {
        String? apnsToken;
        for (var i = 0; i < 5; i++) {
          try {
            apnsToken = await _firebaseMessaging!.getAPNSToken();
          } catch (e) {
            debugLog('⚠️ getAPNSToken failed: $e');
          }

          if (apnsToken != null && apnsToken.isNotEmpty) {
            debugLog('✅ APNs token ready');
            debugLog('   └─ APNs: ${apnsToken.substring(0, apnsToken.length > 12 ? 12 : apnsToken.length)}...');
            break;
          }

          await Future<void>.delayed(const Duration(milliseconds: 800));
        }

        if (apnsToken == null || apnsToken.isEmpty) {
          debugLog('⚠️ APNs token is still null. FCM token may be null on iOS.');
        }
      }

      for (var i = 0; i < 5; i++) {
        _fcmToken = await _firebaseMessaging!.getToken();
        if (_fcmToken != null && _fcmToken!.isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }

      if (_fcmToken != null) {
        debugLog('✅ FCM Token obtained successfully');
        debugLog('   └─ Token: ${_fcmToken!.substring(0, 20)}...');
        debugLog('   └─ Length: ${_fcmToken!.length} characters');
        debugLog('   └─ Timestamp: ${DateTime.now()}');

        debugLog('💾 Saving token to database...');
        await _saveFCMTokenToSupabase(_fcmToken!);
      } else {
        debugLog('❌ Failed to get FCM token');
        debugLog('   └─ Token is null');
        debugLog('   └─ Check Firebase project configuration');
      }
    } catch (e) {
      debugLog('❌ Error getting FCM token: $e');
      debugLog('   └─ Stack trace: ${StackTrace.current}');
    }
  }

  /// Save FCM token to Supabase profiles table
  Future<void> _saveFCMTokenToSupabase(String token) async {
    try {
      debugLog('💾 Saving FCM token to Supabase...');
      debugLog('   └─ Token length: ${token.length} characters');

      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugLog('❌ No authenticated user found');
        debugLog('   └─ User not logged in');
        return;
      }

      debugLog('👤 Current user: ${currentUser.email}');
      debugLog('🆔 User ID: ${currentUser.id}');

      debugLog('📤 Updating profiles table...');
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', currentUser.id);

      debugLog('✅ FCM token saved to Supabase successfully');
      debugLog('   └─ Updated user: ${currentUser.id}');
      debugLog('   └─ Token saved: ${token.substring(0, 20)}...');
    } catch (e) {
      debugLog('❌ Error saving FCM token to Supabase: $e');
      debugLog('   └─ Stack trace: ${StackTrace.current}');
    }
  }

  /// Initialize local notifications for foreground messages
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null || response.payload!.isEmpty) return;
        try {
          final payloadData =
              jsonDecode(response.payload!) as Map<String, dynamic>;
          AppNavigationService.openFromNotification(
            payloadData
                .map((key, value) => MapEntry(key, value?.toString() ?? '')),
          );
        } catch (e) {
          debugLog('⚠️ Failed to parse local notification payload: $e');
        }
      },
    );

    await _ensureAndroidNotificationChannels(_localNotifications);

    debugLog('✅ Local notifications initialized');
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    debugLog('🔧 Setting up message handlers...');

    // Handle background messages
    debugLog('   └─ Setting up background message handler...');
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugLog('   └─ Background message handler set');

    // Handle foreground messages
    debugLog('   └─ Setting up foreground message listener...');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugLog('🎉 ===== FOREGROUND MESSAGE RECEIVED =====');
      debugLog('📨 Message received while app is in foreground');
      debugLog('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      debugLog('📋 Message ID: ${message.messageId}');
      debugLog('📋 Sent Time: ${message.sentTime}');
      debugLog('📋 TTL: ${message.ttl}');
      debugLog('📋 Collapse Key: ${message.collapseKey}');
      debugLog('📋 From: ${message.from}');

      debugLog('📱 Notification Details:');
      debugLog('   - Title: ${message.notification?.title}');
      debugLog('   - Body: ${message.notification?.body}');
      debugLog(
          '   - Android Channel ID: ${message.notification?.android?.channelId}');
      debugLog(
          '   - Android Click Action: ${message.notification?.android?.clickAction}');
      debugLog('   - Android Color: ${message.notification?.android?.color}');
      debugLog('   - Android Sound: ${message.notification?.android?.sound}');
      debugLog('   - Android Tag: ${message.notification?.android?.tag}');
      debugLog('   - Apple Badge: ${message.notification?.apple?.badge}');
      debugLog('   - Apple Sound: ${message.notification?.apple?.sound}');
      debugLog('   - Apple Subtitle: ${message.notification?.apple?.subtitle}');

      debugLog('📦 Custom Data:');
      if (message.data.isNotEmpty) {
        message.data.forEach((key, value) {
          debugLog('   - $key: $value');
        });
      } else {
        debugLog('   - No custom data');
      }

      debugLog('🎉 ===== END OF FOREGROUND MESSAGE =====');

      // Show local notification when app is in foreground
      _showLocalNotification(message);
    });
    debugLog('   └─ Foreground message listener set');

    // Handle notification tap when app is in background
    debugLog('   └─ Setting up background tap handler...');
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugLog('🎯 ===== NOTIFICATION TAP (BACKGROUND) =====');
      debugLog('📱 User tapped notification while app was in background');
      debugLog('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
      debugLog('📋 Message ID: ${message.messageId}');
      debugLog('📱 Title: ${message.notification?.title}');
      debugLog('📱 Body: ${message.notification?.body}');
      debugLog('📦 Data: ${message.data}');
      debugLog('🎯 ===== END OF NOTIFICATION TAP =====');
      _handleNotificationTap(message);
    });

    // Check if app was opened from a terminated state
    if (_firebaseMessaging != null) {
      _firebaseMessaging!.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          debugLog('🎯 ===== NOTIFICATION TAP (TERMINATED) =====');
          debugLog('📱 App opened from terminated state via notification');
          debugLog('⏰ Timestamp: ${DateTime.now().toIso8601String()}');
          debugLog('📋 Message ID: ${message.messageId}');
          debugLog('📱 Title: ${message.notification?.title}');
          debugLog('📱 Body: ${message.notification?.body}');
          debugLog('📦 Data: ${message.data}');
          debugLog('🎯 ===== END OF NOTIFICATION TAP =====');
          _handleNotificationTap(message);
        }
      });
      debugLog('   └─ Background tap handler set');
    }

    debugLog('✅ All message handlers set up successfully');
  }

  /// Show local notification (head-up notification)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    debugLog('🔔 ===== SHOWING LOCAL NOTIFICATION =====');
    debugLog('📱 Creating local notification for foreground message');
    debugLog('📋 Message ID: ${message.messageId}');
    debugLog('📱 Title: ${_resolveNotificationTitle(message)}');
    debugLog('📱 Body: ${_resolveNotificationBody(message)}');
    debugLog('📦 Payload: ${jsonEncode(message.data)}');

    try {
      final isMerchantNewOrder = _isMerchantNewOrderMessage(message);
      final androidDetails = _buildAndroidNotificationDetails(
        isMerchantNewOrder: isMerchantNewOrder,
        insistent: false,
      );
      final darwinDetails = _buildDarwinNotificationDetails(
        isMerchantNewOrder: isMerchantNewOrder,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final notificationId = message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);
      debugLog('🔔 Showing notification with ID: $notificationId');

      await _localNotifications.show(
        notificationId,
        _resolveNotificationTitle(message),
        _resolveNotificationBody(message),
        notificationDetails,
        payload: jsonEncode(message.data),
      );

      debugLog('✅ Local notification displayed successfully');
      debugLog('🔔 ===== END OF LOCAL NOTIFICATION =====');
    } catch (e, stackTrace) {
      debugLog('❌ ERROR showing local notification: $e');
      debugLog('📋 Stack trace: $stackTrace');
      debugLog('🔔 ===== LOCAL NOTIFICATION FAILED =====');
    }
  }

  /// Clear FCM token (call on logout)
  Future<void> clearToken() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': null}).eq('id', currentUser.id);

        debugLog('✅ FCM token cleared from database');
      }
    } catch (e) {
      debugLog('❌ Error clearing FCM token: $e');
    }
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    try {
      if (_firebaseMessaging != null) {
        await _firebaseMessaging!.deleteToken();
        _fcmToken = null;
        debugLog('✅ FCM token deleted successfully');
      }
    } catch (e) {
      debugLog('❌ Error deleting FCM token: $e');
    }
  }

  /// Get current FCM token
  String? get currentToken => _fcmToken;

  /// Get current FCM token (compatibility)
  String? get fcmToken => _fcmToken;

  /// Save FCM token (compatibility method)
  Future<void> saveToken() async {
    try {
      if (_firebaseMessaging == null) {
        debugLog('🔄 saveToken: FirebaseMessaging not ready, initializing...');
        await initialize();
      }
      await _getFCMToken();
    } catch (e) {
      debugLog('❌ saveToken failed: $e');
    }
  }
}
