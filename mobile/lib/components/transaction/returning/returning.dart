import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile/components/utils/localDatabaseMain.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';

class ReturnItem extends StatefulWidget {
  const ReturnItem({Key? key}) : super(key: key);

  @override
  State<ReturnItem> createState() => _ReturnItemState();
}

class _ReturnItemState extends State<ReturnItem> {
  bool isLoading = false;
  String? error;
  MobileScannerController scannerController = MobileScannerController();
  List<Map<String, String>> scannedItems = [];
  Map<String, dynamic>? borrowerDetails;
  List<Map<String, dynamic>> transactionItems = [];
  String? transactionId;

  @override
  void initState() {
    super.initState();
    scanItem();
  }

  @override
  void dispose() {
    scannerController.stop();
    scannerController.dispose();
    super.dispose();
  }

  Future<bool> _isOnline() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Connectivity check error: $e');
      return false;
    }
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
    try {
      await scannerController.start();
    } catch (e) {
      print('Error starting scanner: $e');
      setState(() => error = 'Error starting scanner: $e');
    }
  }

  Future<String?> _showConditionDialog(String itemId) async {
    String? selectedCondition;
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return Item $itemId',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w500,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          final condition = await showModalBottomSheet<String>(
                            context: dialogContext,
                            backgroundColor: Colors.transparent,
                            builder: (context) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        title: Text(
                                          'Good',
                                          style: GoogleFonts.ibmPlexMono(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, 'Good'),
                                      ),
                                      ListTile(
                                        title: Text(
                                          'Fair',
                                          style: GoogleFonts.ibmPlexMono(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, 'Fair'),
                                      ),
                                      ListTile(
                                        title: Text(
                                          'Damaged',
                                          style: GoogleFonts.ibmPlexMono(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, 'Damaged'),
                                      ),
                                      ListTile(
                                        title: Text(
                                          'Broken',
                                          style: GoogleFonts.ibmPlexMono(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, 'Broken'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          if (condition != null) {
                            setDialogState(() {
                              selectedCondition = condition;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedCondition ?? 'Select Condition',
                                    style: GoogleFonts.ibmPlexMono(
                                      color: selectedCondition == null
                                          ? Colors.grey[400]
                                          : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontWeight: FontWeight.w300,
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
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
                              Navigator.pop(dialogContext, selectedCondition);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Text(
                                    'Confirm',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontWeight: FontWeight.w300,
                                      color: selectedCondition == null
                                          ? Colors.grey[600]
                                          : const Color(0xFF34C759),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchTransactionItems(
    String itemId,
    String token,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('${dotenv.env['BASE_URL']}/api/items/$itemId/borrower/'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      print(
        'Transaction items response: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'borrower': {
            'name': data['borrower']['name'],
            'school_id': data['borrower']['school_id'],
            'image': data['borrower']['image'],
          },
          'borrowed_items': List<Map<String, dynamic>>.from(
            data['borrowed_items'],
          ),
          'transaction_id': data['transaction_id']?.toString(),
        };
      } else {
        final errorMsg =
            jsonDecode(response.body)['error'] ??
            'Failed to fetch transaction details';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error fetching transaction items: $e');
      return null;
    }
  }

  Future<void> _returnAllItems() async {
    setState(() => isLoading = true);
    final isOnline = await _isOnline();
    final token = isOnline ? await getToken() : null;

    if (isOnline && token == null) {
      setState(() {
        isLoading = false;
        error = 'Please log in to return items online';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in to return items online',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!isOnline || token == null) {
      // Offline mode: Save return requests to borrow_requests
      for (var item in scannedItems) {
        final requestId = const Uuid().v4();
        await LocalDatabase().saveBorrowRequest({
          'id': requestId,
          'type': 'return',
          'item_id': item['itemId'],
          'condition': item['condition'],
          'borrow_date': DateTime.now().toIso8601String().split('T')[0],
          'school_id': borrowerDetails?['school_id'] ?? '',
          'borrower_name': borrowerDetails?['name'] ?? '',
          'status': 'returning',
          'return_date': DateTime.now().toIso8601String().split('T')[0],
          'photo_path': '',
          'image_url': null,
          'is_synced': 0,
          'request_status': 'pending',
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Offline: Return requests saved locally',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        isLoading = false;
        scannedItems.clear();
        transactionItems.clear();
        borrowerDetails = null;
        transactionId = null;
      });
      Navigator.pop(context);
      return;
    }

    // Online mode
    try {
      final payload = {
        'transaction_id': transactionId,
        'items': scannedItems
            .map(
              (item) => {
                'itemId': int.parse(item['itemId']!),
                'condition': item['condition'],
              },
            )
            .toList(),
        'school_id': borrowerDetails?['school_id'],
      };
      print('Sending return request: $payload');
      final response = await http
          .post(
            Uri.parse('${dotenv.env['BASE_URL']}/api/return_item/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timed out'),
          );

      print('Return response: ${response.statusCode} ${response.body}');
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        for (var item in scannedItems) {
          await LocalDatabase().saveTransaction({
            'id': const Uuid().v4(),
            'item_id': item['itemId'],
            'item_name': transactionItems.firstWhere(
              (t) => t['id'] == item['itemId'],
              orElse: () => {'item_name': 'Unknown'},
            )['item_name'],
            'borrower_name': borrowerDetails?['name'] ?? '',
            'school_id': borrowerDetails?['school_id'] ?? '',
            'borrow_date': null,
            'return_date': DateTime.now().toIso8601String().split('T')[0],
            'photo_path': '',
            'image_url': null,
            'status': 'returned',
            'is_synced': 1,
          });
          await LocalDatabase().saveItemDetails({
            'id': item['itemId'],
            'item_name': transactionItems.firstWhere(
              (t) => t['id'] == item['itemId'],
              orElse: () => {'item_name': 'Unknown'},
            )['item_name'],
            'condition': item['condition'],
            'current_transaction': null,
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'All items returned successfully',
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          isLoading = false;
          scannedItems.clear();
          transactionItems.clear();
          borrowerDetails = null;
          transactionId = null;
        });
        Navigator.pop(context);
      } else {
        // Save to borrow_requests on failure
        for (var item in scannedItems) {
          final requestId = const Uuid().v4();
          await LocalDatabase().saveBorrowRequest({
            'id': requestId,
            'type': 'return',
            'item_id': item['itemId'],
            'condition': item['condition'],
            'borrow_date': DateTime.now().toIso8601String().split('T')[0],
            'school_id': borrowerDetails?['school_id'] ?? '',
            'borrower_name': borrowerDetails?['name'] ?? '',
            'status': 'returning',
            'return_date': DateTime.now().toIso8601String().split('T')[0],
            'photo_path': '',
            'image_url': null,
            'is_synced': 0,
            'request_status': 'pending',
          });
        }
        throw Exception(responseData['error'] ?? 'Failed to return items');
      }
    } catch (e) {
      print('Error returning items: $e');
      setState(() {
        isLoading = false;
        error = 'Error returning items: Saved locally for later sync';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: Saved locally for later sync',
            style: GoogleFonts.ibmPlexMono(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() {
        scannedItems.clear();
        transactionItems.clear();
        borrowerDetails = null;
        transactionId = null;
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItemsScanned =
        transactionItems.isNotEmpty &&
        transactionItems.every(
          (item) => scannedItems.any((s) => s['itemId'] == item['id']),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Column(
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
                        await scannerController.stop();

                        final isOnline = await _isOnline();
                        final token = isOnline ? await getToken() : null;

                        if (isOnline && token != null) {
                          final transactionData = await _fetchTransactionItems(
                            itemId,
                            token,
                          );
                          if (transactionData == null) {
                            setState(() {
                              error = 'Item $itemId not found or not borrowed';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Item $itemId not found or not borrowed',
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
                          if (!transactionData['borrowed_items'].any(
                            (item) => item['id'] == itemId,
                          )) {
                            setState(() {
                              error =
                                  'Item $itemId not part of this transaction';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Item $itemId not part of this transaction',
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
                          setState(() {
                            borrowerDetails = transactionData['borrower'];
                            transactionItems =
                                transactionData['borrowed_items'];
                            transactionId = transactionData['transaction_id'];
                          });
                        } else {
                          final existingTransaction = await LocalDatabase()
                              .getTransactionByItemId(itemId);
                          if (existingTransaction != null) {
                            setState(() {
                              borrowerDetails = {
                                'name': existingTransaction['borrower_name'],
                                'school_id': existingTransaction['school_id'],
                                'image': existingTransaction['image_url'],
                              };
                              transactionItems = [
                                {
                                  'id': itemId,
                                  'item_name':
                                      existingTransaction['item_name'] ??
                                      'Unknown',
                                },
                              ];
                              transactionId = existingTransaction['id'];
                            });
                          } else {
                            setState(() {
                              borrowerDetails = {
                                'name': 'Unknown',
                                'school_id': 'Unknown',
                                'image': null,
                              };
                              transactionItems = [
                                {'id': itemId, 'item_name': 'Unknown'},
                              ];
                              transactionId = const Uuid().v4();
                            });
                          }
                        }

                        final condition = await _showConditionDialog(itemId);
                        if (condition != null) {
                          setState(() {
                            // Remove existing entry if re-scanned
                            scannedItems.removeWhere(
                              (item) => item['itemId'] == itemId,
                            );
                            scannedItems.add({
                              'itemId': itemId,
                              'condition': condition,
                            });
                          });
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: isLoading ? null : () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w300,
                                color: Colors.redAccent,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isLoading || !allItemsScanned
                          ? null
                          : () => _returnAllItems(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Text(
                              'Finish',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w300,
                                color: allItemsScanned
                                    ? const Color(0xFF34C759)
                                    : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (borrowerDetails != null)
            Positioned(
              left: 16,
              top: 16,
              bottom: 100,
              width: 140,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipOval(
                            child: borrowerDetails!['image'] != null
                                ? CachedNetworkImage(
                                    imageUrl:
                                        '${dotenv.env['BASE_URL']}${borrowerDetails!['image']}',
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
                          Text(
                            'Transaction Items:',
                            style: GoogleFonts.ibmPlexMono(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Expanded(
                            child: transactionItems.isEmpty
                                ? Center(
                                    child: Text(
                                      'No items',
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: transactionItems.length,
                                    itemBuilder: (context, index) {
                                      final item = transactionItems[index];
                                      final isScanned = scannedItems.any(
                                        (s) => s['itemId'] == item['id'],
                                      );
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 5,
                                              sigmaY: 5,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['id'],
                                                    style:
                                                        GoogleFonts.ibmPlexMono(
                                                          color: isScanned
                                                              ? Colors.grey[600]
                                                              : Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                  ),
                                                  Text(
                                                    'Condition: ${scannedItems.firstWhere((s) => s['itemId'] == item['id'], orElse: () => {'condition': 'Pending'})['condition']}',
                                                    style:
                                                        GoogleFonts.ibmPlexMono(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 12,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isLoading)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
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
                ),
              ),
            ),
          if (error != null && !isLoading)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
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
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  error = null;
                                  if (transactionItems.isEmpty) {
                                    scannedItems.clear();
                                    transactionItems.clear();
                                    borrowerDetails = null;
                                    transactionId = null;
                                  }
                                });
                                scanItem();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 8,
                                      sigmaY: 8,
                                    ),
                                    child: Text(
                                      'Retry',
                                      style: GoogleFonts.ibmPlexMono(
                                        color: const Color(0xFF34C759),
                                        fontWeight: FontWeight.w300,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
