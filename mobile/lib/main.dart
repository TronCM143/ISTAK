import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile/notifications/notif.dart';
import 'firebase_options.dart';
import 'package:mobile/splashPlusLogin.dart';

// Background handler must be top-level and registered before runApp
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  showLocalNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register background handler early
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final storage = FlutterSecureStorage();
    String? jwt = await storage.read(key: 'jwt_token');

    if (jwt != null) {
      debugPrint("JWT Token: $jwt");
      await initFirebase(jwt);
    } else {
      debugPrint("No JWT token found in storage");
    }
  } catch (e, st) {
    debugPrint("Error in main(): $e");
    debugPrint("$st");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}
