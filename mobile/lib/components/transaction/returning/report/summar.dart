// lib/components/transaction/returnModules/summary.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

const kGreen = Color(0xFF34C759);
const kDarkBg = Color(0xFF0A0A0A);
const kCardBg = Color(0xFF1A1A1A);

class SummaryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String photoPath; // String path
  final String schoolId;
  final bool isReport;

  const SummaryScreen({
    super.key,
    required this.items,
    required this.photoPath,
    required this.schoolId,
    this.isReport = true,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool isLoading = false;
  String? outputMessage;

  // BEFORE
  String get _apiBase => dotenv.env['BASE_URL']!.replaceAll(RegExp(r'/$'), '');

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<void> _submitToBackend() async {
    setState(() {
      isLoading = true;
      outputMessage = null;
    });

    try {
      final token = await _token();
      if (token == null) throw Exception('Missing token');
      if (widget.photoPath.isEmpty) throw Exception('Photo path is empty');

      final url = Uri.parse('$_apiBase/api/return_item/');
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['school_id'] = widget.schoolId
        ..fields['is_report'] = widget.isReport ? 'true' : 'false';

      // Add all selected items + condition
      for (int i = 0; i < widget.items.length; i++) {
        final item = widget.items[i];
        request.fields['items[$i][itemId]'] = item['item_id'].toString();
        request.fields['items[$i][condition]'] = item['condition'] ?? 'Damaged';
      }

      // Attach image file
      final file = File(widget.photoPath);
      if (await file.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('return_image', widget.photoPath),
        );
      } else {
        throw Exception('Photo file does not exist at ${widget.photoPath}');
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() => outputMessage = '✅ Report submitted successfully!');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
        });
      } else {
        throw Exception('Failed: ${response.statusCode} → $body');
      }
    } catch (e) {
      setState(() => outputMessage = '⚠️ Submission failed: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        elevation: 0,
        title: Text(
          widget.isReport ? 'Lost/Damaged Summary' : 'Return Summary',
          style: GoogleFonts.ibmPlexMono(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Image preview
          Container(
            height: 200,
            width: double.infinity,
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
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // List of items and conditions
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.items.length,
              itemBuilder: (context, i) {
                final item = widget.items[i];
                final cond = item['condition'] ?? 'Damaged';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['item_name'] ?? 'Unnamed Item',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cond == 'Damaged'
                              ? Colors.orange.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cond,
                          style: GoogleFonts.ibmPlexMono(
                            color: cond == 'Damaged'
                                ? Colors.orange
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Submit buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitToBackend,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('Submit Report'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (outputMessage != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                outputMessage!,
                style: GoogleFonts.ibmPlexMono(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
