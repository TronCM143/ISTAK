import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/apiURL.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

class ProcessTransaction extends StatelessWidget {
  final Map<String, String>? borrowerData;
  final List<Map<String, dynamic>> scannedItems; // id is String
  final VoidCallback onReset;

  const ProcessTransaction({
    Key? key,
    this.borrowerData,
    required this.scannedItems,
    required this.onReset,
  }) : super(key: key);

  Future<bool> _isOnline() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Connectivity check error: $e');
      return false;
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _saveTransaction(BuildContext context) async {
    if (borrowerData == null || scannedItems.isEmpty) {
      print('Validation failed: Incomplete data');
      print('borrowerData: $borrowerData, scannedItems: $scannedItems');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incomplete data: Borrower details or items missing'),
        ),
      );
      return;
    }

    final schoolId = borrowerData!['schoolId'];
    final name = borrowerData!['borrowerName'];
    final status = borrowerData!['status'];
    final returnDate = borrowerData!['return_date'];
    final borrowImageUrl =
        borrowerData!['image_url']; // Use distinct name to avoid shadowing
    if (schoolId == null ||
        name == null ||
        status == null ||
        returnDate == null ||
        borrowImageUrl == null) {
      print('Validation failed: Missing borrower fields');
      print(
        'schoolId: $schoolId, name: $name, status: $status, returnDate: $returnDate, imageUrl: $borrowImageUrl',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All borrower fields and image are required'),
        ),
      );
      return;
    }

    // Validate item_ids
    final itemIds = <String>[];
    for (var item in scannedItems) {
      final itemId = item['id'];
      if (itemId is! String || itemId.isEmpty) {
        print('Invalid item ID: $itemId is not a valid string');
        print('Item: $item');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid item ID: $itemId is not a valid string'),
          ),
        );
        return;
      }
      itemIds.add(itemId);
    }

    final token = await _getToken();
    if (token == null) {
      print('No token found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save transaction')),
      );
      return;
    }

    final requestId = const Uuid().v4();
    final borrowData = {
      'id': requestId,
      'type': 'borrow',
      'school_id': schoolId,
      'name': name,
      'status': status,
      'return_date': returnDate,
      'item_ids': itemIds,
      'borrow_date': DateTime.now().toIso8601String().split('T')[0],
      'image_url': borrowImageUrl,
      'is_synced': '0',
      'request_status': 'pending',
    };

    if (await _isOnline()) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${API.baseUrl}/api/borrowing/create/'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['school_id'] = schoolId;
        request.fields['name'] = name;
        request.fields['status'] = status;
        request.fields['return_date'] = returnDate;
        request.fields['item_ids'] = jsonEncode(itemIds);
        if (borrowImageUrl.isNotEmpty) {
          request.fields['image_url'] = borrowImageUrl;
        }

        print('📤 Request Payload:');
        print('Fields: ${request.fields}');

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();
        final responseData = jsonDecode(responseBody);

        print('✅ Response Status: ${response.statusCode}');
        print('✅ Response Body: $responseBody');

        if (response.statusCode == 201) {
          await LocalDatabase().saveTransaction({
            'id': responseData['id'],
            'school_id': schoolId,
            'name': name,
            'status': status,
            'borrow_date': borrowData['borrow_date'],
            'return_date': returnDate,
            'item_ids': itemIds,
            'image_url': borrowImageUrl,
            'transaction_status': 'borrowed',
            'is_synced': '1',
          });
          for (var item in scannedItems) {
            await LocalDatabase().saveItemDetails({
              'id': item['id'],
              'item_name': item['item_name'],
              'condition': item['condition'],
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transaction saved: ${responseData['id']}')),
          );
          onReset();
        } else {
          await LocalDatabase().saveBorrowRequest(borrowData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to sync: ${responseData['error'] ?? 'Unknown error'}. Saved locally',
              ),
            ),
          );
        }
      } catch (e) {
        print('❌ Sync error: $e');
        await LocalDatabase().saveBorrowRequest(borrowData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline: Transaction saved locally')),
        );
      }
    } else {
      print('🌐 Offline mode: Saving transaction locally');
      print('📦 Local Data: $borrowData');
      await LocalDatabase().saveBorrowRequest(borrowData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline: Transaction saved locally')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayImageUrl = borrowerData?['image_url'];
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Summary',
              style: GoogleFonts.ibmPlexMono(
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            if (displayImageUrl != null && displayImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  displayImageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[700],
                    child: Text(
                      'Failed to load image',
                      style: GoogleFonts.ibmPlexMono(color: Colors.white),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[700],
                child: Text(
                  'No Image',
                  style: GoogleFonts.ibmPlexMono(color: Colors.white),
                ),
              ),
            const SizedBox(height: 8),
            if (borrowerData != null) ...[
              Text(
                'Name: ${borrowerData!['borrowerName']}',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              Text(
                'School ID: ${borrowerData!['schoolId']}',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
              Text(
                'Return Date: ${borrowerData!['return_date']}',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Total Items: ${scannedItems.length}',
              style: GoogleFonts.ibmPlexMono(
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Item IDs: ${scannedItems.map((item) => item['id']).join(', ')}',
              style: GoogleFonts.ibmPlexMono(
                fontWeight: FontWeight.w300,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReset,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.ibmPlexMono(
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _saveTransaction(context),
                  child: Text(
                    'Save',
                    style: GoogleFonts.ibmPlexMono(
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
