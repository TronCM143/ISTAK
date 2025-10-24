import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:ui';
import '../../../utils/localDatabaseMain.dart';
import 'itemModel.dart';

const kGreen = Color(0xFF34C759);
const kDarkBg = Color(0xFF0A0A0A);
const kCardBg = Color(0xFF1A1A1A);

class SummaryScreen extends StatefulWidget {
  final List<ReturnItem> items;
  final String photoPath;

  const SummaryScreen({
    super.key,
    required this.items,
    required this.photoPath,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool isLoading = false;
  String? outputMessage;
  String? schoolId; // Fetched dynamically

  Future<Map<String, dynamic>?> _fetchBorrowerDetails(
    String itemId,
    String token,
  ) async {
    const maxRetries = 2;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse(
                '${dotenv.env['BASE_URL']}/api/items/$itemId/borrower/',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 10));

        print(
          'Fetch borrower details attempt $attempt: ${response.statusCode} ${response.body}',
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {'school_id': data['borrower']['school_id']};
        }
      } catch (e) {
        print('Error fetching borrower details (attempt $attempt): $e');
        if (attempt == maxRetries) {
          return null;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  Future<void> _uploadToBackend(String token) async {
    try {
      final url = Uri.parse('${dotenv.env['BASE_URL']}/api/return_item/');
      print('Sending return request to: $url');
      print('Request data: school_id=$schoolId, items=${widget.items.length}');

      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token';
      if (schoolId != null) {
        request.fields['school_id'] = schoolId!; // Send if available
      }

      for (int i = 0; i < widget.items.length; i++) {
        request.fields['items[$i][itemId]'] = widget.items[i].itemId;
        request.fields['items[$i][condition]'] = widget.items[i].condition;
      }

      final photoFile = File(widget.photoPath);
      if (photoFile.existsSync()) {
        request.files.add(
          await http.MultipartFile.fromPath('return_image', photoFile.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      print('✅ Upload Response: ${response.statusCode} → ${response.body}');

      if (response.statusCode == 200) {
        setState(() => outputMessage = '✅ Successfully returned!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        });
      } else {
        throw Exception('Failed with ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Upload failed: $e');
      await _storeReturnLocally();
      setState(() => outputMessage = '⚠️ Connection failed. Saved for sync.');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
      });
    }
  }

  Future<void> _submitReturn() async {
    if (widget.items.isEmpty || widget.photoPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing items or photo. Please scan again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      outputMessage = null;
    });

    final isOnline = await _isOnline();
    final token = isOnline ? await _getToken() : null;

    if (isOnline && token != null) {
      // Fetch school_id for the first item
      if (widget.items.isNotEmpty) {
        final borrowerData = await _fetchBorrowerDetails(
          widget.items[0].itemId,
          token,
        );
        if (borrowerData != null) {
          setState(() => schoolId = borrowerData['school_id']);
          print('Fetched school_id: $schoolId');
        } else {
          print('Failed to fetch school_id. Proceeding without it.');
        }
      }
      await _uploadToBackend(token);
    } else {
      await _storeReturnLocally();
      setState(() => outputMessage = '💾 Saved locally! Syncing when online.');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
      });
    }

    setState(() => isLoading = false);
  }

  Future<bool> _isOnline() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _storeReturnLocally() async {
    final db = LocalDatabase();
    final localData = {
      'school_id': schoolId, // May be null
      'items': widget.items.map((e) => e.toJson()).toList(),
      'return_photo_path': widget.photoPath,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await db.insertOfflineReturn(localData);
    print('💾 Return saved locally');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'SUMMARY items → ${widget.items.map((e) => e.toJson()).toList()}',
    );
    debugPrint('SUMMARY photoPath → ${widget.photoPath}');
    debugPrint('SUMMARY schoolId → $schoolId');
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Summary',
          style: GoogleFonts.ibmPlexMono(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Full photo display at top, centered, without cropping
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: 250,
            ), // Allow dynamic height for full image
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: kGreen.withOpacity(0.3), width: 1),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Image.file(
                File(widget.photoPath),
                width: double.infinity,
                fit: BoxFit.contain, // Full image without cropping
                alignment: Alignment.topCenter, // Center at top
              ),
            ),
          ),
          const SizedBox(
            height: 32,
          ), // Increased spacing for better readability
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                100,
              ), // Slightly more padding
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final it = widget.items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16), // Increased margin
                  padding: const EdgeInsets.all(20), // Increased padding
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(
                      16,
                    ), // Slightly larger radius
                    border: Border.all(color: Colors.white12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ], // Subtle shadow for depth
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // Align to start for better organization
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Item ID: ${it.itemId}',
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white,
                                fontSize: 18, // Bigger font
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8), // Increased spacing
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: it.condition == 'Good'
                                    ? kGreen.withOpacity(0.2)
                                    : it.condition == 'Fair'
                                    ? Colors.yellow.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                  8,
                                ), // Slightly larger
                              ),
                              child: Text(
                                it.condition,
                                style: GoogleFonts.ibmPlexMono(
                                  color: it.condition == 'Good'
                                      ? kGreen
                                      : it.condition == 'Fair'
                                      ? Colors.yellow[800]
                                      : Colors.red[400],
                                  fontSize: 16, // Bigger font
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Condition: ${it.condition.toLowerCase()}', // Additional descriptive text for readability
                              style: GoogleFonts.ibmPlexMono(
                                color: Colors.white70,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 16,
                      ), // Spacing between content and buttons
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.white70,
                              size: 24, // Bigger icon
                            ),
                            onPressed: () {}, // Disabled in summary
                            tooltip: 'Edit Condition',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white54,
                              size: 24, // Bigger icon
                            ),
                            onPressed: () {}, // Disabled in summary
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Bottom buttons container with improved styling
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: kDarkBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(context, {'proceed': false}),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            16,
                          ), // Larger radius
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ), // More padding
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ), // Bigger font
                      ),
                    ),
                  ),
                  const SizedBox(width: 16), // Increased spacing
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          isLoading ||
                              widget.items.isEmpty ||
                              widget.photoPath.isEmpty
                          ? null
                          : _submitReturn,
                      style: ButtonStyle(
                        backgroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.white24; // Disabled background
                              }
                              return kGreen; // Normal background
                            }),
                        foregroundColor:
                            MaterialStateProperty.resolveWith<Color>((states) {
                              if (states.contains(MaterialState.disabled)) {
                                return Colors.white70; // Disabled text color
                              }
                              return Colors.black; // Normal text color
                            }),
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                        padding: MaterialStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 16),
                        ),
                        elevation: MaterialStateProperty.all(4),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Submit',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (outputMessage != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12), // Larger radius
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  outputMessage!,
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.white,
                    fontSize: 16, // Bigger font
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
