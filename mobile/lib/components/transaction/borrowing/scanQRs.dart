import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile/apiURL.dart';
import 'package:mobile/components/local_database/localDatabaseMain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ScanItemsQR extends StatefulWidget {
  final List<Map<String, dynamic>> scannedItems;
  final bool isScanning;
  final Function(List<Map<String, dynamic>>) onItemsScanned;
  final Function(bool) onScanningStateChanged;
  final VoidCallback onFinish;

  const ScanItemsQR({
    Key? key,
    required this.scannedItems,
    required this.isScanning,
    required this.onItemsScanned,
    required this.onScanningStateChanged,
    required this.onFinish,
  }) : super(key: key);

  @override
  _ScanItemsQRState createState() => _ScanItemsQRState();
}

class _ScanItemsQRState extends State<ScanItemsQR> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScanningStateChanged(true);
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen(
      (scanData) async {
        if (isProcessing || !widget.isScanning) return;
        setState(() {
          isProcessing = true;
        });
        if (scanData.code != null) {
          await controller.pauseCamera();
          await _showScanDialog(scanData.code!);
        }
        setState(() {
          isProcessing = false;
        });
      },
      onError: (error) {
        print('QR scanner error: $error');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('QR scanner error: $error')));
        setState(() {
          isProcessing = false;
        });
      },
    );
  }

  Future<void> _showScanDialog(String code) async {
    final itemId = code.trim();
    print('🔍 Scanned QR code: $itemId');

    if (itemId.isEmpty) {
      print('Invalid QR code: Empty ID');
      await _resumeScanning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid item ID: QR code is empty')),
      );
      return;
    }

    Map<String, dynamic>? scannedItem;
    String? errorMessage;

    try {
      final token = await SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('access_token'),
      );
      print('🔑 Token: ${token != null ? 'Available' : 'Null'}');
      if (token == null) {
        errorMessage = 'Please log in to scan items';
      } else {
        print('📍 Current scannedItems: ${widget.scannedItems}');
        // Check local database
        final localItem = await LocalDatabase().getItemDetails(itemId);
        print(
          '📍 Local database check for item $itemId: ${localItem != null ? 'Found' : 'Not found'}',
        );
        if (localItem != null) {
          if (widget.scannedItems.any((i) => i['id'] == itemId)) {
            errorMessage = 'Item already scanned';
            print('⚠️ Item $itemId already in scannedItems');
          } else {
            final localTransaction = await LocalDatabase()
                .getTransactionByItemId(itemId);
            print(
              '📍 Local transaction check for item $itemId: ${localTransaction != null ? 'Borrowed' : 'Available'}',
            );
            if (localTransaction != null) {
              errorMessage = 'Item $itemId is currently borrowed';
            } else {
              scannedItem = {
                'id': itemId,
                'item_name': localItem['item_name'],
                'condition': localItem['condition'],
              };
              print('✅ Local item added: $scannedItem');
            }
          }
        } else if (await _isOnline()) {
          print('🌐 Fetching item $itemId from backend');
          final response = await http.get(
            Uri.parse('${API.baseUrl}/api/items/by-id/$itemId/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          print(
            '📡 API Response for item $itemId: Status ${response.statusCode}, Body ${response.body}',
          );

          if (response.statusCode != 200) {
            errorMessage = 'Item not found: ${response.statusCode}';
          } else {
            final item = jsonDecode(response.body);
            if (widget.scannedItems.any((i) => i['id'] == item['id'])) {
              errorMessage = 'Item already scanned';
              print('⚠️ Item $itemId already in scannedItems');
            } else if (item['status'] == 'Borrowed') {
              errorMessage = 'Item $itemId is currently borrowed';
              print('⚠️ Item $itemId is borrowed: ${item['status']}');
            } else {
              await LocalDatabase().saveItemDetails({
                'id': itemId,
                'item_name': item['item_name'],
                'condition': item['condition'],
              });
              scannedItem = {
                'id': itemId, // Use scanned itemId for consistency
                'item_name': item['item_name'],
                'condition': item['condition'],
              };
              print('✅ Backend item added: $scannedItem');
            }
          }
        } else {
          errorMessage = 'Offline: Item not found in local database';
          print('🌐 Offline mode, item $itemId not in local database');
        }
      }
    } catch (e) {
      errorMessage = 'Error scanning QR: $e';
      print('❌ QR scan error for item $itemId: $e');
    }

    if (errorMessage != null) {
      await _resumeScanning();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return;
    }

    if (!mounted) {
      print('⚠️ Widget not mounted, skipping dialog');
      return;
    }

    print('🖼️ Showing dialog for item: $scannedItem');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Success',
            style: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          content: Text(
            'Scanned item ID: $itemId\nName: ${scannedItem!['item_name']}',
            style: GoogleFonts.ibmPlexMono(
              fontWeight: FontWeight.w300,
              color: Colors.black,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                print('🚫 Dialog cancelled for item $itemId');
                Navigator.of(context).pop();
                _resumeScanning();
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: Colors.red,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                print('✅ Saving item $itemId to scannedItems');
                widget.onItemsScanned([...widget.scannedItems, scannedItem!]);
                Navigator.of(context).pop();
                _resumeScanning();
              },
              child: Text(
                'Save',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.w300,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        );
      },
    );
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

  void _removeItem(String itemId) {
    widget.onItemsScanned(
      widget.scannedItems.where((item) => item['id'] != itemId).toList(),
    );
  }

  Future<void> _resumeScanning() async {
    print('📷 Resuming camera');
    widget.onScanningStateChanged(true);
    await controller?.resumeCamera();
    await Future.delayed(
      const Duration(milliseconds: 100),
    ); // Ensure camera is ready
    print('📷 Camera resumed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: widget.isScanning
                ? QRView(
                    key: qrKey,
                    onQRViewCreated: _onQRViewCreated,
                    overlay: QrScannerOverlayShape(
                      borderColor: Colors.white,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 300,
                    ),
                  )
                : Center(
                    child: TextButton(
                      onPressed: _resumeScanning,
                      child: Text(
                        'Resume Scanning',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            width: 150,
            color: Colors.grey[850],
            child: Column(
              children: [
                Expanded(
                  child: widget.scannedItems.isEmpty
                      ? Center(
                          child: Text(
                            'No items scanned',
                            style: GoogleFonts.ibmPlexMono(
                              fontWeight: FontWeight.w300,
                              color: Colors.grey[400],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: widget.scannedItems.length,
                          itemBuilder: (context, index) {
                            final item = widget.scannedItems[index];
                            return ListTile(
                              title: Text(
                                'ID: ${item['id']}',
                                style: GoogleFonts.ibmPlexMono(
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                item['item_name'],
                                style: GoogleFonts.ibmPlexMono(
                                  fontWeight: FontWeight.w300,
                                  color: Colors.grey[400],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => _removeItem(item['id']),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          widget.onItemsScanned([]);
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.scannedItems.isNotEmpty
                            ? widget.onFinish
                            : null,
                        child: Text(
                          'Proceed',
                          style: GoogleFonts.ibmPlexMono(
                            fontWeight: FontWeight.w300,
                            color: widget.scannedItems.isNotEmpty
                                ? Colors.white
                                : Colors.grey[600],
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
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
