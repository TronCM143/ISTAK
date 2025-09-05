import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/apiURl.dart';

final String baseUrl = API.baseUrl;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> getAndSendFcmToken(String userToken) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  String? fcmToken = await messaging.getToken();
  if (fcmToken != null) {
    print("FCM Token: $fcmToken");
    await sendFcmTokenToBackend(userToken, fcmToken);
  }
}

Future<void> sendFcmTokenToBackend(String userToken, String fcmToken) async {
  final response = await http.post(
    Uri.parse("$baseUrl/api/update_fcm_token/"),
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

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  showLocalNotification(message);
}

Future<void> initFirebase(String userToken) async {
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission();

  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // Create channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel_id',
    'Default Notifications',
    description: 'This channel is used for default notifications.',
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

  // Token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    sendFcmTokenToBackend(userToken, newToken);
  });

  // Initial token registration
  await getAndSendFcmToken(userToken);
}

void showLocalNotification(RemoteMessage message) {
  String? title = message.notification?.title ?? message.data['title'];
  String? body = message.notification?.body ?? message.data['body'];

  if (title == null && body == null) return;

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'default_channel_id',
    'Default',
    channelDescription: 'Default notifications',
    importance: Importance.max,
    priority: Priority.high,
  );

  flutterLocalNotificationsPlugin.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(android: androidDetails),
  );
}
