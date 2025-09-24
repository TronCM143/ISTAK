import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile/apiURl.dart';
import 'package:google_fonts/google_fonts.dart';

class ReturnItem extends StatefulWidget {
  const ReturnItem({Key? key}) : super(key: key);

  @override
  State<ReturnItem> createState() => _ReturnItemState();
}

class _ReturnItemState extends State<ReturnItem> {
  final String baseUrl = API.baseUrl;
  bool isLoading = false;
  String? error;
  MobileScannerController scannerController = MobileScannerController();

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    print('Access token: $token');
    return token;
  }

  bool _isValidItemId(String itemId) {
    final isValid = itemId.isNotEmpty && int.tryParse(itemId) != null;
    print('Validating itemId: $itemId, isValid: $isValid');
    return isValid;
  }

  Future<void> returnItem(String itemId) async {
    if (!_isValidItemId(itemId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid item ID: $itemId',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final condition = await _showConditionDialog();
    if (condition == null) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Please log in first');
      }

      final payload = {'item_id': int.parse(itemId), 'condition': condition};
      print('Sending return request for $itemId: $payload');
      final response = await http.post(
        Uri.parse('$baseUrl/api/borrow_process/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print(
        'Return response for $itemId: ${response.statusCode} ${response.body}',
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'Item $itemId returned successfully',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        String errorMessage = responseData['error'] ?? 'Failed to return item';
        if (errorMessage.contains('Item not found')) {
          errorMessage =
              'Item $itemId not found or not managed by your manager';
        } else if (errorMessage.contains('No active transaction')) {
          errorMessage = 'Item $itemId is not borrowed';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error returning item $itemId: $errorMessage',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      print('Error returning item $itemId: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
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
                'Return Item',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w500,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Condition',
                  labelStyle: GoogleFonts.ibmPlexMono(
                    color: const Color.fromARGB(255, 231, 220, 187),
                  ),
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                ),
                style: GoogleFonts.ibmPlexMono(
                  color: const Color.fromARGB(255, 228, 214, 179),
                ),
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
                          SnackBar(
                            content: Text(
                              'Please select a condition',
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.redAccent,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Return Item',
          style: GoogleFonts.ibmPlexMono(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey[850],
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
                        final String itemId = barcode.rawValue!.trim();
                        print('Scanned QR code: $itemId');
                        await scannerController.stop();
                        await returnItem(itemId);
                        await scannerController.start();
                        break;
                      }
                    }
                  },
                ),
              ),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    error!,
                    style: GoogleFonts.ibmPlexMono(
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
