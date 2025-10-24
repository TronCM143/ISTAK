// lib/components/transaction/report/report_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/components/transaction/returning/report/summar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class ReportInputScreen extends StatefulWidget {
  const ReportInputScreen({super.key});

  @override
  State<ReportInputScreen> createState() => _ReportInputScreenState();
}

class _ReportInputScreenState extends State<ReportInputScreen> {
  static const kGreen = Color(0xFF34C759);
  static const kDarkBg = Color(0xFF0A0A0A);
  static const kCardBg = Color(0xFF1A1A1A);
  static const kTextPrimary =
      Colors.white; // Primary text (e.g., titles, main content)
  static const kTextSecondary =
      Colors.white70; // Secondary text (e.g., labels, subtitles)
  static const kBorder = Colors.white24; // Subtle borders for inputs/cards
  final _name = TextEditingController();
  final _schoolId = TextEditingController();
  File? _photo; // Added missing _photo variable declaration

  bool _loading = false;
  List<Map<String, dynamic>> _transactions = []; // raw transactions
  List<Map<String, dynamic>> _items =
      []; // flattened items for condition selection

  // condition per item_id
  final Map<String, String> _selectedCondition = {};

  String get _apiBase => dotenv.env['BASE_URL']!.replaceAll(RegExp(r'/$'), '');

  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('access_token'); // adjust to your key name
  }

  Future<void> _pickPhoto() async {
    if (_name.text.isEmpty || _schoolId.text.isEmpty) {
      _alert('Missing info', 'Please enter Name and School ID first.');
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _processImageAndLoadTransactions() async {
    if (_name.text.isEmpty || _schoolId.text.isEmpty || _photo == null) {
      _alert('Incomplete', 'Enter details and take a photo first.');
      return;
    }
    setState(() => _loading = true);
    try {
      // 1) POST /api/process_image/
      final t = await _token();
      final req =
          http.MultipartRequest(
              'POST',
              Uri.parse('$_apiBase/api/process_image/'),
            )
            ..headers['Authorization'] = 'Bearer $t'
            ..fields['name'] = _name.text.trim()
            ..fields['school_id'] = _schoolId.text.trim()
            ..files.add(
              await http.MultipartFile.fromPath('image', _photo!.path),
            );
      final resp = await req.send();
      if (resp.statusCode != 200) {
        final body = await resp.stream.bytesToString();
        throw Exception('process_image failed: ${resp.statusCode} $body');
      }

      // 2) GET /api/borrowers/ → find borrower id by schoolId
      final borrowers = await _getBorrowers();
      final borrower = borrowers.firstWhere(
        (b) => (b['school_id'] ?? '').toString() == _schoolId.text.trim(),
        orElse: () => {},
      );
      if (borrower.isEmpty) {
        throw Exception('No borrower found for School ID ${_schoolId.text}');
      }
      final borrowerId = borrower['id'];

      // 3) GET /api/borrowers/{id}/transactions/
      final tx = (await _getBorrowerTransactions(
        borrowerId,
      )).cast<Map<String, dynamic>>();
      // flatten items with their transaction reference so we can choose conditions
      final flattened = <Map<String, dynamic>>[];
      for (final tr in tx) {
        final items = (tr['items'] as List?) ?? [];
        for (final it in items) {
          flattened.add({
            'transaction_id': tr['id'],
            'item_id': it['id'],
            'item_name': it['item_name'],
            'image': it['image'],
            'current_condition': it['condition'] ?? 'Damaged',
            'status': tr['status'],
          });
        }
      }

      setState(() {
        _transactions = tx;
        _items = flattened;
        _selectedCondition.clear();
        for (final it in _items) {
          _selectedCondition[it['item_id']] = 'Damaged'; // default
        }
      });
    } catch (e) {
      _alert('Error', '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<List<dynamic>> _getBorrowers() async {
    final t = await _token();
    final r = await http.get(
      Uri.parse('$_apiBase/api/borrowers/'),
      headers: {'Authorization': 'Bearer $t'},
    );
    if (r.statusCode != 200) throw Exception('Failed to fetch borrowers');
    return jsonDecode(r.body) as List;
  }

  Future<List<dynamic>> _getBorrowerTransactions(int borrowerId) async {
    final t = await _token();
    final r = await http.get(
      Uri.parse('$_apiBase/api/borrowers/$borrowerId/transactions/'),
      headers: {'Authorization': 'Bearer $t'},
    );
    if (r.statusCode != 200) throw Exception('Failed to fetch transactions');
    return jsonDecode(r.body) as List;
  }

  void _showSummaryAndSubmit() {
    if (_items.isEmpty) {
      _alert('Nothing to submit', 'No items found for this borrower.');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Summary',
                style: GoogleFonts.ibmPlexMono(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ..._items.map((it) {
                final cond = _selectedCondition[it['item_id']] ?? 'Damaged';
                return ListTile(
                  dense: true,
                  title: Text(
                    it['item_name'],
                    style: GoogleFonts.ibmPlexMono(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Condition: $cond',
                    style: GoogleFonts.ibmPlexMono(color: Colors.white70),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close the dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SummaryScreen(
                              items: _items.map((it) {
                                return {
                                  'item_id': it['item_id'],
                                  'item_name': it['item_name'],
                                  'condition':
                                      _selectedCondition[it['item_id']] ??
                                      'Damaged',
                                };
                              }).toList(),
                              photoPath: _photo!.path, // Pass String path
                              schoolId: _schoolId.text.trim(),
                              isReport: true,
                            ),
                          ),
                        );
                      },
                      child: const Text('Review & Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_photo == null) {
      _alert('Missing photo', 'Capture a photo before submitting.');
      return;
    }
    setState(() => _loading = true);
    try {
      final t = await _token();
      final req =
          http.MultipartRequest('POST', Uri.parse('$_apiBase/api/return_item/'))
            ..headers['Authorization'] = 'Bearer $t'
            ..fields['school_id'] = _schoolId.text.trim()
            ..fields['is_report'] = 'true'
            ..files.add(
              await http.MultipartFile.fromPath('return_image', _photo!.path),
            );

      // Backend expects: items[i][itemId], items[i][condition]
      var i = 0;
      for (final it in _items) {
        final itemId = it['item_id'].toString();
        final cond = _selectedCondition[itemId] ?? 'Damaged';
        req.fields['items[$i][itemId]'] = itemId;
        req.fields['items[$i][condition]'] = cond;
        i++;
      }

      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode != 200) {
        throw Exception('return_item failed: ${resp.statusCode} $body');
      }

      final data = jsonDecode(body);
      final url = data['image_url'];
      _alert('Success', 'Report saved.\n${url ?? ""}');
      // Clear selections
      setState(() {
        _transactions = [];
        _items = [];
        _selectedCondition.clear();
        // Keep name/schoolId for next report if desired
      });
    } catch (e) {
      _alert('Submit failed', '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _alert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: GoogleFonts.ibmPlexMono(color: Colors.white)),
        content: Text(
          msg,
          style: GoogleFonts.ibmPlexMono(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _schoolId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: AppBar(
        backgroundColor: kDarkBg,
        elevation: 0,
        title: Text(
          'Report Lost/Damaged',
          style: GoogleFonts.ibmPlexMono(
            color: kTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter Details',
                    style: GoogleFonts.ibmPlexMono(
                      color: kTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    style: GoogleFonts.ibmPlexMono(color: kTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: GoogleFonts.ibmPlexMono(
                        color: kTextSecondary,
                      ),
                      filled: true,
                      fillColor: kCardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _schoolId,
                    style: GoogleFonts.ibmPlexMono(color: kTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'School ID',
                      labelStyle: GoogleFonts.ibmPlexMono(
                        color: kTextSecondary,
                      ),
                      filled: true,
                      fillColor: kCardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: kGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          // icon: const Icon(
                          //   Icons.camera_alt_outlined,
                          //   color: kGreen,
                          // ),
                          label: Text(
                            'Take a pic',
                            style: GoogleFonts.ibmPlexMono(
                              color: kGreen,
                              fontSize: 23,
                            ),
                          ),
                          onPressed: _pickPhoto,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kGreen,
                            side: BorderSide(color: kGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_photo != null)
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_photo!, fit: BoxFit.cover),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search, color: Colors.black),
                    label: Text(
                      'Find Transactions',
                      style: GoogleFonts.ibmPlexMono(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _processImageAndLoadTransactions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_items.isNotEmpty) ...[
                    Text(
                      'Select Condition per Item',
                      style: GoogleFonts.ibmPlexMono(
                        color: kTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._items.map((it) {
                      final itemId = it['item_id'].toString();
                      final current = _selectedCondition[itemId] ?? 'Damaged';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: kCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: kBorder),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: it['image'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.network(
                                    it['image'],
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              color: kTextSecondary,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  color: kTextSecondary,
                                ),
                          title: Text(
                            it['item_name'],
                            style: GoogleFonts.ibmPlexMono(color: kTextPrimary),
                          ),
                          subtitle: Text(
                            'Current: ${it['current_condition'] ?? 'Damaged'}  |  Status: ${it['status']}',
                            style: GoogleFonts.ibmPlexMono(
                              color: kTextSecondary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: kCardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: current,
                                style: GoogleFonts.ibmPlexMono(
                                  color: kTextPrimary,
                                ),
                                dropdownColor: kDarkBg,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Damaged',
                                    child: Text('Damaged'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Lost',
                                    child: Text('Lost'),
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(
                                    () => _selectedCondition[itemId] =
                                        val ?? 'Damaged',
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.save_outlined,
                        color: Colors.black,
                      ),
                      label: Text(
                        'Review & Save',
                        style: GoogleFonts.ibmPlexMono(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _showSummaryAndSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_loading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: kGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
