import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/apiURl.dart';
import 'package:flutter/material.dart'; // Added for UI

final String baseUrl = API.baseUrl;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
List<Map<String, dynamic>> _notifications = []; // Store notifications locally

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
  _saveNotification(message); // Save notification in background
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
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    showLocalNotification(message);
    _saveNotification(message); // Save notification in foreground
  });
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    sendFcmTokenToBackend(userToken, newToken);
  });
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

void _saveNotification(RemoteMessage message) {
  final data = message.data;
  final notification = {
    'recent': DateTime.now().toIso8601String(), // Current time as recent
    'timeNotified': DateTime.now().toLocal().toString(),
    'itemName': data['item_name'] ?? 'Unknown Item',
    'schoolID': data['school_id'] ?? 'Unknown ID',
    'borrowerName': data['borrower_name'] ?? 'Unknown Borrower',
  };
  _notifications.add(notification);
  print("Saved notification: $notification");
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero, // 0 rounded corners
      ),
      backgroundColor: Colors.grey[850], // Dark background
      title: Text(
        'Updates',
        style: GoogleFonts.ibmPlexMono(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color.fromARGB(
            255,
            193,
            179,
            146,
          ), // White text for contrast
        ),
      ),
      content: Container(
        width: double.maxFinite, // Ensure it takes available width
        child: ListView.builder(
          shrinkWrap: true, // Allow it to size to content
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            return ListTile(
              title: Text(
                'Item: ${notification['itemName']}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Borrower: ${notification['borrowerName']}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'School ID: ${notification['schoolID']}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Time Notified: ${notification['timeNotified']}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    'Recent: ${notification['recent']}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.yellow[700], // Yellow icon/text color
          ),
          child: Icon(Icons.close_sharp),
        ),
      ],
    );
  }
}
