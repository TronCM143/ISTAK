import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/components/transaction/borrowing/processData.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui';
import 'package:mobile/components/transaction/borrowing/scanQRs.dart';

class BorrowerInputAndPhoto extends StatefulWidget {
  const BorrowerInputAndPhoto({Key? key}) : super(key: key);

  @override
  _BorrowerInputAndPhotoState createState() => _BorrowerInputAndPhotoState();
}

class _BorrowerInputAndPhotoState extends State<BorrowerInputAndPhoto> {
  final _nameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  DateTime? _returnDate;
  File? _photo;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();

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

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (pickedFile != null) {
        setState(() {
          _photo = File(pickedFile.path);
          _imageUrl = null; // Reset image_url
          print('📸 Photo captured: ${pickedFile.path}');
        });

        // Check connectivity and process image if online
        final connectivity = await Connectivity().checkConnectivity();
        if (connectivity != ConnectivityResult.none) {
          await _processImage();
        }
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
        ..fields['name'] = _nameController.text
        ..fields['school_id'] = _schoolIdController.text
        ..files.add(await http.MultipartFile.fromPath('image', _photo!.path));

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
        print('❌ Image processing error: $e');
      }
      // Fallback to using raw photo if processing fails
      setState(() {
        _imageUrl = null;
      });
    }
  }

  void _submitData() {
    if (_nameController.text.isEmpty ||
        _schoolIdController.text.isEmpty ||
        _returnDate == null ||
        _photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields and capture a photo'),
        ),
      );
      return;
    }

    final borrowerData = {
      'name': _nameController.text,
      'school_id': _schoolIdController.text,
      'status': 'active',
      'return_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
      if (_imageUrl != null) 'image_url': _imageUrl!,
      if (_imageUrl == null) 'photo_path': _photo!.path,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerDialog(
          allowMultiple: true,
          initial: const {},
          onItemsScanned: (scannedIds) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProcessTransaction(
                  borrowerData: borrowerData,
                  scannedItems: scannedIds
                      .map((id) => {'item_id': id})
                      .toList(),
                  onReset: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
              ),
            );
          },
          onFinish: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16.0),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
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
                          child: _photo != null
                              ? Image.file(
                                  _photo!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    'No Photo',
                                    style: GoogleFonts.ibmPlexMono(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
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
                            child: Text(
                              _photo == null ? 'Take Photo' : 'Retake Photo',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF34C759),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          child: TextField(
                            controller: _nameController,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              labelStyle: GoogleFonts.ibmPlexMono(
                                color: Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: GoogleFonts.ibmPlexMono(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          child: TextField(
                            controller: _schoolIdController,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              labelText: 'School ID',
                              labelStyle: GoogleFonts.ibmPlexMono(
                                color: Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            style: GoogleFonts.ibmPlexMono(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _selectDate(context),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _returnDate == null
                                          ? 'Select Date'
                                          : DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(_returnDate!),
                                      style: GoogleFonts.ibmPlexMono(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _submitData,
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
                                  'Next',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
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
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }
}
