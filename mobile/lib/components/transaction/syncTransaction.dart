import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class SyncTransactions {
  static bool _isSyncing = false;

  // NEW: Non-UI sync logic
  static Future<bool> performSync(
    String type, {
    Function(String, bool)? onFeedback,
  }) async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      // Get token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        onFeedback?.call('Please log in to sync transactions', false);
        return false;
      }

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        onFeedback?.call('No internet connection. Cannot sync.', false);
        return false;
      }

      final db = LocalDatabase();
      final typesToSync = type == 'all' ? ['borrow', 'return'] : [type];
      bool success = true;

      for (final syncType in typesToSync) {
        if (syncType != 'borrow' && syncType != 'return') {
          print('Invalid sync type: $syncType');
          continue;
        }

        final pendingRequests = await db.getPendingRequests(type: syncType);
        if (pendingRequests.isEmpty) {
          onFeedback?.call('No pending $syncType requests to sync', true);
          continue;
        }

        print(
          'Syncing ${pendingRequests.length} pending $syncType requests: $pendingRequests',
        );

        for (var request in pendingRequests) {
          try {
            final itemId = request['item_id'];
            // Fetch item details
            final itemUrl = Uri.parse(
              '${dotenv.env['BASE_URL']}/api/items/?id=$itemId',
            );
            final itemResponse = await http.get(
              itemUrl,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            );

            if (itemResponse.statusCode != 200) {
              print(
                'Item fetch failed for $itemId: ${itemResponse.statusCode} ${itemResponse.body}',
              );
              onFeedback?.call('Failed to fetch item $itemId', false);
              success = false;
              continue;
            }

            final itemData = jsonDecode(itemResponse.body);
            Map<String, dynamic>? item;
            if (itemData is List && itemData.isNotEmpty) {
              item = itemData[0];
            } else if (itemData is Map<String, dynamic>) {
              item = itemData;
            } else {
              print('Invalid item data for $itemId: $itemData');
              onFeedback?.call('Invalid item data for $itemId', false);
              success = false;
              continue;
            }

            final bool isAvailable = item?['current_transaction'] == null;
            print('Item $itemId availability: $isAvailable, type: $syncType');

            if (syncType == 'borrow' && !isAvailable) {
              print('Item $itemId is not available for borrowing');
              onFeedback?.call('Item $itemId is currently borrowed', false);
              await db.deleteBorrowRequest(request['id']);
              success = false;
              continue;
            }

            if (syncType == 'return' && isAvailable) {
              print('Item $itemId is not borrowed for return');
              onFeedback?.call('Item $itemId is not borrowed', false);
              await db.deleteBorrowRequest(request['id']);
              continue;
            }

            // Prepare request payload
            final payload = syncType == 'borrow'
                ? {
                    'item_id': itemId,
                    'borrower_name': request['borrower_name'],
                    'school_id': request['school_id'],
                    'return_date': request['return_date'],
                  }
                : {
                    'item_id': int.parse(itemId),
                    'condition': request['condition'],
                  };

            final response = await http.post(
              Uri.parse('${dotenv.env['BASE_URL']}/api/borrow_process/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(payload),
            );

            print(
              'Sync response for $syncType request ${request['id']}: ${response.statusCode} ${response.body}',
            );
            final responseData = jsonDecode(response.body);

            if ((syncType == 'borrow' && response.statusCode == 201) ||
                (syncType == 'return' && response.statusCode == 200)) {
              await db.deleteBorrowRequest(request['id']);
              await db.saveTransaction({
                'id': responseData['transaction_id'] ?? request['id'],
                'item_id': itemId,
                'item_name': item?['item_name'],
                'borrower_name': request['borrower_name'],
                'school_id': request['school_id'],
                'borrow_date': request['borrow_date'],
                'return_date': syncType == 'return'
                    ? request['return_date']
                    : null,
                'condition': syncType == 'return' ? request['condition'] : null,
                'status': syncType == 'borrow' ? 'borrowed' : 'returned',
                'is_synced': 1,
              });
              await db.saveItemDetails({
                'id': itemId,
                'item_name': item?['item_name'],
                'condition': syncType == 'return'
                    ? request['condition']
                    : item?['condition'],
                'current_transaction': syncType == 'borrow'
                    ? {
                        'id': responseData['transaction_id'] ?? request['id'],
                        'borrow_date': request['borrow_date'],
                        'borrower_name': request['borrower_name'],
                      }
                    : null,
              });
              onFeedback?.call(
                responseData['message'] ??
                    'Item $itemId ${syncType == 'borrow' ? 'borrowed' : 'returned'} successfully',
                true,
              );
              if (syncType == 'borrow' && responseData['borrower'] != null) {
                final borrower = responseData['borrower'];
                onFeedback?.call(
                  'Borrower: ${borrower['name']} (ID: ${borrower['school_id']})',
                  true,
                );
              }
            } else {
              String errorMessage =
                  responseData['error'] ?? 'Failed to process $syncType';
              if (syncType == 'return' &&
                  (errorMessage.contains('Item not found') ||
                      errorMessage.contains('not borrowed'))) {
                errorMessage = 'Item $itemId is not borrowed';
                await db.deleteBorrowRequest(request['id']);
              }
              print(
                'Sync failed for item $itemId ($syncType): ${response.body}',
              );
              onFeedback?.call('Sync failed: $errorMessage', false);
              success = false;
            }
          } catch (e) {
            print('Error syncing $syncType request ${request['id']}: $e');
            onFeedback?.call(
              'Failed to sync item ${request['item_id']} ($syncType): $e',
              false,
            );
            success = false;
          }
        }
      }
      return success;
    } catch (e) {
      print('General sync error: $e');
      onFeedback?.call('Sync error: $e', false);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // UI wrapper for performSync
  static Future<bool> syncTransactions(
    BuildContext context, {
    required String type,
  }) async {
    return performSync(
      type,
      onFeedback: (message, isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
          ),
        );
      },
    );
  }
}
