import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/apiURL.dart';

class BorrowerInputAndPhoto extends StatefulWidget {
  final Function(Map<String, String>) onDataEntered;
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const BorrowerInputAndPhoto({
    Key? key,
    required this.onDataEntered,
    required this.onNext,
    required this.onCancel,
  }) : super(key: key);

  @override
  _BorrowerInputAndPhotoState createState() => _BorrowerInputAndPhotoState();
}

class _BorrowerInputAndPhotoState extends State<BorrowerInputAndPhoto> {
  final _nameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  DateTime? _returnDate;
  File? _photo;
  String? _processedImageUrl;
  final ImagePicker _picker = ImagePicker();
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString("access_token");
      print('📋 Access Token: $_accessToken');
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _returnDate = picked;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_nameController.text.isEmpty || _schoolIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and school ID first')),
      );
      return;
    }

    if (_accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No access token found. Please log in.')),
      );
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Reduce quality to avoid large files
        maxWidth: 1920, // Limit resolution
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        setState(() {
          _photo = File(pickedFile.path);
          print('📸 Photo captured: ${pickedFile.path}');
        });
        await _processImage(pickedFile.path);
      } else {
        print('❌ No photo selected');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
        print('❌ Capture error: $e');
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${API.baseUrl}/api/process_image/'),
      );
      request.headers['Authorization'] = 'Bearer $_accessToken';
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      request.fields['name'] = _nameController.text;
      request.fields['school_id'] = _schoolIdController.text;

      print('📤 Sending image to /api/process_image/');
      print('Fields: ${request.fields}');
      print('File: $imagePath');

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      print('✅ Response Status: ${response.statusCode}');
      print('✅ Response Body: ${responseBody.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody.body);
        if (data['image_url'] != null) {
          setState(() {
            _processedImageUrl = data['image_url'];
            print('📋 Processed Image URL: $_processedImageUrl');
          });
        } else {
          throw Exception('No image_url in response');
        }
      } else {
        throw Exception('Failed to process image: ${responseBody.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
        print('❌ Process error: $e');
      }
    }
  }

  void _submitData() {
    if (_nameController.text.isEmpty ||
        _schoolIdController.text.isEmpty ||
        _returnDate == null ||
        _processedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and capture a photo'),
        ),
      );
      return;
    }
    widget.onDataEntered({
      'borrowerName': _nameController.text,
      'schoolId': _schoolIdController.text,
      'status': 'active',
      'return_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
      'image_url': _processedImageUrl!,
    });
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Image display
            if (_processedImageUrl != null && _processedImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _processedImageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[700],
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Image load error: $error');
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[700],
                      alignment: Alignment.center,
                      child: Text(
                        'Failed to load image',
                        style: GoogleFonts.ibmPlexMono(color: Colors.white),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[700],
                alignment: Alignment.center,
                child: Text(
                  'No Photo',
                  style: GoogleFonts.ibmPlexMono(color: Colors.white),
                ),
              ),

            const SizedBox(height: 16),

            // Take Photo button
            ElevatedButton(
              onPressed: _capturePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _processedImageUrl == null ? 'Take Photo' : 'Retake Photo',
                style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 16),

            // Form fields
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: GoogleFonts.ibmPlexMono(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _schoolIdController,
              decoration: InputDecoration(
                labelText: 'School ID',
                labelStyle: GoogleFonts.ibmPlexMono(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              style: GoogleFonts.ibmPlexMono(color: Colors.white),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Return Date',
                  labelStyle: GoogleFonts.ibmPlexMono(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                child: Text(
                  _returnDate == null
                      ? 'Select Date'
                      : DateFormat('yyyy-MM-dd').format(_returnDate!),
                  style: GoogleFonts.ibmPlexMono(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.ibmPlexMono(
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _submitData,
                  child: Text(
                    'Next',
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
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }
}
