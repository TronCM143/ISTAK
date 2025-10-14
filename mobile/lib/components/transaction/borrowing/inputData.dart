import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/components/transaction/borrowing/processData.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mobile/components/transaction/borrowing/scanQRs.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class BorrowerInputAndPhoto extends StatefulWidget {
  const BorrowerInputAndPhoto({
    Key? key,
    required void Function(String borrowerName) onSuccess,
  }) : super(key: key);

  @override
  _BorrowerInputAndPhotoState createState() => _BorrowerInputAndPhotoState();
}

class _BorrowerInputAndPhotoState extends State<BorrowerInputAndPhoto>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  DateTime? _returnDate;
  File? _photo;
  String? _imageUrl;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
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
                  'Error',
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please enter name and school ID first',
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF32D74B),
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
          _imageUrl = null;
          print('📸 Photo captured: ${pickedFile.path}');
        });

        // final connectivity = await Connectivity().checkConnectivity();
        // if (connectivity != ConnectivityResult.none) {
        //   await _processImage();
        // }
      } else {
        print('❌ No photo selected');
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
                    'Error',
                    style: GoogleFonts.ibmPlexMono(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Error capturing photo: $e',
                    style: GoogleFonts.ibmPlexMono(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF32D74B),
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
        print('❌ Capture error: $e');
      }
    }
  }

  // Future<void> _processImage() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('access_token');
  //     if (token == null) {
  //       throw Exception('No JWT token found. Please log in again.');
  //     }

  //     final url = Uri.parse("${dotenv.env['BASE_URL']}/api/process_image/");
  //     final request = http.MultipartRequest('POST', url)
  //       ..headers['Authorization'] = 'Bearer $token'
  //       ..fields['name'] = _nameController.text
  //       ..fields['school_id'] = _schoolIdController.text
  //       ..files.add(await http.MultipartFile.fromPath('image', _photo!.path));

  //     final response = await request.send();
  //     final responseBody = await http.Response.fromStream(response);

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(responseBody.body);
  //       setState(() {
  //         _imageUrl = data['image_url'];
  //         print('✅ Image processed: $_imageUrl');
  //       });
  //     } else {
  //       throw Exception('Image processing failed: ${responseBody.body}');
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       await showDialog(
  //         context: context,
  //         barrierDismissible: true,
  //         barrierColor: Colors.black.withOpacity(0.6),
  //         builder: (context) => Dialog(
  //           backgroundColor: Colors.black,
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(16),
  //           ),
  //           child: Container(
  //             padding: const EdgeInsets.all(20),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Text(
  //                   'Error',
  //                   style: GoogleFonts.ibmPlexMono(
  //                     color: Colors.white,
  //                     fontSize: 18,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 12),
  //                 Text(
  //                   'Error processing image: $e',
  //                   style: GoogleFonts.ibmPlexMono(
  //                     color: Colors.white,
  //                     fontSize: 14,
  //                   ),
  //                   textAlign: TextAlign.center,
  //                 ),
  //                 const SizedBox(height: 20),
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     color: Color(0xFF32D74B),
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                   child: TextButton(
  //                     onPressed: () => Navigator.of(context).pop(),
  //                     child: Text(
  //                       'OK',
  //                       style: GoogleFonts.ibmPlexMono(
  //                         fontWeight: FontWeight.w600,
  //                         fontSize: 14,
  //                         color: Colors.white,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //       print('❌ Image processing error: $e');
  //     }
  //     setState(() {
  //       _imageUrl = null;
  //     });
  //   }
  // }

  void _submitData() {
    if (_nameController.text.isEmpty ||
        _schoolIdController.text.isEmpty ||
        _returnDate == null ||
        _photo == null) {
      showDialog(
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
                  'Error',
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please fill all fields and capture a photo',
                  style: GoogleFonts.ibmPlexMono(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF32D74B),
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
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 13.0, sigmaY: 12),
          child: Container(color: Colors.transparent),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.transparent, // Solid black background
          ),
        ),
        FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: FakeGlass(
              shape: LiquidRoundedSuperellipse(
                borderRadius: const Radius.circular(30),
              ),
              settings: const LiquidGlassSettings(
                blur: 200,
                thickness: 50, // controls optical depth (refraction)
                glassColor: Color.fromARGB(
                  26,
                  87,
                  87,
                  87,
                ), // dark translucent tint
                lightIntensity: 1.25, // highlight brightness
                ambientStrength: 0.5, // soft glow
                saturation: 1.05,
              ),

              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                margin: const EdgeInsets.all(20),
                // decoration: BoxDecoration(
                //   color: const Color.fromARGB(255, 19, 19, 19),
                //   borderRadius: BorderRadius.circular(20),
                //   border: Border.all(
                //     color: Colors.white.withOpacity(0.3),
                //     width: 0.3,
                //   ),
                // ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, 20, 90, 31),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Text(
                              _photo == null ? 'Take Photo' : 'Retake Photo',
                              style: GoogleFonts.ibmPlexMono(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FakeGlass(
                        shape: LiquidRoundedSuperellipse(
                          borderRadius: const Radius.circular(10),
                        ),
                        settings: const LiquidGlassSettings(
                          thickness: 50, // controls optical depth (refraction)
                          glassColor: Color.fromARGB(
                            26,
                            87,
                            87,
                            87,
                          ), // dark translucent tint
                          lightIntensity: 1.25, // highlight brightness
                          ambientStrength: 0.5, // soft glow
                          saturation: 1.05,
                        ),
                        child: Container(
                          // decoration: BoxDecoration(
                          //   color: Colors.grey[900],
                          //   borderRadius: BorderRadius.circular(12),
                          // ),
                          child: TextField(
                            controller: _nameController,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
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

                      const SizedBox(height: 12),
                      FakeGlass(
                        shape: LiquidRoundedSuperellipse(
                          borderRadius: const Radius.circular(10),
                        ),
                        settings: const LiquidGlassSettings(
                          thickness: 50, // controls optical depth (refraction)
                          glassColor: Color.fromARGB(
                            26,
                            87,
                            87,
                            87,
                          ), // dark translucent tint
                          lightIntensity: 1.25, // highlight brightness
                          ambientStrength: 0.5, // soft glow
                          saturation: 1.05,
                        ),
                        child: Container(
                          // decoration: BoxDecoration(
                          //   color: Colors.grey[900],
                          //   borderRadius: BorderRadius.circular(12),
                          // ),
                          child: TextField(
                            controller: _schoolIdController,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              labelText: 'School ID',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
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

                      const SizedBox(height: 12),
                      FakeGlass(
                        shape: LiquidRoundedSuperellipse(
                          borderRadius: const Radius.circular(10),
                        ),
                        settings: const LiquidGlassSettings(
                          thickness: 50, // controls optical depth (refraction)
                          glassColor: Color.fromARGB(
                            26,
                            87,
                            87,
                            87,
                          ), // dark translucent tint
                          lightIntensity: 1.25, // highlight brightness
                          ambientStrength: 0.5, // soft glow
                          saturation: 1.05,
                        ),
                        child: Container(
                          // decoration: BoxDecoration(
                          //   color: Colors.grey[900],
                          //   borderRadius: BorderRadius.circular(12),
                          // ),
                          child: GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
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

                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0x4DFFFFFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 22, 101, 34),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: GestureDetector(
                              onTap: _submitData,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Next',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontSize: 14,
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
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolIdController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}
