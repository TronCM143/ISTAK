import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class InputFields extends StatefulWidget {
  final File? photo; // <-- added photo input
  final Function(File?) onPhotoTaken;
  final Function(Map<String, String>) onDataEntered;
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const InputFields({
    Key? key,
    required this.onDataEntered,
    required this.onNext,
    required this.onPhotoTaken,
    required this.onCancel,
    this.photo,
  }) : super(key: key);

  @override
  _InputFieldsState createState() => _InputFieldsState();
}

class _InputFieldsState extends State<InputFields> {
  final _nameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  DateTime? _returnDate;

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

  void _submitData() {
    if (_nameController.text.isEmpty ||
        _schoolIdController.text.isEmpty ||
        _returnDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    widget.onDataEntered({
      'borrowerName': _nameController.text,
      'schoolId': _schoolIdController.text,
      'status': 'active',
      'return_date': DateFormat('yyyy-MM-dd').format(_returnDate!),
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
            // IMAGE AT THE TOP
            if (widget.photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  widget.photo!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
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

            // FORM FIELDS BELOW
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

            // BUTTONS AT THE BOTTOM
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
