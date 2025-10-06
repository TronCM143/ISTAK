import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> syncPendingRequests() async {
  final db = await LocalDatabase().database;
  final requests = await LocalDatabase().getPendingRequests();
  final token = await SharedPreferences.getInstance().then(
    (prefs) => prefs.getString('access_token'),
  );
  if (token == null) return;

  for (var request in requests) {
    try {
      final httpRequest = http.MultipartRequest(
        'POST',
        Uri.parse('${dotenv.env['BASE_URL']}/api/borrowing/create/'),
      );
      httpRequest.headers['Authorization'] = 'Bearer $token';
      httpRequest.fields['school_id'] = request['school_id'];
      httpRequest.fields['name'] = request['name'];
      httpRequest.fields['status'] = request['status'];
      httpRequest.fields['return_date'] = request['return_date'];
      httpRequest.fields['item_ids'] = jsonEncode(request['item_ids']);
      httpRequest.files.add(
        await http.MultipartFile.fromPath('image', request['photo_path']),
      );

      final response = await httpRequest.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      if (response.statusCode == 201) {
        await LocalDatabase().deleteBorrowRequest(request['id']);
        await LocalDatabase().saveTransaction({
          'id': responseData['id'],
          'school_id': request['school_id'],
          'name': request['name'],
          'status': request['status'],
          'borrow_date': request['borrow_date'],
          'return_date': request['return_date'],
          'item_ids': request['item_ids'],
          'photo_path': request['photo_path'],
          'transaction_status': 'borrowed',
          'is_synced': '1',
        });
      }
    } catch (e) {
      print('Sync error for request ${request['id']}: $e');
    }
  }
}
