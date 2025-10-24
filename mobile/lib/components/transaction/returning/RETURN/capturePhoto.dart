import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'itemModel.dart';

const kGreen = Color(0xFF34C759);

class CapturePhoto extends StatefulWidget {
  final List<ReturnItem> items; // FIXED: Receive items from scan screen

  const CapturePhoto({super.key, required this.items});

  @override
  State<CapturePhoto> createState() => _CapturePhotoState();
}

class _CapturePhotoState extends State<CapturePhoto> {
  XFile? _captured;

  @override
  void initState() {
    super.initState();
    // Immediately open camera on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openCamera();
    });
  }

  Future<void> _openCamera() async {
    HapticFeedback.mediumImpact();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _captured = picked);
    }
  }

  void _done() {
    // FIXED: Return both photoPath and items (including conditions)
    Navigator.pop(context, {
      'photoPath': _captured?.path,
      'items': widget.items
          .map((e) => e.toJson())
          .toList(), // Pass back the items with conditions
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Capture Photo',
          style: GoogleFonts.ibmPlexMono(color: Colors.white),
        ),
      ),
      body: _captured == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: kGreen),
                  SizedBox(height: 16),
                  Text(
                    'Opening Camera...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : _preview(),
    );
  }

  Widget _preview() {
    return Stack(
      children: [
        if (_captured != null)
          Positioned.fill(
            child: Image.file(File(_captured!.path), fit: BoxFit.cover),
          ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _captured = null);
                      // Re-open camera immediately on retake
                      _openCamera();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Retake', style: GoogleFonts.ibmPlexMono()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _done,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Use Photo',
                      style: GoogleFonts.ibmPlexMono(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
