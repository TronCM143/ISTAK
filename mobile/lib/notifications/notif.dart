import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Get the current device FCM token and send to backend
Future<void> getAndSendFcmToken(String userToken) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  String? fcmToken = await messaging.getToken();

  if (fcmToken != null) {
    print("📱 FCM Token: $fcmToken");
    await sendFcmTokenToBackend(userToken, fcmToken);
  } else {
    print("⚠️ Failed to get FCM token.");
  }
}

/// Send token to backend for this logged-in user
Future<void> sendFcmTokenToBackend(String userToken, String fcmToken) async {
  final response = await http.post(
    Uri.parse("${dotenv.env['BASE_URL']}/api/update_fcm_token/"),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $userToken",
    },
    body: jsonEncode({"fcm_token": fcmToken}),
  );

  if (response.statusCode == 200) {
    print("✅ FCM token updated successfully");
  } else {
    print("❌ Failed to update FCM token: ${response.body}");
  }
}

/// Background handler (runs even when app is terminated)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  showLocalNotification(message);
}

/// Initialize Firebase messaging + notification settings
Future<void> initFirebase(String userToken) async {
  await Firebase.initializeApp();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Ask permission on Android 13+ / iOS
  await FirebaseMessaging.instance.requestPermission();

  // Initialize local notifications
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Create default notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel_id',
    'Default Notifications',
    description: 'This channel is used for system notifications.',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    showLocalNotification(message);
  });

  // Handle token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    sendFcmTokenToBackend(userToken, newToken);
  });

  // Initial token send
  await getAndSendFcmToken(userToken);
}

/// Display system tray notification (no in-app list)
void showLocalNotification(RemoteMessage message) {
  String? title = message.notification?.title ?? message.data['title'];
  String? body = message.notification?.body ?? message.data['body'];

  if (title == null && body == null) return;

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'default_channel_id',
    'Default Notifications',
    channelDescription: 'System tray notifications',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(android: androidDetails),
  );
}
