import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Added for IBM Plex Mono
import 'package:mobile/apiURl.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Borrow extends StatefulWidget {
  const Borrow({Key? key}) : super(key: key);

  @override
  State<Borrow> createState() => _QRScannerState();
}

class _QRScannerState extends State<Borrow> {
  final String baseUrl = API.baseUrl; // e.g., 'http://192.168.1.6:8000'
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
      body: Stack(
        children: [
          QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
          if (isProcessing) const Center(child: CircularProgressIndicator()),
          // Positioned(
          //   bottom: 16,
          //   right: 16,
          //   child: FloatingActionButton(
          //     onPressed: () async {
          //       await controller?.toggleFlash();
          //       setState(() {});
          //     },
          //     child: FutureBuilder<bool?>(
          //       future: controller?.getFlashStatus(),
          //       builder: (context, snapshot) {
          //         return Icon(
          //           snapshot.data ?? false ? Icons.flash_on : Icons.flash_off,
          //         );
          //       },
          //     ),
          //   ),
          // ),
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
        await controller
            .pauseCamera(); // Pause camera to prevent multiple scans
        await _processScannedQR(result!.code!);
        await controller.resumeCamera(); // Resume camera after processing
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

      final itemUrl = Uri.parse('$baseUrl/api/items/?id=${code.trim()}');
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
                  ? 'Item not found'
                  : 'Failed to fetch item details',
            ),
          ),
        );
        return;
      }

      final itemData = jsonDecode(itemResponse.body);
      print('Item response: $itemData');
      Map<String, dynamic>? item;
      if (itemData is List) {
        if (itemData.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Item not found')));
          return;
        }
        item = itemData[0] as Map<String, dynamic>;
      } else if (itemData is Map<String, dynamic>) {
        item = itemData;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid item data format')),
        );
        return;
      }

      int? itemId;
      try {
        itemId = int.parse(code.trim());
      } catch (e) {
        print('Error parsing item_id: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code: must be a number')),
        );
        return;
      }

      final bool isAvailable = item['current_transaction'] == null;

      if (isAvailable) {
        final borrowData = await _showBorrowDialog();
        if (borrowData == null) return;

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseData['message'] ?? 'Item borrowed successfully',
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${responseData['error'] ?? 'Failed to borrow item'}',
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item is already borrowed. Please return it first.'),
          ),
        );
        final condition = await _showConditionDialog();
        if (condition == null) return;

        final response = await http.post(
          Uri.parse('$baseUrl/api/borrow_process/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'item_id': itemId, 'condition': condition}),
        );

        print('Return response: ${response.statusCode} ${response.body}');
        final responseData = jsonDecode(response.body);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseData['message'] ?? 'Item returned successfully',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${responseData['error'] ?? 'Failed to return item'}',
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Error processing QR code: $e\n$stackTrace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Map<String, String>?> _showBorrowDialog() async {
    final borrowerNameController = TextEditingController();
    final schoolIdController = TextEditingController();
    DateTime? selectedDate;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[850], // Dark theme background
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // Justify left
            children: [
              Text(
                'Borrow Item',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w500, // Medium boldness for title
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: borrowerNameController,
                decoration: const InputDecoration(
                  labelText: 'Borrower Name',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300, // Light weight for text
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: schoolIdController,
                decoration: const InputDecoration(
                  labelText: 'School ID',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
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

  Future<String?> _showConditionDialog() async {
    String? selectedCondition;
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[850], // Dark theme background
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // Justify left
            children: [
              Text(
                'Return Item',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w500, // Medium boldness for title
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                dropdownColor: Colors.grey[800],
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300, // Light weight for text
                  color: Colors.white,
                ),
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
                      if (selectedCondition == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a condition'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, selectedCondition);
                    },
                    child: Text(
                      'Return',
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
