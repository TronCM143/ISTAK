import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile/components/transaction/borrowing/sync.dart';

class ProcessTransaction extends StatefulWidget {
  final Map<String, String>? borrowerData;
  final List<Map<String, dynamic>> scannedItems;
  final VoidCallback onReset;

  const ProcessTransaction({
    Key? key,
    required this.borrowerData,
    required this.scannedItems,
    required this.onReset,
  }) : super(key: key);

  @override
  State<ProcessTransaction> createState() => _ProcessTransactionState();
}

class _ProcessTransactionState extends State<ProcessTransaction> {
  bool _isLoading = false;
  bool _isOffline = false;
  String? _outputMessage;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        print("📶 Internet reconnected — syncing pending requests...");
        await syncPendingRequests();
      }
    });
  }

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

      final url = Uri.parse("${dotenv.env['BASE_URL']}/api/borrowing/create/");
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['school_id'] = widget.borrowerData!['school_id']!
        ..fields['name'] = widget.borrowerData!['name']!
        ..fields['status'] = widget.borrowerData!['status']!
        ..fields['return_date'] = widget.borrowerData!['return_date']!;

      for (var item in widget.scannedItems) {
        request.fields['item_ids[]'] = item['item_id'];
      }

      // Use image_url if available, otherwise fall back to photo_path
      final imageUrl = widget.borrowerData!['image_url'];
      final photoPath = widget.borrowerData!['photo_path'];
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
        _showResultDialog(
          title: "✅ Success",
          message: "Transaction successfully saved to the backend!",
          color: Colors.green,
        );
        setState(() {
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
        _isOffline = true;
        _outputMessage = "⚠️ Backend failed, stored offline instead.";
      });
    }
  }

  Future<void> _storeLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final localData = {
      "borrower": widget.borrowerData,
      "items": widget.scannedItems,
      "timestamp": DateTime.now().toIso8601String(),
    };

    List<String> pending = prefs.getStringList("pending_transactions") ?? [];
    pending.add(jsonEncode(localData));
    await prefs.setStringList("pending_transactions", pending);

    final List<String>? verifyList = prefs.getStringList(
      "pending_transactions",
    );
    String parseMessage;
    if (verifyList != null && verifyList.isNotEmpty) {
      try {
        final decoded = jsonDecode(verifyList.last);
        parseMessage =
            "✔ Successfully parsed local data:\n${jsonEncode(decoded)}";
      } catch (e) {
        parseMessage = "❌ Error parsing stored local data: $e";
      }
    } else {
      parseMessage = "❌ No data found in local storage after saving!";
    }

    _showResultDialog(
      title: "💾 Offline Mode",
      message: "Transaction stored locally.\n\n$parseMessage",
      color: Colors.orange,
    );

    setState(() {
      _outputMessage = parseMessage;
    });

    await syncPendingRequests();
  }

  void _showResultDialog({
    required String title,
    required String message,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.lightBlueAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.greenAccent)
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isOffline
                          ? '📴 Offline Mode — Stored Locally'
                          : '🌐 Ready to Process Transaction',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    if (_outputMessage != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _outputMessage!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _submitTransaction,
                      icon: const Icon(Icons.save),
                      label: const Text("Save Transaction"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent[700],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: widget.onReset,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
