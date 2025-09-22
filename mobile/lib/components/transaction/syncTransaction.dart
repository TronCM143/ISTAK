import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';

class SyncTransactions {
  static Future<bool> syncTransactions(
    BuildContext context, {
    required String type, // 'borrow', 'return', or 'all'
  }) async {
    bool success = true;
    bool isSyncing = false;

    if (isSyncing) return false;
    isSyncing = true;

    try {
      // Get token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please log in to sync transactions',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No internet connection. Cannot sync.',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return false;
      }

      final db = LocalDatabase();
      final typesToSync = type == 'all' ? ['borrow', 'return'] : [type];
      for (final syncType in typesToSync) {
        if (syncType != 'borrow' && syncType != 'return') {
          print('Invalid sync type: $syncType');
          continue;
        }

        final pendingRequests = await db.getPendingRequests(type: syncType);
        if (pendingRequests.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No pending $syncType requests to sync',
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
              backgroundColor: Colors.blueGrey,
            ),
          );
          continue;
        }

        print(
          'Syncing ${pendingRequests.length} pending $syncType requests: $pendingRequests',
        );

        for (var request in pendingRequests) {
          try {
            final itemId = request['item_id'];
            // Fetch item details
            final itemUrl = Uri.parse('${API.baseUrl}/api/items/?id=$itemId');
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to fetch item $itemId',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Invalid item data for $itemId',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              success = false;
              continue;
            }

            final bool isAvailable = item?['current_transaction'] == null;
            print('Item $itemId availability: $isAvailable, type: $syncType');

            if (syncType == 'borrow' && !isAvailable) {
              print('Item $itemId is not available for borrowing');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Item $itemId is currently borrowed',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              success = false;
              continue;
            }

            if (syncType == 'return' && isAvailable) {
              print('Item $itemId is not borrowed for return');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Item $itemId is not borrowed',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              await db.deleteBorrowRequest(request['id']);
              continue;
            }

            // Prepare request payload
            final payload = syncType == 'borrow'
                ? {
                    'item_id': itemId, // Keep as string for borrow
                    'borrower_name': request['borrower_name'],
                    'school_id': request['school_id'],
                    'return_date': request['return_date'],
                  }
                : {
                    'item_id': int.parse(itemId), // Convert to int for return
                    'condition': request['condition'],
                  };

            final response = await http.post(
              Uri.parse('${API.baseUrl}/api/borrow_process/'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Synced: ${responseData['message'] ?? 'Item $itemId ${syncType == 'borrow' ? 'borrowed' : 'returned'} successfully'}',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                ),
              );
              if (syncType == 'borrow' && responseData['borrower'] != null) {
                final borrower = responseData['borrower'];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Borrower: ${borrower['name']} (ID: ${borrower['school_id']})',
                      style: GoogleFonts.ibmPlexMono(color: Colors.white),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              print(
                'Synced Transaction ID: ${responseData['id'] ?? 'unknown'}',
              );
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sync failed: $errorMessage',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              );
              success = false;
            }
          } catch (e) {
            print('Error syncing $syncType request ${request['id']}: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to sync item ${request['item_id']} ($syncType): $e',
                  style: GoogleFonts.ibmPlexMono(color: Colors.white),
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
            success = false;
          }
        }
      }
    } catch (e) {
      print('General sync error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync error: $e',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      success = false;
    } finally {
      isSyncing = false;
    }

    return success;
  }
}
