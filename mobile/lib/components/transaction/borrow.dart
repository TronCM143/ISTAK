import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

class Borrow extends StatefulWidget {
  const Borrow({Key? key}) : super(key: key);

  @override
  State<Borrow> createState() => _QRScannerState();
}

class _QRScannerState extends State<Borrow> {
  final String baseUrl = API.baseUrl;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  bool isProcessing = false;
  bool isSyncing = false;
  final TextEditingController returnDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  Future<void> syncPendingRequests() async {
    if (isSyncing) return;
    setState(() {
      isSyncing = true;
    });

    try {
      final token = await getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to sync requests')),
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
      final pendingRequests = await db.getPendingRequests(
        type: 'borrow',
      ); // Specify borrow requests
      if (pendingRequests.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pending borrow requests to sync')),
        );
        return;
      }

      print('Pending borrow requests to sync: $pendingRequests');

      for (var request in pendingRequests) {
        try {
          // Fetch item details to check availability
          final itemId = request['item_id']; // Keep as string
          print('Checking availability for item $itemId');
          final itemUrl = Uri.parse('$baseUrl/api/items/?id=$itemId');
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
                  itemResponse.statusCode == 404
                      ? 'Item $itemId not found'
                      : 'Failed to fetch item $itemId',
                ),
              ),
            );
            continue; // Skip to next request
          }

          final itemData = jsonDecode(itemResponse.body);
          Map<String, dynamic>? item;
          if (itemData is List) {
            if (itemData.isEmpty) {
              print('Item $itemId not found in response: $itemData');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Item $itemId not found')));
              continue;
            }
            item = itemData[0] as Map<String, dynamic>;
          } else if (itemData is Map<String, dynamic>) {
            item = itemData;
          } else {
            print('Invalid item data format for $itemId: $itemData');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid item data format')),
            );
            continue;
          }

          final bool isAvailable = item['current_transaction'] == null;
          print(
            'Item $itemId availability: $isAvailable, current_transaction: ${item['current_transaction']}',
          );

          if (isAvailable) {
            // Send borrow request to backend
            final response = await http.post(
              Uri.parse('$baseUrl/api/borrow_process/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'item_id': itemId,
                'borrower_name': request['borrower_name'],
                'school_id': request['school_id'],
                'return_date': request['return_date'],
              }),
            );

            print(
              'Sync response for request ${request['id']}: ${response.statusCode} ${response.body}',
            );
            final responseData = jsonDecode(response.body);
            if (response.statusCode == 201) {
              // Delete the request from local storage
              await db.deleteBorrowRequest(request['id']);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Synced: ${responseData['message'] ?? 'Item $itemId borrowed successfully'}',
                  ),
                ),
              );
              if (responseData['borrower'] != null) {
                final borrower = responseData['borrower'];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Borrower: ${borrower['name']} (ID: ${borrower['school_id']})',
                    ),
                  ),
                );
              }
            } else {
              print('Sync failed for item $itemId: ${response.body}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sync failed for item $itemId: ${responseData['error'] ?? 'Failed to borrow item'}',
                  ),
                ),
              );
            }
          } else {
            print(
              'Item $itemId not available, current_transaction: ${item['current_transaction']}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Item $itemId is currently borrowed. Request will retry later.',
                ),
              ),
            );
          }
        } catch (e) {
          print('Error syncing request ${request['id']}: $e');
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

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Borrow Item',
          style: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
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
            onPressed: isSyncing ? null : syncPendingRequests,
            tooltip: 'Sync Pending Requests',
          ),
        ],
      ),
      body: Stack(
        children: [
          QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
          if (isProcessing) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) async {
      if (isProcessing) return;
      setState(() {
        isProcessing = true;
        result = scanData;
      });
      if (result != null && result!.code != null) {
        await controller.pauseCamera();
        await _processScannedQR(result!.code!);
        await controller.resumeCamera();
      }
      setState(() {
        isProcessing = false;
      });
    });
  }

  Future<void> _processScannedQR(String code) async {
    print('Scanned QR Code: "$code"');
    try {
      final token = await getToken();
      if (token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in first')));
        return;
      }

      final itemId = code.trim(); // Keep as string
      print('Processing borrow for item $itemId');
      final borrowData = await _showBorrowDialog(context);
      if (borrowData == null) return;

      // Store in local database first
      final requestId = Uuid().v4();
      final borrowDate = DateTime.now().toIso8601String().split('T')[0];
      final requestData = {
        'id': requestId,
        'type': 'borrow',
        'item_id': itemId,
        'borrower_name': borrowData['borrowerName'],
        'school_id': borrowData['schoolId'],
        'return_date': borrowData['return_date'],
        'borrow_date': borrowDate,
        'condition': null, // Not used for borrow
        'is_synced': '0',
        'status': 'pending',
      };
      await LocalDatabase().saveBorrowRequest(requestData);
      print('Saved borrow request locally: $requestData');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request saved locally')));

      // Attempt to sync if online
      try {
        if (await isOnline()) {
          // Fetch item details to check availability
          final itemUrl = Uri.parse('$baseUrl/api/items/?id=$itemId');
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
                  itemResponse.statusCode == 404
                      ? 'Item $itemId not found'
                      : 'Failed to fetch item details',
                ),
              ),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request will sync later')),
            );
            return;
          }

          final itemData = jsonDecode(itemResponse.body);
          Map<String, dynamic>? item;
          if (itemData is List) {
            if (itemData.isEmpty) {
              print('Item $itemId not found in response: $itemData');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Item not found')));
              return;
            }
            item = itemData[0] as Map<String, dynamic>;
          } else if (itemData is Map<String, dynamic>) {
            item = itemData;
          } else {
            print('Invalid item data format for $itemId: $itemData');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid item data format')),
            );
            return;
          }

          final bool isAvailable = item['current_transaction'] == null;
          print(
            'Item $itemId availability: $isAvailable, current_transaction: ${item['current_transaction']}',
          );

          if (isAvailable) {
            // Send borrow request to backend
            final response = await http.post(
              Uri.parse('$baseUrl/api/borrow_process/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'item_id': itemId,
                'borrower_name': borrowData['borrowerName'],
                'school_id': borrowData['schoolId'],
                'return_date': borrowData['return_date'],
              }),
            );

            print(
              'Borrow response for $itemId: ${response.statusCode} ${response.body}',
            );
            final responseData = jsonDecode(response.body);
            if (response.statusCode == 201) {
              // Delete the request from local storage
              await LocalDatabase().deleteBorrowRequest(requestId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    responseData['message'] ??
                        'Item $itemId borrowed successfully',
                  ),
                ),
              );
              if (responseData['borrower'] != null) {
                final borrower = responseData['borrower'];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Borrower: ${borrower['name']} (ID: ${borrower['school_id']})',
                    ),
                  ),
                );
              }
            } else {
              print('Borrow failed for $itemId: ${response.body}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error borrowing item $itemId: ${responseData['error'] ?? 'Failed to borrow item'}',
                  ),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request will sync later')),
              );
            }
          } else {
            print(
              'Item $itemId not available, current_transaction: ${item['current_transaction']}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Item is currently borrowed. Request will sync later.',
                ),
              ),
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
        print('Network error during sync for $itemId: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e. Request will sync later'),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error processing QR code $code: $e\n$stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Map<String, String>?> _showBorrowDialog(BuildContext context) async {
    final borrowerNameController = TextEditingController();
    final schoolIdController = TextEditingController();
    DateTime? selectedDate;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[850],
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Borrow Item',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w500,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: borrowerNameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: GoogleFonts.ibmPlexMono(
                    color: Color.fromARGB(255, 231, 220, 187),
                  ),
                ),
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: const Color.fromARGB(255, 228, 214, 179),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: schoolIdController,
                decoration: InputDecoration(
                  labelText: 'School ID',
                  labelStyle: GoogleFonts.ibmPlexMono(
                    color: Color.fromARGB(255, 231, 220, 187),
                  ),
                ),
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: const Color.fromARGB(255, 209, 202, 163),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final DateTime now = DateTime.now();
                  final DateTime tomorrow = DateTime(
                    now.year,
                    now.month,
                    now.day + 1,
                  );
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: tomorrow,
                    firstDate: tomorrow,
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      selectedDate = picked;
                      returnDateController.text = picked
                          .toIso8601String()
                          .split('T')[0];
                    });
                  }
                },
                child: Text(
                  selectedDate == null
                      ? 'Select Return Date'
                      : 'Return Date: ${selectedDate!.toLocal()}'.split(' ')[0],
                  style: GoogleFonts.ibmPlexMono(
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      if (borrowerNameController.text.isEmpty ||
                          schoolIdController.text.isEmpty ||
                          returnDateController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All fields are required'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'borrowerName': borrowerNameController.text,
                        'schoolId': schoolIdController.text,
                        'return_date': returnDateController.text,
                      });
                    },
                    child: Text(
                      'Borrow',
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
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    returnDateController.dispose();
    super.dispose();
  }
}
