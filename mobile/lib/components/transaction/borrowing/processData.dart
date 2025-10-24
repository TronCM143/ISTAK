import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/components/transaction/sync.dart';
import 'package:lottie/lottie.dart';

class ProcessTransaction extends StatefulWidget {
  final Map<String, String>? borrowerData;
  final List<Map<String, dynamic>> scannedItems;
  final VoidCallback onReset;
  final Function(String)? onSuccess; // New callback for success

  const ProcessTransaction({
    Key? key,
    required this.borrowerData,
    required this.scannedItems,
    required this.onReset,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<ProcessTransaction> createState() => _ProcessTransactionState();
}

class _ProcessTransactionState extends State<ProcessTransaction> {
  bool _isLoading = false;
  bool _isOffline = false;
  String? _outputMessage;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity(); // <-- Add this line (runs async check on load)

    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none && mounted) {
        print("📶 Internet reconnected — syncing pending requests...");
        await syncPendingRequests();
        setState(
          () => _isOffline = false,
        ); // <-- Add this: Reset flag on reconnect
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none && mounted) {
      setState(() => _isOffline = true);
    }
  }

  Future<void> _processImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        throw Exception('No JWT token found. Please log in again.');
      }

      final url = Uri.parse("${dotenv.env['BASE_URL']}/api/process_image/");
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['name'] = widget.borrowerData!['name']!
        ..fields['school_id'] = widget.borrowerData!['school_id']!
        ..files.add(
          await http.MultipartFile.fromPath(
            'image',
            widget.borrowerData!['photo_path']!,
          ),
        );

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody.body);
        setState(() {
          _imageUrl = data['image_url'];
          print('✅ Image processed: $_imageUrl');
        });
      } else {
        throw Exception('Image processing failed: ${responseBody.body}');
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withOpacity(0.6),
          builder: (context) => Dialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WARNING',
                    style: GoogleFonts.ibmPlexMono(
                      color: const Color.fromARGB(255, 145, 0, 0),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'No internet connection',
                    style: GoogleFonts.ibmPlexMono(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 97, 97, 97),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'OK',
                        style: GoogleFonts.ibmPlexMono(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        print('❌ Image processing error: $e');
      }
      setState(() {
        _imageUrl = null;
      });
    }
  }

  // Replace the entire _submitTransaction() method:
  Future<void> _submitTransaction() async {
    if (widget.borrowerData == null || widget.scannedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Missing borrower info or no items scanned!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _outputMessage = null;
    });

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;

    if (isOnline) {
      await _sendToBackend();
    } else {
      await _storeLocally();
      setState(() => _isOffline = true);

      // Auto-reset after 2s for offline
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onReset();
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _sendToBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        throw Exception('No JWT token found. Please log in again.');
      }

      // Process image if needed (only when online)
      final photoPath = widget.borrowerData!['photo_path'];
      if (photoPath != null && File(photoPath).existsSync()) {
        await _processImage();
      }

      final url = Uri.parse("${dotenv.env['BASE_URL']}/api/borrowing/create/");
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['school_id'] = widget.borrowerData!['school_id']!
        ..fields['name'] = widget.borrowerData!['name']!
        ..fields['status'] = widget.borrowerData!['status']!
        ..fields['return_date'] = widget.borrowerData!['return_date']!;

      request.fields['item_ids'] = jsonEncode(
        widget.scannedItems.map((e) => e['item_id']).toList(),
      );

      // Use processed image_url if available, otherwise fall back to photo_path
      final imageUrl = widget.borrowerData!['image_url'] ?? _imageUrl;
      if (imageUrl != null) {
        request.fields['image_url'] = imageUrl;
      } else if (photoPath != null && File(photoPath).existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('image', photoPath),
        );
      }

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      if (response.statusCode == 201) {
        // Trigger success callback with borrower's name
        if (widget.onSuccess != null) {
          widget.onSuccess!(widget.borrowerData!['name']!);
        }

        setState(() {
          _isOffline = false;
          _outputMessage = "✅ Backend Save Successful!";
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) widget.onReset();
        });
      } else {
        debugPrint(
          "❌ Server error: ${response.statusCode} → ${responseBody.body}",
        );
        throw Exception('Server responded with an error: ${responseBody.body}');
      }
    } catch (e) {
      debugPrint("⚠️ Error sending to backend: $e");
      await _storeLocally();
      setState(() {
        _isOffline = true; // <-- Add this: Explicitly set offline on error
      });
    }
  }

  Future<void> _storeLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localData = {
        "borrower": widget.borrowerData,
        "items": widget.scannedItems,
        "timestamp": DateTime.now().toIso8601String(),
      };

      List<String> pending = prefs.getStringList("pending_transactions") ?? [];
      pending.add(jsonEncode(localData));
      await prefs.setStringList("pending_transactions", pending);

      // Always set positive message for local save—no verification errors
      setState(() {
        _outputMessage = "💾 Transaction saved locally!";
      });

      // Safe sync: Try but don't block on errors (e.g., offline)
      try {
        await syncPendingRequests();
      } catch (syncError) {
        debugPrint("⚠️ Sync skipped due to error: $syncError");
        // Don't rethrow—let local save succeed
      }
    } catch (e) {
      debugPrint("❌ Local save failed: $e");
      setState(() {
        _outputMessage = "⚠️ Local save failed—try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(33, 33, 33, 1),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.greenAccent)
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 200),
                    Stack(
                      children: [
                        Row(
                          children: [
                            SizedBox(width: 25),
                            SizedBox(
                              height: 300,
                              width: 400, // adjust based on your layout
                              child: Lottie.asset(
                                'assets/finalSave.json',
                                repeat: true, // 🔁 keeps looping forever
                                animate: true, // ✅ ensures it plays
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),

                        Center(
                          child: Column(
                            children: [
                              SizedBox(height: 300),
                              Text(
                                _isOffline
                                    ? "No internet, Saved locally!"
                                    : "Success Transaction",
                                style: GoogleFonts.ibmPlexMono(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 30),
                              ElevatedButton.icon(
                                onPressed: _submitTransaction,

                                label: Text(
                                  "SUBMIT",
                                  style: GoogleFonts.ibmPlexMono(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 10,
                                  ),
                                  elevation: 8, // ⬅️ Add some depth
                                  shadowColor: Colors.black.withOpacity(
                                    0.5,
                                  ), // ⬅️ Customize shadow color
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      16,
                                    ), // optional nice rounding
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              TextButton(
                                onPressed: widget.onReset,
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.ibmPlexMono(
                                    color: const Color.fromARGB(255, 138, 0, 0),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_outputMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(
                            0.2,
                          ), // Success tint only
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          _outputMessage!,
                          style: GoogleFonts.ibmPlexMono(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}
