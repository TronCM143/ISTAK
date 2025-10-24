import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'components/utils/firebase_options.dart';
import 'package:mobile/components/utils/splashPlusLogin.dart';
import 'package:mobile/components/utils/notif.dart';
import 'package:mobile/components/transaction/sync.dart';

// ✅ Put GlassShowcase in lib/glass_showcase.dart and import that:

/// Handle background FCM messages (must be a top-level entry point on Android)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  showLocalNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Register background FCM handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Retrieve saved JWT token
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString("access_token");

    if (jwt != null) {
      debugPrint("JWT Token found — initializing Firebase messaging");
      await initFirebase(jwt);
    } else {
      debugPrint("No JWT token found in storage — will initialize after login");
    }

    // Check initial connectivity and sync if online
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity != ConnectivityResult.none) {
      debugPrint(
        "🌐 Internet available — running initial syncPendingRequests()",
      );
      await syncPendingRequests();
    } else {
      debugPrint("📴 Offline — pending transactions will sync when online");
    }

    // Listen for connectivity changes to trigger sync
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        debugPrint("🌐 Internet reconnected — running syncPendingRequests()");
        await syncPendingRequests();
      } else {
        debugPrint("📴 Lost internet connection");
      }
    });
  } catch (e, st) {
    debugPrint("❌ Error initializing app: $e");
    debugPrint("$st");
  }

  // Optional: filter noisy blur warnings
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('blur radius')) {
      debugPrint('⚠️ BlurRadius warning from: ${details.stack}');
    } else {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: MaterialApp is *not* const; the home can be const since AssetImage is const.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(
        //  background: AssetImage('assets/background.jpg'),
      ),
    );
  }
}
