import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ✅ Import Firebase notification setup
import 'package:mobile/components/utils/notif.dart';

class AuthService {
  final String baseUrl = dotenv.env['BASE_URL']!;

  /// 🔹 Register new user (Mobile)
  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String password,
    required String email,
    required String managerId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/api/register_mobile/");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "email": email,
          "manager_id": managerId,
        }),
      );

      if (response.statusCode == 201) {
        return {"success": true, "data": jsonDecode(response.body)};
      } else if (response.statusCode == 400) {
        final body = jsonDecode(response.body);
        return {"success": false, "error": body["error"] ?? body.toString()};
      } else {
        return {
          "success": false,
          "error":
              "Unexpected server response: ${response.statusCode} ${response.reasonPhrase}",
        };
      }
    } catch (e) {
      return {"success": false, "error": "Network or parsing error: $e"};
    }
  }

  /// 🔹 Login existing user (Mobile)
  Future<Map<String, dynamic>> loginUser({
    required String username,
    required String password,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/api/login_mobile/");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["access"] != null && data["refresh"] != null) {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString("access_token", data["access"]);
          await prefs.setString("refresh_token", data["refresh"]);

          print("✅ Login successful. Access token stored locally.");

          // ✅ Initialize Firebase and send device FCM token to backend
          try {
            await initFirebase(data["access"]);
            print("✅ Firebase initialized and FCM token sent.");
          } catch (fcmError) {
            print(
              "⚠️ Error initializing Firebase or sending FCM token: $fcmError",
            );
          }
        }

        return {"success": true, "data": data};
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final body = jsonDecode(response.body);
        return {"success": false, "error": body["error"] ?? body.toString()};
      } else {
        return {
          "success": false,
          "error":
              "Unexpected server response: ${response.statusCode} ${response.reasonPhrase}",
        };
      }
    } catch (e) {
      return {"success": false, "error": "Network or parsing error: $e"};
    }
  }
}
