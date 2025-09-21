import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ReturnItem extends StatefulWidget {
  const ReturnItem({Key? key}) : super(key: key);

  @override
  State<ReturnItem> createState() => _ReturnItemState();
}

class _ReturnItemState extends State<ReturnItem> {
  final String baseUrl = API.baseUrl; // e.g., 'http://192.168.1.6:8000'
  bool isLoading = false;
  bool isSyncing = false;
  String? error;
  MobileScannerController scannerController = MobileScannerController();

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<bool> isOnline() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<void> syncPendingReturns() async {
    if (isSyncing) return;
    setState(() {
      isSyncing = true;
    });

    try {
      final token = await getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to sync returns')),
        );
        return;
      }

      if (!(await isOnline())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot sync.')),
        );
        return;
      }

      final db = LocalDatabase();
      final pendingReturns = await db.getPendingRequests(type: 'return');
      if (pendingReturns.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pending return requests to sync')),
        );
        return;
      }

      print('Pending return requests to sync: $pendingReturns');

      for (var request in pendingReturns) {
        try {
          final itemId = request['item_id'];
          final condition = request['condition'];
          print('Processing return for item $itemId with condition $condition');

          final response = await http.post(
            Uri.parse('$baseUrl/api/borrow_process/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'item_id': itemId, 'condition': condition}),
          );

          print(
            'Sync response for return request ${request['id']}: ${response.statusCode} ${response.body}',
          );
          final responseData = jsonDecode(response.body);
          if (response.statusCode == 200) {
            await db.deleteBorrowRequest(request['id']);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Synced: ${responseData['message'] ?? 'Item $itemId returned successfully'}',
                ),
              ),
            );
          } else {
            String errorMessage =
                responseData['error'] ?? 'Failed to return item';
            if (errorMessage.contains('Item not found')) {
              errorMessage = 'Item $itemId isn’t borrowed yet.';
            }
            print('Sync failed for item $itemId: ${response.body}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sync failed for item $itemId: $errorMessage'),
              ),
            );
          }
        } catch (e) {
          print('Error syncing return request ${request['id']}: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync item ${request['item_id']}: $e'),
            ),
          );
        }
      }
    } catch (e) {
      print('Error during sync: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sync error: $e')));
    } finally {
      setState(() {
        isSyncing = false;
      });
    }
  }

  Future<void> returnItem(String itemId) async {
    final condition = await _showConditionDialog();
    if (condition == null) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final token = await getToken();
      if (token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in first')));
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Store in local database first
      final requestId = Uuid().v4();
      final returnDate = DateTime.now().toIso8601String().split('T')[0];
      final requestData = {
        'id': requestId,
        'type': 'return',
        'item_id': itemId,
        'borrower_name': null, // Not needed for return
        'school_id': null, // Not needed for return
        'return_date': returnDate, // Store date for tracking
        'borrow_date': null, // Not needed for return
        'condition': condition,
        'is_synced': '0',
        'status': 'pending',
      };
      await LocalDatabase().saveBorrowRequest(requestData);
      print('Saved return request locally: $requestData');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return request saved locally')),
      );

      // Attempt to sync if online
      if (await isOnline()) {
        final response = await http.post(
          Uri.parse('$baseUrl/api/borrow_process/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'item_id': itemId, 'condition': condition}),
        );

        print(
          'Return response for $itemId: ${response.statusCode} ${response.body}',
        );
        final responseData = jsonDecode(response.body);
        if (response.statusCode == 200) {
          await LocalDatabase().deleteBorrowRequest(requestId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseData['message'] ?? 'Item $itemId returned successfully',
              ),
            ),
          );
        } else {
          String errorMessage =
              responseData['error'] ?? 'Failed to return item';
          if (errorMessage.contains('Item not found')) {
            errorMessage = 'Item $itemId isn’t borrowed yet.';
          }
          print('Return failed for $itemId: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error returning item $itemId: $errorMessage'),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request will sync later')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Request will sync when online',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error returning item $itemId: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<String?> _showConditionDialog() async {
    String? selectedCondition;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Return Item', style: TextStyle(color: Colors.white)),
        content: DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Condition',
            labelStyle: TextStyle(color: Color.fromARGB(255, 231, 220, 187)),
          ),
          style: const TextStyle(color: Colors.white),
          dropdownColor: Colors.grey[850],
          items: const [
            DropdownMenuItem(value: 'Good', child: Text('Good')),
            DropdownMenuItem(value: 'Fair', child: Text('Fair')),
            DropdownMenuItem(value: 'Damaged', child: Text('Damaged')),
            DropdownMenuItem(value: 'Broken', child: Text('Broken')),
          ],
          onChanged: (value) {
            selectedCondition = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              if (selectedCondition == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a condition')),
                );
                return;
              }
              Navigator.pop(context, selectedCondition);
            },
            child: const Text('Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Return Item',
          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        actions: [
          IconButton(
            icon: isSyncing
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.sync, color: Colors.white),
            onPressed: isSyncing ? null : syncPendingReturns,
            tooltip: 'Sync Pending Returns',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 13, 20, 11),
                  Color.fromARGB(255, 40, 38, 38),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: MobileScanner(
                  controller: scannerController,
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        final String itemId = barcode.rawValue!;
                        print('Scanned QR code: $itemId');
                        await scannerController.stop(); // Pause scanning
                        await returnItem(itemId);
                        await scannerController.start(); // Resume scanning
                        break;
                      }
                    }
                  },
                ),
              ),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
