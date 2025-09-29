import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class TakePhoto extends StatefulWidget {
  final Function(File?) onPhotoTaken; // ✅ renamed for clarity
  final VoidCallback onNext;

  const TakePhoto({Key? key, required this.onPhotoTaken, required this.onNext})
    : super(key: key);

  @override
  _TakePhotoState createState() => _TakePhotoState();
}

class _TakePhotoState extends State<TakePhoto> {
  File? _photo;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Automatically open camera on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePhoto();
    });
  }

  Future<void> _capturePhoto() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final image = img.decodeImage(await imageFile.readAsBytes());
        if (image == null) return;

        // Add timestamp watermark
        final timestamp = DateTime.now().toString();

        img.drawString(
          image,
          timestamp, // text to draw
          font: img.arial24,
          x: 10,
          y: 10,
          color: img.ColorUint8.rgba(255, 255, 255, 255), // white text
        );

        // Save to temporary file
        final tempDir = await Directory.systemTemp.createTemp();
        final tempPath =
            '${tempDir.path}/borrower_${timestamp.replaceAll(':', '-')}.png';
        await File(tempPath).writeAsBytes(img.encodePng(image));

        setState(() {
          _photo = File(tempPath);
        });

        // ✅ Pass photo back to parent
        widget.onPhotoTaken(_photo);
      } else {
        Navigator.of(context).pop(); // User canceled camera
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_photo == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Image.file(_photo!, fit: BoxFit.cover)),
          Positioned(
            bottom: 40,
            right: 20,
            child: ElevatedButton(
              onPressed: widget.onNext,
              child: const Text("Next"),
            ),
          ),
        ],
      ),
    );
  }
}
