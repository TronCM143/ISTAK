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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to borrow')),
        );
        return;
      }

      final itemId = code.trim();
      print('Processing borrow for item ID: $itemId');
      final borrowData = await _showBorrowDialog(context);
      if (borrowData == null) return;

      // Store in local database
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
        'condition': null,
        'is_synced': '0',
        'status': 'pending',
      };
      await LocalDatabase().saveBorrowRequest(requestData);
      print('Saved borrow request locally: $requestData');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrow request saved locally. Syncing...'),
        ),
      );

      // Attempt to sync if online
      try {
        if (await isOnline()) {
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
              'Item fetch failed: ${itemResponse.statusCode} ${itemResponse.body}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  itemResponse.statusCode == 404
                      ? 'Item $itemId not found'
                      : 'Failed to fetch item: ${itemResponse.statusCode}',
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
              print('Item $itemId not found: $itemData');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Item $itemId not found')));
              return;
            }
            item = itemData[0] as Map<String, dynamic>;
          } else if (itemData is Map<String, dynamic>) {
            item = itemData;
          } else {
            print('Invalid item data: $itemData');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid item data format')),
            );
            return;
          }

          final bool isAvailable = item['current_transaction'] == null;
          print('Item $itemId availability: $isAvailable');

          if (isAvailable) {
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

            print('Borrow response: ${response.statusCode} ${response.body}');
            final responseData = jsonDecode(response.body);
            if (response.statusCode == 201) {
              await LocalDatabase().deleteBorrowRequest(requestId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Borrowed successfully: ${responseData['message'] ?? 'Item $itemId borrowed'}',
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
              print('Transaction ID: ${responseData['id'] ?? 'unknown'}');
            } else {
              print('Borrow failed: ${response.body}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to borrow: ${responseData['error'] ?? 'Error borrowing item $itemId'}',
                  ),
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Request will sync later')),
              );
            }
          } else {
            print('Item $itemId not available');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Item is currently borrowed. Request will sync later',
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline: Request will sync when online'),
            ),
          );
        }
      } catch (e) {
        print('Sync error for item $itemId: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e. Request will sync later')),
        );
      }
    } catch (e, stackTrace) {
      print('QR processing error: $e\n$stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error processing QR: $e')));
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
