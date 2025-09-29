import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile/apiURl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  List<Map<String, String>> scannedItems = []; // Stores {itemId, condition}
  Map<String, dynamic>? borrowerDetails; // Stores {name, school_id, image}
  List<Map<String, dynamic>> borrowedItems =
      []; // Stores borrower's borrowed items

  @override
  void initState() {
    super.initState();
    scanItem(); // Start QR scanner immediately
  }

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
    final isValid = itemId.isNotEmpty && RegExp(r'^\d{12}$').hasMatch(itemId);
    print('Validating itemId: $itemId, isValid: $isValid');
    return isValid;
  }

  Future<void> scanItem() async {
    await scannerController.start();
  }

  Future<String?> _showConditionDialog(String itemId) async {
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
                'Return Item $itemId',
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
                      'Confirm',
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

  Future<void> _fetchBorrowerAndItems(String itemId) async {
    setState(() => isLoading = true);
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Please log in first');
      }
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/items/$itemId/borrower/'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      print(
        'Borrower and items response: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          borrowerDetails = {
            'name': data['borrower']['name'],
            'school_id': data['borrower']['school_id'],
            'image': data['borrower']['image'],
          };
          borrowedItems = List<Map<String, dynamic>>.from(
            data['borrowed_items'],
          );
        });
      } else {
        final errorMsg =
            jsonDecode(response.body)['error'] ??
            'Failed to fetch borrower details';
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      print('Error fetching borrower and items: $e\n$stackTrace');
      setState(() => error = 'Error: $e');
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
      setState(() => isLoading = false);
    }
  }

  Future<void> _returnItem(String itemId, String condition) async {
    setState(() => isLoading = true);
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Please log in first');
      }

      final payload = {
        'item_id': itemId,
        'condition': condition,
        'school_id': borrowerDetails?['school_id'],
      };
      print('Sending return request: $payload');
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/return_item/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      print('Return response: ${response.statusCode} ${response.body}');
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          scannedItems.add({'itemId': itemId, 'condition': condition});
          borrowedItems.removeWhere((item) => item['id'] == itemId);
        });
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
        throw Exception(responseData['error'] ?? 'Failed to return item');
      }
    } catch (e, stackTrace) {
      print('Error returning item $itemId: $e\n$stackTrace');
      setState(() => error = 'Error returning item: $e');
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
      setState(() => isLoading = false);
    }
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
          Row(
            children: [
              // Left side: Borrower details and borrowed items
              Container(
                width: 140,
                color: Colors.grey[900],
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (borrowerDetails != null) ...[
                      ClipOval(
                        child: borrowerDetails!['image'] != null
                            ? CachedNetworkImage(
                                imageUrl:
                                    '$baseUrl${borrowerDetails!['image']}',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 60,
                                    ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 60,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        borrowerDetails!['name'] ?? 'Unknown',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        borrowerDetails!['school_id'] ?? 'Unknown',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Borrowed Items:',
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: borrowedItems.length,
                        itemBuilder: (context, index) {
                          final item = borrowedItems[index];
                          final isScanned = scannedItems.any(
                            (s) => s['itemId'] == item['id'],
                          );
                          return ListTile(
                            title: Text(
                              item['id'],
                              style: GoogleFonts.ibmPlexMono(
                                color: isScanned
                                    ? Colors.grey[600]
                                    : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Condition: ${scannedItems.firstWhere((s) => s['itemId'] == item['id'], orElse: () => {'condition': item['condition']})['condition']}',
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Right side: QR Scanner
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: MobileScanner(
                        controller: scannerController,
                        onDetect: (capture) async {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              final itemId = barcode.rawValue!.trim();
                              print('Scanned QR code: $itemId');
                              if (!_isValidItemId(itemId)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Invalid item ID: $itemId',
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                continue;
                              }
                              if (scannedItems.any(
                                (item) => item['itemId'] == itemId,
                              )) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Item $itemId already scanned',
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                continue;
                              }
                              await scannerController.stop();
                              // Fetch borrower and borrowed items on first scan
                              if (borrowerDetails == null) {
                                await _fetchBorrowerAndItems(itemId);
                                if (error != null) {
                                  await scannerController.start();
                                  continue;
                                }
                                // Check if item belongs to borrower's borrowed items
                                if (!borrowedItems.any(
                                  (item) => item['id'] == itemId,
                                )) {
                                  setState(
                                    () => error =
                                        'Item $itemId not borrowed by this borrower',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Item $itemId not borrowed by this borrower',
                                        style: GoogleFonts.ibmPlexMono(
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  await scannerController.start();
                                  continue;
                                }
                              } else if (!borrowedItems.any(
                                (item) => item['id'] == itemId,
                              )) {
                                // For subsequent scans, check if item belongs to the same borrower
                                setState(
                                  () => error =
                                      'Item $itemId not borrowed by this borrower',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Item $itemId not borrowed by this borrower',
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                await scannerController.start();
                                continue;
                              }
                              final condition = await _showConditionDialog(
                                itemId,
                              );
                              if (condition != null) {
                                await _returnItem(itemId, condition);
                              }
                              await scannerController.start();
                              break;
                            }
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () => Navigator.pop(context),
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
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (scannedItems.isNotEmpty) {
                                      Navigator.pop(
                                        context,
                                      ); // End session after returns
                                    } else {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No items scanned to return',
                                            style: GoogleFonts.ibmPlexMono(
                                              color: Colors.white,
                                            ),
                                          ),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  },
                            child: Text(
                              'Finish',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (error != null && !isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      error!,
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          error = null;
                          if (borrowerDetails == null) {
                            scannedItems.clear();
                            borrowedItems.clear();
                          }
                        });
                        scanItem();
                      },
                      child: Text(
                        'Retry',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
