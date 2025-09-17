import 'dart:io';
import 'package:flutter/material.dart';
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
      appBar: AppBar(title: const Text('QR Code Scanner'), centerTitle: true),
      body: Stack(
        children: [
          Column(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.red,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: 300,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: result != null
                      ? Text(
                          'Scanned: ${result!.code}',
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        )
                      : const Text(
                          'Scan a QR code to borrow/return an item',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        await controller?.toggleFlash();
                        setState(() {});
                      },
                      child: FutureBuilder<bool?>(
                        future: controller?.getFlashStatus(),
                        builder: (context, snapshot) {
                          return Text(
                            'Flash: ${snapshot.data ?? false ? 'On' : 'Off'}',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await controller?.resumeCamera();
                        setState(() {});
                      },
                      child: const Text('Restart Scan'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

      // Use code as-is for GET request (API will handle conversion)
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

      // Parse item_id for POST request
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
            'borrower_name': borrowData['borrowerName'], // Updated field name
            'school_id': borrowData['schoolId'], // Updated field name
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
          // Display borrower details if available
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
        // Show error message for already borrowed item
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item is already borrowed. Please return it first.'),
          ),
        );
        // Optionally, prompt for return
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
    final returnDateController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrow Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: borrowerNameController,
              decoration: const InputDecoration(labelText: 'Borrower Name'),
            ),
            TextField(
              controller: schoolIdController,
              decoration: const InputDecoration(labelText: 'School ID'),
            ),
            TextField(
              controller: returnDateController,
              decoration: const InputDecoration(
                labelText: 'Return Date (YYYY-MM-DD)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (borrowerNameController.text.isEmpty ||
                  schoolIdController.text.isEmpty ||
                  returnDateController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              Navigator.pop(context, {
                'borrowerName': borrowerNameController.text,
                'schoolId': schoolIdController.text,
                'return_date': returnDateController.text,
              });
            },
            child: const Text('Borrow'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showConditionDialog() async {
    String? selectedCondition;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Item'),
        content: DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Condition'),
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
            child: const Text('Cancel'),
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
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
