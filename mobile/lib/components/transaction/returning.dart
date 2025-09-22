import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile/apiURl.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  bool _isValidItemId(String itemId) {
    return itemId.isNotEmpty && int.tryParse(itemId) != null;
  }

  Future<Map<String, dynamic>?> _fetchItemDetails(
    String itemId,
    String token,
  ) async {
    try {
      final itemUrl = Uri.parse('$baseUrl/api/items/?id=$itemId');
      final response = await http.get(
        itemUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
        'Item fetch response for $itemId: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching item $itemId: $e');
      return null;
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please log in first',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final itemDetails = await _fetchItemDetails(itemId, token);
      if (itemDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Item $itemId not found',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final bool isBorrowed = itemDetails['current_transaction'] != null;
      print(
        'Item $itemId isBorrowed: $isBorrowed, current_transaction: ${itemDetails['current_transaction']}',
      );

      if (!isBorrowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Item $itemId is not borrowed',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final requestId = const Uuid().v4();
      final returnDate = DateTime.now().toIso8601String().split('T')[0];
      final requestData = {
        'id': requestId,
        'type': 'return',
        'item_id': itemId,
        'borrower_name': null,
        'school_id': null,
        'return_date': returnDate,
        'borrow_date': null,
        'condition': condition,
        'is_synced': '0',
        'status': 'pending',
      };
      await LocalDatabase().saveBorrowRequest(requestData);
      print('Saved return request locally: $requestData');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Return request saved locally. Syncing...',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.blueGrey,
        ),
      );

      if (await isOnline()) {
        final response = await http.post(
          Uri.parse('$baseUrl/api/borrow_process/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'item_id': int.parse(itemId),
            'condition': condition,
          }),
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
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          print('Transaction ID: ${responseData['id'] ?? 'unknown'}');
        } else {
          String errorMessage =
              responseData['error'] ?? 'Failed to return item';
          if (errorMessage.contains('Item not found') ||
              errorMessage.contains('not borrowed')) {
            errorMessage = 'Item $itemId is not borrowed';
            await LocalDatabase().deleteBorrowRequest(requestId);
          }
          print('Return failed for $itemId: ${response.body}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error returning item $itemId: $errorMessage',
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Request will sync later',
                style: GoogleFonts.ibmPlexMono(color: Colors.white),
              ),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Offline: Request will sync when online',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.blueGrey,
          ),
        );
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
              if (isLoading) const Center(child: CircularProgressIndicator()),
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
