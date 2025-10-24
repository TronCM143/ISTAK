import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> syncPendingRequests() async {
  final prefs = await SharedPreferences.getInstance();
  List<String> pending = prefs.getStringList("pending_transactions") ?? [];

  if (pending.isEmpty) {
    print("🟢 No pending transactions to sync.");
    return;
  }

  final token = prefs.getString("access_token");
  if (token == null) {
    print("⚠️ Missing access token. Cannot sync now.");
    return;
  }

  print("🔄 Syncing ${pending.length} pending transactions...");

  final url = Uri.parse("${dotenv.env['BASE_URL']}/api/borrowing/create/");
  List<String> successfullySynced = [];

  for (String transactionJson in pending) {
    try {
      final transaction = jsonDecode(transactionJson);
      String? imageUrl = transaction["borrower"]["image_url"];
      final photoPath = transaction["borrower"]["photo_path"];

      // Process image if not already processed
      if (imageUrl == null &&
          photoPath != null &&
          File(photoPath).existsSync()) {
        final processUrl = Uri.parse(
          "${dotenv.env['BASE_URL']}/api/process_image/",
        );
        final processRequest = http.MultipartRequest('POST', processUrl)
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['name'] = transaction["borrower"]["name"]
          ..fields['school_id'] = transaction["borrower"]["school_id"]
          ..files.add(await http.MultipartFile.fromPath('image', photoPath));

        final processResponse = await processRequest.send();
        final processResponseBody = await http.Response.fromStream(
          processResponse,
        );

        if (processResponse.statusCode == 200) {
          final data = jsonDecode(processResponseBody.body);
          imageUrl = data['image_url'];
          print("✅ Image processed during sync: $imageUrl");
        } else {
          print(
            "❌ Image processing failed: ${processResponse.statusCode} → ${processResponseBody.body}",
          );
          // Proceed with fallback to sending the raw image file
        }
      }

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['school_id'] = transaction["borrower"]["school_id"]
        ..fields['name'] = transaction["borrower"]["name"]
        ..fields['status'] = transaction["borrower"]["status"]
        ..fields['return_date'] = transaction["borrower"]["return_date"];

      for (var item in transaction["items"]) {
        request.fields['item_ids[]'] = item["item_id"];
      }

      if (imageUrl != null) {
        request.fields['image_url'] = imageUrl;
      } else if (photoPath != null && File(photoPath).existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('image', photoPath),
        );
      }

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 201) {
        print("✅ Synced successfully: ${transaction["borrower"]["name"]}");
        successfullySynced.add(transactionJson);
      } else {
        print(
          "❌ Failed to sync transaction for ${transaction["borrower"]["name"]}: "
          "${response.statusCode} → ${responseBody.body}",
        );
      }
    } catch (e) {
      print("⚠️ Sync error for transaction: $e");
    }
  }

  if (successfullySynced.isNotEmpty) {
    pending.removeWhere((item) => successfullySynced.contains(item));
    await prefs.setStringList("pending_transactions", pending);
    print(
      "✅ Sync complete — removed ${successfullySynced.length} transactions, "
      "${pending.length} remaining",
    );
  } else {
    print(
      "✅ Sync complete — no transactions synced, ${pending.length} remaining",
    );
  }
}
